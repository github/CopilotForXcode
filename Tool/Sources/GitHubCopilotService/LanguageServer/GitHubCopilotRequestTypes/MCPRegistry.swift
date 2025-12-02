import Foundation
import JSONRPC
import ConversationServiceProvider

/// Schema definitions for MCP Registry API based on the OpenAPI spec:
/// https://github.com/modelcontextprotocol/registry/blob/v1.3.3/docs/reference/api/openapi.yaml

// MARK: - Inputs

public enum ArgumentFormat: String, Codable {
    case string
    case number
    case boolean
    case filepath
}

public protocol InputProtocol: Codable {
    var description: String? { get }
    var isRequired: Bool? { get }
    var format: ArgumentFormat? { get }
    var value: String? { get }
    var isSecret: Bool? { get }
    var defaultValue: String? { get }
    var placeholder: String? { get }
    var choices: [String]? { get }
}

public struct Input: InputProtocol {
    public let description: String?
    public let isRequired: Bool?
    public let format: ArgumentFormat?
    public let value: String?
    public let isSecret: Bool?
    public let defaultValue: String?
    public let placeholder: String?
    public let choices: [String]?

    enum CodingKeys: String, CodingKey {
        case description, isRequired, format, value, isSecret, placeholder, choices
        case defaultValue = "default"
    }
}

public struct InputWithVariables: InputProtocol {
    public let description: String?
    public let isRequired: Bool?
    public let format: ArgumentFormat?
    public let value: String?
    public let isSecret: Bool?
    public let defaultValue: String?
    public let placeholder: String?
    public let choices: [String]?
    public let variables: [String: Input]?

    enum CodingKeys: String, CodingKey {
        case description, isRequired, format, value, isSecret, placeholder, choices, variables
        case defaultValue = "default"
    }
}

public struct KeyValueInput: InputProtocol, Hashable {
    public let name: String
    public let description: String?
    public let isRequired: Bool?
    public let format: ArgumentFormat?
    public let value: String?
    public let isSecret: Bool?
    public let defaultValue: String?
    public let placeholder: String?
    public let choices: [String]?
    public let variables: [String: Input]?
    
    public init(
        name: String,
        description: String?,
        isRequired: Bool?,
        format: ArgumentFormat?,
        value: String?,
        isSecret: Bool?,
        defaultValue: String?,
        placeholder: String?,
        choices: [String]?,
        variables: [String : Input]?
    ) {
        self.name = name
        self.description = description
        self.isRequired = isRequired
        self.format = format
        self.value = value
        self.isSecret = isSecret
        self.defaultValue = defaultValue
        self.placeholder = placeholder
        self.choices = choices
        self.variables = variables
    }

    enum CodingKeys: String, CodingKey {
        case name, description, isRequired, format, value, isSecret, placeholder, choices, variables
        case defaultValue = "default"
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(isRequired)
        hasher.combine(format)
        hasher.combine(value)
        hasher.combine(isSecret)
        hasher.combine(defaultValue)
        hasher.combine(placeholder)
        hasher.combine(choices)
    }
    
    public static func == (lhs: KeyValueInput, rhs: KeyValueInput) -> Bool {
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.isRequired == rhs.isRequired &&
        lhs.format == rhs.format &&
        lhs.value == rhs.value &&
        lhs.isSecret == rhs.isSecret &&
        lhs.defaultValue == rhs.defaultValue &&
        lhs.placeholder == rhs.placeholder &&
        lhs.choices == rhs.choices
    }
}

// MARK: - Arguments

public enum ArgumentType: String, Codable {
    case positional
    case named
}

public protocol ArgumentProtocol: InputProtocol {
    var type: ArgumentType { get }
    var variables: [String: Input]? { get }
}

