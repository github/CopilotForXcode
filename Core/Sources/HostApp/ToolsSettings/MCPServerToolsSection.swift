import SwiftUI
import Persist
import GitHubCopilotService
import Client
import Logger
import Foundation
import SharedUIComponents
import ConversationServiceProvider

/// Section for a single server's tools
struct MCPServerToolsSection: View {
    let serverTools: MCPServerToolsCollection
    @Binding var isServerEnabled: Bool
    var forceExpand: Bool = false
    var isInteractionAllowed: Bool = true
    @Binding var modes: [ConversationMode]
    @Binding var selectedMode: ConversationMode
    @State private var toolEnabledStates: [String: Bool] = [:]
    @State private var isExpanded: Bool = true
    @State private var checkboxMixedState: CheckboxMixedState = .off
    private var originalServerName: String { serverTools.name }

    @State private var isShowingDeleteConfirmation: Bool = false

    private var serverToggleLabel: some View {
        HStack(spacing: 8) {
            Text("MCP Server: \(serverTools.name)")
                .fontWeight(.medium)
                .foregroundStyle(
                    serverTools.status == .running ? .primary : .tertiary
                )
            if serverTools.status == .error || serverTools.status == .blocked {
                let message = extractErrorMessage(serverTools.error?.description ?? "")
                if serverTools.status == .error {
                    Badge(
                        attributedText: createErrorMessage(message),
                        level: .danger,
                        icon: "xmark.circle.fill"
                    )
                    .environment((\.openURL), OpenURLAction { url in
                        if url.absoluteString == "mcp://open-config" {
                            openMCPConfigFile()
                            return .handled
                        }
                        return .systemAction
                    })
                } else if serverTools.status == .blocked {
                    Badge(text: serverTools.registryInfo ?? "Blocked", level: .warning, icon: "exclamationmark.triangle.fill")
                }
            } else if let registryInfo = serverTools.registryInfo {
                Text(registryInfo)
                    .foregroundStyle(.secondary)
                    .font(.system(size: 11))
            }
        }
    }
    
    private func openMCPConfigFile() {
        let url = URL(fileURLWithPath: mcpConfigFilePath)
        NSWorkspace.shared.open(url)
    }
    
    private func createErrorMessage(_ baseMessage: String) -> AttributedString {
        if hasServerConfigPlaceholders() {
            let prefix = baseMessage.isEmpty ? "" : baseMessage + ". "
            var attributedString = AttributedString(prefix + "You may need to update placeholders in ")

            var mcpLink = AttributedString("mcp.json")
            mcpLink.link = URL(string: "mcp://open-config")
            mcpLink.underlineStyle = .single
            
            attributedString.append(mcpLink)
            attributedString.append(AttributedString("."))
            
            return attributedString
        } else {
            return AttributedString(baseMessage)
        }
    }
    
    private var serverToggle: some View {
        HStack(spacing: 8) {
            MixedStateCheckbox(
                title: "",
                font: .systemFont(ofSize: 13),
                state: $checkboxMixedState
            ) {
                switch checkboxMixedState {
                case .off, .mixed:
                    // Enable all tools
                    updateAllToolsStatus(enabled: true)
                case .on:
                    // Disable all tools
                    updateAllToolsStatus(enabled: false)
                }
                updateMixedState()
            }
            .disabled(serverTools.status == .error || serverTools.status == .blocked || !isInteractionAllowed)

            serverToggleLabel
                .contentShape(Rectangle())
                .onTapGesture {
                    if serverTools.status != .error && serverTools.status != .blocked {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
                }

            Spacer()

            Button(action: { isShowingDeleteConfirmation = true }) {
                Image(systemName: "trash").font(.system(size: 12))
            }
            .buttonStyle(HoverButtonStyle())
            .padding(-4)
        }
        .padding(.leading, 4)
    }
    
    private var divider: some View {
        Divider()
            .padding(.leading, 36)
            .padding(.top, 2)
            .padding(.bottom, 4)
    }
    
    private var toolsList: some View {
        VStack(spacing: 0) {
            divider
            ForEach(serverTools.tools, id: \.name) { tool in
                ToolRow(
                    toolName: tool.name,
                    toolDescription: tool.description,
                    toolStatus: tool._status,
                    isServerEnabled: isServerEnabled,
                    isToolEnabled: toolBindingFor(tool),
                    isInteractionAllowed: isInteractionAllowed,
                    onToolToggleChanged: { handleToolToggleChange(tool: tool, isEnabled: $0) }
                )
                .padding(.leading, 36)
            }
        }
        .onChange(of: serverTools) { newValue in
            initializeToolStates(server: newValue)
            updateMixedState()
        }
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Conditional view rendering based on error state
            if serverTools.status == .error || serverTools.status == .blocked {
                // No disclosure group for error state
                VStack(spacing: 0) {
                    serverToggle
                        .padding(.leading, 11)
                        .padding(.trailing, 4)
                    divider.padding(.top, 4)
                }
            } else {
                // Regular DisclosureGroup for non-error state
                DisclosureGroup(isExpanded: $isExpanded) {
                    toolsList
                } label: {
                    serverToggle
                }
                .onAppear {
                    initializeToolStates(server: serverTools)
                    updateMixedState()
                    if forceExpand {
                        isExpanded = true
                    }
                }
                .onChange(of: forceExpand) { newForceExpand in
                    if newForceExpand {
                        isExpanded = true
                    }
                }
                .onChange(of: selectedMode) { _ in
                    toolEnabledStates = [:]
                    initializeToolStates(server: serverTools)
                    updateMixedState()
                }
                .onChange(of: selectedMode.customTools) { _ in
                    Task {
                        await reloadModesAndUpdateStates()
                    }
                }
                .onReceive(DistributedNotificationCenter.default().publisher(for: .gitHubCopilotCustomAgentToolsDidChange)) { _ in
                    Logger.client.info("Custom agent tools change notification received in MCPServerToolsSection")
                    if !selectedMode.isDefaultAgent {
                        Task {
                            await reloadModesAndUpdateStates()
                        }
                    }
                }

                if !isExpanded {
                    divider
                }
            }
        }
        .confirmationDialog(
            "Do you want to delete '\(serverTools.name)'?",
            isPresented: $isShowingDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { deleteServerConfig() }
        }
    }

