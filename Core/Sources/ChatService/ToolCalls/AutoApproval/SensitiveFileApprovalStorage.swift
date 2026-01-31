import Foundation
import Preferences

struct SensitiveFileApprovalStorage {
    /// Stored under `UserDefaults.autoApproval` with key `AutoApproval_SensitiveFiles_GlobalApprovals`.
    ///
    /// Stored as native property-list types (NSDictionary/NSArray/String)
    /// so users can edit values directly in the `*.prefs.plist`.
    ///
    /// Sample structure:
    /// ```
    /// {
    ///   "rules": {
    ///     "**/*.env": { "description": "Secrets", "autoApprove": true }
    ///   }
    /// }
    /// ```

    private struct ToolApprovalState {
        var allowedFiles: Set<String> = []
    }

    private struct ConversationApprovalState {
        var toolApprovals: [String: ToolApprovalState] = [:]
    }


    /// Storage for session-scoped approvals.
    private var approvals: [ConversationID: ConversationApprovalState] = [:]

    private var workspaceUserDefaults: UserDefaultsType { UserDefaults.autoApproval }

    mutating func allowFile(
        scope: AutoApprovalScope,
        toolName: String,
        fileKey: String
    ) {
        guard case .session(let conversationId) = scope else { return }

        let tool = normalize(toolName)
        let key = normalize(fileKey)
        guard !tool.isEmpty, !key.isEmpty else { return }

        allowFileInSession(conversationId: conversationId, tool: tool, fileKey: key)
    }

    mutating func allowFile(
        scope: AutoApprovalScope,
        description: String,
        pattern: String
    ) {
        guard case .global = scope else { return }

        let ruleKey = normalize(pattern)
        guard !ruleKey.isEmpty else { return }

        storeRuleInGlobal(
            ruleKey: ruleKey,
            description: normalize(description),
            autoApprove: true
        )
    }

    func isAllowed(scope: AutoApprovalScope, toolName: String, fileKey: String) -> Bool {
        guard case .session(let conversationId) = scope else { return false }

        let tool = normalize(toolName)
        let key = normalize(fileKey)
        guard !conversationId.isEmpty, !tool.isEmpty, !key.isEmpty else { return false }

        return isAllowedInSession(conversationId: conversationId, tool: tool, fileKey: key)
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

    private mutating func allowFileInSession(conversationId: String, tool: String, fileKey: String) {
        guard !conversationId.isEmpty else { return }
        approvals[conversationId, default: ConversationApprovalState()]
            .toolApprovals[tool, default: ToolApprovalState()]
            .allowedFiles
            .insert(fileKey)
    }

    private func isAllowedInSession(conversationId: String, tool: String, fileKey: String) -> Bool {
        guard !conversationId.isEmpty else { return false }
        return approvals[conversationId]?.toolApprovals[tool]?.allowedFiles.contains(fileKey) == true
    }

    private mutating func clearSession(conversationId: String) {
        guard !conversationId.isEmpty else { return }
        approvals.removeValue(forKey: conversationId)
    }

    // MARK: - Global operations (persisted)

    private mutating func storeRuleInGlobal(
        ruleKey: String,
        description: String,
        autoApprove: Bool
    ) {
        var state = loadGlobalApprovalState()
        var rule = state.rules[ruleKey] ?? SensitiveFileRule(description: "", autoApprove: false)
        
        if !description.isEmpty {
            rule.description = description
        }
        rule.autoApprove = autoApprove
        state.rules[ruleKey] = rule
        
        saveGlobalApprovalState(state)
        NotificationCenter.default.post(
            name: .githubCopilotAgentAutoApprovalDidChange,
            object: nil
        )
    }

    private mutating func clearGlobal() {
        workspaceUserDefaults.set(SensitiveFilesRules(), for: \.sensitiveFilesGlobalApprovals)
    }

    private func loadGlobalApprovalState() -> SensitiveFilesRules {
        return workspaceUserDefaults.value(for: \.sensitiveFilesGlobalApprovals)
    }

    private func saveGlobalApprovalState(_ state: SensitiveFilesRules) {
        workspaceUserDefaults.set(state, for: \.sensitiveFilesGlobalApprovals)
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
