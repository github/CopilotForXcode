import Foundation

/// Helper class for determining tool enabled state and interaction permissions based on agent mode
public final class AgentModeToolHelpers {
    public static func makeConfigurationKey(serverName: String, toolName: String) -> String {
        return "\(serverName)/\(toolName)"
    }

    /// Determines if a tool should be enabled based on the selected agent mode
    public static func isToolEnabledInMode(
        configurationKey: String,
        currentStatus: ToolStatus,
        selectedMode: ConversationMode
    ) -> Bool {
        // For modes other than default agent mode, check if tool is in customTools list
        if !selectedMode.isDefaultAgent {
            guard let customTools = selectedMode.customTools else {
                // If customTools is nil, no tools are enabled
                return false
            }
            
            // If customTools is empty, no tools are enabled
            if customTools.isEmpty {
                return false
            }
            
            return customTools.contains(configurationKey)
        }
        
        // For built-in modes (Agent, Plan, etc.), use tool's current status
        return currentStatus == .enabled
    }

    /// Determines if users should be allowed to interact with tool checkboxes
    public static func isInteractionAllowed(selectedMode: ConversationMode) -> Bool {        
        // Allow interaction for built-in "Agent" mode and custom modes
        if selectedMode.isDefaultAgent || !selectedMode.isBuiltIn {
            return true
        }
        
        // Disable interaction for other built-in modes (like Plan)
        return false
    }
    
    private init() {}
}
