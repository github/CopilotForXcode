import CopilotForXcodeKit
import Foundation
import CodableWrappers
import LanguageServerProtocol

public protocol ConversationServiceType {
    func createConversation(_ request: ConversationRequest, workspace: WorkspaceInfo) async throws -> ConversationCreateResponse?
    func createTurn(with conversationId: String, request: ConversationRequest, workspace: WorkspaceInfo) async throws -> ConversationCreateResponse?
    func deleteTurn(with conversationId: String, turnId: String, workspace: WorkspaceInfo) async throws
    func cancelProgress(_ workDoneToken: String, workspace: WorkspaceInfo) async throws
    func rateConversation(turnId: String, rating: ConversationRating, workspace: WorkspaceInfo) async throws
    func copyCode(request: CopyCodeRequest, workspace: WorkspaceInfo) async throws
    func templates(workspace: WorkspaceInfo) async throws -> [ChatTemplate]?
    func modes(workspace: WorkspaceInfo) async throws -> [ConversationMode]?
    func models(workspace: WorkspaceInfo) async throws -> [CopilotModel]?
    func notifyDidChangeWatchedFiles(_ event: DidChangeWatchedFilesEvent, workspace: WorkspaceInfo) async throws
    func agents(workspace: WorkspaceInfo) async throws -> [ChatAgent]?
    func notifyChangeTextDocument(fileURL: URL, content: String, version: Int, workspace: WorkspaceInfo) async throws
    func reviewChanges(
        workspace: WorkspaceInfo,
        changes: [ReviewChangesParams.Change]
    ) async throws -> CodeReviewResult?
}

public protocol ConversationServiceProvider {
    func createConversation(_ request: ConversationRequest, workspaceURL: URL?) async throws -> ConversationCreateResponse?
    func createTurn(with conversationId: String, request: ConversationRequest, workspaceURL: URL?) async throws -> ConversationCreateResponse?
    func deleteTurn(with conversationId: String, turnId: String, workspaceURL: URL?) async throws
    func stopReceivingMessage(_ workDoneToken: String, workspaceURL: URL?) async throws
    func rateConversation(turnId: String, rating: ConversationRating, workspaceURL: URL?) async throws
    func copyCode(_ request: CopyCodeRequest, workspaceURL: URL?) async throws
    func templates() async throws -> [ChatTemplate]?
    func modes() async throws -> [ConversationMode]?
    func models() async throws -> [CopilotModel]?
    func notifyDidChangeWatchedFiles(_ event: DidChangeWatchedFilesEvent, workspace: WorkspaceInfo) async throws
    func agents() async throws -> [ChatAgent]?
    func notifyChangeTextDocument(fileURL: URL, content: String, version: Int, workspaceURL: URL?) async throws
    func reviewChanges(_ changes: [ReviewChangesParams.Change]) async throws -> CodeReviewResult?
}

public struct ConversationFileReference: Hashable, Codable, Equatable {
    public let url: URL
    public let relativePath: String?
    public let fileName: String?
    public var isCurrentEditor: Bool = false
    public var selection: LSPRange?
    
    public init(
        url: URL, 
        relativePath: String? = nil, 
        fileName: String? = nil, 
        isCurrentEditor: Bool = false, 
        selection: LSPRange? = nil
    ) {
        self.url = url
        self.relativePath = relativePath
        self.fileName = fileName
        self.isCurrentEditor = isCurrentEditor
        self.selection = selection
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(isCurrentEditor)
        hasher.combine(selection)
    }

    public static func == (lhs: ConversationFileReference, rhs: ConversationFileReference) -> Bool {
        return lhs.url == rhs.url && lhs.isCurrentEditor == rhs.isCurrentEditor
    }
}

public struct ConversationDirectoryReference: Hashable, Codable {
    public let url: URL
    // The project URL that this directory belongs to.
    // When directly dragging a directory into the chat, this can be nil.
    public let projectURL: URL?
    
    public var depth: Int {
        guard let projectURL else {
            return -1
        }
        
        let directoryPathComponents = url.pathComponents
        let projectPathComponents = projectURL.pathComponents
        if directoryPathComponents.count <= projectPathComponents.count {
            return 0
        }
        return directoryPathComponents.count - projectPathComponents.count
    }
    
    public var relativePath: String {
        guard let projectURL else {
            return url.path
        }
        
        return url.path.replacingOccurrences(of: projectURL.path, with: "")
    }
    
