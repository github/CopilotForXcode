import Foundation

struct MCPApprovalStorage {
    private struct ServerApprovalState {
        var isServerAllowed: Bool = false
        var allowedTools: Set<String> = []
    }

    private struct ConversationApprovalState {
        var serverApprovals: [String: ServerApprovalState] = [:]
    }

    /// Storage for session-scoped approvals.
    private var approvals: [ConversationID: ConversationApprovalState] = [:]

    mutating func allowTool(scope: AutoApprovalScope, serverName: String, toolName: String) {
        guard case .session(let conversationId) = scope else { return }
        let server = normalize(serverName)
        let tool = normalize(toolName)
        guard !conversationId.isEmpty, !server.isEmpty, !tool.isEmpty else { return }

        approvals[conversationId, default: ConversationApprovalState()]
            .serverApprovals[server, default: ServerApprovalState()]
            .allowedTools
            .insert(tool)
    }

    mutating func allowServer(scope: AutoApprovalScope, serverName: String) {
        guard case .session(let conversationId) = scope else { return }
        let server = normalize(serverName)
        guard !conversationId.isEmpty, !server.isEmpty else { return }

        approvals[conversationId, default: ConversationApprovalState()]
            .serverApprovals[server, default: ServerApprovalState()]
            .isServerAllowed = true
    }

    func isAllowed(scope: AutoApprovalScope, serverName: String, toolName: String) -> Bool {
        guard case .session(let conversationId) = scope else { return false }
        let server = normalize(serverName)
        let tool = normalize(toolName)
        guard !conversationId.isEmpty, !server.isEmpty, !tool.isEmpty else { return false }

        guard let conversationState = approvals[conversationId],
              let serverState = conversationState.serverApprovals[server] else { return false }
        
        if serverState.isServerAllowed { return true }
        return serverState.allowedTools.contains(tool)
    }

    mutating func clear(scope: AutoApprovalScope) {
        guard case .session(let conversationId) = scope else { return }
        guard !conversationId.isEmpty else { return }
        approvals.removeValue(forKey: conversationId)
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
