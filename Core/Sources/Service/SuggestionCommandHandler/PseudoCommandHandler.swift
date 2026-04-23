import ActiveApplicationMonitor
import AppKit
import Dependencies
import Preferences
import SuggestionInjector
import SuggestionBasic
import Toast
import Workspace
import WorkspaceSuggestionService
import XcodeInspector
import XPCShared
import AXHelper
import GitHubCopilotService

/// It's used to run some commands without really triggering the menu bar item.
///
/// For example, we can use it to generate real-time suggestions without Apple Scripts.
struct PseudoCommandHandler {
    static var lastTimeCommandFailedToTriggerWithAccessibilityAPI = Date(timeIntervalSince1970: 0)
    static var lastBundleNotFoundTime = Date(timeIntervalSince1970: 0)
    static var lastBundleDisabledTime = Date(timeIntervalSince1970: 0)
    private var toast: ToastController { ToastControllerDependencyKey.liveValue }

    func presentPreviousSuggestion() async {
        let handler = WindowBaseCommandHandler()
        _ = try? await handler.presentPreviousSuggestion(editor: .init(
            content: "",
            lines: [],
            uti: "",
            cursorPosition: .outOfScope,
            cursorOffset: -1,
            selections: [],
            tabSize: 0,
            indentSize: 0,
            usesTabsForIndentation: false
        ))
    }

    func presentNextSuggestion() async {
        let handler = WindowBaseCommandHandler()
        _ = try? await handler.presentNextSuggestion(editor: .init(
            content: "",
            lines: [],
            uti: "",
            cursorPosition: .outOfScope,
            cursorOffset: -1,
            selections: [],
            tabSize: 0,
            indentSize: 0,
            usesTabsForIndentation: false
        ))
    }

    @WorkspaceActor
    func generateRealtimeSuggestions(sourceEditor: SourceEditor?) async {
        guard let filespace = await getFilespace(),
              let (workspace, _) = try? await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: filespace.fileURL) else { return }

        if Task.isCancelled { return }
        
        let codeCompletionEnabled = UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
        // Enabled both by Feature Flag and User.
        let nesEnabled = FeatureFlagNotifierImpl.shared.featureFlags.editorPreviewFeatures && UserDefaults.shared.value(for: \.realtimeNESToggle)
        guard codeCompletionEnabled || nesEnabled else {
            cleanupAllSuggestions(filespace: filespace, presenter: nil)
            return
        }

        // Can't use handler if content is not available.
        guard let editor = await getEditorContent(sourceEditor: sourceEditor)
        else { return }

        let presenter = PresentInWindowSuggestionPresenter()

        presenter.markAsProcessing(true)
        defer { presenter.markAsProcessing(false) }

