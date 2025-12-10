import Foundation
import Combine
import Persist
import GitHubCopilotService
import ConversationServiceProvider

public let SELECTED_LLM_KEY = "selectedLLM"
public let SELECTED_CHATMODE_KEY = "selectedChatMode"
public let SELECTED_AGENT_SUBMODE_KEY = "selectedAgentSubMode"

public extension Notification.Name {
    static let gitHubCopilotSelectedModelDidChange = Notification.Name("com.github.CopilotForXcode.SelectedModelDidChange")
}

public extension AppState {
    func isSelectedModelSupportVision() -> Bool? {
        if let savedModel = get(key: SELECTED_LLM_KEY) {
           return savedModel["supportVision"]?.boolValue
        }
        return nil
    }
    
    func getSelectedModel() -> LLMModel? {
        guard let savedModel = get(key: SELECTED_LLM_KEY) else {
            return nil
        }
        
        guard let modelName = savedModel["modelName"]?.stringValue,
              let modelFamily = savedModel["modelFamily"]?.stringValue,
              let id = savedModel["id"]?.stringValue else {
            return nil
        }
        
        let displayName = savedModel["displayName"]?.stringValue
        let providerName = savedModel["providerName"]?.stringValue
        let supportVision = savedModel["supportVision"]?.boolValue ?? false
        
        // Try to reconstruct billing info if available
        var billing: CopilotModelBilling?
        if let isPremium = savedModel["billing"]?["isPremium"]?.boolValue,
           let multiplier = savedModel["billing"]?["multiplier"]?.numberValue {
            billing = CopilotModelBilling(
                isPremium: isPremium,
                multiplier: Float(multiplier)
            )
        }
        
        return LLMModel(
            displayName: displayName,
            modelName: modelName,
            modelFamily: modelFamily,
            id: id,
            billing: billing,
            providerName: providerName,
            supportVision: supportVision
        )
    }

    func setSelectedModel(_ model: LLMModel) {
        update(key: SELECTED_LLM_KEY, value: model)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .gitHubCopilotSelectedModelDidChange, object: nil)
        }
    }

    func modelScope() -> PromptTemplateScope {
        return isAgentModeEnabled() ? .agentPanel : .chatPanel
    }
    
    func getSelectedChatMode() -> String {
        if let savedMode = get(key: SELECTED_CHATMODE_KEY),
           let modeName = savedMode.stringValue {
            return convertChatMode(modeName)
        }

        // Default to "Agent"
        return "Agent"
    }

    func setSelectedChatMode(_ mode: String) {
        update(key: SELECTED_CHATMODE_KEY, value: mode)
    }

    func isAgentModeEnabled() -> Bool {
        return getSelectedChatMode() == "Agent"
    }
    
    func getSelectedAgentSubMode() -> String {
        if let savedSubMode = get(key: SELECTED_AGENT_SUBMODE_KEY),
           let subMode = savedSubMode.stringValue {
            return subMode
        }
        // Default to "Agent"
        return "Agent"
    }
    
    func setSelectedAgentSubMode(_ subMode: String) {
        update(key: SELECTED_AGENT_SUBMODE_KEY, value: subMode)
    }

    private func convertChatMode(_ mode: String) -> String {
        switch mode {
        case "Ask":
            return "Ask"
        default:
            return "Agent"
        }
    }
}

public class CopilotModelManagerObservable: ObservableObject {
    static let shared = CopilotModelManagerObservable()
    
    @Published var availableChatModels: [LLMModel] = []
    @Published var availableAgentModels: [LLMModel] = []
    @Published var defaultChatModel: LLMModel?
    @Published var defaultAgentModel: LLMModel?
    @Published var availableChatBYOKModels: [LLMModel] = []
    @Published var availableAgentBYOKModels: [LLMModel] = []
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Initial load
        availableChatModels = CopilotModelManager.getAvailableChatLLMs(scope: .chatPanel)
        availableAgentModels = CopilotModelManager.getAvailableChatLLMs(scope: .agentPanel)
        defaultChatModel = CopilotModelManager.getDefaultChatModel(scope: .chatPanel)
        defaultAgentModel = CopilotModelManager.getDefaultChatModel(scope: .agentPanel)
        availableChatBYOKModels = BYOKModelManager.getAvailableChatLLMs(scope: .chatPanel)
        availableAgentBYOKModels = BYOKModelManager.getAvailableChatLLMs(scope: .agentPanel)
        
