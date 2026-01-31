import Foundation
import Preferences

struct MCPApprovalStorage {
    /// Stored under `UserDefaults.autoApproval` with key `AutoApproval_MCP_GlobalApprovals`.
    ///
    /// Stored as native property-list types (NSDictionary/NSArray/Bool/String)
    /// so users can edit values directly in the `*.prefs.plist`.
    ///
    /// Sample structure:
    /// ```
    /// {
    ///   "servers": {
    ///     "github": {
    ///       "isServerAllowed": false,
    ///       "allowedTools": ["search_issues", "get_issue"]
    ///     },
    ///     "my-filesystem-server": {
    ///       "isServerAllowed": true,
    ///       "allowedTools": []
    ///     }
    ///   }
    /// }
    /// ```

    private struct ServerApprovalState {
        var isServerAllowed: Bool = false
        var allowedTools: Set<String> = []
    }

    private struct ConversationApprovalState {
        var serverApprovals: [String: ServerApprovalState] = [:]
    }


    /// Storage for session-scoped approvals.
    private var approvals: [ConversationID: ConversationApprovalState] = [:]

    private var workspaceUserDefaults: UserDefaultsType { UserDefaults.autoApproval }

    mutating func allowTool(scope: AutoApprovalScope, serverName: String, toolName: String) {
        let server = normalize(serverName)
        let tool = normalize(toolName)
        guard !server.isEmpty, !tool.isEmpty else { return }

        switch scope {
        case .session(let conversationId):
            allowToolInSession(conversationId: conversationId, server: server, tool: tool)
        case .global:
            allowToolInGlobal(server: server, tool: tool)
        }
    }

    mutating func allowServer(scope: AutoApprovalScope, serverName: String) {
        let server = normalize(serverName)
        guard !server.isEmpty else { return }

        switch scope {
        case .session(let conversationId):
            allowServerInSession(conversationId: conversationId, server: server)
        case .global:
            allowServerInGlobal(server: server)
        }
    }

    func isAllowed(scope: AutoApprovalScope, serverName: String, toolName: String) -> Bool {
        let server = normalize(serverName)
        let tool = normalize(toolName)
        guard !server.isEmpty, !tool.isEmpty else { return false }

        switch scope {
        case .session(let conversationId):
            return isAllowedInSession(conversationId: conversationId, server: server, tool: tool)
        case .global:
            return isAllowedInGlobal(server: server, tool: tool)
        }
    }

    mutating func clear(scope: AutoApprovalScope) {
        switch scope {
        case .session(let conversationId):
            clearSession(conversationId: conversationId)
        case .global:
            clearGlobal()
        }
    }

    // MARK: - Session-scoped operations (in-memory)

    private mutating func allowToolInSession(conversationId: String, server: String, tool: String) {
        guard !conversationId.isEmpty else { return }
        approvals[conversationId, default: ConversationApprovalState()]
            .serverApprovals[server, default: ServerApprovalState()]
            .allowedTools
            .insert(tool)
    }

    private mutating func allowServerInSession(conversationId: String, server: String) {
        guard !conversationId.isEmpty else { return }
        approvals[conversationId, default: ConversationApprovalState()]
            .serverApprovals[server, default: ServerApprovalState()]
            .isServerAllowed = true
    }

    private func isAllowedInSession(conversationId: String, server: String, tool: String) -> Bool {
        guard !conversationId.isEmpty else { return false }
        guard let conversationState = approvals[conversationId],
              let serverState = conversationState.serverApprovals[server] else { return false }
        if serverState.isServerAllowed { return true }
        return serverState.allowedTools.contains(tool)
    }

    private mutating func clearSession(conversationId: String) {
        guard !conversationId.isEmpty else { return }
        approvals.removeValue(forKey: conversationId)
    }

    // MARK: - Global operations (persisted)

    private mutating func allowToolInGlobal(server: String, tool: String) {
        var globalApprovals = workspaceUserDefaults.value(for: \.mcpServersGlobalApprovals)
        var serverState = globalApprovals.servers[server] ?? MCPServerApprovalState()

        serverState.allowedTools.insert(tool)
        globalApprovals.servers[server] = serverState
        workspaceUserDefaults.set(globalApprovals, for: \.mcpServersGlobalApprovals)
        
        NotificationCenter.default.post(
            name: .githubCopilotAgentAutoApprovalDidChange,
            object: nil
        )
    }

    private mutating func allowServerInGlobal(server: String) {
        var globalApprovals = workspaceUserDefaults.value(for: \.mcpServersGlobalApprovals)
        var serverState = globalApprovals.servers[server] ?? MCPServerApprovalState()
        
        serverState.isServerAllowed = true
        globalApprovals.servers[server] = serverState
        workspaceUserDefaults.set(globalApprovals, for: \.mcpServersGlobalApprovals)
        
        NotificationCenter.default.post(
            name: .githubCopilotAgentAutoApprovalDidChange,
            object: nil
        )
    }

    private func isAllowedInGlobal(server: String, tool: String) -> Bool {
        let globalApprovals = workspaceUserDefaults.value(for: \.mcpServersGlobalApprovals)
        guard let serverState = globalApprovals.servers[server] else { return false }
        
        if serverState.isServerAllowed { return true }
        return serverState.allowedTools.contains(tool)
    }

    private mutating func clearGlobal() {
        workspaceUserDefaults.set(AutoApprovedMCPServers(), for: \.mcpServersGlobalApprovals)
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
