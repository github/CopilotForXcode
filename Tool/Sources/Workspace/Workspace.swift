import Foundation
import Preferences
import UserDefaultsObserver
import XcodeInspector
import Logger
import UniformTypeIdentifiers
import LanguageServerProtocol

enum Environment {
    static var now = { Date() }
}

public protocol WorkspacePropertyKey {
    associatedtype Value
    static func createDefaultValue() -> Value
}

public class WorkspacePropertyValues {
    private var storage: [ObjectIdentifier: Any] = [:]

    @WorkspaceActor
    public subscript<K: WorkspacePropertyKey>(_ key: K.Type) -> K.Value {
        get {
            if let value = storage[ObjectIdentifier(key)] as? K.Value {
                return value
            }
            let value = key.createDefaultValue()
            storage[ObjectIdentifier(key)] = value
            return value
        }
        set {
            storage[ObjectIdentifier(key)] = newValue
        }
    }
}

open class WorkspacePlugin {
    public private(set) weak var workspace: Workspace?
    public var projectRootURL: URL { workspace?.projectRootURL ?? URL(fileURLWithPath: "/") }
    public var workspaceURL: URL { workspace?.workspaceURL ?? projectRootURL }
    public var filespaces: [URL: Filespace] { workspace?.filespaces ?? [:] }

    public init(workspace: Workspace) {
        self.workspace = workspace
    }

    open func didOpenFilespace(_: Filespace) async {}
    open func didSaveFilespace(_: Filespace) {}
    open func didUpdateFilespace(_: Filespace, content: String, contentChanges: [TextDocumentContentChangeEvent]?) async {}
    open func didCloseFilespace(_: URL) {}
}

@dynamicMemberLookup
public final class Workspace {
    public enum WorkspaceFileError: LocalizedError {
        case unsupportedFile(extensionName: String)
        case fileNotFound(fileURL: URL)
        case invalidFileFormat(fileURL: URL)
        
        public var errorDescription: String? {
            switch self {
            case .unsupportedFile(let extensionName):
                return "File type \(extensionName) unsupported."
            case .fileNotFound(let fileURL):
                return "File \(fileURL) not found."
            case .invalidFileFormat(let fileURL):
                return "The file \(fileURL.lastPathComponent) couldn't be opened because it isn't in the correct format."
            }
        }
    }

    public struct CantFindWorkspaceError: Error, LocalizedError {
        public var errorDescription: String? {
            "Can't find workspace."
        }
    }

    private var additionalProperties = WorkspacePropertyValues()
    public internal(set) var plugins = [ObjectIdentifier: WorkspacePlugin]()
    public let workspaceURL: URL
    public let projectRootURL: URL
    public let openedFileRecoverableStorage: OpenedFileRecoverableStorage
    public private(set) var lastLastUpdateTime = Environment.now()
    public var isExpired: Bool {
        Environment.now().timeIntervalSince(lastLastUpdateTime) > 60 * 60 * 1
    }

    public private(set) var filespaces = [URL: Filespace]()

    let userDefaultsObserver = UserDefaultsObserver(
        object: UserDefaults.shared, forKeyPaths: [
            UserDefaultPreferenceKeys().suggestionFeatureEnabledProjectList.key,
            UserDefaultPreferenceKeys().disableSuggestionFeatureGlobally.key,
        ], context: nil
    )

    public subscript<K>(
        dynamicMember dynamicMember: WritableKeyPath<WorkspacePropertyValues, K>
    ) -> K {
        get { additionalProperties[keyPath: dynamicMember] }
        set { additionalProperties[keyPath: dynamicMember] = newValue }
    }

    public func plugin<P: WorkspacePlugin>(for type: P.Type) -> P? {
        plugins[ObjectIdentifier(type)] as? P
    }