    private func deleteServerConfig() {
        let fileURL = URL(fileURLWithPath: mcpConfigFilePath)

        guard let data = try? Data(contentsOf: fileURL) else {
            Logger.client.error("Failed to read mcp.json when deleting server config.")
            return
        }

        guard var rootObject = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            Logger.client.error("Failed to parse mcp.json when deleting server config.")
            return
        }

        if var servers = rootObject["servers"] as? [String: Any] {
            servers.removeValue(forKey: serverTools.name)
            rootObject["servers"] = servers
        }

        do {
            let newData = try JSONSerialization.data(withJSONObject: rootObject, options: [.prettyPrinted, .sortedKeys])
            try newData.write(to: fileURL)
        } catch {
            Logger.client.error("Failed to write updated mcp.json when deleting server config: \(error.localizedDescription)")
        }
    }

    private func extractErrorMessage(_ description: String) -> String {
        guard let messageRange = description.range(of: "message:"),
            let stackRange = description.range(of: "stack:") else {
            return description
        }
        let start = description.index(messageRange.upperBound, offsetBy: 0)
        let end = description.index(stackRange.lowerBound, offsetBy: 0)
        return description[start..<end].trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func hasServerConfigPlaceholders() -> Bool {
        let configFileURL = URL(fileURLWithPath: mcpConfigFilePath)
        
        guard FileManager.default.fileExists(atPath: mcpConfigFilePath),
              let data = try? Data(contentsOf: configFileURL),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let servers = jsonObject["servers"] as? [String: Any],
              let serverConfig = servers[serverTools.name] else {
            return false
        }
        
        // Convert server config to JSON string
        guard let serverData = try? JSONSerialization.data(withJSONObject: serverConfig, options: []),
              let serverConfigString = String(data: serverData, encoding: .utf8) else {
            return false
        }
        
        // Check for placeholder patterns ending with }"
        // Matches: "{PLACEHOLDER}", "${PLACEHOLDER}", "key={PLACEHOLDER}", "key=${PLACEHOLDER}", "${prefix:PLACEHOLDER}"
        let placeholderPattern = "\"([a-zA-Z0-9_]+=)?\\$?\\{[a-zA-Z0-9_:\\-\\.]+\\}\""

        guard let regex = try? NSRegularExpression(pattern: placeholderPattern, options: []) else {
            return false
        }
        
        let range = NSRange(serverConfigString.startIndex..<serverConfigString.endIndex, in: serverConfigString)
        return regex.firstMatch(in: serverConfigString, options: [], range: range) != nil
    }

    private func initializeToolStates(server: MCPServerToolsCollection) {
        var disabled = 0
        let newStates: [String: Bool] = server.tools.reduce(into: [:]) { result, tool in
            let isEnabled = isToolEnabledInMode(tool.name, currentStatus: tool._status)
            result[tool.name] = isEnabled
            disabled += isEnabled ? 0 : 1
        }
        
        for (toolName, newState) in newStates {
            if toolEnabledStates[toolName] != newState {
                toolEnabledStates[toolName] = newState
            }
        }
        
        for existingToolName in toolEnabledStates.keys {
            if newStates[existingToolName] == nil {
                toolEnabledStates.removeValue(forKey: existingToolName)
            }
        }

        let enabled = toolEnabledStates.count - disabled
        Logger.client.info("Server \(server.name) initialized with \(toolEnabledStates.count) tools (\(enabled) enabled, \(disabled) disabled).")

        if !toolEnabledStates.isEmpty && toolEnabledStates.values.allSatisfy({ !$0 }) {
            DispatchQueue.main.async {
                isServerEnabled = false
            }
        }
    }

    private func toolBindingFor(_ tool: MCPTool) -> Binding<Bool> {
        Binding(
            get: {
                toolEnabledStates[tool.name] ?? isToolEnabledInMode(tool.name, currentStatus: tool._status)
            },
            set: { toolEnabledStates[tool.name] = $0 }
        )
    }

    private func handleToolToggleChange(tool: MCPTool, isEnabled: Bool) {
        toolEnabledStates[tool.name] = isEnabled
        
        // Update server state based on tool states
        updateServerState()
        
        // Update mixed state
        updateMixedState()
        
        // Update only this specific tool status
        updateToolStatus(tool: tool, isEnabled: isEnabled)
    }
    
    private func updateServerState() {
        // If any tool is enabled, server should be enabled
        // If all tools are disabled, server should be disabled
        let allToolsDisabled = serverTools.tools.allSatisfy { tool in
            !(toolEnabledStates[tool.name] ?? (tool._status == .enabled))
        }
        
        isServerEnabled = !allToolsDisabled
    }
    
    private func updateToolStatus(tool: MCPTool, isEnabled: Bool) {
        let serverUpdate = UpdateMCPToolsStatusServerCollection(
            name: serverTools.name,
            tools: [UpdatedMCPToolsStatus(name: tool.name, status: isEnabled ? .enabled : .disabled)]
        )

        updateMCPStatus([serverUpdate])
    }
    
    private func updateAllToolsStatus(enabled: Bool) {
        isServerEnabled = enabled
        
        // Get all tools for this server from the original collection
        let allServerTools = CopilotMCPToolManagerObservable.shared.availableMCPServerTools
            .first(where: { $0.name == originalServerName })?.tools ?? serverTools.tools
        
        // Update all tool states - includes both visible and filtered-out tools
        for tool in allServerTools {
            toolEnabledStates[tool.name] = enabled
        }

        // Create status update for all tools
        let serverUpdate = UpdateMCPToolsStatusServerCollection(
            name: serverTools.name,
            tools: allServerTools.map {
                UpdatedMCPToolsStatus(name: $0.name, status: enabled ? .enabled : .disabled)
            }
        )
        
        updateMCPStatus([serverUpdate])
    }
    
    private func updateMixedState() {
        let allServerTools = CopilotMCPToolManagerObservable.shared.availableMCPServerTools
            .first(where: { $0.name == originalServerName })?.tools ?? serverTools.tools
        
        let enabledCount = allServerTools.filter { tool in
            toolEnabledStates[tool.name] ?? (tool._status == .enabled)
        }.count
        
        let totalCount = allServerTools.count
        
        if enabledCount == 0 {
            checkboxMixedState = .off
        } else if enabledCount == totalCount {
            checkboxMixedState = .on
        } else {
            checkboxMixedState = .mixed
        }
    }

    private func updateMCPStatus(_ serverUpdates: [UpdateMCPToolsStatusServerCollection]) {
        let isDefaultAgentMode = selectedMode.isDefaultAgent
        Task {
            do {
                let service = try getService()
                
                if !isDefaultAgentMode {
                    let chatMode = selectedMode.kind
                    let customChatModeId = selectedMode.isBuiltIn == false ? selectedMode.id : nil
                    let workspaceFolders = await getWorkspaceFolders()
                    
                    try await service
                        .updateMCPServerToolsStatus(
                            serverUpdates,
                            chatAgentMode: chatMode,
                            customChatModeId: customChatModeId,
                            workspaceFolders: workspaceFolders
                        )
                } else {
                    try await service.updateMCPServerToolsStatus(serverUpdates)
                }
            } catch {
                Logger.client.error("Failed to update MCP status: \(error.localizedDescription)")
            }
        }
    }
    
    @MainActor
    private func reloadModesAndUpdateStates() async {
        do {
            let service = try getService()
            let workspaceFolders = await getWorkspaceFolders()
            if let fetchedModes = try await service.getModes(workspaceFolders: workspaceFolders) {
                modes = fetchedModes.filter { $0.kind == .Agent }
                
                if let updatedMode = modes.first(where: { $0.id == selectedMode.id }) {
                    selectedMode = updatedMode
                    
                    let allServerTools = CopilotMCPToolManagerObservable.shared.availableMCPServerTools
                        .first(where: { $0.name == originalServerName })?.tools ?? serverTools.tools
                    
                    for tool in allServerTools {
                        let toolName = "\(serverTools.name)/\(tool.name)"
                        if let customTools = updatedMode.customTools {
                            toolEnabledStates[tool.name] = customTools.contains(toolName)
                        } else {
                            toolEnabledStates[tool.name] = false
                        }
                    }
                    
                    updateMixedState()
                    updateServerState()
                }
            }
        } catch {
            Logger.client.error("Failed to reload modes: \(error.localizedDescription)")
        }
    }
    
    private func isToolEnabledInMode(_ toolName: String, currentStatus: ToolStatus) -> Bool {
        let configurationKey = "\(serverTools.name)/\(toolName)"
        return AgentModeToolHelpers.isToolEnabledInMode(
            configurationKey: configurationKey,
            currentStatus: currentStatus,
            selectedMode: selectedMode
        )
    }
}
