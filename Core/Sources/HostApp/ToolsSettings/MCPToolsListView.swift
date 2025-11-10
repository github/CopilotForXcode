import Combine
import GitHubCopilotService
import Persist
import SwiftUI
import SharedUIComponents
import ConversationServiceProvider

struct MCPToolsListView: View {
    @ObservedObject private var mcpToolManager = CopilotMCPToolManagerObservable.shared
    @State private var serverToggleStates: [String: Bool] = [:]
    @State private var isSearchBarVisible: Bool = false
    @State private var searchText: String = ""
    @State private var modes: [ConversationMode] = []
    @Binding var selectedMode: ConversationMode
    let isCustomAgentEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GroupBox(
                label:
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        Text("Available MCP Tools").fontWeight(.bold)
                        if isCustomAgentEnabled {
                            AgentModeDropdown(modes: $modes, selectedMode: $selectedMode)
                        }
                        Spacer()
                        CollapsibleSearchField(searchText: $searchText, isExpanded: $isSearchBarVisible)
                    }
                    .clipped()
                    
                    AgentModeDescriptionView(selectedMode: selectedMode, isLoadingMode: false)
                }
            ) {
                let filteredServerTools = filteredMCPServerTools()
                if filteredServerTools.isEmpty {
                    EmptyStateView()
                } else {
                    ToolsListView(
                        mcpServerTools: filteredServerTools,
                        serverToggleStates: $serverToggleStates,
                        searchKey: searchText,
                        expandedServerNames: expandedServerNames(filteredServerTools: filteredServerTools),
                        isInteractionAllowed: isInteractionAllowed(),
                        modes: $modes,
                        selectedMode: $selectedMode
                    )
                }
            }
            .groupBoxStyle(CardGroupBoxStyle())
        }
        .onAppear(perform: updateServerToggleStates)
        .onChange(of: mcpToolManager.availableMCPServerTools) { _ in
            updateServerToggleStates()
        }
        .onChange(of: selectedMode) { _ in
            updateServerToggleStates()
        }
    }

    private func updateServerToggleStates() {
        serverToggleStates = mcpToolManager.availableMCPServerTools.reduce(into: [:]) { result, server in
            result[server.name] = !server.tools.isEmpty && !server.tools.allSatisfy { $0._status != .enabled }
        }
    }

    private func filteredMCPServerTools() -> [MCPServerToolsCollection] {
        let key = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return mcpToolManager.availableMCPServerTools }
        return mcpToolManager.availableMCPServerTools.compactMap { server in
            // If server name contains the search key, return the entire server with all tools
            if server.name.lowercased().contains(key) {
                return server
            }
            
            // Otherwise, filter tools by name and description
            let filteredTools = server.tools.filter { tool in
                tool.name.lowercased().contains(key) || (tool.description?.lowercased().contains(key) ?? false)
            }
            if filteredTools.isEmpty { return nil }
            return MCPServerToolsCollection(
                name: server.name,
                status: server.status,
                tools: filteredTools,
                error: server.error
            )
        }
    }

    private func expandedServerNames(filteredServerTools: [MCPServerToolsCollection]) -> Set<String> {
        // Expand all groups that have at least one tool in the filtered list
        Set(filteredServerTools.map { $0.name })
    }
    
    private func isInteractionAllowed() -> Bool {
        return AgentModeToolHelpers.isInteractionAllowed(selectedMode: selectedMode)
    }
}

/// Empty state view when no tools are available
private struct EmptyStateView: View {
    var body: some View {
        Text("No MCP tools available. Make sure your MCP server is configured correctly and running.")
            .foregroundColor(.secondary)
    }
}

// Private components now defined in separate files:
// MCPToolsListContainerView - in MCPToolsListContainerView.swift
// MCPServerToolsSection - in MCPServerToolsSection.swift

/// Private alias for maintaining backward compatibility
private typealias ToolsListView = MCPToolsListContainerView
private typealias ServerToolsSection = MCPServerToolsSection
