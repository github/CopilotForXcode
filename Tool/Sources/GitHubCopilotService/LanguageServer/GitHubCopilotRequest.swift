import ConversationServiceProvider
import Foundation
import JSONRPC
import LanguageServerProtocol
import Status
import SuggestionBasic

struct GitHubCopilotDoc: Codable {
    var source: String
    var tabSize: Int
    var indentSize: Int
    var insertSpaces: Bool
    var path: String
    var uri: String
    var relativePath: String
    var languageId: CodeLanguage
    var position: Position
    /// Buffer version. Not sure what this is for, not sure how to get it
    var version: Int = 0
}

protocol GitHubCopilotRequestType {
    associatedtype Response: Codable
    var request: ClientRequest { get }
}

public struct GitHubCopilotCodeSuggestion: Codable, Equatable {
    public init(
        text: String,
        position: CursorPosition,
        uuid: String,
        range: CursorRange,
        displayText: String
    ) {
        self.text = text
        self.position = position
        self.uuid = uuid
        self.range = range
        self.displayText = displayText
    }

    /// The new code to be inserted and the original code on the first line.
    public var text: String
    /// The position of the cursor before generating the completion.
    public var position: CursorPosition
    /// An id.
    public var uuid: String
    /// The range of the original code that should be replaced.
    public var range: CursorRange
    /// The new code to be inserted.
    public var displayText: String
}

public func editorConfiguration(includeMCP: Bool) -> JSONValue {
    var proxyAuthorization: String? {
        let username = UserDefaults.shared.value(for: \.gitHubCopilotProxyUsername)
        if username.isEmpty { return nil }
        let password = UserDefaults.shared.value(for: \.gitHubCopilotProxyPassword)
        return "\(username):\(password)"
    }

    var http: JSONValue? {
        var d: [String: JSONValue] = [:]
        let proxy = UserDefaults.shared.value(for: \.gitHubCopilotProxyUrl)
        if !proxy.isEmpty {
            d["proxy"] = .string(proxy)
        }
        if let proxyAuthorization = proxyAuthorization {
            d["proxyAuthorization"] = .string(proxyAuthorization)
        }
        let proxyStrictSSL = UserDefaults.shared.value(for: \.gitHubCopilotUseStrictSSL)
        d["proxyStrictSSL"] = .bool(proxyStrictSSL)
        if proxy.isEmpty && proxyStrictSSL == false {
            // Setting the proxy to an empty string avoids the lanaguage server
            // ignoring the proxyStrictSSL setting.
            d["proxy"] = .string("")
        }
        return .hash(d)
    }

    var authProvider: JSONValue? {
        let enterpriseURI = UserDefaults.shared.value(for: \.gitHubCopilotEnterpriseURI)
        return .hash(["uri": .string(enterpriseURI)])
    }

    var mcp: JSONValue? {
        let mcpConfig = UserDefaults.shared.value(for: \.gitHubCopilotMCPConfig)
        return JSONValue.string(mcpConfig)
    }

    var customInstructions: JSONValue? {
        let instructions = UserDefaults.shared.value(for: \.globalCopilotInstructions)
        return .string(instructions)
    }
    
    var agent: JSONValue? {
        var d: [String: JSONValue] = [:]
        
        let agentMaxToolCallingLoop = Double(UserDefaults.shared.value(for: \.agentMaxToolCallingLoop))
        d["maxToolCallingLoop"] = .number(agentMaxToolCallingLoop)
        
        return .hash(d)
    }

    var d: [String: JSONValue] = [:]
    if let http { d["http"] = http }
    if let authProvider { d["github-enterprise"] = authProvider }
    if (includeMCP && mcp != nil) || customInstructions != nil {
        var github: [String: JSONValue] = [:]
        var copilot: [String: JSONValue] = [:]
        if includeMCP {
            copilot["mcp"] = mcp
        }
        copilot["globalCopilotInstructions"] = customInstructions
        copilot["agent"] = agent
        github["copilot"] = .hash(copilot)
        d["github"] = .hash(github)
    }
    return .hash(d)
}

public enum SignInInitiateStatus: String, Codable {
    case promptUserDeviceFlow = "PromptUserDeviceFlow"
    case alreadySignedIn = "AlreadySignedIn"
}

