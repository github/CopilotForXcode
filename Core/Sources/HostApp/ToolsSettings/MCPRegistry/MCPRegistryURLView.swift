import AppKit
import Logger
import SharedUIComponents
import SwiftUI
import Client
import XPCShared
import GitHubCopilotService
import ComposableArchitecture

struct MCPRegistryURLView: View {
    @State private var isExpanded: Bool = false
    @AppStorage(\.mcpRegistryBaseURL) var mcpRegistryBaseURL
    @AppStorage(\.mcpRegistryBaseURLHistory) private var mcpRegistryBaseURLHistory
    @State private var isLoading: Bool = false
    @State private var tempURLText: String = ""
    @State private var errorMessage: String = ""
    @State private var mcpRegistry: [MCPRegistryEntry]? = nil

    private let maxURLLength = 2048
    private let mcpRegistryUrlVersion = "/v0.1/servers"

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                DisclosureSettingsRow(
                    isExpanded: $isExpanded,
                    accessibilityLabel: { $0 ? "Collapse mcp registry base URL section" : "Expand mcp registry base URL section" },
                    title: { Text("MCP Registry Base URL").font(.headline) + Text(" (Optional)") },
                    subtitle: { Text("Connect to available MCP servers for your AI workflows using the Registry URL.") },
                    actions: {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().controlSize(.small)
                            }
                            
                            Button {
                                isExpanded = true
                            } label: {
                                HStack(spacing: 0) {
                                    Image(systemName: "square.and.pencil")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 12, height: 12, alignment: .center)
                                        .padding(4)
                                    Text("Edit URL")
                                }
                                .conditionalFontWeight(.semibold)
                            }
                            .buttonStyle(.bordered)
                            .help("Configure your MCP Registry Base URL")
                            .disabled(mcpRegistry?.first?.registryAccess == .registryOnly)
                            
                            Button { Task{ await loadMCPServers() } } label: {
                                HStack(spacing: 0) {
                                    Image(systemName: "square.grid.2x2")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 12, height: 12, alignment: .center)
                                        .padding(4)
                                    Text("Browse MCP Servers...")
                                }
                                .conditionalFontWeight(.semibold)
                            }
                            .buttonStyle(.bordered)
                            .help("Browse MCP Servers")
                        }
                        .padding(.vertical, 12)
                    }
                )
                
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        MCPRegistryURLInputField(
                            urlText: $tempURLText,
                            maxURLLength: maxURLLength,
                            isSheet: false,
                            mcpRegistryEntry: mcpRegistry?.first,
                            onValidationChange: { _ in
                                // Only validate, don't update mcpRegistryURL here
                            },
                            onCommit: {
                                // Update mcpRegistryURL when user presses Enter
                                tempURLText = tempURLText
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                    .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                                if tempURLText != mcpRegistryBaseURL {
                                    mcpRegistryBaseURL = tempURLText
                                }
                            }
                        )
                        
                        if !errorMessage.isEmpty {
                            Badge(text: errorMessage, level: .danger, icon: "xmark.circle.fill")
                        }
                    }
                    .padding(.leading, 36)
                    .padding([.trailing, .bottom], 20)
                    .background(QuaternarySystemFillColor.opacity(0.75))
                    .transition(.opacity.combined(with: .scale(scale: 1, anchor: .top)))
                    .onAppear {
                        tempURLText = mcpRegistryBaseURL
                    }
                }
            }
            .cornerRadius(12)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .inset(by: 0.5)
                    .stroke(SecondarySystemFillColor, lineWidth: 1)
                    .animation(.easeInOut(duration: 0.3), value: isExpanded)
            )
            .animation(.easeInOut(duration: 0.3), value: isExpanded)
            .onAppear {
                tempURLText = mcpRegistryBaseURL
                Task { await getMCPRegistryAllowlist() }
            }
            .onReceive(DistributedNotificationCenter.default().publisher(for: .authStatusDidChange)) { _ in
                Task { await getMCPRegistryAllowlist() }
            }
            .onChange(of: mcpRegistryBaseURL) { newValue in
                // Update the temp text to reflect the new URL
                tempURLText = newValue
                Task { await updateGalleryWindowIfOpen() }
            }
            .onChange(of: mcpRegistry) { _ in
                Task { await updateGalleryWindowIfOpen() }
            }
        }
    }
    
    private func loadMCPServers() async {
        // Update mcpRegistryURL with current tempURLText before loading
        tempURLText = tempURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        if tempURLText != mcpRegistryBaseURL {
            mcpRegistryBaseURL = tempURLText
        }
        
        isLoading = true
        defer { isLoading = false }
        do {
            let service = try getService()
            let serverList = try await service.listMCPRegistryServers(
                .init(baseUrl: mcpRegistryBaseURL + mcpRegistryUrlVersion, limit: 30, version: "latest")
            )
            
            guard let serverList = serverList, !serverList.servers.isEmpty else {
                Logger.client.info("No MCP servers found at registry URL: \(mcpRegistryBaseURL)")
                return
            }
            
            // Add to history on successful load
            mcpRegistryBaseURLHistory.addToHistory(mcpRegistryBaseURL)
            errorMessage = ""
            
            MCPServerGalleryWindow.open(serverList: serverList, mcpRegistryEntry: mcpRegistry?.first)
        } catch {
            Logger.client.error("Failed to load MCP servers from registry: \(error.localizedDescription)")
            if let serviceError = error as? XPCExtensionServiceError {
                errorMessage = serviceError.underlyingError?.localizedDescription ?? serviceError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            isExpanded = true
        }
    }
    
    private func getMCPRegistryAllowlist() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let service = try getService()
            
            // Only fetch allowlist if user is logged in
            let authStatus = try await service.getXPCServiceAuthStatus()
            guard authStatus?.status == .loggedIn else {
                Logger.client.info("User not logged in, skipping MCP registry allowlist fetch")
                return
            }
            
            let result = try await service.getMCPRegistryAllowlist()
            
            guard let result = result, !result.mcpRegistries.isEmpty else {
                if result == nil {
                    Logger.client.error("Failed to get allowlist result")
                } else {
                    mcpRegistry = []
                }
                return
            }
            
            if let firstRegistry = result.mcpRegistries.first {
                let entry = MCPRegistryEntry(
                    url: firstRegistry.url,
                    registryAccess: firstRegistry.registryAccess,
                    owner: firstRegistry.owner
                )
                mcpRegistry = [entry]
                Logger.client.info("Current MCP Registry Entry: \(entry)")
                
                // If registryOnly, force the URL to be the registry URL
                if entry.registryAccess == .registryOnly {
                    mcpRegistryBaseURL = entry.url
                    tempURLText = entry.url
                }
            }
        } catch {
            Logger.client.error("Failed to get MCP allowlist from registry: \(error)")
        }
    }
    
    private func updateGalleryWindowIfOpen() async {
        // Only update if the gallery window is currently open
        guard MCPServerGalleryWindow.isOpen() else {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Let the view model handle the entire update flow including clearing and fetching
        if let error = await MCPServerGalleryWindow.refreshFromURL(mcpRegistryEntry: mcpRegistry?.first) {
            // Display error in the URL view
            if let serviceError = error as? XPCExtensionServiceError {
                errorMessage = serviceError.underlyingError?.localizedDescription ?? serviceError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
            isExpanded = true
        } else {
            errorMessage = ""
        }
    }
}

#Preview {
    MCPRegistryURLView()
        .padding()
        .frame(width: 900)
}
