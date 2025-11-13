import AppKit
import AppKitExtension
import ChatService
import Combine
import ConversationServiceProvider
import GitHubCopilotService
import Persist
import SharedUIComponents
import SwiftUI
import SystemUtils
import Workspace
import XcodeInspector

public extension Notification.Name {
    static let gitHubCopilotChatModeDidChange = Notification
        .Name("com.github.CopilotForXcode.ChatModeDidChange")
}

public struct ChatModePicker: View {
    @Binding var chatMode: String
    @Binding var selectedAgent: ConversationMode

    let projectRootURL: URL?
    @Environment(\.colorScheme) var colorScheme
    @State var isAgentModeFFEnabled: Bool
    @State var isEditorPreviewFFEnabled: Bool
    @State var isCustomAgentPolicyEnabled: Bool
    @State private var cancellables = Set<AnyCancellable>()
    @State private var builtInAgents: [ConversationMode] = []
    @State private var customAgents: [ConversationMode] = []
    @State private var isCreateSheetPresented = false
    @State private var agentToDelete: ConversationMode?
    @State private var showDeleteConfirmation = false
    var onScopeChange: (PromptTemplateScope, String?) -> Void

    public init(
        projectRootURL: URL?,
        chatMode: Binding<String>,
        selectedAgent: Binding<ConversationMode>,
        onScopeChange: @escaping (PromptTemplateScope, String?) -> Void = { _, _ in }
    ) {
        _chatMode = chatMode
        _selectedAgent = selectedAgent
        self.projectRootURL = projectRootURL
        self.onScopeChange = onScopeChange
        isAgentModeFFEnabled = FeatureFlagNotifierImpl.shared.featureFlags.agentMode
        isEditorPreviewFFEnabled = FeatureFlagNotifierImpl.shared.featureFlags.editorPreviewFeatures
        isCustomAgentPolicyEnabled = CopilotPolicyNotifierImpl.shared.copilotPolicy.customAgentEnabled
    }

    private func setAskMode() {
        chatMode = ChatMode.Ask.rawValue
        AppState.shared.setSelectedChatMode(ChatMode.Ask.rawValue)
        onScopeChange(.chatPanel, nil)
        NotificationCenter.default.post(
            name: .gitHubCopilotChatModeDidChange,
            object: nil
        )
    }

    private func setAgentMode(_ agent: ConversationMode) {
        chatMode = ChatMode.Agent.rawValue
        selectedAgent = agent
        AppState.shared.setSelectedChatMode(ChatMode.Agent.rawValue)
        AppState.shared.setSelectedAgentSubMode(agent.id)

        // Load agents if switching from Ask mode
        Task {
            await loadCustomAgentsAsync()
        }
        onScopeChange(.agentPanel, agent.model)
        NotificationCenter.default.post(
            name: .gitHubCopilotChatModeDidChange,
            object: nil
        )
    }

    private func subscribeToFeatureFlagsDidChangeEvent() {
        FeatureFlagNotifierImpl.shared.featureFlagsDidChange.sink(receiveValue: { featureFlags in
            isAgentModeFFEnabled = featureFlags.agentMode
            isEditorPreviewFFEnabled = featureFlags.editorPreviewFeatures
        })
        .store(in: &cancellables)
    }

    private func subscribeToPolicyDidChangeEvent() {
        CopilotPolicyNotifierImpl.shared.policyDidChange.sink(receiveValue: { policy in
            isCustomAgentPolicyEnabled = policy.customAgentEnabled
        })
        .store(in: &cancellables)
    }

    private func loadCustomAgents() {
        Task {
            await loadCustomAgentsAsync()

            // Only restore if we're in Agent mode
            if chatMode == ChatMode.Agent.rawValue {
                loadSelectedAgentSubMode()
            }
        }
    }

    private func loadCustomAgentsAsync() async {
        guard let modes = await SharedChatService.shared.loadConversationModes() else {
            // Fallback: create default built-in modes when server returns nil
            builtInAgents = [.defaultAgent]
            customAgents = []
            return
        }

        // Filter built-in modes (exclude Edit)
        builtInAgents = modes.filter { $0.isBuiltIn && $0.kind == .Agent }

        // Filter for custom agent modes (non-built-in)
        customAgents = modes.filter { !$0.isBuiltIn && $0.kind == .Agent }
    }

    private func deleteCustomAgent(_ agent: ConversationMode) {
        agentToDelete = agent
        showDeleteConfirmation = true
    }
    
