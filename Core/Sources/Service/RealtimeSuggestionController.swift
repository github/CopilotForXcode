import ActiveApplicationMonitor
import AppKit
import AsyncAlgorithms
import AXExtension
import Combine
import Foundation
import Logger
import Preferences
import Status
import QuartzCore
import Workspace
import XcodeInspector

public actor RealtimeSuggestionController {
    private var cancellable: Set<AnyCancellable> = []
    private var inflightPrefetchTask: Task<Void, Error>?
    private var editorObservationTask: Task<Void, Error>?
    private var sourceEditor: SourceEditor?

    init() {}

    deinit {
        cancellable.forEach { $0.cancel() }
        inflightPrefetchTask?.cancel()
        editorObservationTask?.cancel()
    }

    nonisolated
    func start() {
        Task { await observeXcodeChange() }
    }

    private func observeXcodeChange() {
        cancellable.forEach { $0.cancel() }

        XcodeInspector.shared.$focusedEditor
            .sink { [weak self] editor in
                guard let self else { return }
                Task {
                    guard let editor else { return }
                    await self.handleFocusElementChange(editor)
                }
            }.store(in: &cancellable)
    }

    private func handleFocusElementChange(_ sourceEditor: SourceEditor) {
        self.sourceEditor = sourceEditor

        let notificationsFromEditor = sourceEditor.axNotifications

        editorObservationTask?.cancel()
        editorObservationTask = nil

        editorObservationTask = Task { [weak self] in
            if let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL {
                await PseudoCommandHandler().invalidateRealtimeSuggestionsIfNeeded(
                    fileURL: fileURL,
                    sourceEditor: sourceEditor
                )
            }

            let valueChange = await notificationsFromEditor.notifications()
                .filter { $0.kind == .valueChanged }
            let selectedTextChanged = await notificationsFromEditor.notifications()
                .filter { $0.kind == .selectedTextChanged }

            await withTaskGroup(of: Void.self) { [weak self] group in
                group.addTask { [weak self] in
                    let handler = { [weak self] in
                        guard let self else { return }
                        await cancelInFlightTasks()
                        await self.triggerPrefetchDebounced()
                        await self.notifyEditingFileChange(editor: sourceEditor.element)
                    }
                    
                    for await _ in valueChange {
                        if Task.isCancelled { return }
                        await handler()
                    }
                }
                group.addTask {
                    let handler = {
                        guard let fileURL = await XcodeInspector.shared.safe.activeDocumentURL
                        else { return }
                        await PseudoCommandHandler().invalidateRealtimeSuggestionsIfNeeded(
                            fileURL: fileURL,
                            sourceEditor: sourceEditor
                        )
                    }

                    if #available(macOS 13.0, *) {
                        for await _ in selectedTextChanged._throttle(for: .milliseconds(200)) {
                            if Task.isCancelled { return }
                            await handler()
                        }
                    } else {
                        for await _ in selectedTextChanged {
                            if Task.isCancelled { return }
                            await handler()
                        }
                    }
                }

                await group.waitForAll()
            }
        }

        Task { @WorkspaceActor in // Get cache ready for real-time suggestions.
            guard UserDefaults.shared.value(for: \.preCacheOnFileOpen) else { return }
            guard let fileURL = await XcodeInspector.shared.safe.realtimeActiveDocumentURL
            else { return }
            let (_, filespace) = try await Service.shared.workspacePool
                .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)

            if filespace.codeMetadata.uti == nil {
                // avoid the command get called twice
                filespace.codeMetadata.uti = ""
                do {
                    try await XcodeInspector.shared.safe.latestActiveXcode?
                        .triggerCopilotCommand(name: "Sync Text Settings")
                    await Status.shared.updateExtensionStatus(.granted)
                } catch {
                    if filespace.codeMetadata.uti?.isEmpty ?? true {
                        filespace.codeMetadata.uti = nil
                    }
                    if let cantRunError = error as? AppInstanceInspector.CantRunCommand {
                        if cantRunError.errorDescription.contains("No bundle found") {
                            await Status.shared.updateExtensionStatus(.notGranted)
                        } else if cantRunError.errorDescription.contains("found but disabled") {
                            await Status.shared.updateExtensionStatus(.disabled)
                        }
                    }
                }
            }
        }
    }

    func triggerPrefetchDebounced(force: Bool = false) {
        inflightPrefetchTask = Task(priority: .utility) { @WorkspaceActor in
            try? await Task.sleep(nanoseconds: UInt64(
                max(UserDefaults.shared.value(for: \.realtimeSuggestionDebounce), 0.15)
                    * 1_000_000_000
            ))

            if Task.isCancelled { return }
            
            // check if user loggin
            let authStatus = await Status.shared.getAuthStatus()
            guard authStatus.status == .loggedIn else { return }

            if UserDefaults.shared.value(for: \.disableSuggestionFeatureGlobally),
               let fileURL = await XcodeInspector.shared.safe.activeDocumentURL,
               let (workspace, _) = try? await Service.shared.workspacePool
               .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
            {
                let isEnabled = workspace.isSuggestionFeatureEnabled
                if !isEnabled { return }
            }
            if Task.isCancelled { return }

            // So the editor won't be blocked (after information are cached)!
            await PseudoCommandHandler().generateRealtimeSuggestions(sourceEditor: sourceEditor)
        }
    }

    func cancelInFlightTasks(excluding: Task<Void, Never>? = nil) async {
        inflightPrefetchTask?.cancel()

        // cancel in-flight tasks
        await withTaskGroup(of: Void.self) { group in
            for (_, workspace) in Service.shared.workspacePool.workspaces {
                group.addTask {
                    await workspace.cancelInFlightRealtimeSuggestionRequests()
                }
            }
        }
    }

    /// This method will still return true if the completion panel is hidden by esc.
    /// Looks like the Xcode will keep the panel around until content is changed,
    /// not sure how to observe that it's hidden.
    func isCompletionPanelPresenting() -> Bool {
        guard let activeXcode = ActiveApplicationMonitor.shared.activeXcode else { return false }
        let application = AXUIElementCreateApplication(activeXcode.processIdentifier)
        return application.focusedWindow?.child(identifier: "_XC_COMPLETION_TABLE_") != nil
    }

    func notifyEditingFileChange(editor: AXUIElement) async {
        guard let fileURL = await XcodeInspector.shared.safe.activeDocumentURL,
              let (workspace, _) = try? await Service.shared.workspacePool
              .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        else { return }
        await workspace.didUpdateFilespace(fileURL: fileURL, content: editor.value)
    }
}