public struct PositionalArgument: ArgumentProtocol, Hashable {
    public let type: ArgumentType = .positional
    public let description: String?
    public let isRequired: Bool?
    public let format: ArgumentFormat?
    public let value: String?
    public let isSecret: Bool?
    public let defaultValue: String?
    public let placeholder: String?
    public let choices: [String]?
    public let variables: [String: Input]?
    public let valueHint: String?
    public let isRepeated: Bool?

    enum CodingKeys: String, CodingKey {
        case type, description, isRequired, format, value, isSecret, placeholder, choices, variables, valueHint, isRepeated
        case defaultValue = "default"
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(description)
        hasher.combine(isRequired)
        hasher.combine(format)
        hasher.combine(value)
        hasher.combine(isSecret)
        hasher.combine(defaultValue)
        hasher.combine(placeholder)
        hasher.combine(choices)
        hasher.combine(valueHint)
        hasher.combine(isRepeated)
    }
    
    public static func == (lhs: PositionalArgument, rhs: PositionalArgument) -> Bool {
        lhs.type == rhs.type &&
        lhs.description == rhs.description &&
        lhs.isRequired == rhs.isRequired &&
        lhs.format == rhs.format &&
        lhs.value == rhs.value &&
        lhs.isSecret == rhs.isSecret &&
        lhs.defaultValue == rhs.defaultValue &&
        lhs.placeholder == rhs.placeholder &&
        lhs.choices == rhs.choices &&
        lhs.valueHint == rhs.valueHint &&
        lhs.isRepeated == rhs.isRepeated
    }
}

public struct NamedArgument: ArgumentProtocol, Hashable {
    public let type: ArgumentType = .named
    public let name: String
    public let description: String?
    public let isRequired: Bool?
    public let format: ArgumentFormat?
    public let value: String?
    public let isSecret: Bool?
    public let defaultValue: String?
    public let placeholder: String?
    public let choices: [String]?
    public let variables: [String: Input]?
    public let isRepeated: Bool?

    enum CodingKeys: String, CodingKey {
        case type, name, description, isRequired, format, value, isSecret, placeholder, choices, variables, isRepeated
        case defaultValue = "default"
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(name)
        hasher.combine(description)
        hasher.combine(isRequired)
        hasher.combine(format)
        hasher.combine(value)
        hasher.combine(isSecret)
        hasher.combine(defaultValue)
        hasher.combine(placeholder)
        hasher.combine(choices)
        hasher.combine(isRepeated)
    }
    
    public static func == (lhs: NamedArgument, rhs: NamedArgument) -> Bool {
        lhs.type == rhs.type &&
        lhs.name == rhs.name &&
        lhs.description == rhs.description &&
        lhs.isRequired == rhs.isRequired &&
        lhs.format == rhs.format &&
        lhs.value == rhs.value &&
        lhs.isSecret == rhs.isSecret &&
        lhs.defaultValue == rhs.defaultValue &&
        lhs.placeholder == rhs.placeholder &&
        lhs.choices == rhs.choices &&
        lhs.isRepeated == rhs.isRepeated
    }
}

public enum Argument: Codable, Hashable {
    case positional(PositionalArgument)
    case named(NamedArgument)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Discriminator.self)
        let type = try container.decode(ArgumentType.self, forKey: .type)
        switch type {
        case .positional:
            self = .positional(try PositionalArgument(from: decoder))
        case .named:
            self = .named(try NamedArgument(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .positional(let arg):
            try arg.encode(to: encoder)
        case .named(let arg):
            try arg.encode(to: encoder)
        }
    }

    private enum Discriminator: String, CodingKey {
        case type
    }
}

// MARK: - Transport

public enum TransportType: String, Codable {
    case streamableHttp = "streamable-http"
    case stdio = "stdio"
    case sse = "sse"
    
    public var displayText: String {
        switch self {
        case .streamableHttp:
            return "Streamable HTTP"
        case .stdio:
            return "Stdio"
        case .sse:
            return "SSE"
        }
    }
}

public protocol TransportProtocol: Codable {
    var type: TransportType { get }
    var variables: [String: Input]? { get }
}

