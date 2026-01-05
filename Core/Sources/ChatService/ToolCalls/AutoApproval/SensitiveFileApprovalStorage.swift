import Foundation

struct SensitiveFileApprovalStorage {
    private struct ToolApprovalState {
        var allowedFiles: Set<String> = []
    }

    private struct ConversationApprovalState {
        var toolApprovals: [String: ToolApprovalState] = [:]
    }

    /// Storage for session-scoped approvals.
    private var approvals: [ConversationID: ConversationApprovalState] = [:]

    mutating func allowFile(scope: AutoApprovalScope, toolName: String, fileKey: String) {
        guard case .session(let conversationId) = scope else { return }
        let tool = normalize(toolName)
        let key = normalize(fileKey)
        guard !conversationId.isEmpty, !tool.isEmpty, !key.isEmpty else { return }

        approvals[conversationId, default: ConversationApprovalState()]
            .toolApprovals[tool, default: ToolApprovalState()]
            .allowedFiles
            .insert(key)
    }

    func isAllowed(scope: AutoApprovalScope, toolName: String, fileKey: String) -> Bool {
        guard case .session(let conversationId) = scope else { return false }
        let tool = normalize(toolName)
        let key = normalize(fileKey)
        guard !conversationId.isEmpty, !tool.isEmpty, !key.isEmpty else { return false }

        return approvals[conversationId]?.toolApprovals[tool]?.allowedFiles.contains(key) == true
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
