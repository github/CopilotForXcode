import Foundation

public actor ToolAutoApprovalManager {
    public static let shared = ToolAutoApprovalManager()

    public enum AutoApproval: Equatable, Sendable {
        case mcpTool(conversationId: String, serverName: String, toolName: String)
        case mcpServer(conversationId: String, serverName: String)
        case sensitiveFile(conversationId: String, toolName: String, fileKey: String)
    }

    private var mcpStorage = MCPApprovalStorage()
    private var sensitiveFileStorage = SensitiveFileApprovalStorage()

    public init() {}

    public func approve(_ approval: AutoApproval) {
        switch approval {
        case let .mcpTool(conversationId, serverName, toolName):
            allowMCPTool(conversationId: conversationId, serverName: serverName, toolName: toolName)
        case let .mcpServer(conversationId, serverName):
            allowMCPServer(conversationId: conversationId, serverName: serverName)
        case let .sensitiveFile(conversationId, toolName, fileKey):
            allowSensitiveFile(conversationId: conversationId, toolName: toolName, fileKey: fileKey)
        }
    }

    // MARK: - MCP approvals

    public func allowMCPTool(conversationId: String, serverName: String, toolName: String) {
        mcpStorage.allowTool(scope: .session(conversationId), serverName: serverName, toolName: toolName)
    }

    public func allowMCPServer(conversationId: String, serverName: String) {
        mcpStorage.allowServer(scope: .session(conversationId), serverName: serverName)
    }

    public func isMCPAllowed(
        conversationId: String,
        serverName: String,
        toolName: String
    ) -> Bool {
        mcpStorage.isAllowed(scope: .session(conversationId), serverName: serverName, toolName: toolName)
    }

    // MARK: - Sensitive file approvals

    public func allowSensitiveFile(conversationId: String, toolName: String, fileKey: String) {
        sensitiveFileStorage.allowFile(scope: .session(conversationId), toolName: toolName, fileKey: fileKey)
    }

    public func isSensitiveFileAllowed(
        conversationId: String,
        toolName: String,
        fileKey: String
    ) -> Bool {
        sensitiveFileStorage.isAllowed(scope: .session(conversationId), toolName: toolName, fileKey: fileKey)
    }

    // MARK: - Cleanup

    public func clearConversationData(conversationId: String?) {
        guard let conversationId else { return }
        mcpStorage.clear(scope: .session(conversationId))
        sensitiveFileStorage.clear(scope: .session(conversationId))
    }
}

