import Client
import ComposableArchitecture
import ConversationServiceProvider
import Foundation
import GitHubCopilotService
import Logger
import Persist
import SharedUIComponents
import SwiftUI
import SystemUtils
import Toast

struct MCPConfigView: View {
    @State private var mcpConfig: String = ""
    @Environment(\.toast) var toast
    @ObservedObject private var featureFlags = FeatureFlagManager.shared
    @ObservedObject private var copilotPolicy = CopilotPolicyManager.shared
    @State private var configFilePath: String = mcpConfigFilePath
    @State private var isMonitoring: Bool = false
    @State private var lastModificationDate: Date? = nil
    @State private var fileMonitorTask: Task<Void, Error>? = nil
    @State private var selectedOption = ToolType.MCP
    @State private var selectedMode: ConversationMode = .defaultAgent
    @Environment(\.colorScheme) var colorScheme
    
    private var isCustomAgentEnabled: Bool {
        featureFlags.isEditorPreviewEnabled && copilotPolicy.isCustomAgentEnabled
    }

    private static var lastSyncTimestamp: Date? = nil
    @State private var debounceTimer: Timer?
    private static let refreshDebounceInterval: TimeInterval = 1.0 // 1.0 second debounce

    enum ToolType: String, CaseIterable, Identifiable {
        case MCP, BuiltIn
        var id: Self { self }
    }

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                Picker("", selection: $selectedOption) {
                    if #available(macOS 26.0, *) {
                        Text("MCP".padded(centerTo: 24, with: "\u{2002}")).tag(ToolType.MCP)
                        Text("Built-In".padded(centerTo: 24, with: "\u{2002}")).tag(ToolType.BuiltIn)
                    } else {
                        Text("MCP").tag(ToolType.MCP)
                        Text("Built-In").tag(ToolType.BuiltIn)
                    }
                }
                .frame(width: 400)
                .labelsHidden()
                .pickerStyle(.segmented)
                .padding(.top, 12)
                .padding(.bottom, 4)

                Group {
                    if selectedOption == .MCP {
                        VStack(alignment: .leading, spacing: 8) {
                            MCPIntroView(isMCPFFEnabled: featureFlags.isMCPEnabled)
                            if featureFlags.isMCPEnabled {
                                MCPManualInstallView()

                                if featureFlags.isEditorPreviewEnabled && ( SystemUtils.isPrereleaseBuild || SystemUtils.isDeveloperMode ) {
                                    MCPRegistryURLView()
                                }

                                MCPToolsListView(
                                    selectedMode: $selectedMode,
                                    isCustomAgentEnabled: isCustomAgentEnabled
                                )

                                HStack {
                                    Spacer()
                                    AdaptiveHelpLink(action: { NSWorkspace.shared.open(
                                        URL(string: "https://modelcontextprotocol.io/introduction")!
                                    ) })
                                }
                            }
                        }
                        .onAppear {
                            setupConfigFilePath()
                            if featureFlags.isMCPEnabled {
                                startMonitoringConfigFile()
                            }
                        }
                        .onDisappear {
                            stopMonitoringConfigFile()
                        }
                        .onChange(of: featureFlags.isMCPEnabled) { newMCPFFEnabled in
                            if newMCPFFEnabled {
                                startMonitoringConfigFile()
                                refreshConfiguration()
                            } else {
                                stopMonitoringConfigFile()
                            }
                        }
                        .onChange(of: isCustomAgentEnabled) { isEnabled in
                            if !isEnabled && !selectedMode.isDefaultAgent {
                                selectedMode = .defaultAgent
                            }
                        }
                    } else {
                        BuiltInToolsListView(
                            selectedMode: $selectedMode,
                            isCustomAgentEnabled: isCustomAgentEnabled
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func setupConfigFilePath() {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: configDirectory.path) {
            try? fileManager.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }

        // If the file doesn't exist, create one with a proper structure
        let configFileURL = URL(fileURLWithPath: configFilePath)
        if !fileManager.fileExists(atPath: configFilePath) {
            try? """
            {
                "servers": {

                }
            }
            """.write(to: configFileURL, atomically: true, encoding: .utf8)
        }

        // Read the current content from file and ensure it's valid JSON
        mcpConfig = readAndValidateJSON(from: configFileURL) ?? "{}"

        // Get initial modification date
        lastModificationDate = getFileModificationDate(url: configFileURL)
    }

    /// Reads file content and validates it as JSON, returning only the "servers" object
    private func readAndValidateJSON(from url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        // Try to parse as JSON to validate
        do {
            // First verify it's valid JSON
            let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            // Extract the "servers" object
            guard let servers = jsonObject?["servers"] as? [String: Any] else {
                Logger.client.info("No 'servers' key found in MCP configuration")
                toast("No 'servers' key found in MCP configuration", .error)
                // Return empty object if no servers section
                return "{}"
            }

            // Convert the servers object back to JSON data
            let serversData = try JSONSerialization.data(
                withJSONObject: servers, options: [.prettyPrinted])

            // Return as a string
            return String(data: serversData, encoding: .utf8)
        } catch {
            // If parsing fails, return nil
            Logger.client.info("Parsing MCP JSON error: \(error)")
            toast("Invalid JSON in MCP configuration file", .error)
            return nil
        }
    }

    private func getFileModificationDate(url: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }

    private func startMonitoringConfigFile() {
        stopMonitoringConfigFile()  // Stop existing monitoring if any

        isMonitoring = true
        Logger.client.info("Starting MCP config file monitoring")

        fileMonitorTask = Task {
            let configFileURL = URL(fileURLWithPath: configFilePath)

            // Check for file changes periodically
            while isMonitoring {
                try? await Task.sleep(nanoseconds: 3_000_000_000)  // Check every 1 second for better responsiveness

                guard isMonitoring else { break }  // Extra check after sleep

                let currentDate = getFileModificationDate(url: configFileURL)

                if let currentDate = currentDate, currentDate != lastModificationDate {
                    // File modification date has changed, update our record
                    Logger.client.info("MCP config file change detected")
                    lastModificationDate = currentDate

                    // Read and validate the updated content
                    if let validJson = readAndValidateJSON(from: configFileURL) {
                        await MainActor.run {
                            mcpConfig = validJson
                            refreshConfiguration()
                            toast("MCP configuration file updated", .info)
                        }
                    } else {
                        // If JSON is invalid, show error
                        await MainActor.run {
                            toast("Invalid JSON in MCP configuration file", .error)
                            Logger.client.info("Invalid JSON detected during monitoring")
                        }
                    }
                }
            }
            Logger.client.info("Stopped MCP config file monitoring")
        }
    }

    private func stopMonitoringConfigFile() {
        guard isMonitoring else { return }
        Logger.client.info("Stopping MCP config file monitoring")
        isMonitoring = false
        fileMonitorTask?.cancel()
        fileMonitorTask = nil
    }

    func refreshConfiguration() {
        if MCPConfigView.lastSyncTimestamp == lastModificationDate {
            return
        }

        MCPConfigView.lastSyncTimestamp = lastModificationDate

        let fileURL = URL(fileURLWithPath: configFilePath)
        if let jsonString = readAndValidateJSON(from: fileURL) {
            UserDefaults.shared.set(jsonString, for: \.gitHubCopilotMCPConfig)
        }

        // Debounce the refresh notification to avoid sending too frequently
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: MCPConfigView.refreshDebounceInterval, repeats: false) { _ in
            Task {
                do {
                    let service = try getService()
                    try await service.postNotification(
                        name: Notification.Name
                            .gitHubCopilotShouldRefreshEditorInformation.rawValue
                    )
                    await MainActor.run {
                        toast("Fetching MCP tools...", .info)
                    }
                } catch {
                    await MainActor.run {
                        toast(error.localizedDescription, .error)
                    }
                }
            }
        }
    }
}

extension String {
    func padded(centerTo total: Int, with pad: Character = " ") -> String {
        guard count < total else { return self }
        let deficit = total - count
        let left = deficit / 2
        let right = deficit - left
        return String(repeating: pad, count: left) + self + String(repeating: pad, count: right)
    }
}
