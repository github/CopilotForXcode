import CopilotForXcodeKit
import Foundation
import LanguageServerProtocol
import SuggestionBasic
import ConversationServiceProvider
import JSONRPC
import Logger

public enum ConversationSource: String, Codable {
    case panel, inline
}

public struct FileReference: Codable, Equatable, Hashable {
    public var type: String = "file"
    public let uri: String
    public let position: Position?
    public let visibleRange: SuggestionBasic.CursorRange?
    public let selection: SuggestionBasic.CursorRange?
    public let openedAt: String?
    public let activeAt: String?
}

public struct DirectoryReference: Codable, Equatable, Hashable {
    public var type: String = "directory"
    public let uri: String
}

public enum Reference: Codable, Equatable, Hashable {
    case file(FileReference)
    case directory(DirectoryReference)
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .file(let fileRef):
            try fileRef.encode(to: encoder)
        case .directory(let directoryRef):
            try directoryRef.encode(to: encoder)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "file":
            let fileRef = try FileReference(from: decoder)
            self = .file(fileRef)
        case "directory":
            let directoryRef = try DirectoryReference(from: decoder)
            self = .directory(directoryRef)
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unknown reference type: \(type)"
                )
            )
        }
    }
    
    public static func from(_ ref: ConversationAttachedReference) -> Reference {
        switch ref {
        case .file(let fileRef):
            return .file(
                .init(
                    uri: fileRef.url.absoluteString,
                    position: nil,
                    visibleRange: nil,
                    selection: nil,
                    openedAt: nil,
                    activeAt: nil
                )
            )
        case .directory(let directoryRef):
            return .directory(.init(uri: directoryRef.url.absoluteString))
        }
    }
}

struct ConversationCreateParams: Codable {
    var workDoneToken: String
    var turns: [TurnSchema]
    var capabilities: Capabilities
    var textDocument: Doc?
    var references: [Reference]?
    var computeSuggestions: Bool?
    var source: ConversationSource?
    var workspaceFolder: String?
    var workspaceFolders: [WorkspaceFolder]?
    var ignoredSkills: [String]?
    var model: String?
    var modelProviderName: String?
    var chatMode: String?
    var needToolCallConfirmation: Bool?
    var userLanguage: String?

    struct Capabilities: Codable {
        var skills: [String]
        var allSkills: Bool?
    }
}

// MARK: Conversation Progress

public enum ConversationProgressKind: String, Codable {
    case begin, report, end
}

protocol BaseConversationProgress: Codable {
    var kind: ConversationProgressKind { get }
    var conversationId: String { get }
    var turnId: String { get }
}

public struct ConversationProgressBegin: BaseConversationProgress {
    public let kind: ConversationProgressKind
    public let conversationId: String
    public let turnId: String
}

public struct ConversationProgressReport: BaseConversationProgress {

    public let kind: ConversationProgressKind
    public let conversationId: String
    public let turnId: String
    public let reply: String?
    public let references: [FileReference]?
    public let steps: [ConversationProgressStep]?
    public let editAgentRounds: [AgentRound]?
}

public struct ConversationProgressEnd: BaseConversationProgress {
    public let kind: ConversationProgressKind
    public let conversationId: String
    public let turnId: String
    public let error: CopilotLanguageServerError?
    public let followUp: ConversationFollowUp?
    public let suggestedTitle: String?
}

enum ConversationProgressContainer: Decodable {
    case begin(ConversationProgressBegin)
    case report(ConversationProgressReport)
    case end(end: ConversationProgressEnd)

    enum CodingKeys: String, CodingKey {
        case kind
    }

    init(from decoder: Decoder) throws {
        do {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let kind = try container.decode(ConversationProgressKind.self, forKey: .kind)

            switch kind {
            case .begin:
                let begin = try ConversationProgressBegin(from: decoder)
                self = .begin(begin)
            case .report:
                let report = try ConversationProgressReport(from: decoder)
                self = .report(report)
            case .end:
                let end = try ConversationProgressEnd(from: decoder)
                self = .end(end: end)
            }
        } catch {
            Logger.gitHubCopilot.error("Error decoding ConversationProgressContainer: \(error)")
            throw error
        }
     }
 }

// MARK: Conversation rating

struct ConversationRatingParams: Codable {
    var turnId: String
    var rating: ConversationRating
    var doc: Doc?
    var source: ConversationSource?
}

// MARK: Conversation templates
struct ConversationTemplatesParams: Codable {
    var workspaceFolders: [WorkspaceFolder]?
}

// MARK: Conversation turn
struct TurnCreateParams: Codable {
    var workDoneToken: String
    var conversationId: String
    var turnId: String?
    var message: MessageContent
    var textDocument: Doc?
    var ignoredSkills: [String]?
    var references: [Reference]?
    var model: String?
    var modelProviderName: String?
    var workspaceFolder: String?
    var workspaceFolders: [WorkspaceFolder]?
    var chatMode: String?
    var needToolCallConfirmation: Bool?
}

struct TurnDeleteParams: Codable {
    var conversationId: String
    var turnId: String
    var source: ConversationSource?
}

// MARK: Copy

struct CopyCodeParams: Codable {
    var turnId: String
    var codeBlockIndex: Int
    var copyType: CopyKind
    var copiedCharacters: Int
    var totalCharacters: Int
    var copiedText: String
    var doc: Doc?
    var source: ConversationSource?
}

// MARK: Conversation context

public struct ConversationContextParams: Codable {
    public var conversationId: String
    public var turnId: String
    public var skillId: String
}

public typealias ConversationContextRequest = JSONRPCRequest<ConversationContextParams>


// MARK: Watched Files

public struct WatchedFilesParams: Codable {
    public var workspaceFolder: WorkspaceFolder
    public var excludeGitignoredFiles: Bool
    public var excludeIDEIgnoredFiles: Bool
    public var partialResultToken: ProgressToken?
}

public typealias WatchedFilesRequest = JSONRPCRequest<WatchedFilesParams>
