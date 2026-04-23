import CopilotForXcodeKit
import Foundation
import Preferences
import ConversationServiceProvider
import TelemetryServiceProvider
import LanguageServerProtocol

// Exported from `CopilotForXcodeKit`, as we need to modify the protocol for document change
public protocol CopilotForXcodeExtensionCapability {
    associatedtype TheSuggestionService: SuggestionServiceType
    associatedtype TheChatService: ChatServiceType
    associatedtype ThePromptToCodeService: PromptToCodeServiceType
    
    /// The suggestion service.
    ///
    /// Provide a non nil value if the extension provides a suggestion service, even if
    /// the extension is not yet ready to provide suggestions.
    ///
    /// If you don't have a suggestion service in this extension, simply ignore this property.
    var suggestionService: TheSuggestionService? { get }
    /// Not implemented yet.
    var chatService: TheChatService? { get }
    /// Not implemented yet.
    var promptToCodeService: ThePromptToCodeService? { get }
    
    // MARK: Optional Methods
    
    /// Called when a workspace is opened.
    ///
    /// A workspace may have already been opened when the extension is activated.
    /// Use ``HostServer/getExistedWorkspaces()`` to get all ``WorkspaceInfo`` instead.
    func workspaceDidOpen(_ workspace: WorkspaceInfo)
    
    /// Called when a workspace is closed.
    func workspaceDidClose(_ workspace: WorkspaceInfo)
    
    /// Called when a document is saved.
    func workspace(_ workspace: WorkspaceInfo, didSaveDocumentAt documentURL: URL)
    
    /// Called when a document is closed.
    ///
    /// - note: Copilot for Xcode doesn't know that a document is closed. It use
    /// some mechanism to detect if the document is closed which is inaccurate and could be delayed.
    func workspace(_ workspace: WorkspaceInfo, didCloseDocumentAt documentURL: URL)
    
    /// Called when a document is opened.
    ///
    /// - note: Copilot for Xcode doesn't know that a document is opened. It use
    /// some mechanism to detect if the document is opened which is inaccurate and could be delayed.
    func workspace(_ workspace: WorkspaceInfo, didOpenDocumentAt documentURL: URL) async
    
    /// Called when a document is changed.
    ///
    /// - attention: `content` could be nil if \
    ///   • the document is too large \
    ///   • the document is binary \
    ///   • the document is git ignored \
    ///   • the extension is not considered in-use by the host app \
    ///   • the extension has no permission to access the file \
    ///   \
    ///   If you still want to access the file content in these cases,
    ///   you will have to access the file by yourself, or call ``HostServer/getDocument(at:)``.
    func workspace(
        _ workspace: WorkspaceInfo,
        didUpdateDocumentAt documentURL: URL,
        content: String?,
        contentChanges: [TextDocumentContentChangeEvent]?
    ) async
    
    /// Called occasionally to inform the extension how it is used in the app.
    ///
    /// The `usage` contains information like the current user-picked suggestion service, etc.
    /// You can use this to determine if you would like to startup or dispose some resources.
    ///
    /// For example, if you are running a language server to provide suggestions, you may want to
    /// kill the process when the suggestion service is no longer in use.
    func extensionUsageDidChange(_ usage: ExtensionUsage)
}

public extension CopilotForXcodeExtensionCapability {
    func xcodeDidBecomeActive() {}
    
    func xcodeDidBecomeInactive() {}
    
    func xcodeDidSwitchEditor() {}
    
    func workspaceDidOpen(_: WorkspaceInfo) {}
    
    func workspaceDidClose(_: WorkspaceInfo) {}
    
    func workspace(_: WorkspaceInfo, didSaveDocumentAt _: URL) {}
    
    func workspace(_: WorkspaceInfo, didCloseDocumentAt _: URL) {}
    
    func workspace(_: WorkspaceInfo, didOpenDocumentAt _: URL) async {}
    
    func workspace(
        _ workspace: WorkspaceInfo,
        didUpdateDocumentAt documentURL: URL,
        content: String?,
        contentChanges: [TextDocumentContentChangeEvent]? = nil
    ) async {}
    
    func extensionUsageDidChange(_: ExtensionUsage) {}
}

public extension CopilotForXcodeExtensionCapability
where TheSuggestionService == NoSuggestionService
{
    var suggestionService: TheSuggestionService? { nil }
}

public extension CopilotForXcodeExtensionCapability
where ThePromptToCodeService == NoPromptToCodeService
{
    var promptToCodeService: ThePromptToCodeService? { nil }
}

public extension CopilotForXcodeExtensionCapability where TheChatService == NoChatService {
    var chatService: TheChatService? { nil }
}

public typealias CopilotForXcodeCapability = CopilotForXcodeExtensionCapability & CopilotForXcodeChatCapability & CopilotForXcodeTelemetryCapability

public protocol CopilotForXcodeChatCapability {
    var conversationService: ConversationServiceType? { get }
}

public protocol CopilotForXcodeTelemetryCapability {
    var telemetryService: TelemetryServiceType? { get }
}

public protocol BuiltinExtension: CopilotForXcodeCapability {
    /// An id that let the extension manager determine whether the extension is in use.
    var suggestionServiceId: BuiltInSuggestionFeatureProvider { get }

    /// It's usually called when the app is about to quit,
    /// you should clean up all the resources here.
    func terminate()
}