enum GitHubCopilotRequest {
    struct GetVersion: GitHubCopilotRequestType {
        struct Response: Codable {
            var version: String
        }

        var request: ClientRequest {
            .custom("getVersion", .hash([:]), ClientRequest.NullHandler)
        }
    }

    struct CheckStatus: GitHubCopilotRequestType {
        struct Response: Codable {
            var status: GitHubCopilotAccountStatus
            var user: String?
        }

        var request: ClientRequest {
            .custom("checkStatus", .hash([:]), ClientRequest.NullHandler)
        }
    }

    struct CheckQuota: GitHubCopilotRequestType {
        typealias Response = GitHubCopilotQuotaInfo

        var request: ClientRequest {
            .custom("checkQuota", .hash([:]), ClientRequest.NullHandler)
        }
    }

    struct SignInInitiate: GitHubCopilotRequestType {
        struct Response: Codable {
            var status: SignInInitiateStatus
            var userCode: String?
            var verificationUri: String?
            var expiresIn: Int?
            var interval: Int?
            var user: String?
        }

        var request: ClientRequest {
            .custom("signInInitiate", .hash([:]), ClientRequest.NullHandler)
        }
    }

    struct SignInConfirm: GitHubCopilotRequestType {
        struct Response: Codable {
            var status: GitHubCopilotAccountStatus
            var user: String
        }

        var userCode: String

        var request: ClientRequest {
            .custom("signInConfirm", .hash([
                "userCode": .string(userCode),
            ]), ClientRequest.NullHandler)
        }
    }

    struct SignOut: GitHubCopilotRequestType {
        struct Response: Codable {
            var status: GitHubCopilotAccountStatus
        }

        var request: ClientRequest {
            .custom("signOut", .hash([:]), ClientRequest.NullHandler)
        }
    }

    struct GetCompletions: GitHubCopilotRequestType {
        struct Response: Codable {
            var completions: [GitHubCopilotCodeSuggestion]
        }

