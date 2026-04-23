import GitHubCopilotService
import Logger
import SharedUIComponents
import SwiftUI
import SystemUtils

struct MCPXcodeServerInstallView: View {
    @State private var xcodeVersion: String? = SystemUtils.xcodeVersion
    @State private var isConfigured: Bool = false
    @State private var isInstalling: Bool = false
    @State private var installError: String? = nil
    /// Server names from mcp.json whose config matches xcrun mcpbridge.
    /// Cached to avoid repeated file I/O during SwiftUI rendering.
    @State private var configuredXcodeServerNames: Set<String> = []
    @ObservedObject private var mcpToolManager = CopilotMCPToolManagerObservable.shared
    @ObservedObject private var registryService = MCPRegistryService.shared

    private let requiredXcodeVersion = "26.4"
    private let serverName = "xcode"

    private var meetsVersionRequirement: Bool {
        guard let version = xcodeVersion else { return false }
        return version.compare(requiredXcodeVersion, options: .numeric) != .orderedAscending
    }

    private var isConnected: Bool {
        mcpToolManager.availableMCPServerTools.contains { server in
            configuredXcodeServerNames.contains(server.name) &&
            server.status == .running &&
            !server.tools.isEmpty
        }
    }

    /// Configured in mcp.json but not yet showing in available tools from the language server
    private var isConfiguredButNotConnected: Bool {
        isConfigured && !isConnected
    }

    private var isAlreadyInstalled: Bool {
        isConfigured || isConnected
    }

    private var isRegistryOnly: Bool {
        registryService.mcpRegistryEntries?.first?.registryAccess == .registryOnly
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Xcode MCP Server")
                    .font(.headline)
                    .padding(.vertical, 4)

                subtitleView()
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            actionsView()
                .padding(.vertical, 12)
        }
        .padding(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
        .background(QuaternarySystemFillColor.opacity(0.75))
        .settingsContainerStyle(isExpanded: false)
        .onAppear {
            checkInstallationStatus()
            Task { await registryService.refreshAllowlist() }
        }
        .onChange(of: mcpToolManager.availableMCPServerTools) { _ in
            checkInstallationStatus()
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func subtitleView() -> some View {
        if !meetsVersionRequirement {
            let versionText = xcodeVersion ?? "unknown"
            Text("Requires Xcode \(requiredXcodeVersion) or later. Current version: \(versionText).")
        } else if isConnected {
            Text("Xcode's built-in MCP server is connected, enabling richer editor integration.")
        } else if isRegistryOnly {
            Text("Manual installation of Xcode's built-in MCP server is blocked by your organization's registry policy. Please check the MCP Registry for an approved installation option, or contact your enterprise IT administrator.")
        } else if isConfiguredButNotConnected {
            Text("Please confirm in Xcode to allow the built-in MCP server.")
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Connect Copilot to Xcode's built-in MCP server to enable richer editor integration.")
                if let installError {
                    Text(installError)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }

    @ViewBuilder
    private func actionsView() -> some View {
        if !meetsVersionRequirement {
            EmptyView()
        } else if isConnected {
            Text("Connected").foregroundColor(.secondary)
        } else if isRegistryOnly {
            EmptyView()
        } else if isConfiguredButNotConnected {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Waiting for connection...")
                    .foregroundColor(.secondary)
            }
        } else {
            Button {
                installXcodeMCPServer()
            } label: {
                HStack(spacing: 4) {
                    if isInstalling {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "plus.circle")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12, alignment: .center)
                            .padding(2)
                    }
                    Text("Install")
                }
                .conditionalFontWeight(.semibold)
            }
            .buttonStyle(.bordered)
            .disabled(isInstalling)
        }
    }

    // MARK: - Actions

    private func checkInstallationStatus() {
        let (configured, names) = readXcodeMCPServerNamesFromConfig()
        isConfigured = configured
        configuredXcodeServerNames = names
    }

    /// Returns (isConfigured, setOfMatchingServerNames) by reading mcp.json once.
    private func readXcodeMCPServerNamesFromConfig() -> (Bool, Set<String>) {
        let configFileURL = URL(fileURLWithPath: mcpConfigFilePath)
        guard FileManager.default.fileExists(atPath: configFileURL.path),
              let data = try? Data(contentsOf: configFileURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = json["servers"] as? [String: Any]
        else {
            return (false, [])
        }

        var names = Set<String>()
        for (key, value) in servers {
            guard let serverConfig = value as? [String: Any] else { continue }
            let command = serverConfig["command"] as? String ?? ""
            let args = serverConfig["args"] as? [String] ?? []
            if command.contains("xcrun") && args.contains(where: { $0.contains("mcpbridge") }) {
                names.insert(key)
            }
        }
        return (!names.isEmpty, names)
    }

    private func installXcodeMCPServer() {
        isInstalling = true
        installError = nil

        let configFileURL = URL(fileURLWithPath: mcpConfigFilePath)
        let fileManager = FileManager.default

        do {
            if !fileManager.fileExists(atPath: configDirectory.path) {
                try fileManager.createDirectory(
                    at: configDirectory,
                    withIntermediateDirectories: true
                )
            }

            var config: [String: Any]
            if fileManager.fileExists(atPath: configFileURL.path),
               let data = try? Data(contentsOf: configFileURL),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            {
                config = existing
            } else {
                config = ["servers": [String: Any]()]
            }

            var servers = config["servers"] as? [String: Any] ?? [:]

            // Skip write if the entry already points to xcrun mcpbridge
            if let existing = servers[serverName] as? [String: Any],
               let command = existing["command"] as? String,
               let args = existing["args"] as? [String],
               command.contains("xcrun") && args.contains(where: { $0.contains("mcpbridge") })
            {
                isConfigured = true
                configuredXcodeServerNames.insert(serverName)
                isInstalling = false
                return
            }

            servers[serverName] = [
                "type": "stdio",
                "command": "xcrun",
                "args": ["mcpbridge"]
            ]

            config["servers"] = servers

            let jsonData = try JSONSerialization.data(
                withJSONObject: config,
                options: [.prettyPrinted, .sortedKeys]
            )
            try jsonData.write(to: configFileURL, options: .atomic)

            isConfigured = true
            configuredXcodeServerNames.insert(serverName)
            Logger.client.info("Successfully added Xcode MCP Server to configuration")
        } catch {
            installError = "Failed to update configuration: \(error.localizedDescription)"
            Logger.client.error("Failed to install Xcode MCP Server: \(error)")
        }

        isInstalling = false
    }
}
