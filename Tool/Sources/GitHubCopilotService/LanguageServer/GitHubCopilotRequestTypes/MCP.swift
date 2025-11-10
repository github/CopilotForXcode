import Foundation
import JSONRPC
import LanguageServerProtocol
import ConversationServiceProvider

public enum MCPServerStatus: String, Codable, Equatable, Hashable {
    case running = "running"
    case stopped = "stopped"
    case error = "error"
    case blocked = "blocked"
}

public struct InputSchema: Codable, Equatable, Hashable {
    public var type: String = "object"
    public var properties: [String: JSONValue]?
    
    public init(properties: [String: JSONValue]? = nil) {
        self.properties = properties
    }
    
    // Custom coding for handling `properties` as Any
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        
        if let propertiesData = try? container.decode(Data.self, forKey: .properties),
           let props = try? JSONSerialization.jsonObject(with: propertiesData) as? [String: JSONValue] {
            properties = props
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        if let props = properties,
           let propertiesData = try? JSONSerialization.data(withJSONObject: props) {
            try container.encode(propertiesData, forKey: .properties)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case properties
    }
}

public struct ToolAnnotations: Codable, Equatable, Hashable {
    public var title: String?
    public var readOnlyHint: Bool?
    public var destructiveHint: Bool?
    public var idempotentHint: Bool?
    public var openWorldHint: Bool?
    
    public init(
        title: String? = nil,
        readOnlyHint: Bool? = nil,
        destructiveHint: Bool? = nil,
        idempotentHint: Bool? = nil,
        openWorldHint: Bool? = nil
    ) {
        self.title = title
        self.readOnlyHint = readOnlyHint
        self.destructiveHint = destructiveHint
        self.idempotentHint = idempotentHint
        self.openWorldHint = openWorldHint
    }
    
    enum CodingKeys: String, CodingKey {
        case title
        case readOnlyHint
        case destructiveHint
        case idempotentHint
        case openWorldHint
    }
}

public struct MCPTool: Codable, Equatable, Hashable {
    public let name: String
    public let description: String?
    public let _status: ToolStatus
    public let inputSchema: InputSchema
    public var annotations: ToolAnnotations?
    
    public init(
        name: String,
        description: String? = nil,
        _status: ToolStatus,
        inputSchema: InputSchema,
        annotations: ToolAnnotations? = nil
    ) {
        self.name = name
        self.description = description
        self._status = _status
        self.inputSchema = inputSchema
        self.annotations = annotations
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case _status
        case inputSchema
        case annotations
    }
}

public struct MCPServerToolsCollection: Codable, Equatable, Hashable {
    public let name: String
    public let status: MCPServerStatus
    public let tools: [MCPTool]
    public let error: String?
    public let registryInfo: String?
    
    public init(
        name: String,
        status: MCPServerStatus,
        tools: [MCPTool],
        error: String? = nil,
        registryInfo: String? = nil
    ) {
        self.name = name
        self.status = status
        self.tools = tools
        self.error = error
        self.registryInfo = registryInfo
    }
}

public struct GetAllToolsParams: Codable, Hashable {
    public var servers: [MCPServerToolsCollection]
    
    public static func decode(fromParams params: JSONValue?) -> GetAllToolsParams? {
        try? JSONDecoder().decode(Self.self, from: (try? JSONEncoder().encode(params)) ?? Data())
    }
}

public struct UpdatedMCPToolsStatus: Codable, Hashable {
    public var name: String
    public var status: ToolStatus
    
    public init(name: String, status: ToolStatus) {
        self.name = name
        self.status = status
    }
}

public struct UpdateMCPToolsStatusServerCollection: Codable, Hashable {
    public var name: String
    public var tools: [UpdatedMCPToolsStatus]
    
    public init(name: String, tools: [UpdatedMCPToolsStatus]) {
        self.name = name
        self.tools = tools
    }
}

public struct UpdateMCPToolsStatusParams: Codable, Hashable {
    public var chatModeKind: ChatMode?
    public var customChatModeId: String?
    public var workspaceFolders: [WorkspaceFolder]?
    public var servers: [UpdateMCPToolsStatusServerCollection]

    public init(
        chatModeKind: ChatMode? = nil,
        customChatModeId: String? = nil,
        workspaceFolders: [WorkspaceFolder]? = nil,
        servers: [UpdateMCPToolsStatusServerCollection]
    ) {
        self.chatModeKind = chatModeKind
        self.customChatModeId = customChatModeId
        self.workspaceFolders = workspaceFolders
        self.servers = servers
    }
}

public typealias CopilotMCPToolsRequest = JSONRPCRequest<GetAllToolsParams>

public struct DynamicOAuthParams: Codable, Hashable {
    public let title: String
    public let header: String?
    public let detail: String
    public let inputs: [DynamicOAuthInput]

    public init(
        title: String,
        header: String?,
        detail: String,
        inputs: [DynamicOAuthInput]
    ) {
        self.title = title
        self.header = header
        self.detail = detail
        self.inputs = inputs
    }
}

public struct DynamicOAuthInput: Codable, Hashable {
    public let title: String
    public let value: String
    public let description: String
    public let placeholder: String
    public let required: Bool
    
    public init(
        title: String,
        value: String,
        description: String,
        placeholder: String,
        required: Bool
    ) {
        self.title = title
        self.value = value
        self.description = description
        self.placeholder = placeholder
        self.required = required
    }
}

public typealias DynamicOAuthRequest = JSONRPCRequest<DynamicOAuthParams>

public struct DynamicOAuthResponse: Codable, Hashable {
    public let clientId: String
    public let clientSecret: String
    
    public init(
        clientId: String,
        clientSecret: String
    ) {
        self.clientId = clientId
        self.clientSecret = clientSecret
    }
}