    init(workspaceURL: URL) {
        self.workspaceURL = workspaceURL
        self.projectRootURL = WorkspaceXcodeWindowInspector.extractProjectURL(
            workspaceURL: workspaceURL,
            documentURL: nil
        ) ?? workspaceURL
        openedFileRecoverableStorage = .init(projectRootURL: projectRootURL)
        let openedFiles = openedFileRecoverableStorage.openedFiles
        Task { @WorkspaceActor in
            for fileURL in openedFiles {
                do {
                    _ = try await createFilespaceIfNeeded(fileURL: fileURL)
                } catch _ as WorkspaceFileError {
                    openedFileRecoverableStorage.closeFile(fileURL: fileURL)
                } catch {
                    Logger.workspacePool.error(error)
                }
            }
        }
    }

    public func refreshUpdateTime() {
        lastLastUpdateTime = Environment.now()
    }

    @WorkspaceActor
    public func createFilespaceIfNeeded(fileURL: URL) async throws -> Filespace {
        let extensionName = fileURL.pathExtension
        
        if ["xcworkspace", "xcodeproj"].contains(
            extensionName
        ) || FileManager.default
            .fileIsDirectory(atPath: fileURL.path) {
            throw WorkspaceFileError.unsupportedFile(extensionName: extensionName)
        }
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw WorkspaceFileError.fileNotFound(fileURL: fileURL)
        }
        
        if let contentType = try fileURL.resourceValues(forKeys: [.contentTypeKey]).contentType,
           !contentType.conforms(to: UTType.data) {
            throw WorkspaceFileError.invalidFileFormat(fileURL: fileURL)
        }
        
        let content = try String(contentsOf: fileURL)
        
        let existedFilespace = filespaces[fileURL]
        let filespace = existedFilespace ?? .init(
            fileURL: fileURL,
            content: content,
            onSave: { [weak self] filespace in
                guard let self else { return }
                self.didSaveFilespace(filespace)
            },
            onClose: { [weak self] url in
                guard let self else { return }
                self.didCloseFilespace(url)
            }
        )
        if filespaces[fileURL] == nil {
            filespaces[fileURL] = filespace
        }
        if existedFilespace == nil {
            await didOpenFilespace(filespace)
        } else {
            filespace.refreshUpdateTime()
        }
        return filespace
    }

    @WorkspaceActor
    public func closeFilespace(fileURL: URL) {
        filespaces[fileURL] = nil
    }

    @WorkspaceActor
    public func didUpdateFilespace(fileURL: URL, content: String) async {
        refreshUpdateTime()
        guard let filespace = filespaces[fileURL] else { return }
        filespace.bumpVersion()
        filespace.refreshUpdateTime()
        
        let oldContent = filespace.fileContent
        
        // Calculate incremental changes if NES is enabled and we have old content
        let changes: [TextDocumentContentChangeEvent]? = {
            guard let oldContent = oldContent else { return nil }
            return calculateIncrementalChanges(oldContent: oldContent, newContent: content)
        }()
        
        for plugin in plugins.values {
            if let changes, let oldContent {
                await plugin.didUpdateFilespace(filespace, content: oldContent, contentChanges: changes)
            } else {
                // fallback to full content sync
                await plugin.didUpdateFilespace(filespace, content: content, contentChanges: nil)
            }
        }
        
        filespace.setFileContent(content)
    }

    @WorkspaceActor
    public func didOpenFilespace(_ filespace: Filespace) async {
        refreshUpdateTime()
        openedFileRecoverableStorage.openFile(fileURL: filespace.fileURL)
        for plugin in plugins.values {
            await plugin.didOpenFilespace(filespace)
        }
    }

    @WorkspaceActor
    func didCloseFilespace(_ fileURL: URL) {
        for plugin in self.plugins.values {
            plugin.didCloseFilespace(fileURL)
        }
    }

    @WorkspaceActor
    func didSaveFilespace(_ filespace: Filespace) {
        refreshUpdateTime()
        filespace.refreshUpdateTime()
        for plugin in plugins.values {
            plugin.didSaveFilespace(filespace)
        }
    }
}

