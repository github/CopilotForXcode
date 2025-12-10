import CopilotForXcodeKit
import Foundation
import LanguageServerProtocol


public struct AgentRound: Codable, Equatable {
    public let roundId: Int
    public var reply: String
    public var toolCalls: [AgentToolCall]?
    public var subAgentRounds: [AgentRound]?
    
    public init(roundId: Int, reply: String, toolCalls: [AgentToolCall]? = [], subAgentRounds: [AgentRound]? = []) {
        self.roundId = roundId
        self.reply = reply
        self.toolCalls = toolCalls
        self.subAgentRounds = subAgentRounds
    }
}

public struct AgentToolCall: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public var progressMessage: String?
    public var status: ToolCallStatus
    public var input: [String: AnyCodable]?
    public let inputMessage: String?
    public var error: String?
    public var result: [ToolCallResultData]?
    public var resultDetails: [ToolResultItem]?
    public var invokeParams: InvokeClientToolParams?
    public var title: String?
    
    public enum ToolCallStatus: String, Codable {
        case waitForConfirmation, accepted, running, completed, error, cancelled
    }

    public init(
        id: String,
        name: String,
        progressMessage: String? = nil,
        status: ToolCallStatus,
        input: [String: AnyCodable]? = nil,
        inputMessage: String? = nil,
        error: String? = nil,
        result: [ToolCallResultData]? = nil,
        resultDetails: [ToolResultItem]? = nil,
        invokeParams: InvokeClientToolParams? = nil,
        title: String? = nil
    ) {
        self.id = id
        self.name = name
        self.progressMessage = progressMessage
        self.status = status
        self.input = input
        self.inputMessage = inputMessage
        self.error = error
        self.result = result
        self.resultDetails = resultDetails
        self.invokeParams = invokeParams
        self.title = title
    }

    public var isToolcallingLoopContinueTool: Bool {
        self.name == "internal.tool_calling_loop_continue_confirmation"
    }
}

public enum ToolCallResultData: Codable, Equatable {
    case text(String)
    case data(mimeType: String, data: String)
    
    private enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    private enum ItemType: String, Codable {
        case text, data
    }
    
    private struct DataValue: Codable {
        let mimeType: String
        let data: String
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)
        
        switch type {
        case .text:
            let value = try container.decode(String.self, forKey: .value)
            self = .text(value)
        case .data:
            let value = try container.decode(DataValue.self, forKey: .value)
            self = .data(mimeType: value.mimeType, data: value.data)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let string):
            try container.encode(ItemType.text, forKey: .type)
            try container.encode(string, forKey: .value)
        case .data(let mimeType, let data):
            try container.encode(ItemType.data, forKey: .type)
            try container.encode(DataValue(mimeType: mimeType, data: data), forKey: .value)
        }
    }
}

public enum ToolResultItem: Codable, Equatable {
    case text(String)
    case fileLocation(FileLocation)
    
    public struct FileLocation: Codable, Equatable {
        public let uri: String
        public let range: LSPRange
        
        public init(uri: String, range: LSPRange) {
            self.uri = uri
            self.range = range
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case type, value
    }
    
    private enum ItemType: String, Codable {
        case text, fileLocation
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ItemType.self, forKey: .type)
        
        switch type {
        case .text:
            let value = try container.decode(String.self, forKey: .value)
            self = .text(value)
        case .fileLocation:
            let value = try container.decode(FileLocation.self, forKey: .value)
            self = .fileLocation(value)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let string):
            try container.encode(ItemType.text, forKey: .type)
            try container.encode(string, forKey: .value)
        case .fileLocation(let location):
            try container.encode(ItemType.fileLocation, forKey: .type)
            try container.encode(location, forKey: .value)
        }
    }
}
