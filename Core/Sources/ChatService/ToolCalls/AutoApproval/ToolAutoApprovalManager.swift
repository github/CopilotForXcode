import Foundation

public actor ToolAutoApprovalManager {
    public static let shared = ToolAutoApprovalManager()

    public enum AutoApproval: Equatable, Sendable {
        case mcpTool(scope: AutoApprovalScope, serverName: String, toolName: String)
        case mcpServer(scope: AutoApprovalScope, serverName: String)
        case sensitiveFile(
            scope: AutoApprovalScope,
            toolName: String,
            description: String,
            pattern: String?
        )
        case terminal(scope: AutoApprovalScope, commands: [String])
    }

    private var mcpStorage = MCPApprovalStorage()
    private var sensitiveFileStorage = SensitiveFileApprovalStorage()
    private var terminalStorage = TerminalApprovalStorage()

    public init() {}

    public func approve(_ approval: AutoApproval) {
        switch approval {
        case let .mcpTool(scope, serverName, toolName):
            switch scope {
            case .session(let conversationId):
                allowMCPTool(conversationId: conversationId, serverName: serverName, toolName: toolName)
            case .global:
                allowMCPToolGlobally(serverName: serverName, toolName: toolName)
            }

        case let .mcpServer(scope, serverName):
            switch scope {
            case .session(let conversationId):
                allowMCPServer(conversationId: conversationId, serverName: serverName)
            case .global:
                allowMCPServerGlobally(serverName: serverName)
            }

        case let .sensitiveFile(scope, toolName, description, pattern):
            switch scope {
            case .session(let conversationId):
                let key = resolveFileKey(description: description, pattern: pattern)
                allowSensitiveFile(conversationId: conversationId, toolName: toolName, fileKey: key)
            case .global:
                guard let pattern, !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    // Global approvals require an explicit pattern.
                    return
                }
                allowSensitiveRuleGlobally(description: description, pattern: pattern)
            }

        case let .terminal(scope, commands):
            switch scope {
            case .global:
                allowTerminalCommandGlobally(commands: commands)
            case .session(let conversationId):
                if commands.isEmpty {
                    allowTerminalAllCommandsInSession(conversationId: conversationId)
                } else {
                    allowTerminalCommandsInSession(conversationId: conversationId, commands: commands)
                }
            }
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

    // MARK: - Global MCP approvals

    public func allowMCPToolGlobally(serverName: String, toolName: String) {
        mcpStorage.allowTool(scope: .global, serverName: serverName, toolName: toolName)
    }

    public func allowMCPServerGlobally(serverName: String) {
        mcpStorage.allowServer(scope: .global, serverName: serverName)
    }

    public func isMCPAllowedGlobally(serverName: String, toolName: String) -> Bool {
        mcpStorage.isAllowed(scope: .global, serverName: serverName, toolName: toolName)
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

    // MARK: - Global Sensitive file approvals

    public func allowSensitiveRuleGlobally(description: String, pattern: String) {
        // toolName is intentionally ignored for global sensitive-file approvals.
        sensitiveFileStorage.allowFile(
            scope: .global,
            description: description,
            pattern: pattern
        )
    }

    // MARK: - Global terminal approvals

    /// Stores global auto-approvals for one or more terminal command lines.
    public func allowTerminalCommandGlobally(commands: [String]) {
        terminalStorage.allowCommands(scope: .global, commands: commands)
    }

    /// Stores session-scoped auto-approvals.
    ///
    /// Heuristic:
    /// - entries containing whitespace are treated as exact command lines
    /// - otherwise treated as command names (matching `cmd ...`)
    public func allowTerminalCommandsInSession(conversationId: String, commands: [String]) {
        terminalStorage.allowCommands(scope: .session(conversationId), commands: commands)
    }

    public func allowTerminalAllCommandsInSession(conversationId: String) {
        terminalStorage.allowAllCommands(scope: .session(conversationId))
    }

    public func isTerminalAllowed(conversationId: String, commandLine: String?) -> Bool {
        guard let commandLine, !commandLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return terminalStorage.isAllCommandsAllowedInSession(conversationId: conversationId)
        }

        return terminalStorage.isAllowed(scope: .session(conversationId), commandLine: commandLine)
    }

    private func resolveFileKey(description: String, pattern: String?) -> String {
        if let pattern, !pattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return pattern
        }
        return SensitiveFileConfirmationInfo(
            description: description,
            pattern: pattern
        ).sessionKey
    }

    // MARK: - Cleanup

    public func clearConversationData(conversationId: String?) {
        guard let conversationId else { return }
        mcpStorage.clear(scope: .session(conversationId))
        sensitiveFileStorage.clear(scope: .session(conversationId))
        terminalStorage.clear(scope: .session(conversationId))
    }

    public func clearGlobalData() {
        mcpStorage.clear(scope: .global)
        sensitiveFileStorage.clear(scope: .global)
        terminalStorage.clear(scope: .global)
    }
}