        // Setup notification to update when models change
        NotificationCenter.default.publisher(for: .gitHubCopilotModelsDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.availableChatModels = CopilotModelManager.getAvailableChatLLMs(scope: .chatPanel)
                self?.availableAgentModels = CopilotModelManager.getAvailableChatLLMs(scope: .agentPanel)
                self?.defaultChatModel = CopilotModelManager.getDefaultChatModel(scope: .chatPanel)
                self?.defaultAgentModel = CopilotModelManager.getDefaultChatModel(scope: .agentPanel)
                self?.availableChatBYOKModels = BYOKModelManager.getAvailableChatLLMs(scope: .chatPanel)
                self?.availableAgentBYOKModels = BYOKModelManager.getAvailableChatLLMs(scope: .agentPanel)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .gitHubCopilotShouldSwitchFallbackModel)
            .receive(on: DispatchQueue.main)
            .sink { _ in
                if let fallbackModel = CopilotModelManager.getFallbackLLM(
                    scope: AppState.shared
                        .isAgentModeEnabled() ? .agentPanel : .chatPanel
                ) {
                    AppState.shared.setSelectedModel(
                        .init(
                            modelName: fallbackModel.modelName,
                            modelFamily: fallbackModel.modelFamily,
                            id: fallbackModel.id,
                            billing: fallbackModel.billing,
                            supportVision: fallbackModel.capabilities.supports.vision
                        )
                    )
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Copilot Model Manager
public extension CopilotModelManager {
    static func getAvailableChatLLMs(scope: PromptTemplateScope = .chatPanel) -> [LLMModel] {
        let LLMs = CopilotModelManager.getAvailableLLMs()
        return LLMs.filter(
            { $0.scopes.contains(scope) }
        ).map {
            return LLMModel(
                modelName: $0.modelName,
                modelFamily: $0.isChatFallback ? $0.id : $0.modelFamily,
                id: $0.id,
                billing: $0.billing,
                supportVision: $0.capabilities.supports.vision
            )
        }
    }

    static func getDefaultChatModel(scope: PromptTemplateScope = .chatPanel) -> LLMModel? {
        let LLMs = CopilotModelManager.getAvailableLLMs()
        let LLMsInScope = LLMs.filter({ $0.scopes.contains(scope) })
        let defaultModel = LLMsInScope.first(where: { $0.isChatDefault && !$0.isAutoModel })
        // If a default model is found, return it
        if let defaultModel = defaultModel {
            return LLMModel(
                modelName: defaultModel.modelName,
                modelFamily: defaultModel.modelFamily,
                id: defaultModel.id,
                billing: defaultModel.billing,
                supportVision: defaultModel.capabilities.supports.vision
            )
        }

        // Fallback to gpt-4.1 if available
        let gpt4_1 = LLMsInScope.first(where: { $0.modelFamily == "gpt-4.1" })
        if let gpt4_1 = gpt4_1 {
            return LLMModel(
                modelName: gpt4_1.modelName,
                modelFamily: gpt4_1.modelFamily,
                id: gpt4_1.id,
                billing: gpt4_1.billing,
                supportVision: gpt4_1.capabilities.supports.vision
            )
        }

        // If no default model is found, fallback to the first available model
        if let firstModel = LLMsInScope.first(where: { !$0.isAutoModel }) {
            return LLMModel(
                modelName: firstModel.modelName,
                modelFamily: firstModel.modelFamily,
                id: firstModel.id,
                billing: firstModel.billing,
                supportVision: firstModel.capabilities.supports.vision
            )
        }

        return nil
    }
}

// MARK: - BYOK Model Manager
public extension BYOKModelManager {
    static func getAvailableChatLLMs(scope: PromptTemplateScope = .chatPanel) -> [LLMModel] {
        var BYOKModels = BYOKModelManager.getRegisteredBYOKModels()
        if scope == .agentPanel {
            BYOKModels = BYOKModels.filter(
                { $0.modelCapabilities?.toolCalling == true }
            )
        }
        return BYOKModels.map {
            return LLMModel(
                displayName: $0.modelCapabilities?.name,
                modelName: $0.modelId,
                modelFamily: $0.modelId,
                id: $0.modelId,
                billing: nil,
                providerName: $0.providerName.rawValue,
                supportVision: $0.modelCapabilities?.vision ?? false
            )
        }
    }
}

public struct LLMModel: Codable, Hashable, Equatable {
    public let displayName: String?
    public let modelName: String
    public let modelFamily: String
    public let id: String
    public let billing: CopilotModelBilling?
    public let providerName: String?
    public let supportVision: Bool
    
    public init(
        displayName: String? = nil,
        modelName: String,
        modelFamily: String,
        id: String,
        billing: CopilotModelBilling?,
        providerName: String? = nil,
        supportVision: Bool
    ) {
        self.displayName = displayName
        self.modelName = modelName
        self.modelFamily = modelFamily
        self.id = id
        self.billing = billing
        self.providerName = providerName
        self.supportVision = supportVision
    }
}

public extension LLMModel {
    /// Apply to `Copilot Models`
    var isPremiumModel: Bool { billing?.isPremium == true }
    /// Apply to `Copilot Models`
    var isStandardModel: Bool { !isPremiumModel || billing == nil }
    /// Apply to `Copilot Models`
    var isAutoModel: Bool { isStandardModel && modelName == "Auto" }
}

extension CopilotModel {
    var isAutoModel: Bool { modelName == "Auto" }
}
