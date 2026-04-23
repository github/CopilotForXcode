import AppKit
import XcodeInspector
import Preferences
import ChatService
import ConversationServiceProvider

extension WidgetWindowsController {
    @MainActor
    func hideAgentConfigurationWidgetWindow() {
        windows.agentConfigurationWidgetWindow.alphaValue = 0
        windows.agentConfigurationWidgetWindow.setIsVisible(false)
    }
    
    @MainActor
    func displayAgentConfigurationWidgetWindow() {
        windows.agentConfigurationWidgetWindow.setIsVisible(true)
        windows.agentConfigurationWidgetWindow.alphaValue = 1
        windows.agentConfigurationWidgetWindow.orderFrontRegardless()
    }
    
    @MainActor
    func applyOpacityForAgentConfigurationWidget(by noFocus: Bool? = nil) {
        let state = store.withState { $0.panelState.agentConfigurationWidgetState }
        guard let noFocus = noFocus,
              !noFocus,
              let focusedEditor = state.focusedEditor
        else {
            hideAgentConfigurationWidgetWindow()
            return
        }
        
        let currentMode = state.currentMode

        if currentMode != nil {
            displayAgentConfigurationWidgetWindow()
        } else {
            hideAgentConfigurationWidgetWindow()
        }
    }
}
