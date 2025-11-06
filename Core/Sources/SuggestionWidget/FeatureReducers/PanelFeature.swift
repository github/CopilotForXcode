import AppKit
import ComposableArchitecture
import Foundation

@Reducer
public struct PanelFeature {
    @ObservableState
    public struct State: Equatable {
        public var content: SharedPanelFeature.Content {
            get { sharedPanelState.content }
            set {
                sharedPanelState.content = newValue
                suggestionPanelState.content = newValue.suggestion
             }
        }
        
        public var nesContent: NESCodeSuggestionProvider? {
            get { nesSuggestionPanelState.nesContent }
            set {
                nesSuggestionPanelState.nesContent = newValue
            }
        }

        // MARK: SharedPanel

        var sharedPanelState = SharedPanelFeature.State()

        // MARK: SuggestionPanel

        var suggestionPanelState = SuggestionPanelFeature.State()
        
        // MARK: NESSuggestionPanel
        
        public var nesSuggestionPanelState = NESSuggestionPanelFeature.State()

        var warningMessage: String?
        var warningURL: String?
    }

    public enum Action: Equatable {
        case presentSuggestion
        case presentNESSuggestion
        case presentSuggestionProvider(CodeSuggestionProvider, displayContent: Bool)
        case presentNESSuggestionProvider(NESCodeSuggestionProvider, displayContent: Bool)
        case presentError(String)
        case presentPromptToCode(PromptToCodeGroup.PromptToCodeInitialState)
        case displayPanelContent
        case displayNESPanelContent
        case expandSuggestion
        case discardSuggestion
        case discardNESSuggestion
        case removeDisplayedContent
        case switchToAnotherEditorAndUpdateContent
        case hidePanel
        case showPanel
        case hideNESPanel
        case showNESPanel
        case onRealtimeNESToggleChanged(Bool)

        case sharedPanel(SharedPanelFeature.Action)
        case suggestionPanel(SuggestionPanelFeature.Action)
        case nesSuggestionPanel(NESSuggestionPanelFeature.Action)

        case presentWarning(message: String, url: String?)
        case dismissWarning
    }

    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    @Dependency(\.xcodeInspector) var xcodeInspector
    @Dependency(\.activateThisApp) var activateThisApp
    var windows: WidgetWindows? { suggestionWidgetControllerDependency.windowsController?.windows }