        var doc: GitHubCopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getCompletions", .hash([
                "doc": dict,
            ]), ClientRequest.NullHandler)
        }
    }

    struct GetCompletionsCycling: GitHubCopilotRequestType {
        struct Response: Codable {
            var completions: [GitHubCopilotCodeSuggestion]
        }

        var doc: GitHubCopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getCompletionsCycling", .hash([
                "doc": dict,
            ]), ClientRequest.NullHandler)
        }
    }

    struct InlineCompletion: GitHubCopilotRequestType {
        struct Response: Codable {
            var items: [InlineCompletionItem]
        }

        struct InlineCompletionItem: Codable {
            var insertText: String
            var filterText: String?
            var range: Range?
            var command: Command?

            struct Range: Codable {
                var start: Position
                var end: Position
            }

            struct Command: Codable {
                var title: String
                var command: String
                var arguments: [String]?
            }
        }

        var doc: Input

        struct Input: Codable {
            var textDocument: _TextDocument; struct _TextDocument: Codable {
                var uri: String
                var version: Int
            }

            var position: Position
            var formattingOptions: FormattingOptions
            var context: _Context; struct _Context: Codable {
                enum TriggerKind: Int, Codable {
                    case invoked = 1
                    case automatic = 2
                }

                var triggerKind: TriggerKind
            }
        }

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("textDocument/inlineCompletion", dict, ClientRequest.NullHandler)
        }
    }

    struct GetPanelCompletions: GitHubCopilotRequestType {
        struct Response: Codable {
            var completions: [GitHubCopilotCodeSuggestion]
        }

        var doc: GitHubCopilotDoc

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(doc)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("getPanelCompletions", .hash([
                "doc": dict,
            ]), ClientRequest.NullHandler)
        }
    }
    
    // MARK: - NES
    
    struct CopilotInlineEdit: GitHubCopilotRequestType {
        typealias Response = CopilotInlineEditsResponse
        
        var params: CopilotInlineEditsParams
        
        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("textDocument/copilotInlineEdit", dict, ClientRequest.NullHandler)
        }
    }

    struct NotifyShown: GitHubCopilotRequestType {
        struct Response: Codable {}

        var completionUUID: String

        var request: ClientRequest {
            .custom("notifyShown", .hash([
                "uuid": .string(completionUUID),
            ]), ClientRequest.NullHandler)
        }
    }

    struct NotifyAccepted: GitHubCopilotRequestType {
        struct Response: Codable {}

        var completionUUID: String

        var acceptedLength: Int?

        var request: ClientRequest {
            var dict: [String: JSONValue] = [
                "uuid": .string(completionUUID),
            ]
            if let acceptedLength {
                dict["acceptedLength"] = .number(Double(acceptedLength))
            }

            return .custom("notifyAccepted", .hash(dict), ClientRequest.NullHandler)
        }
    }
    
    struct NotifyCopilotInlineEditAccepted: GitHubCopilotRequestType {
        typealias Response = Bool
        
        // NES suggestion ID
        var params: [String]
        
        var request: ClientRequest {
            let args: [JSONValue] = params.map { JSONValue.string($0) }
            return .workspaceExecuteCommand(
                .init(command: "github.copilot.didAcceptNextEditSuggestionItem", arguments: args),
                ClientRequest.NullHandler
            )
        }
    }

    struct NotifyRejected: GitHubCopilotRequestType {
        struct Response: Codable {}

        var completionUUIDs: [String]

        var request: ClientRequest {
            .custom("notifyRejected", .hash([
                "uuids": .array(completionUUIDs.map(JSONValue.string)),
            ]), ClientRequest.NullHandler)
        }
    }

    // MARK: Conversation

    struct CreateConversation: GitHubCopilotRequestType {
        typealias Response = ConversationCreateResponse

        var params: ConversationCreateParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/create", dict, ClientRequest.NullHandler)
        }
    }

    // MARK: Conversation turn

    struct CreateTurn: GitHubCopilotRequestType {
        typealias Response = ConversationCreateResponse

        var params: TurnCreateParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/turn", dict, ClientRequest.NullHandler)
        }
    }

    struct DeleteTurn: GitHubCopilotRequestType {
        struct Response: Codable {}

        var params: TurnDeleteParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/turnDelete", dict, ClientRequest.NullHandler)
        }
    }

    // MARK: Conversation rating

    struct ConversationRating: GitHubCopilotRequestType {
        struct Response: Codable {}

        var params: ConversationRatingParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/rating", dict, ClientRequest.NullHandler)
        }
    }

    // MARK: Conversation templates

    struct GetTemplates: GitHubCopilotRequestType {
        typealias Response = Array<ChatTemplate>

        var params: ConversationTemplatesParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/templates", dict, ClientRequest.NullHandler)
        }
    }

    // MARK: Conversation Modes

    struct GetModes: GitHubCopilotRequestType {
        typealias Response = Array<ConversationMode>

        var params: ConversationModesParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/modes", dict, ClientRequest.NullHandler)
        }
    }

    // MARK: Copilot Models

    struct CopilotModels: GitHubCopilotRequestType {
        typealias Response = Array<CopilotModel>

        var request: ClientRequest {
            .custom("copilot/models", .hash([:]), ClientRequest.NullHandler)
        }
    }

    // MARK: MCP Tools

    struct UpdatedMCPToolsStatus: GitHubCopilotRequestType {
        typealias Response = Array<MCPServerToolsCollection>

        var params: UpdateMCPToolsStatusParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("mcp/updateToolsStatus", dict, ClientRequest.NullHandler)
        }
    }

    // MARK: MCP Registry

    struct MCPRegistryListServers: GitHubCopilotRequestType {
        typealias Response = MCPRegistryServerList

        var params: MCPRegistryListServersParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("mcp/registry/listServers", dict, ClientRequest.NullHandler)
        }
    }

    struct MCPRegistryGetServer: GitHubCopilotRequestType {
        typealias Response = MCPRegistryServerDetail

        var params: MCPRegistryGetServerParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("mcp/registry/getServer", dict, ClientRequest.NullHandler)
        }
    }

    struct MCPRegistryGetAllowlist: GitHubCopilotRequestType {
        typealias Response = GetMCPRegistryAllowlistResult

        var request: ClientRequest {
            .custom("mcp/registry/getAllowlist", .hash([:]), ClientRequest.NullHandler)
        }
    }

    // MARK: - Conversation Agents

    struct GetAgents: GitHubCopilotRequestType {
        typealias Response = Array<ChatAgent>

        var request: ClientRequest {
            .custom("conversation/agents", .hash([:]), ClientRequest.NullHandler)
        }
    }

    // MARK: - Code Review

    struct ReviewChanges: GitHubCopilotRequestType {
        typealias Response = CodeReviewResult

        var params: ReviewChangesParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("copilot/codeReview/reviewChanges", dict, ClientRequest.NullHandler)
        }
    }

    struct RegisterTools: GitHubCopilotRequestType {
        typealias Response = Array<LanguageModelTool>

        var params: RegisterToolsParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/registerTools", dict, ClientRequest.NullHandler)
        }
    }

    struct UpdateToolsStatus: GitHubCopilotRequestType {
        typealias Response = Array<LanguageModelTool>

        var params: UpdateToolsStatusParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/updateToolsStatus", dict, ClientRequest.NullHandler)
        }
    }

    // MARK: Copy code

    struct CopyCode: GitHubCopilotRequestType {
        struct Response: Codable {}

        var params: CopyCodeParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("conversation/copyCode", dict, ClientRequest.NullHandler)
        }
    }

    // MARK: Telemetry

    struct TelemetryException: GitHubCopilotRequestType {
        struct Response: Codable {}

        var params: TelemetryExceptionParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("telemetry/exception", dict, ClientRequest.NullHandler)
        }
    }

    // MARK: BYOK

    struct BYOKSaveModel: GitHubCopilotRequestType {
        typealias Response = BYOKSaveModelResponse

        var params: BYOKSaveModelParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("copilot/byok/saveModel", dict, ClientRequest.NullHandler)
        }
    }

    struct BYOKDeleteModel: GitHubCopilotRequestType {
        typealias Response = BYOKDeleteModelResponse

        var params: BYOKDeleteModelParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("copilot/byok/deleteModel", dict, ClientRequest.NullHandler)
        }
    }

    struct BYOKListModels: GitHubCopilotRequestType {
        typealias Response = BYOKListModelsResponse

        var params: BYOKListModelsParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("copilot/byok/listModels", dict, ClientRequest.NullHandler)
        }
    }

    struct BYOKSaveApiKey: GitHubCopilotRequestType {
        typealias Response = BYOKSaveApiKeyResponse

        var params: BYOKSaveApiKeyParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("copilot/byok/saveApiKey", dict, ClientRequest.NullHandler)
        }
    }

    struct BYOKDeleteApiKey: GitHubCopilotRequestType {
        typealias Response = BYOKDeleteApiKeyResponse

        var params: BYOKDeleteApiKeyParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("copilot/byok/deleteApiKey", dict, ClientRequest.NullHandler)
        }
    }

    struct BYOKListApiKeys: GitHubCopilotRequestType {
        typealias Response = BYOKListApiKeysResponse

        var params: BYOKListApiKeysParams

        var request: ClientRequest {
            let data = (try? JSONEncoder().encode(params)) ?? Data()
            let dict = (try? JSONDecoder().decode(JSONValue.self, from: data)) ?? .hash([:])
            return .custom("copilot/byok/listApiKeys", dict, ClientRequest.NullHandler)
        }
    }
}

