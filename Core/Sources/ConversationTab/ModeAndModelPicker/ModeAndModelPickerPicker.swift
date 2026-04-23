import SwiftUI
import ChatService
import Persist
import ComposableArchitecture
import GitHubCopilotService
import Combine
import HostAppActivator
import SharedUIComponents
import ConversationServiceProvider

struct ModeAndModelPicker: View {
    let projectRootURL: URL?
    @Binding var selectedAgent: ConversationMode

    @State private var selectedModel: LLMModel?
    @ObservedObject private var modelManager = CopilotModelManagerObservable.shared
    static var lastRefreshModelsTime: Date = .init(timeIntervalSince1970: 0)

    @State private var chatMode = "Ask"
    
    // Separate caches for both scopes
    @State private var askScopeCache: ScopeCache = ScopeCache()
    @State private var agentScopeCache: ScopeCache = ScopeCache()
    
    @State var isMCPFFEnabled: Bool
    @State var isBYOKFFEnabled: Bool
    @State private var cancellables = Set<AnyCancellable>()

    let attributes: [NSAttributedString.Key: NSFont] = ModelMenuItemFormatter.attributes

    init(projectRootURL: URL?, selectedAgent: Binding<ConversationMode>) {
        self.projectRootURL = projectRootURL
        self._selectedAgent = selectedAgent
        let initialModel = AppState.shared.getSelectedModel() ??
            CopilotModelManager.getDefaultChatModel()
        self._selectedModel = State(initialValue: initialModel)
        self.isMCPFFEnabled = FeatureFlagNotifierImpl.shared.featureFlags.mcp
        self.isBYOKFFEnabled = FeatureFlagNotifierImpl.shared.featureFlags.byok
        updateAgentPicker()
    }
    
    private func subscribeToFeatureFlagsDidChangeEvent() {
        FeatureFlagNotifierImpl.shared.featureFlagsDidChange.sink(receiveValue: { featureFlags in
            isMCPFFEnabled = featureFlags.mcp
            isBYOKFFEnabled = featureFlags.byok
        })
        .store(in: &cancellables)
    }

    var copilotModels: [LLMModel] {
        AppState.shared.isAgentModeEnabled() ?
        modelManager.availableAgentModels : modelManager.availableChatModels
    }
    
    var byokModels: [LLMModel] {
        AppState.shared.isAgentModeEnabled() ?
        modelManager.availableAgentBYOKModels : modelManager.availableChatBYOKModels
    }

    var defaultModel: LLMModel? {
        AppState.shared.isAgentModeEnabled() ? modelManager.defaultAgentModel : modelManager.defaultChatModel
    }

    // Get the current cache based on scope
    var currentCache: ScopeCache {
        AppState.shared.isAgentModeEnabled() ? agentScopeCache : askScopeCache
    }

    // Update cache for specific scope only if models changed
    func updateModelCacheIfNeeded(for scope: PromptTemplateScope) {
        let clsModels = scope == .agentPanel ? modelManager.availableAgentModels : modelManager.availableChatModels
        let byokModels = isBYOKFFEnabled ? (scope == .agentPanel ? modelManager.availableAgentBYOKModels : modelManager.availableChatBYOKModels) : []
        let currentModels = clsModels + byokModels
        let modelsHash = currentModels.hashValue
        
        if scope == .agentPanel {
            guard agentScopeCache.lastModelsHash != modelsHash else { return }
            agentScopeCache = buildCache(for: currentModels, currentHash: modelsHash)
        } else {
            guard askScopeCache.lastModelsHash != modelsHash else { return }
            askScopeCache = buildCache(for: currentModels, currentHash: modelsHash)
        }
    }
    
    // Build cache for given models
    private func buildCache(for models: [LLMModel], currentHash: Int) -> ScopeCache {
        var newCache: [String: String] = [:]
        var maxWidth: CGFloat = 0

        for model in models {
            let multiplierText = ModelMenuItemFormatter.getMultiplierText(for: model)
            newCache[model.id.appending(model.providerName ?? "")] = multiplierText

            let displayName = "✓ \(model.displayName ?? model.modelName)"
            let displayNameWidth = displayName.size(withAttributes: attributes).width
            let multiplierWidth = multiplierText.isEmpty ? 0 : multiplierText.size(withAttributes: attributes).width
            let totalWidth = displayNameWidth + ModelMenuItemFormatter.minimumPaddingWidth + multiplierWidth
            maxWidth = max(maxWidth, totalWidth)
        }

        if maxWidth == 0, let selectedModel = selectedModel {
            maxWidth = (selectedModel.displayName ?? selectedModel.modelName).size(withAttributes: attributes).width
        }
        
        return ScopeCache(
            modelMultiplierCache: newCache,
            cachedMaxWidth: maxWidth,
            lastModelsHash: currentHash
        )
    }