        do {
            if codeCompletionEnabled {
                try await _generateRealtimeCodeCompletionSuggestions(
                    editor: editor,
                    sourceEditor: sourceEditor,
                    filespace: filespace,
                    workspace: workspace,
                    presenter: presenter
                )
            } else {
                cleanupCodeCompletionSuggestion(filespace: filespace, presenter: presenter)
            }
            
            if nesEnabled,
               (codeCompletionEnabled == false || filespace.presentingSuggestion == nil) {
                try await _generateRealtimeNESSuggestions(
                    editor: editor,
                    sourceEditor: sourceEditor,
                    filespace: filespace,
                    workspace: workspace,
                    presenter: presenter
                )
            } else {
                cleanupNESSuggestion(filespace: filespace, presenter: presenter)
            }
            
        } catch {
            cleanupAllSuggestions(filespace: filespace, presenter: presenter)
        }
    }
    
    @WorkspaceActor
    private func cleanupCodeCompletionSuggestion(
        filespace: Filespace,
        presenter: PresentInWindowSuggestionPresenter?
    ) {
        filespace.reset()
        presenter?.discardSuggestion(fileURL: filespace.fileURL)
    }
    
    @WorkspaceActor
    private func cleanupNESSuggestion(
        filespace: Filespace,
        presenter: PresentInWindowSuggestionPresenter?
    ) {
        filespace.resetNESSuggestion()
        presenter?.discardNESSuggestion(fileURL: filespace.fileURL)
    }
    
    @WorkspaceActor
    private func cleanupAllSuggestions(
        filespace: Filespace,
        presenter: PresentInWindowSuggestionPresenter?
    ) {
        cleanupCodeCompletionSuggestion(filespace: filespace, presenter: presenter)
        cleanupNESSuggestion(filespace: filespace, presenter: presenter)
        filespace.resetSnapshot()
        filespace.resetNESSnapshot()
    }
    
    @WorkspaceActor
    func _generateRealtimeCodeCompletionSuggestions(
        editor: EditorContent,
        sourceEditor: SourceEditor?,
        filespace: Filespace,
        workspace: Workspace,
        presenter: PresentInWindowSuggestionPresenter
    ) async throws {
        if filespace.presentingSuggestion != nil {
            // Check if the current suggestion is still valid.
            if filespace.validateSuggestions(
                lines: editor.lines,
                cursorPosition: editor.cursorPosition
            ) {
                return
            } else {
                filespace.reset()
                presenter.discardSuggestion(fileURL: filespace.fileURL)
            }
        }
        
        let fileURL = filespace.fileURL
        
        try await workspace.generateSuggestions(
            forFileAt: fileURL,
            editor: editor
        )
        let editorContent = sourceEditor?.getContent()
        if let editorContent {
            _ = filespace.validateSuggestions(
                lines: editorContent.lines,
                cursorPosition: editorContent.cursorPosition
            )
        }
        
        if !filespace.errorMessage.isEmpty {
            presenter
                .presentWarningMessage(
                    filespace.errorMessage,
                    url: "https://github.com/github-copilot/signup/copilot_individual"
                )
        }
        if filespace.presentingSuggestion != nil {
            presenter.presentSuggestion(fileURL: fileURL)
            workspace.notifySuggestionShown(fileFileAt: fileURL)
        } else {
            presenter.discardSuggestion(fileURL: fileURL)
        }
    }
    
    @WorkspaceActor
    func _generateRealtimeNESSuggestions(
        editor: EditorContent,
        sourceEditor: SourceEditor?,
        filespace: Filespace,
        workspace: Workspace,
        presenter: PresentInWindowSuggestionPresenter
    ) async throws {
        if filespace.presentingNESSuggestion != nil {
            // Check if the current NES suggestion is still valid.
            if filespace.validateNESSuggestions(
                lines: editor.lines,
                cursorPosition: editor.cursorPosition
            ) {
                return
            } else {
                filespace.resetNESSuggestion()
                presenter.discardNESSuggestion(fileURL: filespace.fileURL)
            }
        }
        
        let fileURL = filespace.fileURL
        
        try await workspace.generateNESSuggestions(forFileAt: fileURL, editor: editor)
        
        let editorContent = sourceEditor?.getContent()
        if let editorContent {
            _ = filespace.validateNESSuggestions(
                lines: editorContent.lines,
                cursorPosition: editorContent.cursorPosition
            )
        }
        // TODO: handle errorMessage if any
        if filespace.presentingNESSuggestion != nil {
            presenter.presentNESSuggestion(fileURL: fileURL)
            workspace.notifyNESSuggestionShown(forFileAt: fileURL)
        } else {
            presenter.discardNESSuggestion(fileURL: fileURL)
        }
    }

    @WorkspaceActor
    func invalidateRealtimeSuggestionsIfNeeded(fileURL: URL, sourceEditor: SourceEditor) async {
        guard let (_, filespace) = try? await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL) else { return }

        if filespace.presentingSuggestion == nil {
            return // skip if there's no suggestion presented.
        }

        let content = sourceEditor.getContent()
        if !filespace.validateSuggestions(
            lines: content.lines,
            cursorPosition: content.cursorPosition
        ) {
            PresentInWindowSuggestionPresenter().discardSuggestion(fileURL: fileURL)
        }
    }
    
    @WorkspaceActor
    func invalidateRealtimeNESSuggestionsIfNeeded(fileURL: URL, sourceEditor: SourceEditor) async {
        guard let (_, filespace) = try? await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL) else { return }
        
        if filespace.presentingNESSuggestion == nil {
            return // skip if there's no NES suggestion presented.
        }
        
        let content = sourceEditor.getContent()
        if !filespace.validateNESSuggestions(
            lines: content.lines,
            cursorPosition: content.cursorPosition
        ) {
            PresentInWindowSuggestionPresenter().discardNESSuggestion(fileURL: fileURL)
        }
    }

    func rejectSuggestions() async {
        let handler = WindowBaseCommandHandler()
        _ = try? await handler.rejectSuggestion(editor: .init(
            content: "",
            lines: [],
            uti: "",
            cursorPosition: .outOfScope,
            cursorOffset: -1,
            selections: [],
            tabSize: 0,
            indentSize: 0,
            usesTabsForIndentation: false
        ))
    }
    
    func rejectNESSuggestions() async {
        let handler = WindowBaseCommandHandler()
        _ = try? await handler.rejectNESSuggestion(editor: .init(
            content: "",
            lines: [],
            uti: "",
            cursorPosition: .outOfScope,
            cursorOffset: -1,
            selections: [],
            tabSize: 0,
            indentSize: 0,
            usesTabsForIndentation: false
        ))
    }

    func handleCustomCommand(_ command: CustomCommand) async {
        guard let editor = await {
            if let it = await getEditorContent(sourceEditor: nil) {
                return it
            }
            switch command.feature {
            // editor content is not required.
            case .customChat, .chatWithSelection, .singleRoundDialog:
                return .init(
                    content: "",
                    lines: [],
                    uti: "",
                    cursorPosition: .outOfScope,
                    cursorOffset: -1,
                    selections: [],
                    tabSize: 0,
                    indentSize: 0,
                    usesTabsForIndentation: false
                )
            // editor content is required.
            case .promptToCode:
                return nil
            }
        }() else {
            do {
                try await XcodeInspector.shared.safe.latestActiveXcode?
                    .triggerCopilotCommand(name: command.name)
            } catch {
                let presenter = PresentInWindowSuggestionPresenter()
                presenter.presentError(error)
            }
            return
        }

        let handler = WindowBaseCommandHandler()
        do {
            try await handler.handleCustomCommand(id: command.id, editor: editor)
        } catch {
            let presenter = PresentInWindowSuggestionPresenter()
            presenter.presentError(error)
        }
    }

    func acceptPromptToCode() async {
        do {
            if UserDefaults.shared.value(for: \.alwaysAcceptSuggestionWithAccessibilityAPI) {
                throw CancellationError()
            }
            do {
                try await XcodeInspector.shared.safe.latestActiveXcode?
                    .triggerCopilotCommand(name: "Accept Prompt to Code")
            } catch {
                let last = Self.lastTimeCommandFailedToTriggerWithAccessibilityAPI
                let now = Date()
                if now.timeIntervalSince(last) > 60 * 60 {
                    Self.lastTimeCommandFailedToTriggerWithAccessibilityAPI = now
                    toast.toast(content: """
                    The app is using a fallback solution to accept suggestions. \
                    For better experience, please restart Xcode to re-activate the Copilot \
                    menu item.
                    """, level: .warning)
                }

                throw error
            }
        } catch {
            guard let xcode = ActiveApplicationMonitor.shared.activeXcode
                    ?? ActiveApplicationMonitor.shared.latestXcode else { return }
            let application = AXUIElementCreateApplication(xcode.processIdentifier)
            guard let focusElement = application.focusedElement,
                  focusElement.description == "Source Editor"
            else { return }
            guard let (
                content,
                lines,
                _,
                cursorPosition,
                cursorOffset
            ) = await getFileContent(sourceEditor: nil)
            else {
                PresentInWindowSuggestionPresenter()
                    .presentErrorMessage("Unable to get file content.")
                return
            }
            let handler = WindowBaseCommandHandler()
            do {
                guard let result = try await handler.acceptPromptToCode(editor: .init(
                    content: content,
                    lines: lines,
                    uti: "",
                    cursorPosition: cursorPosition,
                    cursorOffset: cursorOffset,
                    selections: [],
                    tabSize: 0,
                    indentSize: 0,
                    usesTabsForIndentation: false
                )) else { return }

                try injectUpdatedCodeWithAccessibilityAPI(result, focusElement: focusElement)
            } catch {
                PresentInWindowSuggestionPresenter().presentError(error)
            }
        }
    }

    func acceptSuggestion(_ suggestionType: CodeSuggestionType) async {
        do {
            if UserDefaults.shared.value(for: \.alwaysAcceptSuggestionWithAccessibilityAPI) {
                throw CancellationError()
            }
            do {
                switch suggestionType {
                case .codeCompletion:
                    try await XcodeInspector.shared.safe.latestActiveXcode?
                        .triggerCopilotCommand(name: "Accept Suggestion")
                case .nes:
                    try await XcodeInspector.shared.safe.latestActiveXcode?
                        .triggerCopilotCommand(name: "Accept Next Edit Suggestion")
                }
            } catch {
                let lastBundleNotFoundTime = Self.lastBundleNotFoundTime
                let lastBundleDisabledTime = Self.lastBundleDisabledTime
                let now = Date()
                if let cantRunError = error as? AppInstanceInspector.CantRunCommand {
                    if cantRunError.errorDescription.contains("No bundle found") {
                        // Extension permission not granted
                        if now.timeIntervalSince(lastBundleNotFoundTime) > 60 * 60 {
                            Self.lastBundleNotFoundTime = now
                            toast.toast(
                                title: "GitHub Copilot Extension Permission Not Granted",
                                content: """
                                Enable Extensions → Xcode Source Editor → GitHub Copilot \
                                for Xcode for faster and full-featured code completion. \
                                [View How-to Guide](https://github.com/github/CopilotForXcode/blob/main/TROUBLESHOOTING.md#extension-permission)
                                """,
                                level: .warning,
                                button: .init(
                                    title: "Enable",
                                    action: { NSWorkspace.openXcodeExtensionsPreferences() }
                                )
                            )
                        }
                    } else if cantRunError.errorDescription.contains("found but disabled") {
                        if now.timeIntervalSince(lastBundleDisabledTime) > 60 * 60 {
                            Self.lastBundleDisabledTime = now
                            toast.toast(
                                title: "GitHub Copilot Extension Disabled",
                                content: "Quit and restart Xcode to enable extension.",
                                level: .warning,
                                button: .init(
                                    title: "Restart Xcode",
                                    action: { NSWorkspace.restartXcode() }
                                )
                            )
                        }
                    }
                }

                throw error
            }
        } catch {
            guard let xcode = ActiveApplicationMonitor.shared.activeXcode
                    ?? ActiveApplicationMonitor.shared.latestXcode else { return }
            let application = AXUIElementCreateApplication(xcode.processIdentifier)
            guard let focusElement = application.focusedElement,
                  focusElement.description == "Source Editor"
            else { return }
            guard let (
                content,
                lines,
                _,
                cursorPosition,
                cursorOffset
            ) = await getFileContent(sourceEditor: nil)
            else {
                PresentInWindowSuggestionPresenter()
                    .presentErrorMessage("Unable to get file content.")
                return
            }
            let handler = WindowBaseCommandHandler()
            do {
                let editor: EditorContent = .init(
                    content: content,
                    lines: lines,
                    uti: "",
                    cursorPosition: cursorPosition,
                    cursorOffset: cursorOffset,
                    selections: [],
                    tabSize: 0,
                    indentSize: 0,
                    usesTabsForIndentation: false
                )
                
                let result = try await {
                    switch suggestionType {
                    case .codeCompletion:
                        return try await handler.acceptSuggestion(editor: editor)
                    case .nes:
                        return try await handler.acceptNESSuggestion(editor: editor)
                    }
                }()
                
                guard let result else { return }

                try injectUpdatedCodeWithAccessibilityAPI(result, focusElement: focusElement)
            } catch {
                PresentInWindowSuggestionPresenter().presentError(error)
            }
        }
    }
    
    func goToNextEditSuggestion() async {
        do {
            guard let sourceEditor = await XcodeInspector.shared.safe.focusedEditor,
                  let fileURL = sourceEditor.realtimeDocumentURL
            else { return }
            let (workspace, _) = try await Service.shared.workspacePool
                .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
            
            guard let suggestion = await workspace.getNESSuggestion(forFileAt: fileURL)
            else { return }
            
            AXHelper.scrollSourceEditorToLine(
                suggestion.range.start.line,
                content: sourceEditor.getContent().content,
                focusedElement: sourceEditor.element
            )
        } catch {
            // Handle if needed
        }
    }

    func dismissSuggestion() async {
        guard let documentURL = await XcodeInspector.shared.safe.activeDocumentURL else { return }
        guard let (_, filespace) = try? await Service.shared.workspacePool
            .fetchOrCreateWorkspaceAndFilespace(fileURL: documentURL) else { return }

        await filespace.reset()
        PresentInWindowSuggestionPresenter().discardSuggestion(fileURL: documentURL)
    }

    func openChat(forceDetach: Bool) {
        let store = Service.shared.guiController.store
        Task { @MainActor in
            await store.send(.createAndSwitchToChatTabIfNeeded).finish()
            store.send(.openChatPanel(forceDetach: forceDetach))
        }
    }
}

