import Foundation
import Workspace
public final class KeyBindingManager {
    let tabToAcceptSuggestion: TabToAcceptSuggestion
    public init(
        workspacePool: WorkspacePool,
        acceptSuggestion: @escaping () -> Void,
        acceptNESSuggestion: @escaping () -> Void,
        expandSuggestion: @escaping () -> Void,
        collapseSuggestion: @escaping () -> Void,
        dismissSuggestion: @escaping () -> Void,
        rejectNESSuggestion: @escaping () -> Void,
        goToNextEditSuggestion: @escaping () -> Void,
        isNESPanelOutOfFrame: @escaping () -> Bool
    ) {
        tabToAcceptSuggestion = .init(
            workspacePool: workspacePool,
            acceptSuggestion: acceptSuggestion,
            acceptNESSuggestion: acceptNESSuggestion,
            dismissSuggestion: dismissSuggestion,
            expandSuggestion: expandSuggestion,
            collapseSuggestion: collapseSuggestion,
            rejectNESSuggestion: rejectNESSuggestion,
            goToNextEditSuggestion: goToNextEditSuggestion,
            isNESPanelOutOfFrame: isNESPanelOutOfFrame
        )
    }

    public func start() {
        tabToAcceptSuggestion.start()
    }
    
    @MainActor
    public func stopForExit() {
        tabToAcceptSuggestion.stopForExit()
    }
}