    public var body: some ReducerOf<Self> {
        Scope(state: \.suggestionPanelState, action: \.suggestionPanel) {
            SuggestionPanelFeature()
        }

        Scope(state: \.sharedPanelState, action: \.sharedPanel) {
            SharedPanelFeature()
        }
        
        Scope(state: \.nesSuggestionPanelState, action: \.nesSuggestionPanel) {
            NESSuggestionPanelFeature()
        }

        Reduce { state, action in
            switch action {
            case .presentSuggestion:
                return .run { send in
                    guard let fileURL = await xcodeInspector.safe.activeDocumentURL,
                          let provider = await fetchSuggestionProvider(fileURL: fileURL)
                    else { return }
                    await send(.presentSuggestionProvider(provider, displayContent: true))
                }
                
            case .presentNESSuggestion:
                return .run { send in
                    guard let fileURL = await xcodeInspector.safe.activeDocumentURL,
                          let provider = await fetchNESSuggestionProvider(fileURL: fileURL)
                    else { return }
                    await send(.presentNESSuggestionProvider(provider, displayContent: true))
                }

            case let .presentSuggestionProvider(provider, displayContent):
                state.content.suggestion = provider
                if displayContent {
                    return .run { send in
                        await send(.displayPanelContent)
                    }.animation(.easeInOut(duration: 0.2))
                }
                return .none
                
            case let .presentNESSuggestionProvider(provider, displayContent):
                state.nesContent = provider
                if displayContent {
                    return .run { send in
                        await send(.displayNESPanelContent)
                    }.animation(.easeInOut(duration: 0.2))
                }
                return .none

            case let .presentError(errorDescription):
                state.content.error = errorDescription
                return .run { send in
                    await send(.displayPanelContent)
                }.animation(.easeInOut(duration: 0.2))

            case let .presentPromptToCode(initialState):
                return .run { send in
                    await send(.sharedPanel(.promptToCodeGroup(.createPromptToCode(initialState))))
                }

            case .displayPanelContent:
                if !state.sharedPanelState.isEmpty {
                    state.sharedPanelState.isPanelDisplayed = true
                }

                if state.suggestionPanelState.content != nil {
                    state.suggestionPanelState.isPanelDisplayed = true
                }
                return .none
                
            case .displayNESPanelContent:
                if state.nesSuggestionPanelState.nesContent != nil {
                    state.nesSuggestionPanelState.isPanelDisplayed = true
                }
                return .none

            case .discardSuggestion:
                state.content.suggestion = nil
                return .none
            
            case .discardNESSuggestion:
                state.nesContent = nil
                return .none
                
            case .expandSuggestion:
                state.content.isExpanded = true
                return .none
            case .switchToAnotherEditorAndUpdateContent:
                return .run { send in
                    guard let fileURL = await xcodeInspector.safe.realtimeActiveDocumentURL
                    else { return }

                    await send(.sharedPanel(
                        .promptToCodeGroup(
                            .updateActivePromptToCode(documentURL: fileURL)
                        )
                    ))
                }
            case .hidePanel:
                state.suggestionPanelState.isPanelDisplayed = false
                return .none
            case .showPanel:
                state.suggestionPanelState.isPanelDisplayed = true
                return .none
            case .hideNESPanel:
                state.nesSuggestionPanelState.isPanelDisplayed = false
                return .none
            case .showNESPanel:
                state.nesSuggestionPanelState.isPanelDisplayed = true
                return .none
            case let .onRealtimeNESToggleChanged(isOn):
                if !isOn {
                    return .run { send in
                        await send(.hideNESPanel)
                        await send(.discardNESSuggestion)
                    }
                }
                return .none
                
            case .removeDisplayedContent:
                state.content.error = nil
                state.content.suggestion = nil
                state.nesContent = nil
                return .none

            case .sharedPanel(.promptToCodeGroup(.activateOrCreatePromptToCode)),
                 .sharedPanel(.promptToCodeGroup(.createPromptToCode)):
                let hasPromptToCode = state.content.promptToCode != nil
                return .run { send in
                    await send(.displayPanelContent)

                    if hasPromptToCode {
                        activateThisApp()
                        await MainActor.run {
                            windows?.sharedPanelWindow.makeKey()
                        }
                    }
                }.animation(.easeInOut(duration: 0.2))

            case .sharedPanel:
                return .none

            case .suggestionPanel:
                return .none
                
            case .nesSuggestionPanel:
                return .none

            case .presentWarning(let message, let url):
                state.warningMessage = message
                state.warningURL = url
                state.suggestionPanelState.warningMessage = message
                state.suggestionPanelState.warningURL = url
                return .none

            case .dismissWarning:
                state.warningMessage = nil
                state.warningURL = nil
                state.suggestionPanelState.warningMessage = nil
                state.suggestionPanelState.warningURL = nil
                return .none
            }
        }
    }

    func fetchSuggestionProvider(fileURL: URL) async -> CodeSuggestionProvider? {
        guard let provider = await suggestionWidgetControllerDependency
            .suggestionWidgetDataSource?
            .suggestionForFile(at: fileURL) else { return nil }
        return provider
    }
    
    func fetchNESSuggestionProvider(fileURL: URL) async -> NESCodeSuggestionProvider? {
        guard let provider = await suggestionWidgetControllerDependency
            .suggestionWidgetDataSource?
            .nesSuggestionForFile(at: fileURL) else { return nil }
        return provider
    }
}

