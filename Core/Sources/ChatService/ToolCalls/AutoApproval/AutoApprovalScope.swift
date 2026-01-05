import Foundation

public typealias ConversationID = String

public enum AutoApprovalScope: Hashable {
    case session(ConversationID)
    // Future scopes:
    // case workspace(String)
    // case global
}