    public var displayName: String { url.lastPathComponent }
    
    public init(url: URL, projectURL: URL? = nil) {
        self.url = url
        self.projectURL = projectURL
    }
}

extension ConversationDirectoryReference: Equatable {
    public static func == (lhs: ConversationDirectoryReference, rhs: ConversationDirectoryReference) -> Bool {
        lhs.url.path == rhs.url.path && lhs.projectURL == rhs.projectURL
    }
}

public enum ConversationAttachedReference: Hashable, Codable, Equatable {
    case file(ConversationFileReference)
    case directory(ConversationDirectoryReference)
    
    public var url: URL { 
        switch self {
        case .directory(let ref):
            return ref.url
        case .file(let ref):
            return ref.url
        }
    }
    
    public var isDirectory: Bool {
        switch self {
        case .directory: true
        case .file: false
        }
    }
    
    public var relativePath: String {
        switch self {
        case .directory(let dir): dir.relativePath
        case .file(let file): 
            file.relativePath ?? file.url.lastPathComponent
        }
    }
    
    public var displayName: String {
        switch self {
        case .directory(let dir): dir.displayName
        case .file(let file):
            file.fileName ?? file.url.lastPathComponent
        }
    }
}

public enum ImageReferenceSource: String, Codable {
    case file = "file"
    case pasted = "pasted"
    case screenshot = "screenshot"
}

public struct ImageReference: Equatable, Codable, Hashable {
    public var data: Data
    public var fileUrl: URL?
    public var source: ImageReferenceSource
    
    public init(data: Data, source: ImageReferenceSource) {
        self.data = data
        self.source = source
    }
    
    public init(data: Data, fileUrl: URL) {
        self.data = data
        self.fileUrl = fileUrl
        self.source = .file
    }
    
    public func dataURL(imageType: String = "") -> String {
        let base64String = data.base64EncodedString()
        var type = imageType
        if let url = fileUrl, imageType.isEmpty {
            type = url.pathExtension
        }
            
        let mimeType: String
        switch type {
        case "png":
            mimeType = "image/png"
        case "jpeg", "jpg":
            mimeType = "image/jpeg"
        case "bmp":
            mimeType = "image/bmp"
        case "gif":
            mimeType = "image/gif"
        case "webp":
            mimeType = "image/webp"
        case "tiff", "tif":
            mimeType = "image/tiff"
        default:
            mimeType = "image/png"
        }
        
        return "data:\(mimeType);base64,\(base64String)"
    }
}

public enum MessageContentType: String, Codable {
    case text = "text"
    case imageUrl = "image_url"
}

public enum ImageDetail: String, Codable {
    case low = "low"
    case high = "high"
}

public struct ChatCompletionImageURL: Codable,Equatable {
    let url: String
    let detail: ImageDetail?
    
    public init(url: String, detail: ImageDetail? = nil) {
        self.url = url
        self.detail = detail
    }
}

public struct ChatCompletionContentPartText: Codable, Equatable {
    public let type: MessageContentType
    public let text: String
    
    public init(text: String) {
        self.type = .text
        self.text = text
    }
}

public struct ChatCompletionContentPartImage: Codable, Equatable {
    public let type: MessageContentType
    public let imageUrl: ChatCompletionImageURL
    
    public init(imageUrl: ChatCompletionImageURL) {
        self.type = .imageUrl
        self.imageUrl = imageUrl
    }
    
    public init(url: String, detail: ImageDetail? = nil) {
        self.type = .imageUrl
        self.imageUrl = ChatCompletionImageURL(url: url, detail: detail)
    }
}

public enum ChatCompletionContentPart: Codable, Equatable {
    case text(ChatCompletionContentPartText)
    case imageUrl(ChatCompletionContentPartImage)

    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(MessageContentType.self, forKey: .type)
        
        switch type {
        case .text:
            self = .text(try ChatCompletionContentPartText(from: decoder))
        case .imageUrl:
            self = .imageUrl(try ChatCompletionContentPartImage(from: decoder))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let content):
            try content.encode(to: encoder)
        case .imageUrl(let content):
            try content.encode(to: encoder)
        }
    }
}

public enum MessageContent: Codable, Equatable {
    case string(String)
    case messageContentArray([ChatCompletionContentPart])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let arrayValue = try? container.decode([ChatCompletionContentPart].self) {
            self = .messageContentArray(arrayValue)
        } else {
            throw DecodingError.typeMismatch(MessageContent.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Array of MessageContent"))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .messageContentArray(let value):
            try container.encode(value)
        }
    }
}

