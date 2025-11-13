import Client
import Combine
import ConversationServiceProvider
import GitHubCopilotService
import Logger
import Persist
import SwiftUI
import SharedUIComponents

struct BuiltInToolsListView: View {
    @ObservedObject private var builtInToolManager = CopilotBuiltInToolManagerObservable.shared
    @State private var isSearchBarVisible: Bool = false
    @State private var searchText: String = ""
    @State private var toolEnabledStates: [String: Bool] = [:]
    @State private var modes: [ConversationMode] = []
    @Binding var selectedMode: ConversationMode
    let isCustomAgentEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GroupBox(label: headerView) {
                contentView
            }
            .groupBoxStyle(CardGroupBoxStyle())
        }
        .onAppear {
            initializeToolStates()
            // Refresh client tools to get any late-arriving server tools
            Task {
                do {
                    let service = try getService()
                    _ = try await service.refreshClientTools()
                } catch {
                    Logger.client.error("Failed to refresh client tools: \(error)")
                }
            }
        }
        .onChange(of: builtInToolManager.availableLanguageModelTools) { _ in
            initializeToolStates()
        }
        .onChange(of: selectedMode) { _ in
            toolEnabledStates = [:] // Clear state immediately
            initializeToolStates()
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: .gitHubCopilotCustomAgentToolsDidChange)) { _ in
            Logger.client.info("Custom agent tools change notification received in BuiltInToolsListView")
            if !selectedMode.isDefaultAgent {
                Task {
                    await reloadModesAndUpdateStates()
                }
            }
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                Text("Built-In Tools").fontWeight(.bold)
                if isCustomAgentEnabled {
                    AgentModeDropdown(modes: $modes, selectedMode: $selectedMode)
                }
                Spacer()
                CollapsibleSearchField(searchText: $searchText, isExpanded: $isSearchBarVisible)
            }
            .clipped()
            
            AgentModeDescriptionView(selectedMode: selectedMode, isLoadingMode: false)
        }
    }
    
    // MARK: - Content View

    private var contentView: some View {
        let filteredTools = filteredLanguageModelTools()

        if filteredTools.isEmpty {
            return AnyView(EmptyStateView())
        } else {
            return AnyView(toolsListView(tools: filteredTools))
        }
    }

    // MARK: - Tools List View

    private func toolsListView(tools: [LanguageModelTool]) -> some View {
        VStack(spacing: 0) {
            ForEach(tools, id: \.name) { tool in
                ToolRow(
                    toolName: tool.displayName ?? tool.name,
                    toolDescription: tool.displayDescription,
                    toolStatus: tool.status,
                    isServerEnabled: true,
                    isToolEnabled: toolBindingFor(tool),
                    isInteractionAllowed: isInteractionAllowed(),
                    onToolToggleChanged: { isEnabled in
                        handleToolToggleChange(tool: tool, isEnabled: isEnabled)
                    }
                )
            }
        }
    }

    // MARK: - Helper Methods
    
    private func initializeToolStates() {
        // When mode changes, recalculate everything from scratch
        var map: [String: Bool] = [:]
        for tool in builtInToolManager.availableLanguageModelTools {
            map[tool.name] = isToolEnabledInMode(tool)
        }
        toolEnabledStates = map
    }

    private func toolBindingFor(_ tool: LanguageModelTool) -> Binding<Bool> {
        Binding(
            get: {
                toolEnabledStates[tool.name] ?? isToolEnabledInMode(tool)
            },
            set: { newValue in
                toolEnabledStates[tool.name] = newValue
            }
        )
    }

    private func filteredLanguageModelTools() -> [LanguageModelTool] {
        let key = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return builtInToolManager.availableLanguageModelTools }

        return builtInToolManager.availableLanguageModelTools.filter { tool in
            tool.name.lowercased().contains(key) ||
                (tool.description?.lowercased().contains(key) ?? false) ||
                (tool.displayName?.lowercased().contains(key) ?? false)
        }
    }

    private func handleToolToggleChange(tool: LanguageModelTool, isEnabled: Bool) {
        let toolUpdate = ToolStatusUpdate(name: tool.name, status: isEnabled ? .enabled : .disabled)
        updateToolStatus([toolUpdate])
    }

    private func updateToolStatus(_ toolUpdates: [ToolStatusUpdate]) {
        Task {
            do {
                let service = try getService()
                
                if !selectedMode.isDefaultAgent {
                    let chatMode = selectedMode.kind
                    let customChatModeId = selectedMode.isBuiltIn == false ? selectedMode.id : nil
                    let workspaceFolders = await getWorkspaceFolders()
                    
                    let updatedTools = try await service
                        .updateToolsStatus(
                            toolUpdates,
                            chatAgentMode: chatMode,
                            customChatModeId: customChatModeId,
                            workspaceFolders: workspaceFolders
                        )
                    
                    if updatedTools == nil {
                        Logger.client.error("Failed to update built-in tool status: No updated tools returned")
                    }
                    
                    await reloadModesAndUpdateStates()
                } else {
                    let updatedTools = try await service.updateToolsStatus(toolUpdates)
                    if updatedTools == nil {
                        Logger.client.error("Failed to update built-in tool status: No updated tools returned")
                    }
                }
            } catch {
                Logger.client.error("Failed to update built-in tool status: \(error.localizedDescription)")
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
                    
                    for tool in builtInToolManager.availableLanguageModelTools {
                        if let customTools = updatedMode.customTools {
                            toolEnabledStates[tool.name] = customTools.contains(tool.name)
                        } else {
                            toolEnabledStates[tool.name] = false
                        }
                    }
                }
            }
        } catch {
            Logger.client.error("Failed to reload modes: \(error.localizedDescription)")
        }
    }
    
    private func isToolEnabledInMode(_ tool: LanguageModelTool) -> Bool {
        return AgentModeToolHelpers.isToolEnabledInMode(
            configurationKey: tool.name,
            currentStatus: tool.status,
            selectedMode: selectedMode
        )
    }
    
    private func isInteractionAllowed() -> Bool {
        return AgentModeToolHelpers.isInteractionAllowed(selectedMode: selectedMode)
    }
}

/// Empty state view when no tools are available
private struct EmptyStateView: View {
    var body: some View {
        Text("No built-in tools available. Make sure background permissions are granted.")
            .foregroundColor(.secondary)
    }
}
