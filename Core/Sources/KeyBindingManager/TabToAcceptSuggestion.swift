import ActiveApplicationMonitor
import AppKit
import CGEventOverride
import Foundation
import Logger
import Preferences
import SuggestionBasic
import UserDefaultsObserver
import Workspace
import XcodeInspector
import SuggestionWidget

final class TabToAcceptSuggestion {
    let hook: CGEventHookType = CGEventHook(eventsOfInterest: [.keyDown]) { message in
        Logger.service.debug("TabToAcceptSuggestion: \(message)")
    }

    let workspacePool: WorkspacePool
    let acceptSuggestion: () -> Void
    let acceptNESSuggestion: () -> Void
    let expandSuggestion: () -> Void
    let collapseSuggestion: () -> Void
    let dismissSuggestion: () -> Void
    let rejectNESSuggestion: () -> Void
    let goToNextEditSuggestion: () -> Void
    let isNESPanelOutOfFrame: () -> Bool
    private var modifierEventMonitor: Any?
    private let userDefaultsObserver = UserDefaultsObserver(
        object: UserDefaults.shared, forKeyPaths: [
            UserDefaultPreferenceKeys().acceptSuggestionWithTab.key,
            UserDefaultPreferenceKeys().dismissSuggestionWithEsc.key,
        ], context: nil
    )
    private var stoppedForExit = false

    struct ObservationKey: Hashable {}

    var canTapToAcceptSuggestion: Bool {
        UserDefaults.shared.value(for: \.acceptSuggestionWithTab)
    }

    var canEscToDismissSuggestion: Bool {
        UserDefaults.shared.value(for: \.dismissSuggestionWithEsc)
    }

    @MainActor
    func stopForExit() {
        stoppedForExit = true
        stopObservation()
    }

    init(
        workspacePool: WorkspacePool,
        acceptSuggestion: @escaping () -> Void,
        acceptNESSuggestion: @escaping () -> Void,
        dismissSuggestion: @escaping () -> Void,
        expandSuggestion: @escaping () -> Void,
        collapseSuggestion: @escaping () -> Void,
        rejectNESSuggestion: @escaping () -> Void,
        goToNextEditSuggestion: @escaping () -> Void,
        isNESPanelOutOfFrame: @escaping () -> Bool
    ) {
        _ = ThreadSafeAccessToXcodeInspector.shared
        self.workspacePool = workspacePool
        self.acceptSuggestion = acceptSuggestion
        self.acceptNESSuggestion = acceptNESSuggestion
        self.dismissSuggestion = dismissSuggestion
        self.rejectNESSuggestion = rejectNESSuggestion
        self.expandSuggestion = expandSuggestion
        self.collapseSuggestion = collapseSuggestion
        self.goToNextEditSuggestion = goToNextEditSuggestion
        self.isNESPanelOutOfFrame = isNESPanelOutOfFrame

        hook.add(
            .init(
                eventsOfInterest: [.keyDown],
                convert: { [weak self] _, _, event in
                    self?.handleEvent(event) ?? .unchanged
                }
            ),
            forKey: ObservationKey()
        )
    }

    func start() {
        Task { [weak self] in
            for await _ in ActiveApplicationMonitor.shared.createInfoStream() {
                guard let self else { return }
                try Task.checkCancellation()
                Task { @MainActor in
                    if ActiveApplicationMonitor.shared.activeXcode != nil {
                        self.startObservation()
                    } else {
                        self.stopObservation()
                    }
                }
            }
        }

        userDefaultsObserver.onChange = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                if self.canTapToAcceptSuggestion {
                    self.startObservation()
                } else {
                    self.stopObservation()
                }
            }
        }
    }

    @MainActor
    func startObservation() {
        guard !stoppedForExit else { return }
        guard canTapToAcceptSuggestion else { return }
        hook.activateIfPossible()
        removeMonitor()
        modifierEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleModifierEvents(event: event)
        }
    }

    @MainActor
    func stopObservation() {
        hook.deactivate()
        removeMonitor()
    }

    private func removeMonitor() {
        if let monitor = modifierEventMonitor {
            NSEvent.removeMonitor(monitor)
            modifierEventMonitor = nil
        }
    }

    func handleEvent(_ event: CGEvent) -> CGEventManipulation.Result {
        let keycode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let tab = 48
        let escape = 53
        
        if keycode == tab {
            let (accept, reason, codeSuggestionType) = Self.shouldAcceptSuggestion(
                event: event,
                workspacePool: workspacePool,
                xcodeInspector: ThreadSafeAccessToXcodeInspector.shared
            )
            if let reason = reason {
                Logger.service.debug("TabToAcceptSuggestion: \(accept ? "" : "not") accepting due to: \(reason)")
            }
            if accept, let codeSuggestionType {
                switch codeSuggestionType {
                case .codeCompletion:
                    acceptSuggestion()
                case .nes:
                    if isNESPanelOutOfFrame() {
                        goToNextEditSuggestion()
                    } else {
                        acceptNESSuggestion()
                    }
                }
                return .discarded
            }
            return .unchanged
        } else if keycode == escape {
            let (shouldReject, reason) = Self.shouldRejectNESSuggestion(
                event: event,
                workspacePool: workspacePool,
                xcodeInspector: ThreadSafeAccessToXcodeInspector.shared
            )
            if let reason = reason {
                Logger.service.debug("ShouldRejectNESSuggestion: \(shouldReject ? "" : "not") rejecting due to: \(reason)")
            }
            if shouldReject {
                rejectNESSuggestion()
                return .discarded
            }
        }
        
        return .unchanged
    }

    func handleModifierEvents(event: NSEvent) {
        if event.modifierFlags.contains(NSEvent.ModifierFlags.option) {
            expandSuggestion()
        } else {
            collapseSuggestion()
        }
    }
}

