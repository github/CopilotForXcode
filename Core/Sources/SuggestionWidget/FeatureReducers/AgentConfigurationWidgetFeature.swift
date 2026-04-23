import ComposableArchitecture
import Foundation
import SuggestionBasic
import XcodeInspector
import ChatTab
import ConversationTab
import ChatService
import ConversationServiceProvider

@Reducer
public struct AgentConfigurationWidgetFeature {
    @ObservableState
    public struct State: Equatable {
        public var focusedEditor: SourceEditor? = nil
        public var isPanelDisplayed: Bool = false
        public var currentMode: ConversationMode? = nil

        public var lineHeight: Double = 16.0
    }
        
    public enum Action: Equatable {
        case setCurrentMode(ConversationMode?)
        case onFocusedEditorChanged(SourceEditor?)
    }
    
    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onFocusedEditorChanged(let editor):
                state.focusedEditor = editor
                return .run { send in
                    let currentMode = await getCurrentMode(for: editor)
                    await send(.setCurrentMode(currentMode))
                }
            case .setCurrentMode(let mode):
                state.currentMode = mode
                return .none
            }
        }
    }
}

private func getCurrentMode(for focusedEditor: SourceEditor?) async -> ConversationMode? {
    guard let documentURL = focusedEditor?.realtimeDocumentURL,
          documentURL.pathExtension == "md",
          documentURL.lastPathComponent.hasSuffix(".agent.md") else {
        return nil
    }
    
    // Load all conversation modes
    guard let modes = await SharedChatService.shared.loadConversationModes() else {
        return nil
    }
    
    // Find the mode that matches the current document URL
    let documentURLString = documentURL.absoluteString
    let mode = modes.first { mode in
        guard let modeURI = mode.uri else { return false }
        return modeURI == documentURLString || URL(string: modeURI)?.path == documentURL.path
    }
    
    return mode
}