extension PseudoCommandHandler {
    /// When Xcode commands are not available, we can fallback to directly
    /// set the value of the editor with Accessibility API.
    func injectUpdatedCodeWithAccessibilityAPI(
        _ result: UpdatedContent,
        focusElement: AXUIElement
    ) throws {
        try AXHelper().injectUpdatedCodeWithAccessibilityAPI(
            result,
            focusElement: focusElement,
            onError: {
                PresentInWindowSuggestionPresenter()
                    .presentErrorMessage("Fail to set editor content.")
            }
        )
    }

    func getFileContent(sourceEditor: AXUIElement?) async
    -> (
        content: String,
        lines: [String],
        selections: [CursorRange],
        cursorPosition: CursorPosition,
        cursorOffset: Int
    )?
    {
        guard let xcode = ActiveApplicationMonitor.shared.activeXcode
                ?? ActiveApplicationMonitor.shared.latestXcode else { return nil }
        let application = AXUIElementCreateApplication(xcode.processIdentifier)
        guard let focusElement = sourceEditor ?? application.focusedElement,
              focusElement.description == "Source Editor"
        else { return nil }
        guard let selectionRange = focusElement.selectedTextRange else { return nil }
        let content = focusElement.value
        let split = content.breakLines(appendLineBreakToLastLine: false)
        let range = SourceEditor.convertRangeToCursorRange(selectionRange, in: content)
        return (content, split, [range], range.start, selectionRange.lowerBound)
    }

