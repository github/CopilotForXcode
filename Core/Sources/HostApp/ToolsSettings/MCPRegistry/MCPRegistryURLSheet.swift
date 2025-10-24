import GitHubCopilotService
import SwiftUI

struct MCPRegistryURLSheet: View {
    @AppStorage(\.mcpRegistryURL) private var mcpRegistryURL
    @AppStorage(\.mcpRegistryURLHistory) private var mcpRegistryURLHistory
    @Environment(\.dismiss) private var dismiss
    @State private var originalMcpRegistryURL: String = ""
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
                    Text("MCP Registry URL").font(.headline)
                    Spacer()
                    AdaptiveHelpLink(action: openHelpLink)
                }

                VStack(alignment: .leading, spacing: 4) {
                    MCPRegistryURLInputField(
                        urlText: $originalMcpRegistryURL,
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
                        originalMcpRegistryURL = originalMcpRegistryURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        if originalMcpRegistryURL != mcpRegistryURL {
                            mcpRegistryURL = originalMcpRegistryURL
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
        originalMcpRegistryURL = mcpRegistryURL
    }

    private func openHelpLink() {
        NSWorkspace.shared.open(URL(string: "https://docs.github.com/en/copilot/how-tos/provide-context/use-mcp/select-an-mcp-registry")!)
    }
}
