import ChatService
import ComposableArchitecture
import Combine
import ConversationServiceProvider
import SwiftUIFlowLayout
import GitHubCopilotService
import GitHubCopilotViewModel
import LanguageServerProtocol
import Preferences
import SharedUIComponents
import Status
import SwiftUI
import Workspace
import XcodeInspector

enum ShowingType { case template, agent }

struct InputAreaTextEditor: View {
    @Perception.Bindable var chat: StoreOf<Chat>
    let r: Double
    var focusedField: FocusState<Chat.State.Field?>.Binding
    let editorMode: Chat.EditorMode
    @State var cancellable = Set<AnyCancellable>()
    @State private var isFilePickerPresented = false
    @State private var allFiles: [ConversationAttachedReference]? = nil
    @State private var filteredTemplates: [ChatTemplate] = []
    @State private var filteredAgent: [ChatAgent] = []
    @State private var showingTemplates = false
    @State private var dropDownShowingType: ShowingType? = nil
    @State private var textEditorState: TextEditorState? = nil
    
    @AppStorage(\.enableCurrentEditorContext) var enableCurrentEditorContext: Bool
    @State private var isCurrentEditorContextEnabled: Bool = UserDefaults.shared.value(
        for: \.enableCurrentEditorContext
    )
    @ObservedObject private var status: StatusObserver = .shared
    @State private var isCCRFFEnabled: Bool
    @State private var isCCRHovering: Bool = false
    @State private var cancellables = Set<AnyCancellable>()
    
    @StateObject private var fontScaleManager = FontScaleManager.shared
    
    var fontScale: Double {
        fontScaleManager.currentScale
    }
    
    init(
        chat: StoreOf<Chat>,
        r: Double,
        focusedField: FocusState<Chat.State.Field?>.Binding,
        editorMode: Chat.EditorMode
    ) {
        self.chat = chat
        self.r = r
        self.focusedField = focusedField
        self.editorMode = editorMode
        self.isCCRFFEnabled = FeatureFlagNotifierImpl.shared.featureFlags.ccr
    }
    
    var isEditorActive: Bool {
        editorMode == chat.editorMode
    }
    
    var isRequestingConversation: Bool {
        if chat.isReceivingMessage,
           let requestType = chat.requestType,
           requestType == .conversation {
            return true
        }
        return false
    }
    
    var isRequestingCodeReview: Bool {
        if chat.isReceivingMessage,
           let requestType = chat.requestType,
           requestType == .codeReview {
            return true
        }
        
        return false
    }

    var projectRootURL: URL? {
        WorkspaceXcodeWindowInspector.extractProjectURL(
            workspaceURL: chat.workspaceURL,
            documentURL: chat.state.currentEditor?.url
        )
    }
    