    private func performDelete() {
        guard let agent = agentToDelete,
              let uriString = agent.uri,
              let fileURL = URL(string: uriString) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
            loadCustomAgents()
        } catch {
            // Error handling
        }
        agentToDelete = nil
    }

    private func openAgentFileInXcode(_ agent: ConversationMode) {
        guard let uriString = agent.uri, let fileURL = URL(string: uriString) else {
            return
        }

        NSWorkspace.openFileInXcode(fileURL: fileURL)
    }

    private func createNewAgent() {
        isCreateSheetPresented = true
    }

    private var displayName: String {
        return selectedAgent.name
    }

    private var displayIconName: String? {
        // Custom agents don't have icons
        if !selectedAgent.isBuiltIn {
            return nil
        }
        // Use checklist icon for Plan, Agent icon for others
        return AgentModeIcon.icon(for: selectedAgent.name)
    }

    public var body: some View {
        VStack {
            if isAgentModeFFEnabled {
                HStack(spacing: -1) {
                    ModeButton(
                        title: "Ask",
                        isSelected: chatMode == ChatMode.Ask.rawValue,
                        activeBackground: colorScheme == .dark ? Color.white.opacity(0.25) : Color.white,
                        activeTextColor: Color.primary,
                        inactiveTextColor: Color.primary.opacity(0.5),
                        action: {
                            setAskMode()
                        }
                    )

                    AgentModeButton(
                        title: displayName,
                        isSelected: chatMode == ChatMode.Agent.rawValue,
                        activeBackground: Color.accentColor,
                        activeTextColor: Color.white,
                        inactiveTextColor: Color.primary.opacity(0.5),
                        chatMode: chatMode,
                        builtInAgentModes: builtInAgents,
                        customAgents: customAgents,
                        selectedAgent: selectedAgent,
                        selectedIconName: displayIconName,
                        isCustomAgentEnabled: isEditorPreviewFFEnabled && isCustomAgentPolicyEnabled,
                        onSelectAgent: { setAgentMode($0) },
                        onEditAgent: { openAgentFileInXcode($0) },
                        onDeleteAgent: { deleteCustomAgent($0) },
                        onCreateAgent: { createNewAgent() }
                    )
                }
                .scaledPadding(1)
                .scaledFrame(height: 22, alignment: .topLeading)
                .background(.primary.opacity(0.1))
                .cornerRadius(16)
                .padding(4)
                .help("Set Agent")
            } else {
                EmptyView()
            }
        }
        .task {
            subscribeToFeatureFlagsDidChangeEvent()
            subscribeToPolicyDidChangeEvent()
            await loadCustomAgentsAsync()
            loadSelectedAgentSubMode()
            if !isAgentModeFFEnabled {
                setAskMode()
            }
        }
        .onChange(of: isAgentModeFFEnabled) { newAgentModeFFEnabled in
            if !newAgentModeFFEnabled {
                setAskMode()
            }
        }
        .onChange(of: isEditorPreviewFFEnabled) { newValue in
            // If editor preview is disabled and current agent is not the default agent, reset to default
            if !newValue && chatMode == ChatMode.Agent.rawValue && !selectedAgent.isDefaultAgent {
                let defaultAgent = builtInAgents.first(where: { $0.isDefaultAgent }) ?? .defaultAgent
                setAgentMode(defaultAgent)
            }
        }
        .onChange(of: isCustomAgentPolicyEnabled) { newValue in
            // If custom agent policy is disabled and current agent is not the default agent, reset to default
            if !newValue && chatMode == ChatMode.Agent.rawValue && !selectedAgent.isDefaultAgent {
                let defaultAgent = builtInAgents.first(where: { $0.isDefaultAgent }) ?? .defaultAgent
                setAgentMode(defaultAgent)
            }
        }
        // Minimal refresh: when app becomes active (e.g. user returns from editing an agent file in Xcode)
        // Reload custom agents to pick up external changes without adding complex file monitoring.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loadCustomAgents()
        }
        .onChange(of: selectedAgent) { newAgent in
            // When selectedAgent changes externally (e.g., from handoff), 
            // call setAgentMode to trigger all side effects
            // Guard: only trigger if we're not already in the correct state to avoid redundant work
            guard chatMode != ChatMode.Agent.rawValue || 
                  AppState.shared.getSelectedAgentSubMode() != newAgent.id else {
                return
            }
            setAgentMode(newAgent)
        }
        .sheet(isPresented: $isCreateSheetPresented) {
            CreateCustomCopilotFileView(
                promptType: .agent,
                editorPluginVersion: SystemUtils.editorPluginVersionString,
                getCurrentProjectURL: { projectRootURL },
                onSuccess: { _ in
                    loadCustomAgents()
                },
                onError: { _ in
                    // Handle error silently or log it
                }
            )
        }
        .confirmationDialog(
            // `agentToDelete` should always be non-nil, adding fallback for compilation safety
            "Are you sure you want to delete '\(agentToDelete?.name ?? "Agent")'?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { performDelete() }
        }
    }

    private func loadSelectedAgentSubMode() {
        let subMode = AppState.shared.getSelectedAgentSubMode()

        // Try to find the agent
        if let agent = findAgent(byId: subMode) {
            // If it's not the default agent and custom agents are disabled, reset to default
            if !agent.isDefaultAgent && (!isEditorPreviewFFEnabled || !isCustomAgentPolicyEnabled) {
                selectedAgent = builtInAgents.first(where: { $0.isDefaultAgent }) ?? .defaultAgent
                AppState.shared.setSelectedAgentSubMode("Agent")
                return
            }
            selectedAgent = agent
            return
        }

        // Default to Agent mode if nothing matches
        selectedAgent = builtInAgents.first(where: { $0.isDefaultAgent }) ?? .defaultAgent
    }

    private func findAgent(byId id: String) -> ConversationMode? {
        // Check built-in agents first
        if let builtIn = builtInAgents.first(where: { $0.id == id }) {
            return builtIn
        }
        // Check custom agents
        if let custom = customAgents.first(where: { $0.id == id }) {
            return custom
        }
        return nil
    }
}