public struct StdioTransport: TransportProtocol, Hashable {
    public let type: TransportType = .stdio
    public let variables: [String : Input]?

    enum CodingKeys: String, CodingKey {
        case type, variables
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
    }

    public static func == (lhs: StdioTransport, rhs: StdioTransport) -> Bool {
        lhs.type == rhs.type
    }
}

public struct StreamableHttpTransport: TransportProtocol, Hashable {
    public let type: TransportType = .streamableHttp
    public let url: String
    public let headers: [KeyValueInput]?
    public let variables: [String : Input]?

    enum CodingKeys: String, CodingKey {
        case type, url, headers, variables
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(url)
        hasher.combine(headers)
    }

    public static func == (lhs: StreamableHttpTransport, rhs: StreamableHttpTransport) -> Bool {
        lhs.type == rhs.type &&
        lhs.url == rhs.url &&
        lhs.headers == rhs.headers
    }
}

public struct SseTransport: TransportProtocol, Hashable {
    public let type: TransportType = .sse
    public let url: String
    public let headers: [KeyValueInput]?
    public let variables: [String : Input]?

    enum CodingKeys: String, CodingKey {
        case type, url, headers, variables
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(url)
        hasher.combine(headers)
    }

    public static func == (lhs: SseTransport, rhs: SseTransport) -> Bool {
        lhs.type == rhs.type &&
        lhs.url == rhs.url &&
        lhs.headers == rhs.headers
    }
}

public enum Transport: Codable, Hashable {
    case stdio(StdioTransport)
    case streamableHTTP(StreamableHttpTransport)
    case sse(SseTransport)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Discriminator.self)
        let type = try container.decode(TransportType.self, forKey: .type)
        switch type {
        case .stdio:
            self = .stdio(try StdioTransport(from: decoder))
        case .streamableHttp:
            self = .streamableHTTP(try StreamableHttpTransport(from: decoder))
        case .sse:
            self = .sse(try SseTransport(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .stdio(let arg):
            try arg.encode(to: encoder)
        case .streamableHTTP(let arg):
            try arg.encode(to: encoder)
        case .sse(let arg):
            try arg.encode(to: encoder)
        }
    }

    private enum Discriminator: String, CodingKey {
        case type
    }
}

public enum Remote: Codable, Hashable {
    case streamableHTTP(StreamableHttpTransport)
    case sse(SseTransport)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: Discriminator.self)
        let type = try container.decode(TransportType.self, forKey: .type)
        switch type {
        case .stdio:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unexpected type: stdio for Remote"
            )
        case .streamableHttp:
            self = .streamableHTTP(try StreamableHttpTransport(from: decoder))
        case .sse:
            self = .sse(try SseTransport(from: decoder))
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .streamableHTTP(let arg):
            try arg.encode(to: encoder)
        case .sse(let arg):
            try arg.encode(to: encoder)
        }
    }

    private enum Discriminator: String, CodingKey {
        case type
    }
}

// MARK: - Package

public struct Package: Codable, Hashable {
    public let registryType: String
    public let registryBaseUrl: String?
    public let identifier: String
    public let version: String?
    public let fileSha256: String?
    public let runtimeHint: String?
    public let transport: Transport
    public let runtimeArguments: [Argument]?
    public let packageArguments: [Argument]?
    public let environmentVariables: [KeyValueInput]?
    
    public init(
        registryType: String,
        registryBaseUrl: String?,
        identifier: String,
        version: String?,
        fileSha256: String?,
        runtimeHint: String?,
        transport: Transport,
        runtimeArguments: [Argument]?,
        packageArguments: [Argument]?,
        environmentVariables: [KeyValueInput]?
    ) {
        self.registryType = registryType
        self.registryBaseUrl = registryBaseUrl
        self.identifier = identifier
        self.version = version
        self.fileSha256 = fileSha256
        self.runtimeHint = runtimeHint
        self.transport = transport
        self.runtimeArguments = runtimeArguments
        self.packageArguments = packageArguments
        self.environmentVariables = environmentVariables
    }
}