    var body: some View {
        WithPerceptionTracking {
            let typedMessage = chat.state.getChatContext(of: editorMode).typedMessage
            VStack(spacing: 0) {
                chatContextView
                
                if isFilePickerPresented {
                    FilePicker(
                        allFiles: $allFiles,
                        workspaceURL: chat.workspaceURL,
                        onSubmit: { ref in
                            chat.send(.addReference(ref))
                        },
                        onExit: {
                            isFilePickerPresented = false
                            focusedField.wrappedValue = .textField
                        }
                    )
                    .onAppear() {
                        allFiles = ContextUtils.getFilesFromWorkspaceIndex(workspaceURL: chat.workspaceURL)
                    }
                }
                
                if !chat.state.attachedImages.isEmpty {
                    ImagesScrollView(chat: chat, editorMode: editorMode)
                }
                
                ZStack(alignment: .topLeading) {
                    if typedMessage.isEmpty {
                        Group {
                            chat.isAgentMode ?
                            Text("Edit files in your workspace in agent mode") :
                            Text("Ask Copilot or type / for commands")
                        }
                        .scaledFont(size: 14)
                        .foregroundColor(Color(nsColor: .placeholderTextColor))
                        .padding(8)
                        .padding(.horizontal, 4)
                    }
                    
                    HStack(spacing: 0) {
                        AutoresizingCustomTextEditor(
                            text: Binding(
                                get: { typedMessage },
                                set: { newValue in chat.send(.updateTypedMessage(newValue)) }
                            ),
                            font: .systemFont(ofSize: 14 * fontScale),
                            isEditable: true,
                            maxHeight: 400,
                            onSubmit: {
                                if (dropDownShowingType == nil) {
                                    submitChatMessage()
                                }
                                dropDownShowingType = nil
                            },
                            onTextEditorStateChanged: { (state: TextEditorState?) in
                                DispatchQueue.main.async {
                                    textEditorState = state
                                }
                            }
                        )
                        .focused(focusedField, equals: isEditorActive ? .textField : nil)
                        .bind($chat.focusedField, to: focusedField)
                        .padding(8)
                        .fixedSize(horizontal: false, vertical: true)
                        .onChange(of: typedMessage) { newValue in
                            Task {
                                await onTypedMessageChanged(newValue: newValue)
                            }
                        }
                        /// When chat mode changed, the chat tamplate and agent need to be reloaded
                        .onChange(of: chat.isAgentMode) { _ in
                            guard isEditorActive else { return }
                            Task {
                                await onTypedMessageChanged(newValue: typedMessage)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
                
                HStack(spacing: 0) {
                    ModeAndModelPicker(projectRootURL: projectRootURL, selectedAgent: $chat.selectedAgent)

                    Spacer()
                    
                    if chat.editorMode.isDefault {
                        codeReviewButton
                            .buttonStyle(HoverButtonStyle(padding: 0, hoverColor: .clear))
                            .opacity(isRequestingConversation ? 0 : 1)
                    }
                    
                    ZStack {
                        sendButton
                            .opacity(isRequestingConversation || isRequestingCodeReview ? 0 : 1)
                            .foregroundColor(
                                typedMessage.isEmpty ? Color(nsColor: .tertiaryLabelColor) : Color(
                                    "IconStrokeColor"
                                )
                            )
                            .disabled(typedMessage.isEmpty)

                        stopButton
                            .opacity(isRequestingConversation || isRequestingCodeReview ? 1 : 0)
                            .foregroundColor(Color("IconStrokeColor"))
                    }
                    .buttonStyle(
                        HoverButtonStyle(
                            padding: 0,
                            hoverColor: Color(nsColor: .quaternaryLabelColor),
                            backgroundColor: Color(nsColor: .quinaryLabel),
                            cornerRadius: .infinity
                        )
                    )
                }
                .padding(8)
                .padding(.top, -4)
            }
            .overlay(alignment: .top) {
                dropdownOverlay
            }
            .onAppear() {
                guard editorMode.isDefault else { return }
                subscribeToActiveDocumentChangeEvent()
                // Check quota for CCR
                Task {
                    if status.quotaInfo == nil,
                       let service = try? GitHubCopilotViewModel.shared.getGitHubCopilotAuthService() {
                        _ = try? await service.checkQuota()
                    }
                }
            }
            .task {
                subscribeToFeatureFlagsDidChangeEvent()
            }
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.quaternary, lineWidth: 1)
            }
            .background {
                if isEditorActive {
                    Button(action: {
                        chat.send(.returnButtonTapped)
                    }) {
                        EmptyView()
                    }
                    .keyboardShortcut(KeyEquivalent.return, modifiers: [.shift])
                    .accessibilityHidden(true)
                    
                    Button(action: {
                        focusedField.wrappedValue = .textField
                    }) {
                        EmptyView()
                    }
                    .keyboardShortcut("l", modifiers: [.command])
                    .accessibilityHidden(true)
                    
                    buildReloadContextButtons()
                }
            }
            
        }
    }
    
    private var reloadNextContextButton: some View {
        Button(action: {
            chat.send(.reloadNextContext)
        }) {
            EmptyView()
        }
        .keyboardShortcut(KeyEquivalent.downArrow, modifiers: [])
        .accessibilityHidden(true)
    }
    
    private var reloadPreviousContextButton: some View {
        Button(action: {
            chat.send(.reloadPreviousContext)
        }) {
            EmptyView()
        }
        .keyboardShortcut(KeyEquivalent.upArrow, modifiers: [])
        .accessibilityHidden(true)
    }
    
    @ViewBuilder
    private func buildReloadContextButtons() -> some View {
        if let textEditorState = textEditorState {
            switch textEditorState {
            case .empty, .singleLine:
                ZStack {
                    reloadPreviousContextButton
                    reloadNextContextButton
                }
            case .multipleLines(let cursorAt):
                switch cursorAt {
                case .first:
                    reloadPreviousContextButton
                case .last:
                    reloadNextContextButton
                case .middle:
                    EmptyView()
                }
            }
        } else {
            EmptyView()
        }
    }
    
    private var sendButton: some View {
        Button(action: {
            submitChatMessage()
        }) {
            Image(systemName: "paperplane")
                .scaledFont(size: 12, weight: .medium)
                .padding(.leading, 5)
                .padding(.trailing, 6)
                .padding(.top, 6.5)
                .padding(.bottom, 5.5)
        }
        .keyboardShortcut(KeyEquivalent.return, modifiers: [])
        .help("Send")
    }
    
    private var stopButton: some View {
        Button(action: {
            chat.send(.stopRespondingButtonTapped)
        }) {
            Image(systemName: "stop.fill")
                .scaledFont(size: 12, weight: .medium)
                .padding(8)
        }
        .keyboardShortcut(KeyEquivalent.escape, modifiers: [])
        .help("Stop")
    }
    
    private var isFreeUser: Bool {
        guard let quotaInfo = status.quotaInfo else { return true }
        
        return quotaInfo.isFreeUser
    }
    
    private var ccrDisabledTooltip: String {
        if !isCCRFFEnabled {
            return "GitHub Copilot Code Review is disabled by org policy. Contact your admin."
        }
        
        return "GitHub Copilot Code Review is temporarily unavailable."
    }
    
    var codeReviewIcon: some View {
        Image("codeReview")
            .resizable()
            .scaledToFit()
            .scaledFrame(width: 14, height: 14)
            .padding(6)
    }
    
    private var codeReviewButton: some View {
        Group {
            if isFreeUser {
                // Show nothing
            } else if isCCRFFEnabled {
                Menu {
                    Button(action: {
                        chat.send(.codeReview(.request(.index)))
                    }) {
                        Text("Review Staged Changes")
                    }

                    Button(action: {
                        chat.send(.codeReview(.request(.workingTree)))
                    }) {
                        Text("Review Unstaged Changes")
                    }
                } label: {
                    codeReviewIcon
                        .foregroundColor(isCCRHovering ? .primary : Color("IconStrokeColor"))
                }
                .scaledFont(.body)
                .onHover { hovering in
                    isCCRHovering = hovering
                }
                .opacity(isRequestingCodeReview ? 0 : 1)
                .help("Code Review")
            } else {
                codeReviewIcon
                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    .help(ccrDisabledTooltip)
            }
        }
    }
    
    private func subscribeToFeatureFlagsDidChangeEvent() {
        FeatureFlagNotifierImpl.shared.featureFlagsDidChange
            .sink(receiveValue: { isCCRFFEnabled = $0.ccr })
            .store(in: &cancellables)
    }
    
    private var dropdownOverlay: some View {
        Group {
            if dropDownShowingType != nil {
                if dropDownShowingType == .template {
                    ChatDropdownView(items: $filteredTemplates, prefixSymbol: "/") { template in
                        chat.send(.updateTypedMessage("/" + template.id + " "))
                        if template.id == "releaseNotes" {
                            submitChatMessage()
                        }
                    }
                } else if dropDownShowingType == .agent {
                    ChatDropdownView(items: $filteredAgent, prefixSymbol: "@") { agent in
                        chat.send(.updateTypedMessage("@" + agent.id + " "))
                    }
                }
            }
        }
    }
    
    func onTypedMessageChanged(newValue: String) async {
        guard chat.editorMode.isDefault else { return }
        if newValue.hasPrefix("/") {
            filteredTemplates = await chatTemplateCompletion(text: newValue)
            dropDownShowingType = filteredTemplates.isEmpty ? nil : .template
        } else if newValue.hasPrefix("@") && !chat.isAgentMode {
            filteredAgent = await chatAgentCompletion(text: newValue)
            dropDownShowingType = filteredAgent.isEmpty ? nil : .agent
        } else {
            dropDownShowingType = nil
        }
    }
    
    enum ChatContextButtonType { case imageAttach, contextAttach}
    
    private var chatContextView: some View {
        let buttonItems: [ChatContextButtonType] = [.contextAttach, .imageAttach]
        // Always use the latest current editor from state
        let currentEditorItem: [ConversationFileReference] = [chat.state.currentEditor].compactMap {
            $0
        }
        let references = chat.state.getChatContext(of: editorMode).attachedReferences
        let chatContextItems: [Any] = buttonItems.map {
            $0 as ChatContextButtonType
        } + currentEditorItem + references
        return FlowLayout(mode: .scrollable, items: chatContextItems, itemSpacing: 4) { item in
            if let buttonType = item as? ChatContextButtonType {
                if buttonType == .imageAttach {
                    VisionMenuView(chat: chat)
                } else if buttonType == .contextAttach {
                    // File picker button
                    Button(action: {
                        withAnimation {
                            isFilePickerPresented.toggle()
                            if !isFilePickerPresented {
                                focusedField.wrappedValue = .textField
                            }
                        }
                    }) {
                        Image(systemName: "paperclip")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaledFrame(width: 16, height: 16)
                            .scaledPadding(4)
                            .foregroundColor(.primary.opacity(0.85))
                            .scaledFont(size: 11, weight: .semibold)
                    }
                    .buttonStyle(HoverButtonStyle(padding: 0))
                    .help("Add Context")
                    .cornerRadius(6)
                }
            } else if let select = item as? ConversationFileReference, select.isCurrentEditor {
                makeCurrentEditorView(select)
            } else if let select = item as? ConversationAttachedReference {
                makeReferenceItemView(select)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
    
    @ViewBuilder
    func makeCurrentEditorView(_ ref: ConversationFileReference) -> some View {
        let toggleTrailingPadding: CGFloat = {
            if #available(macOS 26.0, *) {
                return 8
            } else {
                return 4
            }
        }()
        
        HStack(alignment: .center, spacing: 0) {
            makeContextFileNameView(url: ref.url, isCurrentEditor: true, selection: ref.selection)
            
            Toggle("", isOn: $isCurrentEditorContextEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
                .controlSize(.mini)
                .frame(width: 34)
                .padding(.trailing, toggleTrailingPadding)
                .onChange(of: isCurrentEditorContextEnabled) { newValue in
                    enableCurrentEditorContext = newValue
                }
        }
        .chatContextReferenceStyle(isCurrentEditor: true, r: r)
    }
    
    @ViewBuilder
    func makeReferenceItemView(_ ref: ConversationAttachedReference) -> some View {
        HStack(spacing: 0) {
            makeContextFileNameView(url: ref.url, isCurrentEditor: false, isDirectory: ref.isDirectory)
            
            Button(action: { chat.send(.removeReference(ref)) }) {
                Image(systemName: "xmark")
                    .resizable()
                    .scaledFrame(width: 8, height: 8)
                    .foregroundColor(.primary.opacity(0.85))
                    .padding(4)
            }
            .buttonStyle(HoverButtonStyle())
        }
        .chatContextReferenceStyle(isCurrentEditor: false, r: r)
    }
    
    @ViewBuilder
    func makeContextFileNameView(
        url: URL,
        isCurrentEditor: Bool,
        isDirectory: Bool = false,
        selection: LSPRange? = nil
    ) -> some View {
        drawFileIcon(url, isDirectory: isDirectory)
            .scaledToFit()
            .scaledFrame(width: 16, height: 16)
            .foregroundColor(.primary.opacity(0.85))
            .padding(4)
            .opacity(isCurrentEditor && !isCurrentEditorContextEnabled ? 0.4 : 1.0)
        
        HStack(spacing: 0) {
            Text(url.lastPathComponent)
            
            Group {
                if isCurrentEditor, let selection {
                    let startLine = selection.start.line
                    let endLine = selection.end.line
                    if startLine == endLine {
                        Text(String(format: ":%d", selection.start.line + 1))
                    } else {
                        Text(String(format: ":%d-%d", selection.start.line + 1, selection.end.line + 1))
                    }
                }
            }
            .foregroundColor(.secondary)
        }
        .lineLimit(1)
        .truncationMode(.middle)
        .foregroundColor(
            isCurrentEditor && !isCurrentEditorContextEnabled
            ? .secondary
            : .primary.opacity(0.85)
        )
        .scaledFont(.body)
        .opacity(isCurrentEditor && !isCurrentEditorContextEnabled ? 0.4 : 1.0)
        .help(url.getPathRelativeToHome())
    }
    
    func chatTemplateCompletion(text: String) async -> [ChatTemplate] {
        guard text.count >= 1 && text.first == "/" else { return [] }
        
        let prefix = String(text.dropFirst()).lowercased()
        let promptTemplates: [ChatTemplate] = await SharedChatService.shared.loadChatTemplates() ?? []
        let releaseNotesTemplate: ChatTemplate = .init(
            id: "releaseNotes",
            description: "What's New",
            shortDescription: "What's New",
            scopes: [.chatPanel, .agentPanel]
        )
        
        let templates = promptTemplates + [releaseNotesTemplate]
        let skippedTemplates = [ "feedback", "help" ]
        
        return templates.filter {
            $0.scopes.contains(chat.isAgentMode ? .agentPanel : .chatPanel) &&
            $0.id.lowercased().hasPrefix(prefix) &&
            !skippedTemplates.contains($0.id)
        }
    }
    
    func chatAgentCompletion(text: String) async -> [ChatAgent] {
        guard text.count >= 1 && text.first == "@" else { return [] }
        let prefix = text.dropFirst()
        var chatAgents = await SharedChatService.shared.loadChatAgents() ?? []
        
        if let index = chatAgents.firstIndex(where: { $0.slug == "project" }) {
            let projectAgent = chatAgents[index]
            chatAgents[index] = .init(slug: "workspace", name: "workspace", description: "Ask about your workspace", avatarUrl: projectAgent.avatarUrl)
        }
        
        /// only enable the @workspace
        let includedAgents = ["workspace"]
        
        return chatAgents.filter { $0.slug.hasPrefix(prefix) && includedAgents.contains($0.slug) }
    }
    
    func subscribeToActiveDocumentChangeEvent() {
        var task: Task<Void, Error>?
        var currentFocusedEditor: SourceEditor?
        
        Publishers.CombineLatest3(
            XcodeInspector.shared.$latestActiveXcode,
            XcodeInspector.shared.$activeDocumentURL
                .removeDuplicates(),
            XcodeInspector.shared.$focusedEditor
                .removeDuplicates()
        )
        .receive(on: DispatchQueue.main)
        .sink { newXcode, newDocURL, newFocusedEditor in
            var currentEditor: ConversationFileReference?
            
            // First check for realtimeWorkspaceURL if activeWorkspaceURL is nil
            if let realtimeURL = newXcode?.realtimeDocumentURL, newDocURL == nil {
                if supportedFileExtensions.contains(realtimeURL.pathExtension) {
                    currentEditor = ConversationFileReference(url: realtimeURL, isCurrentEditor: true)
                }
            } else if let docURL = newDocURL, supportedFileExtensions.contains(newDocURL?.pathExtension ?? "") {
                currentEditor = ConversationFileReference(url: docURL, isCurrentEditor: true)
            }
            
            if var currentEditor = currentEditor {
                if let selection = newFocusedEditor?.getContent().selections.first,
                   selection.start != selection.end {
                    currentEditor.selection = .init(start: selection.start, end: selection.end)
                }
                
                chat.send(.setCurrentEditor(currentEditor))
            }
            
            if currentFocusedEditor != newFocusedEditor {
                task?.cancel()
                task = nil
                currentFocusedEditor = newFocusedEditor
                
                if let editor = currentFocusedEditor {
                    task = Task { @MainActor in
                        for await _ in await editor.axNotifications.notifications()
                            .filter({ $0.kind == .selectedTextChanged }) {
                            handleSourceEditorSelectionChanged(editor)
                        }
                    }
                }
            }
        }
        .store(in: &cancellable)
    }
    
    private func handleSourceEditorSelectionChanged(_ sourceEditor: SourceEditor) {
        guard let fileURL = sourceEditor.realtimeDocumentURL,
              let currentEditorURL = chat.currentEditor?.url,
              fileURL == currentEditorURL
        else {
            return
        }
        
        var currentEditor: ConversationFileReference = .init(url: fileURL, isCurrentEditor: true)
        
        if let selection = sourceEditor.getContent().selections.first,
           selection.start != selection.end {
            currentEditor.selection = .init(start: selection.start, end: selection.end)
        }
        
        chat.send(.setCurrentEditor(currentEditor))
    }
    
    func submitChatMessage() {
        chat.send(.sendButtonTapped(UUID().uuidString))
    }
}