extension TabToAcceptSuggestion {
    
    enum SuggestionAction {
        case acceptSuggestion, rejectNESSuggestion
    }
    
    /// Returns whether a given keyboard event should be intercepted and trigger
    /// accepting a suggestion.
    static func shouldAcceptSuggestion(
        event: CGEvent,
        workspacePool: WorkspacePool,
        xcodeInspector: ThreadSafeAccessToXcodeInspectorProtocol
    ) -> (accept: Bool, reason: String?, codeSuggestionType: CodeSuggestionType?) {
        let (isValidEvent, eventReason) = Self.validateEvent(event)
        guard isValidEvent else { return (false, eventReason, nil) }
        
        let (isValidFilespace, filespaceReason, codeSuggestionType) = Self.validateFilespace(
            event,
            workspacePool: workspacePool,
            xcodeInspector: xcodeInspector,
            suggestionAction: .acceptSuggestion
        )
        guard isValidFilespace else { return (false, filespaceReason, nil) }
        
        return (true, nil, codeSuggestionType)
    }
    
    static func shouldRejectNESSuggestion(
        event: CGEvent,
        workspacePool: WorkspacePool,
        xcodeInspector: ThreadSafeAccessToXcodeInspectorProtocol
    ) -> (accept: Bool, reason: String?) {
        let (isValidEvent, eventReason) = Self.validateEvent(event)
        guard isValidEvent else { return (false, eventReason) }
        
        let (isValidFilespace, filespaceReason, _) = Self.validateFilespace(
            event,
            workspacePool: workspacePool,
            xcodeInspector: xcodeInspector,
            suggestionAction: .rejectNESSuggestion
        )
        guard isValidFilespace else { return (false, filespaceReason) }
        
        return (true, nil)
    }
    
    static private func validateEvent(_ event: CGEvent) -> (Bool, String?) {
        if event.flags.contains(.maskHelp) { return (false, nil) }
        if event.flags.contains(.maskShift) { return (false, nil) }
        if event.flags.contains(.maskControl) { return (false, nil) }
        if event.flags.contains(.maskCommand) { return (false, nil) }
        
        return (true, nil)
    }
    
    static private func validateFilespace(
        _ event: CGEvent,
        workspacePool: WorkspacePool,
        xcodeInspector: ThreadSafeAccessToXcodeInspectorProtocol,
        suggestionAction: SuggestionAction
    ) -> (Bool, String?, CodeSuggestionType?) {
        guard xcodeInspector.hasActiveXcode else {
            return (false, "No active Xcode", nil)
        }
        guard xcodeInspector.hasFocusedEditor else {
            return (false, "No focused editor", nil)
        }
        guard let fileURL = xcodeInspector.activeDocumentURL else {
            return (false, "No active document", nil)
        }
        guard let filespace = workspacePool.fetchFilespaceIfExisted(fileURL: fileURL) else {
            return (false, "No filespace", nil)
        }
        
        var codeSuggestionType: CodeSuggestionType? = {
            if let _ = filespace.presentingSuggestion { return .codeCompletion }
            if let _ = filespace.presentingNESSuggestion { return .nes }
            return nil
        }()
        guard let codeSuggestionType = codeSuggestionType else {
            return (false, "No suggestion", nil)
        }
        
        if suggestionAction == .rejectNESSuggestion, codeSuggestionType != .nes {
            return (false, "Invalid NES suggestion", nil)
        }
        
        return (true, nil, codeSuggestionType)
    }
}

import Combine

protocol ThreadSafeAccessToXcodeInspectorProtocol {
    var activeDocumentURL: URL? {get}
    var hasActiveXcode: Bool {get}
    var hasFocusedEditor: Bool {get}
}

private class ThreadSafeAccessToXcodeInspector: ThreadSafeAccessToXcodeInspectorProtocol {
    static let shared = ThreadSafeAccessToXcodeInspector()

    private(set) var activeDocumentURL: URL?
    private(set) var hasActiveXcode = false
    private(set) var hasFocusedEditor = false
    private var cancellable: Set<AnyCancellable> = []

    init() {
        let inspector = XcodeInspector.shared

        inspector.$activeDocumentURL.receive(on: DispatchQueue.main).sink { [weak self] newValue in
            self?.activeDocumentURL = newValue
        }.store(in: &cancellable)

        inspector.$activeXcode.receive(on: DispatchQueue.main).sink { [weak self] newValue in
            self?.hasActiveXcode = newValue != nil
        }.store(in: &cancellable)

        inspector.$focusedEditor.receive(on: DispatchQueue.main).sink { [weak self] newValue in
            self?.hasFocusedEditor = newValue != nil
        }.store(in: &cancellable)
    }
}
