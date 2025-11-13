import AppKit
import ChatService
import ComposableArchitecture
import ConversationServiceProvider
import ConversationTab
import GitHubCopilotService
import LanguageServerProtocol
import Logger
import SharedUIComponents
import SuggestionBasic
import SwiftUI
import XcodeInspector

struct SelectedAgentModel: Equatable {
    let displayName: String
    let modelName: String
    let source: ModelSource

    enum ModelSource: Equatable {
        case copilot
        case byok(provider: String)
    }
}

struct AgentConfigurationWidgetView: View {
    let store: StoreOf<AgentConfigurationWidgetFeature>

    @State private var showPopover = false
    @State private var isHovered = false
    @State private var selectedToolStates: [String: [String: Bool]] = [:]
    @State private var selectedModel: SelectedAgentModel? = nil
    @State private var searchText = ""
    @State private var isSearchFieldExpanded = false
    @State private var generateHandoffExample: Bool = true
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        WithPerceptionTracking {
            if store.isPanelDisplayed {
                VStack {
                    buildAgentConfigurationButton()
                        .popover(isPresented: $showPopover) {
                            buildConfigView(currentMode: store.currentMode).padding(.horizontal, 4)
                        }
                }
                .animation(.easeInOut(duration: 0.2), value: store.isPanelDisplayed)
                .onChange(of: showPopover) { newValue in
                    if newValue {
                        // Load state from agent file when popover is opened
                        loadToolStatesFromAgentFile(currentMode: store.currentMode)
                        // Refresh client tools to get any late-arriving server tools
                        Task {
                            await GitHubCopilotService.refreshClientTools()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func buildAgentConfigurationButton() -> some View {
        let fontSize = store.lineHeight * 0.7
        let lineHeight = store.lineHeight

        ZStack {
            Button(action: { showPopover.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.pencil")
                        .resizable()
                        .scaledToFit()
                        .frame(width: fontSize, height: fontSize)
                    Text("Customize Agent")
                        .font(.system(size: fontSize))
                        .fixedSize()
                }
                .frame(height: lineHeight)
                .foregroundColor(isHovered ? Color("ItemSelectedColor") : .secondary)
            }
            .buttonStyle(.plain)
            .contentShape(Capsule())
            .help("Configure tools and model for custom agent")
            .onHover { isHovered = $0 }
        }
    }

    @ViewBuilder
    private func buildConfigView(currentMode: ConversationMode?) -> some View {
        if let currentMode = currentMode {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Configure Model")
                            .font(.system(size: 15, weight: .bold))

                        Text("The AI model to use when running the prompt. If not specified, the currently selected model in model picker is used.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)

                        AgentModelPickerSection(
                            selectedModel: $selectedModel
                        )

                        Divider()

                        if currentMode.handOffs?.isEmpty ?? true {
                            Text("Configure Handoffs")
                                .font(.system(size: 15, weight: .bold))

                            Text("Suggested next actions or prompts to transition between custom agents. Handoff buttons appear as interactive suggestions after a chat response completes.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                            Toggle(isOn: $generateHandoffExample) {
                                Text("Generate Handoff Example")
                                    .font(.system(size: 11, weight: .regular))
                            }
                            .toggleStyle(.checkbox)
                            .help("Adds a starter handoff example to the agent file YAML frontmatter.")

                            Divider()
                        }

                        // Title with Search
                        HStack {
                            Text("Configure Tools")
                                .font(.system(size: 15, weight: .bold))

                            Spacer()

                            CollapsibleSearchField(
                                searchText: $searchText,
                                isExpanded: $isSearchFieldExpanded,
                                placeholderString: "Search tools..."
                            )
                        }

                        Text("A list of built-in tools and MCP tools that are available for this agent. If a given tool is not available when running the agent, it is ignored.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.bottom, 8)

                        // MCP Tools Section
                        AgentToolsSection(
                            title: "MCP Tools",
                            currentMode: currentMode,
                            selectedToolStates: $selectedToolStates,
                            searchText: searchText
                        )

                        // Built-In Tools Section
                        AgentBuiltInToolsSection(
                            title: "Built-In Tools",
                            currentMode: currentMode,
                            selectedToolStates: $selectedToolStates,
                            searchText: searchText
                        )
                    }
                    .padding(12)
                }
                .frame(width: 500, height: 600)

                Divider()

                // Buttons
                HStack(spacing: 12) {
                    Button(action: { showPopover = false }) {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        updateAgentTools(selectedToolStates: selectedToolStates, currentMode: currentMode)
                        applyAgentFileChanges(
                            selectedModel: selectedModel,
                            generateHandoffExample: generateHandoffExample,
                            currentMode: currentMode
                        )
                        showPopover = false
                    }) {
                        Text("Apply")
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(12)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else {
            // Should never be shown since widget only displays when mode exists
            VStack {
                Text("No agent mode available")
                    .foregroundColor(.secondary)
            }
            .frame(width: 500, height: 600)
        }
    }

    // MARK: - Helper functions

    // MARK: - Agent File Utilities

    private struct AgentFileAccess {
        let documentURL: URL
        let content: String
    }

    private func validateAndReadAgentFile() -> AgentFileAccess? {
        guard let documentURL = store.withState({ $0.focusedEditor?.realtimeDocumentURL }) else {
            Logger.extension.error("Could not access agent file - documentURL is nil")
            return nil
        }
        guard documentURL.pathExtension == "md" else {
            Logger.extension.error("Could not access agent file - invalid extension")
            return nil
        }
        guard documentURL.lastPathComponent.hasSuffix(".agent.md") else {
            Logger.extension.error("Could not access agent file - filename does not end with .agent.md")
            return nil
        }
        guard let content = try? String(contentsOf: documentURL) else {
            Logger.extension.error("Could not access agent file - unable to read file")
            return nil
        }
        return AgentFileAccess(documentURL: documentURL, content: content)
    }

    private struct YAMLFrontmatterInfo {
        var lines: [String]
        let frontmatterEndIndex: Int?
        let modelLineIndex: Int?
        let toolsLineIndex: Int?
        let handoffsLineIndex: Int?
    }

    private func parseYAMLFrontmatter(content: String) -> YAMLFrontmatterInfo {
        var lines = content.components(separatedBy: .newlines)
        var inFrontmatter = false
        var frontmatterEndIndex: Int?
        var modelLineIndex: Int?
        var toolsLineIndex: Int?
        var handoffsLineIndex: Int?

        for (idx, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" {
                if !inFrontmatter {
                    inFrontmatter = true
                } else {
                    inFrontmatter = false
                    frontmatterEndIndex = idx
                    break
                }
            } else if inFrontmatter {
                if trimmed.hasPrefix("model:") {
                    modelLineIndex = idx
                } else if trimmed.hasPrefix("tools:") {
                    toolsLineIndex = idx
                } else if trimmed.hasPrefix("handoffs:") || trimmed.hasPrefix("handOffs:") {
                    handoffsLineIndex = idx
                }
            }
        }

        return YAMLFrontmatterInfo(
            lines: lines,
            frontmatterEndIndex: frontmatterEndIndex,
            modelLineIndex: modelLineIndex,
            toolsLineIndex: toolsLineIndex,
            handoffsLineIndex: handoffsLineIndex
        )
    }

    private func writeToAgentFile(url: URL, content: String, successMessage: String) {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            Logger.extension.info(successMessage)
        } catch {
            Logger.extension.error("Error writing agent file: \(error)")
        }
    }

    private func formatModelLine(_ selectedModel: SelectedAgentModel?) -> String? {
        guard let model = selectedModel else { return nil }
        let sourceLabel: String
        switch model.source {
        case .copilot:
            sourceLabel = "copilot"
        case let .byok(provider):
            sourceLabel = provider
        }
        return "model: '\(model.displayName) (\(sourceLabel))'"
    }

    private func loadMCPToolStates(enabledTools: Set<String>) {
        guard let mcpServerTools = CopilotMCPToolManager.getAvailableMCPServerToolsCollections() else { return }
        for server in mcpServerTools {
            for tool in server.tools {
                let configurationKey = AgentModeToolHelpers.makeConfigurationKey(
                    serverName: server.name,
                    toolName: tool.name
                )
                selectedToolStates["mcp"]?[configurationKey] = enabledTools.contains(configurationKey)
            }
        }
    }

    private func loadBuiltInToolStates(enabledTools: Set<String>) {
        guard let builtInTools = CopilotLanguageModelToolManager.getAvailableLanguageModelTools() else { return }
        for tool in builtInTools {
            selectedToolStates["builtin"]?[tool.name] = enabledTools.contains(tool.name)
        }
    }

    private func collectMCPToolUpdates(selectedToolStates: [String: [String: Bool]]) -> [UpdateMCPToolsStatusServerCollection] {
        guard let mcpStates = selectedToolStates["mcp"],
              let mcpServerTools = CopilotMCPToolManager.getAvailableMCPServerToolsCollections() else {
            return []
        }

        return mcpServerTools.map { server in
            let toolUpdates = server.tools.map { tool in
                let configurationKey = AgentModeToolHelpers.makeConfigurationKey(
                    serverName: server.name,
                    toolName: tool.name
                )
                let isEnabled = mcpStates[configurationKey] ?? false
                return UpdatedMCPToolsStatus(
                    name: tool.name,
                    status: isEnabled ? .enabled : .disabled
                )
            }
            return UpdateMCPToolsStatusServerCollection(
                name: server.name,
                tools: toolUpdates
            )
        }
    }

    private func collectBuiltInToolUpdates(selectedToolStates: [String: [String: Bool]]) -> [ToolStatusUpdate] {
        guard let builtInStates = selectedToolStates["builtin"],
              let builtInTools = CopilotLanguageModelToolManager.getAvailableLanguageModelTools() else {
            return []
        }

        return builtInTools.map { tool in
            let isEnabled = builtInStates[tool.name] ?? false
            return ToolStatusUpdate(
                name: tool.name,
                status: isEnabled ? .enabled : .disabled
            )
        }
    }

    private func updateMCPToolsViaAPI(
        service: GitHubCopilotService,
        mcpCollections: [UpdateMCPToolsStatusServerCollection],
        chatModeKind: ChatMode?,
        customChatModeId: String?,
        workspaceFolders: [WorkspaceFolder]
    ) async {
        guard !mcpCollections.isEmpty else { return }
        do {
            let _ = try await service.updateMCPToolsStatus(
                params: UpdateMCPToolsStatusParams(
                    chatModeKind: chatModeKind,
                    customChatModeId: customChatModeId,
                    workspaceFolders: workspaceFolders,
                    servers: mcpCollections
                )
            )
            Logger.extension.info("MCP tools updated via API")
            
            // Notify Settings app about custom agent tool changes
            DistributedNotificationCenter.default().postNotificationName(
                .gitHubCopilotCustomAgentToolsDidChange,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        } catch {
            Logger.extension.error("Error updating MCP tools via API: \(error)")
        }
    }

    private func updateBuiltInToolsViaAPI(
        service: GitHubCopilotService,
        builtInToolUpdates: [ToolStatusUpdate],
        chatModeKind: ChatMode?,
        customChatModeId: String?,
        workspaceFolders: [WorkspaceFolder]
    ) async {
        guard !builtInToolUpdates.isEmpty else { return }
        do {
            let _ = try await service.updateToolsStatus(
                params: UpdateToolsStatusParams(
                    chatmodeKind: chatModeKind,
                    customChatModeId: customChatModeId,
                    workspaceFolders: workspaceFolders,
                    tools: builtInToolUpdates
                )
            )
            Logger.extension.info("Built-in tools updated via API")
            
            // Notify Settings app about custom agent tool changes
            DistributedNotificationCenter.default().postNotificationName(
                .gitHubCopilotCustomAgentToolsDidChange,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        } catch {
            Logger.extension.error("Error updating built-in tools via API: \(error)")
        }
    }

    private func parseModelFromMode(_ mode: ConversationMode?) -> SelectedAgentModel? {
        guard let mode = mode,
              let modelString = mode.model else {
            return nil
        }

        // Parse format: "displayName (copilot)" or "displayName (providerName)"
        if let openParen = modelString.lastIndex(of: "("),
           let closeParen = modelString.lastIndex(of: ")") {
            let displayName = String(modelString[..<openParen]).trimmingCharacters(in: .whitespaces)
            let sourceString = String(modelString[modelString.index(after: openParen) ..< closeParen])
                .trimmingCharacters(in: .whitespaces)
                .lowercased()

            let source: SelectedAgentModel.ModelSource
            if sourceString == "copilot" {
                source = .copilot
            } else {
                source = .byok(provider: sourceString)
            }

            return SelectedAgentModel(
                displayName: displayName,
                modelName: displayName,
                source: source
            )
        }

        return nil
    }

    private func loadToolStatesFromAgentFile(currentMode: ConversationMode?) {
        Task {
            await MainActor.run {
                // Load model
                if let parsedModel = parseModelFromMode(currentMode) {
                    let copilotModels = CopilotModelManager.getAvailableChatLLMs(scope: .agentPanel)
                    let byokModels = BYOKModelManager.getAvailableChatLLMs(scope: .agentPanel)
                    let allModels = copilotModels + byokModels

                    // Find matching model by display name and source
                    let matchingModel = allModels.first { model in
                        let modelDisplayName = model.displayName ?? model.modelName
                        let matchesName = modelDisplayName == parsedModel.displayName

                        switch parsedModel.source {
                        case .copilot:
                            return matchesName && model.providerName == nil
                        case let .byok(provider):
                            return matchesName && model.providerName?.lowercased() == provider.lowercased()
                        }
                    }

                    if let model = matchingModel {
                        selectedModel = SelectedAgentModel(
                            displayName: model.displayName ?? model.modelName,
                            modelName: model.modelName,
                            source: model.providerName == nil ? .copilot : .byok(provider: model.providerName!)
                        )
                    } else {
                        selectedModel = nil
                    }
                } else {
                    selectedModel = nil
                }

                // Reset states
                selectedToolStates = ["mcp": [:], "builtin": [:]]

                // Load tool states from customTools in current mode
                guard let customTools = currentMode?.customTools else {
                    return
                }

                let enabledTools = Set(customTools)
                loadMCPToolStates(enabledTools: enabledTools)
                loadBuiltInToolStates(enabledTools: enabledTools)
            }
        }
    }

    private func updateAgentTools(selectedToolStates: [String: [String: Bool]], currentMode: ConversationMode?) {
        Task {
            // Get the workspace URL and extract project root URL
            guard let projectRootURL = await XcodeInspector.shared.safe.realtimeActiveProjectURL,
                  let service = GitHubCopilotService.getProjectGithubCopilotService(for: projectRootURL) else {
                Logger.extension.error("Could not get GitHubCopilotService for project")
                return
            }

            // Get workspace folders
            let workspaceFolders = [WorkspaceFolder(
                uri: projectRootURL.absoluteString,
                name: projectRootURL.lastPathComponent
            )]

            let chatModeKind: ChatMode? = currentMode?.kind
            let customChatModeId: String? = currentMode?.id

            let mcpCollections = collectMCPToolUpdates(selectedToolStates: selectedToolStates)
            let builtInToolUpdates = collectBuiltInToolUpdates(selectedToolStates: selectedToolStates)

            await updateMCPToolsViaAPI(
                service: service,
                mcpCollections: mcpCollections,
                chatModeKind: chatModeKind,
                customChatModeId: customChatModeId,
                workspaceFolders: workspaceFolders
            )

            await updateBuiltInToolsViaAPI(
                service: service,
                builtInToolUpdates: builtInToolUpdates,
                chatModeKind: chatModeKind,
                customChatModeId: customChatModeId,
                workspaceFolders: workspaceFolders
            )
        }
    }

    private func applyAgentFileChanges(
        selectedModel: SelectedAgentModel?,
        generateHandoffExample: Bool,
        currentMode: ConversationMode
    ) {
        guard let fileAccess = validateAndReadAgentFile() else { return }
        
        var yamlInfo = parseYAMLFrontmatter(content: fileAccess.content)
        
        // Apply model update and get the index where model was placed
        let modelIndex = applyModelUpdate(to: &yamlInfo, selectedModel: selectedModel)
        
        // Apply handoffs update after model
        if generateHandoffExample && (currentMode.handOffs?.isEmpty ?? true) {
            applyHandoffsUpdate(to: &yamlInfo, afterModelIndex: modelIndex)
        }
        
        let updatedContent = yamlInfo.lines.joined(separator: "\n")
        writeToAgentFile(url: fileAccess.documentURL, content: updatedContent, successMessage: "Agent file updated")
    }
    
    private func applyModelUpdate(to yamlInfo: inout YAMLFrontmatterInfo, selectedModel: SelectedAgentModel?) -> Int? {
        let modelLine = formatModelLine(selectedModel)
        
        if let modelLine = modelLine {
            if let modelIdx = yamlInfo.modelLineIndex {
                yamlInfo.lines[modelIdx] = modelLine
                return modelIdx
            } else if let endIdx = yamlInfo.frontmatterEndIndex {
                yamlInfo.lines.insert(modelLine, at: endIdx)
                return endIdx
            }
        } else if let modelIdx = yamlInfo.modelLineIndex {
            yamlInfo.lines.remove(at: modelIdx)
            return nil
        }
        return yamlInfo.modelLineIndex
    }
    
    private func applyHandoffsUpdate(to yamlInfo: inout YAMLFrontmatterInfo, afterModelIndex modelIndex: Int?) {
        guard yamlInfo.handoffsLineIndex == nil else { return }
        
        let snippet = [
            "handoffs:",
            "  - label: Start Implementation",
            "    agent: implementation",
            "    prompt: Now implement the plan outlined above.",
            "    send: true",
        ]
        
        if let mIdx = modelIndex {
            yamlInfo.lines.insert(contentsOf: snippet, at: mIdx + 1)
        } else if let endIdx = yamlInfo.frontmatterEndIndex {
            yamlInfo.lines.insert(contentsOf: snippet, at: endIdx)
        }
    }

    // MARK: - MCP Tools Section

    private struct AgentToolsSection: View {
        let title: String
        let currentMode: ConversationMode
        @Binding var selectedToolStates: [String: [String: Bool]]
        let searchText: String

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                let mcpServerTools = CopilotMCPToolManager.getAvailableMCPServerToolsCollections() ?? []

                if mcpServerTools.isEmpty {
                    Text("No MCP tools available.")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                        .padding(.vertical, 8)
                } else {
                    ForEach(mcpServerTools, id: \.name) { server in
                        AgentMCPServerSection(
                            serverTools: server,
                            currentMode: currentMode,
                            selectedToolStates: $selectedToolStates,
                            searchText: searchText
                        )
                    }
                }
            }
        }
    }

    // MARK: - MCP Server Section

    private struct AgentMCPServerSection: View {
        let serverTools: MCPServerToolsCollection
        let currentMode: ConversationMode
        @Binding var selectedToolStates: [String: [String: Bool]]
        let searchText: String

        @State private var isExpanded: Bool = false
        @State private var checkboxState: CheckboxMixedState = .off

        private func matchesSearch(_ text: String, _ description: String?) -> Bool {
            guard !searchText.isEmpty else { return true }
            let lowercasedSearch = searchText.lowercased()
            return text.lowercased().contains(lowercasedSearch) ||
                (description?.lowercased().contains(lowercasedSearch) ?? false)
        }

        private var serverNameMatches: Bool {
            matchesSearch(serverTools.name, nil)
        }

        private var hasMatchingTools: Bool {
            guard !searchText.isEmpty else { return false }
            if serverNameMatches { return true }
            return serverTools.tools.contains { tool in
                matchesSearch(tool.name, tool.description)
            }
        }

        private var filteredTools: [MCPTool] {
            guard !searchText.isEmpty else { return serverTools.tools }
            if serverNameMatches { return serverTools.tools }
            return serverTools.tools.filter { tool in
                matchesSearch(tool.name, tool.description)
            }
        }

        var body: some View {
            // Don't show this server if search is active and there are no matches
            if searchText.isEmpty || hasMatchingTools {
                VStack(alignment: .leading, spacing: 0) {
                    DisclosureGroup(isExpanded: $isExpanded) {
                        VStack(alignment: .leading, spacing: 0) {
                            Divider()
                                .padding(.vertical, 4)

                            ForEach(filteredTools, id: \.name) { tool in
                                let configurationKey = AgentModeToolHelpers.makeConfigurationKey(
                                    serverName: serverTools.name,
                                    toolName: tool.name
                                )
                                let isSelected = selectedToolStates["mcp"]?[configurationKey] ?? AgentModeToolHelpers.isToolEnabledInMode(
                                    configurationKey: configurationKey,
                                    currentStatus: .enabled,
                                    selectedMode: currentMode
                                )
                                AgentToolRow(
                                    toolName: tool.name,
                                    toolDescription: tool.description,
                                    isSelected: isSelected,
                                    isBlocked: serverTools.status == .blocked || serverTools.status == .error,
                                    onToggle: { isSelected in
                                        if selectedToolStates["mcp"] == nil {
                                            selectedToolStates["mcp"] = [:]
                                        }
                                        selectedToolStates["mcp"]?[configurationKey] = isSelected
                                        updateServerSelectionState()
                                    }
                                )
                                .padding(.leading, 20)
                            }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            MixedStateCheckbox(
                                title: "",
                                font: .systemFont(ofSize: 13),
                                state: $checkboxState,
                                action: {
                                    // Toggle based on current state
                                    switch checkboxState {
                                    case .off, .mixed:
                                        toggleAllTools(selected: true)
                                    case .on:
                                        toggleAllTools(selected: false)
                                    }
                                }
                            )
                            .disabled(serverTools.status == .blocked || serverTools.status == .error)

                            HStack(spacing: 8) {
                                if serverTools.status == .blocked || serverTools.status == .error {
                                    Text("MCP Server: \(serverTools.name)")
                                        .font(.system(size: 13, weight: .medium))
                                } else {
                                    let selectedCount = serverTools.tools.filter { tool in
                                        let configurationKey = AgentModeToolHelpers.makeConfigurationKey(
                                            serverName: serverTools.name,
                                            toolName: tool.name
                                        )
                                        if let state = selectedToolStates["mcp"]?[configurationKey] {
                                            return state
                                        }
                                        return AgentModeToolHelpers.isToolEnabledInMode(
                                            configurationKey: configurationKey,
                                            currentStatus: .enabled,
                                            selectedMode: currentMode
                                        )
                                    }.count
                                    Text("MCP Server: \(serverTools.name) ")
                                        .font(.system(size: 13, weight: .medium))
                                        + Text("(\(selectedCount) of \(serverTools.tools.count) Selected)")
                                        .font(.system(size: 13, weight: .regular))
                                }

                                if serverTools.status == .error {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 11))
                                } else if serverTools.status == .blocked {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 11))
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation {
                                    isExpanded.toggle()
                                }
                            }

                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }
                .disabled(serverTools.status != .running)
                .onAppear {
                    updateServerSelectionState()
                }
                .onChange(of: selectedToolStates) { _ in
                    updateServerSelectionState()
                }
                .onChange(of: searchText) { _ in
                    if hasMatchingTools && !isExpanded && serverTools.status == .running {
                        isExpanded = true
                    }
                }
            }
        }

        private func toggleAllTools(selected: Bool) {
            if selectedToolStates["mcp"] == nil {
                selectedToolStates["mcp"] = [:]
            }
            for tool in serverTools.tools {
                let configurationKey = AgentModeToolHelpers.makeConfigurationKey(
                    serverName: serverTools.name,
                    toolName: tool.name
                )
                selectedToolStates["mcp"]?[configurationKey] = selected
            }
            updateServerSelectionState()
        }

        private func isToolSelected(_ tool: MCPTool) -> Bool {
            let configurationKey = AgentModeToolHelpers.makeConfigurationKey(
                serverName: serverTools.name,
                toolName: tool.name
            )
            if let state = selectedToolStates["mcp"]?[configurationKey] {
                return state
            }
            return AgentModeToolHelpers.isToolEnabledInMode(
                configurationKey: configurationKey,
                currentStatus: .enabled,
                selectedMode: currentMode
            )
        }

        private func updateServerSelectionState() {
            guard serverTools.status != .blocked && serverTools.status != .error && !serverTools.tools.isEmpty else {
                checkboxState = .off
                return
            }

            let selectedCount = serverTools.tools.filter { isToolSelected($0) }.count
            checkboxState = selectedCount == 0 ? .off : (selectedCount == serverTools.tools.count ? .on : .mixed)
        }
    }

    // MARK: - Built-In Tools Section

    private struct AgentBuiltInToolsSection: View {
        let title: String
        let currentMode: ConversationMode
        @Binding var selectedToolStates: [String: [String: Bool]]
        let searchText: String

        @State private var isExpanded: Bool = false
        @State private var checkboxState: CheckboxMixedState = .off

        private func matchesBuiltInSearch(_ tool: LanguageModelTool) -> Bool {
            guard !searchText.isEmpty else { return true }
            let lowercasedSearch = searchText.lowercased()
            return tool.name.lowercased().contains(lowercasedSearch) ||
                (tool.displayName?.lowercased().contains(lowercasedSearch) ?? false) ||
                (tool.description?.lowercased().contains(lowercasedSearch) ?? false)
        }

        private var builtInNameMatches: Bool {
            guard !searchText.isEmpty else { return false }
            let lowercasedSearch = searchText.lowercased()
            return "built-in".contains(lowercasedSearch) || "builtin".contains(lowercasedSearch)
        }

        private func hasMatchingTools(builtInTools: [LanguageModelTool]) -> Bool {
            guard !searchText.isEmpty else { return false }
            if builtInNameMatches { return true }
            return builtInTools.contains { matchesBuiltInSearch($0) }
        }

        private func filteredTools(builtInTools: [LanguageModelTool]) -> [LanguageModelTool] {
            guard !searchText.isEmpty else { return builtInTools }
            if builtInNameMatches { return builtInTools }
            return builtInTools.filter { matchesBuiltInSearch($0) }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))

                let builtInTools = CopilotLanguageModelToolManager.getAvailableLanguageModelTools() ?? []

                if builtInTools.isEmpty {
                    Text("No built-in tools available.")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                        .padding(.vertical, 8)
                } else if searchText.isEmpty || hasMatchingTools(builtInTools: builtInTools) {
                    VStack(alignment: .leading, spacing: 0) {
                        DisclosureGroup(isExpanded: $isExpanded) {
                            VStack(alignment: .leading, spacing: 0) {
                                Divider()
                                    .padding(.vertical, 4)

                                ForEach(filteredTools(builtInTools: builtInTools), id: \.name) { tool in
                                    let isSelected = selectedToolStates["builtin"]?[tool.name] ?? AgentModeToolHelpers.isToolEnabledInMode(
                                        configurationKey: tool.name,
                                        currentStatus: tool.status,
                                        selectedMode: currentMode
                                    )
                                    AgentToolRow(
                                        toolName: tool.displayName ?? tool.name,
                                        toolDescription: tool.description,
                                        isSelected: isSelected,
                                        isBlocked: false,
                                        onToggle: { isSelected in
                                            if selectedToolStates["builtin"] == nil {
                                                selectedToolStates["builtin"] = [:]
                                            }
                                            selectedToolStates["builtin"]?[tool.name] = isSelected
                                            updateBuiltInSelectionState(builtInTools: builtInTools)
                                        }
                                    )
                                    .padding(.leading, 20)
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                MixedStateCheckbox(
                                    title: "",
                                    font: .systemFont(ofSize: 13),
                                    state: $checkboxState,
                                    action: {
                                        // Toggle based on current state
                                        switch checkboxState {
                                        case .off, .mixed:
                                            toggleAllBuiltInTools(selected: true, builtInTools: builtInTools)
                                        case .on:
                                            toggleAllBuiltInTools(selected: false, builtInTools: builtInTools)
                                        }
                                    }
                                )

                                let selectedCount = builtInTools.filter { tool in
                                    if let state = selectedToolStates["builtin"]?[tool.name] {
                                        return state
                                    }
                                    return AgentModeToolHelpers.isToolEnabledInMode(
                                        configurationKey: tool.name,
                                        currentStatus: tool.status,
                                        selectedMode: currentMode
                                    )
                                }.count
                                (Text("Built-In ")
                                    .font(.system(size: 13, weight: .medium))
                                    + Text("(\(selectedCount) of \(builtInTools.count) Selected)")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(.secondary))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation {
                                            isExpanded.toggle()
                                        }
                                    }

                                Spacer()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onAppear {
                        updateBuiltInSelectionState(builtInTools: builtInTools)
                    }
                    .onChange(of: selectedToolStates) { _ in
                        updateBuiltInSelectionState(builtInTools: builtInTools)
                    }
                    .onChange(of: searchText) { _ in
                        if hasMatchingTools(builtInTools: builtInTools) && !isExpanded {
                            isExpanded = true
                        }
                    }
                }
            }
        }

        private func toggleAllBuiltInTools(selected: Bool, builtInTools: [LanguageModelTool]) {
            if selectedToolStates["builtin"] == nil {
                selectedToolStates["builtin"] = [:]
            }
            for tool in builtInTools {
                selectedToolStates["builtin"]?[tool.name] = selected
            }
            updateBuiltInSelectionState(builtInTools: builtInTools)
        }

        private func isBuiltInToolSelected(_ tool: LanguageModelTool) -> Bool {
            if let state = selectedToolStates["builtin"]?[tool.name] {
                return state
            }
            return AgentModeToolHelpers.isToolEnabledInMode(
                configurationKey: tool.name,
                currentStatus: tool.status,
                selectedMode: currentMode
            )
        }

        private func updateBuiltInSelectionState(builtInTools: [LanguageModelTool]) {
            guard !builtInTools.isEmpty else {
                checkboxState = .off
                return
            }

            let selectedCount = builtInTools.filter { isBuiltInToolSelected($0) }.count
            checkboxState = selectedCount == 0 ? .off : (selectedCount == builtInTools.count ? .on : .mixed)
        }
    }

    // MARK: - Agent Tool Row

    private struct AgentToolRow: View {
        let toolName: String
        let toolDescription: String?
        let isSelected: Bool
        let isBlocked: Bool
        let onToggle: (Bool) -> Void

        var body: some View {
            HStack(alignment: .center) {
                Toggle(isOn: Binding(
                    get: { isSelected },
                    set: { onToggle($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(toolName)
                                .font(.system(size: 12, weight: .medium))

                            if let description = toolDescription {
                                Text(description)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .help(description)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .toggleStyle(.checkbox)
                .disabled(isBlocked)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Agent Model Picker Section

    private struct AgentModelPickerSection: View {
        @Binding var selectedModel: SelectedAgentModel?
        @State private var copilotModels: [LLMModel] = []
        @State private var byokModels: [LLMModel] = []
        @State private var modelCache: [String: String] = [:]

        // Target width for menu items (popover width minus padding and margins)
        // Popover is 500pt wide, subtract horizontal padding (12pt * 2) and menu item padding (8pt * 2)
        let targetMenuItemWidth: CGFloat = 460
        let attributes: [NSAttributedString.Key: NSFont] = ModelMenuItemFormatter.attributes

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Menu {
                    // None option
                    Button(action: {
                        selectedModel = nil
                    }) {
                        Text(createModelMenuItemAttributedString(
                            modelName: "Not Specified",
                            isSelected: selectedModel == nil,
                            multiplierText: ""
                        ))
                    }

                    Divider()

                    if let model = copilotModels.first(where: { $0.isAutoModel }) {
                        Button(action: { selectModel(model) }) {
                            Text(createModelMenuItemAttributedString(
                                modelName: model.displayName ?? model.modelName,
                                isSelected: isModelSelected(model),
                                multiplierText: modelCache[model.modelName] ?? "Variable"
                            ))
                        }

                        Divider()
                    }

                    // Copilot models section
                    if !copilotModels.isEmpty {
                        Section(header: Text("Copilot Models")) {
                            ForEach(copilotModels.filter { !$0.isAutoModel }, id: \.modelName) { model in
                                Button(action: { selectModel(model) }) {
                                    Text(createModelMenuItemAttributedString(
                                        modelName: model.displayName ?? model.modelName,
                                        isSelected: isModelSelected(model),
                                        multiplierText: modelCache[model.modelName] ?? ""
                                    ))
                                }
                            }
                        }
                    }

                    // BYOK models section
                    if !byokModels.isEmpty {
                        Divider()
                        Section(header: Text("BYOK Models")) {
                            ForEach(byokModels, id: \.modelName) { model in
                                Button(action: { selectModel(model) }) {
                                    Text(createModelMenuItemAttributedString(
                                        modelName: model.displayName ?? model.modelName,
                                        isSelected: isModelSelected(model),
                                        multiplierText: modelCache[model.modelName] ?? ""
                                    ))
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(selectedModelDisplayText())
                            .font(.system(size: 12))
                            .foregroundColor(selectedModel == nil ? .secondary : .primary)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .onAppear {
                    loadModels()
                }
            }
        }

        private func selectModel(_ model: LLMModel) {
            selectedModel = SelectedAgentModel(
                displayName: model.displayName ?? model.modelName,
                modelName: model.modelName,
                source: model.providerName == nil ? .copilot : .byok(provider: model.providerName!)
            )
        }

        private func isModelSelected(_ model: LLMModel) -> Bool {
            guard let selected = selectedModel else { return false }
            if selected.modelName != model.modelName { return false }

            switch selected.source {
            case .copilot:
                return model.providerName == nil
            case let .byok(provider):
                return model.providerName?.lowercased() == provider.lowercased()
            }
        }

        private func loadModels() {
            copilotModels = CopilotModelManager.getAvailableChatLLMs(scope: .agentPanel)
            byokModels = BYOKModelManager.getAvailableChatLLMs(scope: .agentPanel)
            
            var newCache: [String: String] = [:]
            let allModels = copilotModels + byokModels
            for model in allModels {
                newCache[model.modelName] = ModelMenuItemFormatter.getMultiplierText(for: model)
            }
            modelCache = newCache
        }

        private func selectedModelDisplayText() -> String {
            guard let model = selectedModel else {
                return "Select a model..."
            }

            let sourceLabel: String
            switch model.source {
            case .copilot:
                sourceLabel = "copilot"
            case let .byok(provider):
                sourceLabel = provider
            }

            return "\(model.displayName) (\(sourceLabel))"
        }

        private func createModelMenuItemAttributedString(
            modelName: String,
            isSelected: Bool,
            multiplierText: String
        ) -> AttributedString {
            return ModelMenuItemFormatter.createModelMenuItemAttributedString(
                modelName: modelName,
                isSelected: isSelected,
                multiplierText: multiplierText,
                targetWidth: targetMenuItemWidth,
            )
        }
    }
}