    func updateCurrentModel() {
        let currentModel = AppState.shared.getSelectedModel()
        var allAvailableModels = copilotModels
        if isBYOKFFEnabled {
            allAvailableModels += byokModels
        }
        
        // Find the fresh model from available models that matches the persisted selection.
        // This ensures transient fields like degradationReason stay up to date.
        let freshModel = allAvailableModels.first { model in
            model == currentModel
        }

        if freshModel == nil && currentModel != nil {
            // Switch to default model if current model is not available
            if let fallbackModel = defaultModel {
                AppState.shared.setSelectedModel(fallbackModel)
                selectedModel = fallbackModel
            } else if let firstAvailable = allAvailableModels.first {
                // If no default model, use first available
                AppState.shared.setSelectedModel(firstAvailable)
                selectedModel = firstAvailable
            } else {
                selectedModel = nil
            }
        } else {
            selectedModel = freshModel ?? defaultModel
        }
    }
    
    func updateAgentPicker() {
        self.chatMode = AppState.shared.getSelectedChatMode()
    }
    
    func switchModelsForScope(_ scope: PromptTemplateScope, model: String?) {
        let newModeModels = CopilotModelManager.getAvailableChatLLMs(
            scope: scope
        ) + BYOKModelManager.getAvailableChatLLMs(scope: scope)
        
        // If a model string is provided, try to parse and find it
        if let modelString = model {
            if let parsedModel = parseModelString(modelString, from: newModeModels) {
                // Model exists in the scope, set it
                AppState.shared.setSelectedModel(parsedModel)
                self.updateCurrentModel()
                updateModelCacheIfNeeded(for: scope)
                return
            }
            // If model doesn't exist in scope, fall through to default behavior
        }
        
        if let currentModel = AppState.shared.getSelectedModel() {
            if !newModeModels.isEmpty && !newModeModels.contains(where: { $0 == currentModel }) {
                let defaultModel = CopilotModelManager.getDefaultChatModel(scope: scope)
                if let defaultModel = defaultModel {
                    AppState.shared.setSelectedModel(defaultModel)
                } else {
                    AppState.shared.setSelectedModel(newModeModels[0])
                }
            }
        }
        
        self.updateCurrentModel()
        updateModelCacheIfNeeded(for: scope)
    }
    
    // Parse model string in format "{Model DisplayName} ({providerName or copilot})"
    // If no parentheses, defaults to Copilot model
    private func parseModelString(_ modelString: String, from availableModels: [LLMModel]) -> LLMModel? {
        var displayName: String
        var isCopilotModel: Bool
        var provider: String = ""
        
        // Extract display name and provider from the format: "DisplayName (provider)"
        if let openParenIndex = modelString.lastIndex(of: "("),
           let closeParenIndex = modelString.lastIndex(of: ")"),
           openParenIndex < closeParenIndex {
            
            let displayNameEndIndex = modelString.index(before: openParenIndex)
            displayName = String(modelString[..<displayNameEndIndex]).trimmingCharacters(in: .whitespaces)
            
            let providerStartIndex = modelString.index(after: openParenIndex)
            provider = String(modelString[providerStartIndex..<closeParenIndex]).trimmingCharacters(in: .whitespaces)
            
            // Determine if it's a Copilot or BYOK model
            isCopilotModel = provider.lowercased() == "copilot"
        } else {
            // No parentheses found, default to Copilot model
            displayName = modelString.trimmingCharacters(in: .whitespaces)
            isCopilotModel = true
        }
        
        // Search in available models
        return availableModels.first { model in
            let matchesDisplayName = (model.displayName ?? model.modelName) == displayName
            
            if isCopilotModel {
                // For Copilot models, providerName should be nil or empty
                return matchesDisplayName && (model.providerName == nil || model.providerName?.isEmpty == true)
            } else {
                // For BYOK models, providerName should match (case-insensitive)
                guard let modelProvider = model.providerName else { return false }
                return matchesDisplayName && modelProvider.lowercased() == provider.lowercased()
            }
        }
    }
    
