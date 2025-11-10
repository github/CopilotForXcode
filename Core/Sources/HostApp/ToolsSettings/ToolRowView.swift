import SwiftUI
import ConversationServiceProvider

/// Individual tool row
struct ToolRow: View {
    let toolName: String
    let toolDescription: String?
    let toolStatus: ToolStatus
    let isServerEnabled: Bool
    @Binding var isToolEnabled: Bool
    var isInteractionAllowed: Bool = true
    let onToolToggleChanged: (Bool) -> Void

    var body: some View {
        HStack(alignment: .center) {
            Toggle(isOn: Binding(
                get: { isToolEnabled },
                set: { newValue in
                    isToolEnabled = newValue
                    onToolToggleChanged(newValue)
                }
            )) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(toolName).fontWeight(.medium)
                        
                        if let description = toolDescription {
                            Text(description)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .help(description)
                        }
                    }

                    Divider().padding(.vertical, 4)
                }
            }
            .disabled(!isInteractionAllowed)
        }
        .padding(.vertical, 0)
    }
}