public struct TurnSchema: Codable {
    public var request: MessageContent
    public var response: String?
    public var agentSlug: String?
    public var turnId: String?
    
    public init(request: String, response: String? = nil, agentSlug: String? = nil, turnId: String? = nil) {
        self.request = .string(request)
        self.response = response
        self.agentSlug = agentSlug
        self.turnId = turnId
    }
    
    public init(
        request: [ChatCompletionContentPart],
        response: String? = nil,
        agentSlug: String? = nil,
        turnId: String? = nil
    ) {
        self.request = .messageContentArray(request)
        self.response = response
        self.agentSlug = agentSlug
        self.turnId = turnId
    }
    
    public init(request: MessageContent, response: String? = nil, agentSlug: String? = nil, turnId: String? = nil) {
        self.request = request
        self.response = response
        self.agentSlug = agentSlug
        self.turnId = turnId
    }
}

public struct ConversationRequest {
    public var workDoneToken: String
    public var content: String
    public var contentImages: [ChatCompletionContentPartImage] = []
    public var workspaceFolder: String
    public var activeDoc: Doc?
    public var skills: [String]
    public var ignoredSkills: [String]?
    public var references: [ConversationAttachedReference]?
    public var model: String?
    public var modelProviderName: String?
    public var turns: [TurnSchema]
    public var agentMode: Bool = false
    public var customChatModeId: String? = nil
    public var userLanguage: String? = nil
    public var turnId: String? = nil

    public init(
        workDoneToken: String,
        content: String,
        contentImages: [ChatCompletionContentPartImage] = [],
        workspaceFolder: String,
        activeDoc: Doc? = nil,
        skills: [String],
        ignoredSkills: [String]? = nil,
        references: [ConversationAttachedReference]? = nil,
        model: String? = nil,
        modelProviderName: String? = nil,
        turns: [TurnSchema] = [],
        agentMode: Bool = false,
        customChatModeId: String? = nil,
        userLanguage: String?,
        turnId: String? = nil
    ) {
        self.workDoneToken = workDoneToken
        self.content = content
        self.contentImages = contentImages
        self.workspaceFolder = workspaceFolder
        self.activeDoc = activeDoc
        self.skills = skills
        self.ignoredSkills = ignoredSkills
        self.references = references
        self.model = model
        self.modelProviderName = modelProviderName
        self.turns = turns
        self.agentMode = agentMode
        self.customChatModeId = customChatModeId
        self.userLanguage = userLanguage
        self.turnId = turnId
    }
}

public struct CopyCodeRequest {
    public var turnId: String
    public var codeBlockIndex: Int
    public var copyType: CopyKind
    public var copiedCharacters: Int
    public var totalCharacters: Int
    public var copiedText: String
    
    init(turnId: String, codeBlockIndex: Int, copyType: CopyKind, copiedCharacters: Int, totalCharacters: Int, copiedText: String) {
        self.turnId = turnId
        self.codeBlockIndex = codeBlockIndex
        self.copyType = copyType
        self.copiedCharacters = copiedCharacters
        self.totalCharacters = totalCharacters
        self.copiedText = copiedText
    }
}

public enum ConversationRating: Int, Codable {
    case unrated = 0
    case helpful = 1
    case unhelpful = -1
}

public enum CopyKind: Int, Codable {
    case keyboard = 1
    case toolbar = 2
}


public struct ConversationFollowUp: Codable, Equatable {
    public var message: String
    public var id: String
    public var type: String
    
    public init(message: String, id: String, type: String) {
        self.message = message
        self.id = id
        self.type = type
    }
}

public struct ConversationProgressStep: Codable, Equatable, Identifiable {
    public enum StepStatus: String, Codable {
        case running, completed, failed, cancelled
    }
    
    public struct StepError: Codable, Equatable {
        public let message: String
    }
    
    public let id: String
    public let title: String
    public let description: String?
    public var status: StepStatus
    public let error: StepError?
    
    public init(id: String, title: String, description: String?, status: StepStatus, error: StepError?) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.error = error
    }
}

public struct DidChangeWatchedFilesEvent: Codable {
    public var workspaceUri: String
    public var changes: [FileEvent]
    
    public init(workspaceUri: String, changes: [FileEvent]) {
        self.workspaceUri = workspaceUri
        self.changes = changes
    }
}