// MARK: - Icons

public enum IconMimeType: String, Codable {
    case png = "image/png"
    case jpeg = "image/jpeg"
    case jpg = "image/jpg"
    case svg = "image/svg+xml"
    case webp = "image/webp"
}

public enum IconTheme: String, Codable {
    case light, dark
}

public struct Icon: Codable, Hashable {
    public let src: String
    public let mimeType: IconMimeType?
    public let sizes: [String]?
    public let theme: IconTheme?
}

// MARK: - Repository

public struct Repository: Codable {
    public let url: String
    public let source: String
    public let id: String?
    public let subfolder: String?

    public init(url: String, source: String, id: String?, subfolder: String?) {
        self.url = url
        self.source = source
        self.id = id
        self.subfolder = subfolder
    }

    enum CodingKeys: String, CodingKey {
        case url, source, id, subfolder
    }
}

// MARK: - Meta

public enum ServerStatus: String, Codable {
    case active
    case deprecated
    case deleted
}

public struct OfficialMeta: Codable {
    public let status: ServerStatus
    public let publishedAt: String
    public let updatedAt: String
    public let isLatest: Bool
    
    public init(
        status: ServerStatus,
        publishedAt: String,
        updatedAt: String,
        isLatest: Bool
    ) {
        self.status = status
        self.publishedAt = publishedAt
        self.updatedAt = updatedAt
        self.isLatest = isLatest
    }
}

public struct PublisherProvidedMeta: Codable {
    private let additionalProperties: [String: AnyCodable]?
    
    public init(
        additionalProperties: [String: AnyCodable]? = nil
    ) {
        self.additionalProperties = additionalProperties
    }

    public init(from decoder: Decoder) throws {
        let allKeys = try decoder.container(keyedBy: AnyCodingKey.self)
        var extras: [String: AnyCodable] = [:]
        
        for key in allKeys.allKeys {
            extras[key.stringValue] = try allKeys.decode(AnyCodable.self, forKey: key)
        }
        additionalProperties = extras.isEmpty ? nil : extras
    }

    public func encode(to encoder: Encoder) throws {
        if let additionalProperties = additionalProperties {
            var dynamicContainer = encoder.container(keyedBy: AnyCodingKey.self)
            for (key, value) in additionalProperties {
                try dynamicContainer.encode(value, forKey: AnyCodingKey(stringValue: key)!)
            }
        }
    }
}

public struct MCPRegistryExtensionMeta: Codable {
    public let publisherProvided: PublisherProvidedMeta?

    enum CodingKeys: String, CodingKey {
        case publisherProvided = "io.modelcontextprotocol.registry/publisher-provided"
    }

    public init(publisherProvided: PublisherProvidedMeta?) {
        self.publisherProvided = publisherProvided
    }
}

public struct ServerMeta: Codable {
    public let official: OfficialMeta
    private let additionalProperties: [String: AnyCodable]?

    enum CodingKeys: String, CodingKey {
        case official = "io.modelcontextprotocol.registry/official"
    }
    
    public init(
        official: OfficialMeta,
        additionalProperties: [String: AnyCodable]? = nil
    ) {
        self.official = official
        self.additionalProperties = additionalProperties
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        official = try container.decode(OfficialMeta.self, forKey: .official)

        let allKeys = try decoder.container(keyedBy: AnyCodingKey.self)
        var extras: [String: AnyCodable] = [:]

        for key in allKeys.allKeys {
            if key.stringValue != "io.modelcontextprotocol.registry/official" {
                extras[key.stringValue] = try allKeys.decode(AnyCodable.self, forKey: key)
            }
        }
        additionalProperties = extras.isEmpty ? nil : extras
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(official, forKey: .official)

        if let additionalProperties = additionalProperties {
            var dynamicContainer = encoder.container(keyedBy: AnyCodingKey.self)
            for (key, value) in additionalProperties {
                try dynamicContainer.encode(value, forKey: AnyCodingKey(stringValue: key)!)
            }
        }
    }
}