// MARK: Notifications

public enum GitHubCopilotNotification {
    public struct StatusNotification: Codable {
        public enum StatusKind: String, Codable {
            case normal = "Normal"
            case error = "Error"
            case warning = "Warning"
            case inactive = "Inactive"

            public var clsStatus: CLSStatus.Status {
                switch self {
                case .normal:
                    .normal
                case .error:
                    .error
                case .warning:
                    .warning
                case .inactive:
                    .inactive
                }
            }
        }

        public var kind: StatusKind
        public var busy: Bool
        public var message: String?

        public static func decode(fromParams params: JSONValue?) -> StatusNotification? {
            try? JSONDecoder().decode(Self.self, from: (try? JSONEncoder().encode(params)) ?? Data())
        }
    }

    public struct MCPRuntimeNotification: Codable {
        public enum MCPRuntimeLogLevel: String, Codable {
            case Info = "info"
            case Warning = "warning"
            case Error = "error"
        }

        public var level: MCPRuntimeLogLevel
        public var message: String
        public var server: String
        public var tool: String?
        public var time: Double

        public static func decode(fromParams params: JSONValue?) -> MCPRuntimeNotification? {
            try? JSONDecoder().decode(Self.self, from: (try? JSONEncoder().encode(params)) ?? Data())
        }
    }
}
