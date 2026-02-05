import Foundation
import Preferences

struct TerminalApprovalStorage {
    /// Stored under `UserDefaults.autoApproval` with key `AutoApproval_Terminal_GlobalApprovals`.
    ///
    /// Stored as native property-list types (NSDictionary/NSArray/String)
    /// so users can edit values directly in the `*.prefs.plist`.
    ///
    /// Sample structure:
    /// ```
    /// {
    ///   "commands": {
    ///     "git status": true
    ///   }
    /// }
    /// ```

    private struct ConversationApprovalState {
        var isAllCommandsAllowed: Bool = false
        /// Stored as normalized command names (e.g. `git`, `brew`) and/or normalized
        /// exact command lines (e.g. `git status`).
        ///
        /// Note: command names are case-sensitive (e.g. `FOO` != `foo`).
        var allowedCommands: Set<String> = []
    }

    private var workspaceUserDefaults: UserDefaultsType { UserDefaults.autoApproval }

    /// Storage for session-scoped approvals.
    private var approvals: [ConversationID: ConversationApprovalState] = [:]

    mutating func allowAllCommands(scope: AutoApprovalScope) {
        guard case .session(let conversationId) = scope else { return }
        guard !conversationId.isEmpty else { return }
        approvals[conversationId, default: ConversationApprovalState()].isAllCommandsAllowed = true
    }

    mutating func allowCommands(scope: AutoApprovalScope, commands: [String]) {
        switch scope {
        case .global:
            allowCommandsGlobally(commands: commands)
        case .session(let conversationId):
            allowCommandsInSession(conversationId: conversationId, commands: commands)
        }
    }

    func isAllowed(scope: AutoApprovalScope, commandLine: String) -> Bool {
        guard case .session(let conversationId) = scope else { return false }

        let normalizedCommandLine = normalizeCommandLine(commandLine)
        guard !normalizedCommandLine.isEmpty else { return false }

        return isAllowedInSession(conversationId: conversationId, commandLine: normalizedCommandLine)
    }

    func isAllCommandsAllowedInSession(conversationId: ConversationID) -> Bool {
        guard !conversationId.isEmpty else { return false }
        return approvals[conversationId]?.isAllCommandsAllowed == true
    }

    mutating func clear(scope: AutoApprovalScope) {
        switch scope {
        case .session(let conversationId):
            approvals.removeValue(forKey: conversationId)
        case .global:
            workspaceUserDefaults.set(TerminalCommandsRules(), for: \.terminalCommandsGlobalApprovals)
        }
    }

    // MARK: - Global operations (persisted)

    private mutating func storeRuleInGlobal(commandKey: String, autoApprove: Bool) {
        var state = loadGlobalApprovalState()
        state.commands[commandKey] = autoApprove

        saveGlobalApprovalState(state)
        NotificationCenter.default.post(
            name: .githubCopilotAgentAutoApprovalDidChange,
            object: nil
        )
    }

    private mutating func allowCommandsGlobally(commands: [String]) {
        let keys = commands
            .map { normalizeCommandLine($0) }
            .filter { !$0.isEmpty }

        guard !keys.isEmpty else { return }

        for key in keys {
            storeRuleInGlobal(commandKey: key, autoApprove: true)
        }
    }

    private mutating func allowCommandsInSession(conversationId: String, commands: [String]) {
        guard !conversationId.isEmpty else { return }

        let trimmed = commands.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return }

        var state = approvals[conversationId, default: ConversationApprovalState()]

        for item in trimmed {
            // Heuristic:
            // - entries containing whitespace are treated as exact command lines
            // - otherwise treated as command names (matching `cmd ...`)
            if item.rangeOfCharacter(from: .whitespacesAndNewlines) != nil {
                let exact = normalizeCommandLine(item)
                if !exact.isEmpty {
                    state.allowedCommands.insert(exact)
                }
            } else {
                let name = normalizeCommandLine(item)
                if !name.isEmpty {
                    state.allowedCommands.insert(name)
                }
            }
        }

        approvals[conversationId] = state
    }

    private func isAllowedInSession(conversationId: String, commandLine: String) -> Bool {
        guard !conversationId.isEmpty else { return false }
        guard let state = approvals[conversationId] else { return false }

        if state.isAllCommandsAllowed { return true }
        if state.allowedCommands.contains(commandLine) { return true }

        let requiredCommandNames = ToolAutoApprovalManager.extractTerminalCommandNames(from: commandLine)
            .map { normalizeCommandLine($0) }
            .filter { !$0.isEmpty }

        guard !requiredCommandNames.isEmpty else { return false }
        return requiredCommandNames.allSatisfy { state.allowedCommands.contains($0) }
    }

    private func loadGlobalApprovalState() -> TerminalCommandsRules {
        workspaceUserDefaults.value(for: \.terminalCommandsGlobalApprovals)
    }

    private func saveGlobalApprovalState(_ state: TerminalCommandsRules) {
        workspaceUserDefaults.set(state, for: \.terminalCommandsGlobalApprovals)
    }

    // MARK: - Key normalization

    private func normalizeCommandLine(_ commandLine: String) -> String {
        commandLine.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
