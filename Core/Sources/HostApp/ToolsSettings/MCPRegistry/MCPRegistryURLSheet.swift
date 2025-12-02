import GitHubCopilotService
import SwiftUI
import SharedUIComponents

struct MCPRegistryURLSheet: View {
    @AppStorage(\.mcpRegistryBaseURL) private var mcpRegistryBaseURL
    @AppStorage(\.mcpRegistryBaseURLHistory) private var mcpRegistryBaseURLHistory
    @Environment(\.dismiss) private var dismiss
    @State private var originalMcpRegistryBaseURL: String = ""
    @State private var isFormValid: Bool = true
    
    let mcpRegistryEntry: MCPRegistryEntry?
    let onURLUpdated: (() -> Void)?
    
    init(mcpRegistryEntry: MCPRegistryEntry? = nil, onURLUpdated: (() -> Void)? = nil) {
        self.mcpRegistryEntry = mcpRegistryEntry
        self.onURLUpdated = onURLUpdated
    }

    var body: some View {
        Form {
            VStack(alignment: .center, spacing: 20) {
                HStack(alignment: .center) {
                    Spacer()
                    Text("MCP Registry Base URL").font(.headline)
                    Spacer()
                    AdaptiveHelpLink(action: openHelpLink)
                }

                VStack(alignment: .leading, spacing: 4) {
                    MCPRegistryURLInputField(
                        urlText: $originalMcpRegistryBaseURL,
                        isSheet: true,
                        mcpRegistryEntry: mcpRegistryEntry,
                        onValidationChange: { isValid in
                            isFormValid = isValid
                        }
                    )
                }

                HStack(spacing: 8) {
                    Spacer()
                    Button("Cancel", role: .cancel) { dismiss() }
                    Button("Update") {
                        // Check if URL changed before updating
                        originalMcpRegistryBaseURL = originalMcpRegistryBaseURL
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        if originalMcpRegistryBaseURL != mcpRegistryBaseURL {
                            mcpRegistryBaseURL = originalMcpRegistryBaseURL
                            onURLUpdated?()
                        }
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isFormValid || mcpRegistryEntry?.registryAccess == .registryOnly)
                }
            }
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .padding(20)
        }
        .onAppear {
            loadExistingURL()
        }
    }

    private func loadExistingURL() {
        originalMcpRegistryBaseURL = mcpRegistryBaseURL
    }

    private func openHelpLink() {
        NSWorkspace.shared.open(URL(string: "https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp/select-an-mcp-registry")!)
    }
}