extension Workspace {
    /// Calculates incremental changes between two document states.
    /// Each change is computed on the state resulting from the previous change,
    /// as required by the LSP specification.
    ///
    /// This implementation finds the common prefix and suffix, then creates
    /// a single change event for the differing middle section. This ensures
    /// correctness while being efficient for typical editing scenarios.
    ///
    /// - Parameters:
    ///   - oldContent: The original document content
    ///   - newContent: The new document content
    /// - Returns: Array of TextDocumentContentChangeEvent in order
    func calculateIncrementalChanges(
        oldContent: String,
        newContent: String
    ) -> [TextDocumentContentChangeEvent]? {
        // Handle identical content
        if oldContent == newContent {
            return nil
        }
        
        // Handle empty old content (new file)
        if oldContent.isEmpty {
            let endPosition = calculateEndPosition(content: oldContent)
            return [TextDocumentContentChangeEvent(
                range: LSPRange(
                    start: Position(line: 0, character: 0),
                    end: Position(line: 0, character: 0)
                ),
                rangeLength: 0,
                text: newContent
            )]
        }
        
        // Handle empty new content (cleared file)
        if newContent.isEmpty {
            let endPosition = calculateEndPosition(content: oldContent)
            return [TextDocumentContentChangeEvent(
                range: LSPRange(
                    start: Position(line: 0, character: 0),
                    end: endPosition
                ),
                rangeLength: oldContent.utf16.count,
                text: ""
            )]
        }
        
        // Find common prefix
        let oldUTF16 = Array(oldContent.utf16)
        let newUTF16 = Array(newContent.utf16)
        let maxCalculationLength = 10000
        guard oldUTF16.count <= maxCalculationLength,
              newUTF16.count <= maxCalculationLength else {
            // Fallback to full replacement for very large contents
            return nil
        }
        
        var prefixLength = 0
        let minLength = min(oldUTF16.count, newUTF16.count)
        while prefixLength < minLength && oldUTF16[prefixLength] == newUTF16[prefixLength] {
            prefixLength += 1
        }
        
        // Find common suffix (after prefix)
        var suffixLength = 0
        while suffixLength < minLength - prefixLength &&
                oldUTF16[oldUTF16.count - 1 - suffixLength] == newUTF16[newUTF16.count - 1 - suffixLength] {
            suffixLength += 1
        }
        
        // Calculate positions
        let startPosition = utf16OffsetToPosition(
            content: oldContent,
            offset: prefixLength
        )
        
        let endOffset = oldUTF16.count - suffixLength
        let endPosition = utf16OffsetToPosition(
            content: oldContent,
            offset: endOffset
        )
        
        // Extract replacement text from new content
        let newStartOffset = prefixLength
        let newEndOffset = newUTF16.count - suffixLength
        
        let replacementText: String
        if newStartOffset <= newEndOffset {
            let startIndex = newContent.utf16.index(newContent.utf16.startIndex, offsetBy: newStartOffset)
            let endIndex = newContent.utf16.index(newContent.utf16.startIndex, offsetBy: newEndOffset)
            replacementText = String(newContent[startIndex..<endIndex])
        } else {
            replacementText = ""
        }
        
        let rangeLength = endOffset - prefixLength
        
        return [TextDocumentContentChangeEvent(
            range: LSPRange(
                start: startPosition,
                end: endPosition
            ),
            rangeLength: rangeLength,
            text: replacementText
        )]
    }
    
    /// Converts UTF-16 offset to LSP Position (line, character)
    private func utf16OffsetToPosition(content: String, offset: Int) -> Position {
        var line = 0
        var character = 0
        
        let utf16View = content.utf16
        let safeOffset = min(offset, utf16View.count)
        let endIndex = utf16View.index(utf16View.startIndex, offsetBy: safeOffset)
        
        for char in utf16View[..<endIndex] {
            if char == 0x000A { // Line feed (\n)
                line += 1
                character = 0
            } else {
                character += 1
            }
        }
        
        return Position(line: line, character: character)
    }
    
    /// Calculates the end position of content
    private func calculateEndPosition(content: String) -> Position {
        return utf16OffsetToPosition(content: content, offset: content.utf16.count)
    }
}