// MARK: - Servers

public struct MCPRegistryServerDetail: Codable {
    public let name: String
    public let description: String
    public let title: String?
    public let repository: Repository?
    public let version: String
    public let websiteUrl: String?
    public let icons: [Icon]?
    public let schemaURL: String?
    public let packages: [Package]?
    public let remotes: [Remote]?
    public let meta: MCPRegistryExtensionMeta?

    enum CodingKeys: String, CodingKey {
        case name, description, title, repository, version, packages, remotes, websiteUrl, icons
        case schemaURL = "$schema"
        case meta = "_meta"
    }

    public init(
        name: String,
        description: String,
        title: String?,
        repository: Repository?,
        version: String,
        websiteUrl: String?,
        icons: [Icon]?,
        schemaURL: String?,
        packages: [Package]?,
        remotes: [Remote]?,
        meta: MCPRegistryExtensionMeta?
    ) {
        self.name = name
        self.description = description
        self.title = title
        self.repository = repository
        self.version = version
        self.websiteUrl = websiteUrl
        self.icons = icons
        self.schemaURL = schemaURL
        self.packages = packages
        self.remotes = remotes
        self.meta = meta
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        version = try container.decode(String.self, forKey: .version)
        websiteUrl = try container.decodeIfPresent(String.self, forKey: .websiteUrl)
        icons = try container.decodeIfPresent([Icon].self, forKey: .icons)
        schemaURL = try container.decodeIfPresent(String.self, forKey: .schemaURL)
        packages = try container.decodeIfPresent([Package].self, forKey: .packages)
        remotes = try container.decodeIfPresent([Remote].self, forKey: .remotes)
        meta = try container.decodeIfPresent(MCPRegistryExtensionMeta.self, forKey: .meta)

        // Custom handling for repository: {} → nil
        if container.contains(.repository) {
            // Decode raw dictionary to see if it is empty
            let repoDict = try container.decode([String: AnyCodable].self, forKey: .repository)
            if repoDict.isEmpty {
                repository = nil
            } else {
                // Re-decode as Repository from the same key
                repository = try container.decode(Repository.self, forKey: .repository)
            }
        } else {
            repository = nil
        }
    }
}

public struct MCPRegistryServerResponse : Codable {
    public let server: MCPRegistryServerDetail
    public let meta: ServerMeta

    public init(server: MCPRegistryServerDetail, meta: ServerMeta) {
        self.server = server
        self.meta = meta
    }

    enum CodingKeys: String, CodingKey {
        case server
        case meta = "_meta"
    }
}

public struct MCPRegistryServerListMetadata: Codable {
    public let nextCursor: String?
    public let count: Int?
}

public struct MCPRegistryServerList: Codable {
    public let servers: [MCPRegistryServerResponse]
    public let metadata: MCPRegistryServerListMetadata?
}

// MARK: - Requests

public struct MCPRegistryListServersParams: Codable {
    public let baseUrl: String
    public let cursor: String?
    public let limit: Int?
    public let search: String?
    public let updatedSince: String?
    public let version: String?

    public init(
        baseUrl: String,
        cursor: String? = nil,
        limit: Int?,
        search: String? = nil,
        updatedSince: String? = nil,
        version: String? = nil
    ) {
        self.baseUrl = baseUrl
        self.cursor = cursor
        self.limit = limit
        self.search = search
        self.updatedSince = updatedSince
        self.version = version
    }
}

public struct MCPRegistryGetServerParams: Codable {
    public let baseUrl: String
    public let id: String
    public let version: String?

    public init(baseUrl: String, id: String, version: String?) {
        self.baseUrl = baseUrl
        self.id = id
        self.version = version
    }
}

// MARK: - Internal Helpers

private struct AnyCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