    func getFileURL() async -> URL? {
        await XcodeInspector.shared.safe.realtimeActiveDocumentURL
    }

    @WorkspaceActor
    func getFilespace() async -> Filespace? {
        guard
            let fileURL = await getFileURL(),
            let (_, filespace) = try? await Service.shared.workspacePool
                .fetchOrCreateWorkspaceAndFilespace(fileURL: fileURL)
        else { return nil }
        return filespace
    }

    @WorkspaceActor
    func getEditorContent(sourceEditor: SourceEditor?) async -> EditorContent? {
        guard let filespace = await getFilespace(),
              let sourceEditor = await {
                  if let sourceEditor { sourceEditor }
                  else { await XcodeInspector.shared.safe.focusedEditor }
              }()
        else { return nil }
        if Task.isCancelled { return nil }
        let content = sourceEditor.getContent()
        let uti = filespace.codeMetadata.uti ?? ""
        let tabSize = filespace.codeMetadata.tabSize ?? 4
        let indentSize = filespace.codeMetadata.indentSize ?? 4
        let usesTabsForIndentation = filespace.codeMetadata.usesTabsForIndentation ?? false
        return .init(
            content: content.content,
            lines: content.lines,
            uti: uti,
            cursorPosition: content.cursorPosition,
            cursorOffset: content.cursorOffset,
            selections: content.selections.map {
                .init(start: $0.start, end: $0.end)
            },
            tabSize: tabSize,
            indentSize: indentSize,
            usesTabsForIndentation: usesTabsForIndentation
        )
    }
}

