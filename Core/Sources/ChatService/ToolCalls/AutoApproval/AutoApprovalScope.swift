import Foundation

public typealias ConversationID = String

public enum AutoApprovalScope: Hashable {
    case session(ConversationID)
    /// Applies to all workspaces. Persisted in `UserDefaults.autoApproval`.
    case global
    // Future scopes:
    // case workspace(String)
}
