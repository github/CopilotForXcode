import Foundation

// MARK: - Agent Mode Icon Constants

enum AgentModeIcon {
    /// Icon for Plan mode (SF Symbol: checklist)
    static let plan = "checklist"
    
    /// Icon for Agent mode (Custom asset: Agent)
    static let agent = "Agent"
    
    /// Icon for create/add actions (SF Symbol: plus)
    static let plus = "plus"
    
    /// Returns the appropriate icon name for a given agent mode name
    /// - Parameter modeName: The name of the agent mode
    /// - Returns: The icon name to use, or nil for custom agents
    static func icon(for modeName: String) -> String {
        return modeName.lowercased() == "plan" ? plan : agent
    }
}