    private var mcpButton: some View {
        Group {
            if isMCPFFEnabled {
                Button(action: {
                    let currentSubMode = AppState.shared.getSelectedAgentSubMode()
                    try? launchHostAppToolsSettings(currentAgentSubMode: currentSubMode)
                }) {
                    mcpIcon.foregroundColor(.primary.opacity(0.85))
                }
                .buttonStyle(HoverButtonStyle(padding: 0))
                .help("Configure your MCP server")
            } else {
                // Non-interactive view that looks like a button but only shows tooltip
                mcpIcon.foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .padding(0)
                    .help("MCP servers are disabled by org policy. Contact your admin.")
            }
        }
        .cornerRadius(6)
    }
    
    private var mcpIcon: some View {
        Image(systemName: "wrench.and.screwdriver")
            .resizable()
            .scaledToFit()
            .scaledFrame(width: 16, height: 16)
            .padding(4)
            .font(Font.system(size: 11, weight: .semibold))
    }
    
    // Main view body
    var body: some View {
        WithPerceptionTracking {
            HStack(spacing: 0) {
                // Custom segmented control with color change
                ChatModePicker(
                    projectRootURL: projectRootURL,
                    chatMode: $chatMode,
                    selectedAgent: $selectedAgent,
                    onScopeChange: switchModelsForScope
                )
                    .onAppear {
                        updateAgentPicker()
                    }
                    .onReceive(
                        NotificationCenter.default.publisher(for: .gitHubCopilotChatModeDidChange)) { _ in
                            updateAgentPicker()
                    }
                
                if chatMode == "Agent" {
                    mcpButton
                }

                // Model Picker
                Group {
                    if !copilotModels.isEmpty && selectedModel != nil {
                        ChatModelPicker(
                            selectedModel: selectedModel,
                            copilotModels: copilotModels,
                            byokModels: byokModels,
                            isBYOKFFEnabled: isBYOKFFEnabled,
                            currentCache: currentCache
                        )
                    } else {
                        EmptyView()
                    }
                }
            }
            .onAppear() {
                updateCurrentModel()
                // Initialize both caches
                updateModelCacheIfNeeded(for: .chatPanel)
                updateModelCacheIfNeeded(for: .agentPanel)
                Task {
                    await refreshModels()
                }
            }
            .onChange(of: defaultModel) { _ in
                updateCurrentModel()
            }
            .onChange(of: modelManager.availableChatModels) { _ in
                updateCurrentModel()
                updateModelCacheIfNeeded(for: .chatPanel)
            }
            .onChange(of: modelManager.availableAgentModels) { _ in
                updateCurrentModel()
                updateModelCacheIfNeeded(for: .agentPanel)
            }
            .onChange(of: modelManager.availableChatBYOKModels) { _ in
                updateCurrentModel()
                updateModelCacheIfNeeded(for: .chatPanel)
            }
            .onChange(of: modelManager.availableAgentBYOKModels) { _ in
                updateCurrentModel()
                updateModelCacheIfNeeded(for: .agentPanel)
            }
            .onChange(of: chatMode) { _ in
                updateCurrentModel()
            }
            .onChange(of: isBYOKFFEnabled) { _ in
                updateCurrentModel()
            }
            .onReceive(NotificationCenter.default.publisher(for: .gitHubCopilotSelectedModelDidChange)) { _ in
                updateCurrentModel()
            }
            .task {
                subscribeToFeatureFlagsDidChangeEvent()
            }
        }
    }

    @MainActor
    func refreshModels() async {
        let now = Date()
        if now.timeIntervalSince(Self.lastRefreshModelsTime) < 60 {
            return
        }

        Self.lastRefreshModelsTime = now
        let copilotModels = await SharedChatService.shared.copilotModels()
        if !copilotModels.isEmpty {
            CopilotModelManager.updateLLMs(copilotModels)
        }
    }

}

struct ModelPicker_Previews: PreviewProvider {
    @State static var agent: ConversationMode = .defaultAgent
    
    static var previews: some View {
        ModeAndModelPicker(projectRootURL: nil, selectedAgent: $agent)
    }
}
