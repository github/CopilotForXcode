import SwiftUI
import ConversationServiceProvider

struct AgentModeDescription {
    static func descriptionText(for mode: ConversationMode) -> String {
        // Check if it's the built-in "Agent" mode
        if mode.isDefaultAgent {
            return "The selected tools will be applied globally for all chat sessions that use the default agent."
        }
        
        // Check if it's a custom mode
        if !mode.isBuiltIn {
            return "The selected tools are configured by the '\(mode.name)' custom agent. Changes to the tools will be applied to the custom agent file as well."
        }
        
        // Other built-in modes (like Plan, etc.)
        return "The selected tools are configured by the '\(mode.name)' agent. Changes to the tools are not allowed for now."
    }
}

/// Shared description view for agent modes
struct AgentModeDescriptionView: View {
    let selectedMode: ConversationMode
    let isLoadingMode: Bool
    
    var body: some View {
        if !isLoadingMode {
            Text(AgentModeDescription.descriptionText(for: selectedMode))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
