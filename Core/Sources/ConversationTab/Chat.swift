import ChatService
import ComposableArchitecture
import Foundation
import ChatAPIService
import Preferences
import Terminal
import ConversationServiceProvider
import Persist
import GitHubCopilotService
import Logger
import OrderedCollections
import SwiftUI
import GitHelper
import SuggestionBasic

public struct DisplayedChatMessage: Equatable {
    public enum Role: Equatable {
        case user
        case assistant
        case ignored
    }

    public var id: String
    public var role: Role
    public var text: String
    public var imageReferences: [ImageReference] = []
    public var references: [ConversationReference] = []
    public var followUp: ConversationFollowUp? = nil
    public var suggestedTitle: String? = nil
    public var errorMessages: [String] = []
    public var steps: [ConversationProgressStep] = []
    public var editAgentRounds: [AgentRound] = []
    public var parentTurnId: String? = nil
    public var panelMessages: [CopilotShowMessageParams] = []
    public var codeReviewRound: CodeReviewRound? = nil
    public var fileEdits: [FileEdit] = []
    public var turnStatus: ChatMessage.TurnStatus? = nil
    public let requestType: RequestType
    public var modelName: String? = nil
    public var billingMultiplier: Float? = nil

    public init(
        id: String,
        role: Role,
        text: String,
        imageReferences: [ImageReference] = [],
        references: [ConversationReference] = [],
        followUp: ConversationFollowUp? = nil,
        suggestedTitle: String? = nil,
        errorMessages: [String] = [],
        steps: [ConversationProgressStep] = [],
        editAgentRounds: [AgentRound] = [],
        parentTurnId: String? = nil,
        panelMessages: [CopilotShowMessageParams] = [],
        codeReviewRound: CodeReviewRound? = nil,
        fileEdits: [FileEdit] = [],
        turnStatus: ChatMessage.TurnStatus? = nil,
        requestType: RequestType,
        modelName: String? = nil,
        billingMultiplier: Float? = nil
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.imageReferences = imageReferences
        self.references = references
        self.followUp = followUp
        self.suggestedTitle = suggestedTitle
        self.errorMessages = errorMessages
        self.steps = steps
        self.editAgentRounds = editAgentRounds
        self.parentTurnId = parentTurnId
        self.panelMessages = panelMessages
        self.codeReviewRound = codeReviewRound
        self.fileEdits = fileEdits
        self.turnStatus = turnStatus
        self.requestType = requestType
        self.modelName = modelName
        self.billingMultiplier = billingMultiplier
    }
}

private var isPreview: Bool {
    ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
}

struct ChatContext: Equatable {
    var typedMessage: String
    var attachedReferences: [ConversationAttachedReference]
    var attachedImages: [ImageReference]
    
    init(typedMessage: String, attachedReferences: [ConversationAttachedReference] = [], attachedImages: [ImageReference] = []) {
        self.typedMessage = typedMessage
        self.attachedReferences = attachedReferences
        self.attachedImages = attachedImages
    }
    
    static func empty() -> ChatContext {
        .init(typedMessage: "", attachedReferences: [], attachedImages: [])
    }
    
    static func from(_ message: DisplayedChatMessage, projectURL: URL) -> ChatContext {
        .init(
            typedMessage: message.text, 
            attachedReferences: message.references.compactMap {
                guard let url = $0.url else { return nil }
                if $0.isDirectory {
                    return .directory(.init(url: url))
                } else {
                    let relativePath = url.path.replacingOccurrences(of: projectURL.path, with: "")
                    let fileName = url.lastPathComponent
                    return .file(.init(url: url, relativePath: relativePath, fileName: fileName))
                }
            }, 
            attachedImages: message.imageReferences)
    }
}

struct ChatContextProvider: Equatable {
    var contextStack: [ChatContext]
    
    init(contextStack: [ChatContext] = []) {
        self.contextStack = contextStack
    }
    
    mutating func reset() {
        contextStack = []
    }
    
    mutating func getNextContext() -> ChatContext? { 
        guard !contextStack.isEmpty else {
            return nil
        }
        
        return contextStack.removeLast()
    }
    
    func getPreviousContext(from history: [DisplayedChatMessage], projectURL: URL) -> ChatContext? {
        let previousUserMessage: DisplayedChatMessage? = {
            let userMessages = history.filter { $0.role == .user }
            guard !userMessages.isEmpty else {
                return nil
            }
            
            let stackCount = contextStack.count
            guard userMessages.count > stackCount else {
                return nil
            }
            
            let index = userMessages.count - stackCount - 1
            guard index >= 0 else { return nil }
            
            return userMessages[index]
        }()
        
        var context: ChatContext?
        if let previousUserMessage {
            context = .from(previousUserMessage, projectURL: projectURL)
        }
        
        return context
    }
    
    mutating func pushContext(_ context: ChatContext) { 
        contextStack.append(context) 
    }
}

@Reducer
struct Chat {
    public typealias MessageID = String
    public enum EditorMode: Hashable {
        case input // Default input mode
        case editUserMessage(MessageID)
        
        var isDefault: Bool { self == .input }
        
        var isEditingUserMessage: Bool {
            switch self {
            case .input: false
            case .editUserMessage: true
            }
        }
        
        var editingUserMessageId: String? {
            switch self {
            case .input: nil
            case .editUserMessage(let messageID): messageID
            }
        }
    }

    @ObservableState
    struct EditorState: Equatable {
        enum Field: String, Hashable {
            case textField
            case fileSearchBar
        }
        
        var codeReviewState = ConversationCodeReviewFeature.State()

        var mode: EditorMode
        var contexts: [EditorMode: ChatContext]
        var contextProvider: ChatContextProvider
        var focusedField: Field?
        var currentEditor: ConversationFileReference?
        var handOffClicked: Bool = false

        init(
            mode: EditorMode = .input,
            contexts: [EditorMode: ChatContext] = [.input: .empty()],
            contextProvider: ChatContextProvider = .init(),
            focusedField: Field? = nil,
            currentEditor: ConversationFileReference? = nil,
            handOffClicked: Bool = false
        ) {
            self.mode = mode
            self.contexts = contexts
            self.contextProvider = contextProvider
            self.focusedField = focusedField
            self.currentEditor = currentEditor
            self.handOffClicked = handOffClicked
        }

        func context(for mode: EditorMode) -> ChatContext {
            contexts[mode] ?? .empty()
        }

        mutating func setContext(_ context: ChatContext, for mode: EditorMode) {
            contexts[mode] = context
        }

        mutating func updateCurrentContext(_ update: (inout ChatContext) -> Void) {
            var context = self.context(for: mode)
            update(&context)
            setContext(context, for: mode)
        }

        mutating func keepOnlyInputContext() {
            let inputContext = context(for: .input)
            contexts = [.input: inputContext]
        }

        mutating func clearAttachedImages() {
            updateCurrentContext { $0.attachedImages.removeAll() }
        }

        mutating func addReference(_ reference: ConversationAttachedReference) {
            updateCurrentContext { context in
                guard !context.attachedReferences.contains(reference) else { return }
                context.attachedReferences.append(reference)
            }
        }

        mutating func removeReference(_ reference: ConversationAttachedReference) {
            updateCurrentContext { context in
                guard let index = context.attachedReferences.firstIndex(of: reference) else { return }
                context.attachedReferences.remove(at: index)
            }
        }

        mutating func addImage(_ image: ImageReference) {
            updateCurrentContext { context in
                guard !context.attachedImages.contains(image) else { return }
                context.attachedImages.append(image)
            }
        }

        mutating func removeImage(_ image: ImageReference) {
            updateCurrentContext { context in
                guard let index = context.attachedImages.firstIndex(of: image) else { return }
                context.attachedImages.remove(at: index)
            }
        }

        mutating func pushContext(_ context: ChatContext) {
            contextProvider.pushContext(context)
        }

        mutating func resetContextProvider() {
            contextProvider.reset()
        }

        mutating func popNextContext() -> ChatContext? {
            contextProvider.getNextContext()
        }

        func previousContext(from history: [DisplayedChatMessage], projectURL: URL) -> ChatContext? {
            contextProvider.getPreviousContext(from: history, projectURL: projectURL)
        }
    }

    @ObservableState
    struct ConversationState: Equatable {
        var history: [DisplayedChatMessage]
        var isReceivingMessage: Bool
        var requestType: RequestType?

        init(
            history: [DisplayedChatMessage] = [],
            isReceivingMessage: Bool = false,
            requestType: RequestType? = nil
        ) {
            self.history = history
            self.isReceivingMessage = isReceivingMessage
            self.requestType = requestType
        }

        func subsequentMessages(after messageId: MessageID) -> [DisplayedChatMessage] {
            guard let index = history.firstIndex(where: { $0.id == messageId }) else {
                return []
            }
            return Array(history[(index + 1)...])
        }

        func editUserMessageEffectedMessages(for mode: EditorMode) -> [DisplayedChatMessage] {
            guard case .editUserMessage(let messageId) = mode else {
                return []
            }
            return subsequentMessages(after: messageId)
        }
    }

    struct AgentEditingState: Equatable {
        var fileEditMap: OrderedDictionary<URL, FileEdit>
        var diffViewerController: DiffViewWindowController?

        init(
            fileEditMap: OrderedDictionary<URL, FileEdit> = [:],
            diffViewerController: DiffViewWindowController? = nil
        ) {
            self.fileEditMap = fileEditMap
            self.diffViewerController = diffViewerController
        }

        static func == (lhs: AgentEditingState, rhs: AgentEditingState) -> Bool {
            lhs.fileEditMap == rhs.fileEditMap && lhs.diffViewerController === rhs.diffViewerController
        }
    }

    struct EnvironmentState: Equatable {
        var isAgentMode: Bool
        var workspaceURL: URL?
        var selectedAgent: ConversationMode

        init(
            isAgentMode: Bool = AppState.shared.isAgentModeEnabled(),
            workspaceURL: URL? = nil,
            selectedAgent: ConversationMode = .defaultAgent
        ) {
            self.isAgentMode = isAgentMode
            self.workspaceURL = workspaceURL
            self.selectedAgent = selectedAgent
        }
    }

    @ObservableState
    struct State: Equatable {
        typealias Field = EditorState.Field

        // Not use anymore. the title of history tab will get from chat tab info
        // Keep this var as `ChatTabItemView` reference this
        var title: String
        var editor: EditorState
        var conversation: ConversationState
        var agentEditing: AgentEditingState
        var environment: EnvironmentState
        var chatMenu: ChatMenu.State
        var codeReviewState: ConversationCodeReviewFeature.State

        init(
            title: String = "New Chat",
            editor: EditorState = .init(),
            conversation: ConversationState = .init(),
            agentEditing: AgentEditingState = .init(),
            environment: EnvironmentState = .init(),
            chatMenu: ChatMenu.State = .init(),
            codeReviewState: ConversationCodeReviewFeature.State = .init()
        ) {
            self.title = title
            self.editor = editor
            self.conversation = conversation
            self.agentEditing = agentEditing
            self.environment = environment
            self.chatMenu = chatMenu
            self.codeReviewState = codeReviewState
        }

        init(
            title: String = "New Chat",
            editorMode: EditorMode = .input,
            editorModeContexts: [EditorMode: ChatContext] = [.input: .empty()],
            focusedField: Field? = nil,
            history: [DisplayedChatMessage] = [],
            isReceivingMessage: Bool = false,
            requestType: RequestType? = nil,
            fileEditMap: OrderedDictionary<URL, FileEdit> = [:],
            diffViewerController: DiffViewWindowController? = nil,
            isAgentMode: Bool = AppState.shared.isAgentModeEnabled(),
            workspaceURL: URL? = nil,
            selectedAgent: ConversationMode = .defaultAgent,
            chatMenu: ChatMenu.State = .init(),
            codeReviewState: ConversationCodeReviewFeature.State = .init()
        ) {
            self.init(
                title: title,
                editor: EditorState(
                    mode: editorMode,
                    contexts: editorModeContexts,
                    focusedField: focusedField
                ),
                conversation: ConversationState(
                    history: history,
                    isReceivingMessage: isReceivingMessage,
                    requestType: requestType
                ),
                agentEditing: AgentEditingState(
                    fileEditMap: fileEditMap,
                    diffViewerController: diffViewerController
                ),
                environment: EnvironmentState(
                    isAgentMode: isAgentMode,
                    workspaceURL: workspaceURL,
                    selectedAgent: selectedAgent
                ),
                chatMenu: chatMenu,
                codeReviewState: codeReviewState
            )
        }

        var editorMode: EditorMode {
            get { editor.mode }
            set {
                editor.mode = newValue
                if editor.contexts[newValue] == nil {
                    editor.contexts[newValue] = .empty()
                }
            }
        }

        var chatContext: ChatContext {
            get { editor.context(for: editor.mode) }
            set { editor.setContext(newValue, for: editor.mode) }
        }

        var history: [DisplayedChatMessage] {
            get { conversation.history }
            set { conversation.history = newValue }
        }

        var isReceivingMessage: Bool {
            get { conversation.isReceivingMessage }
            set { conversation.isReceivingMessage = newValue }
        }

        var requestType: RequestType? {
            get { conversation.requestType }
            set { conversation.requestType = newValue }
        }

        var handOffClicked: Bool {
            get { editor.handOffClicked }
            set { editor.handOffClicked = newValue }
        }

        var focusedField: Field? {
            get { editor.focusedField }
            set { editor.focusedField = newValue }
        }

        var currentEditor: ConversationFileReference? {
            get { editor.currentEditor }
            set { editor.currentEditor = newValue }
        }

        var attachedReferences: [ConversationAttachedReference] {
            chatContext.attachedReferences
        }

        var attachedImages: [ImageReference] {
            chatContext.attachedImages
        }

        var typedMessage: String {
            get { chatContext.typedMessage }
            set {
                editor.updateCurrentContext { $0.typedMessage = newValue }
                editor.resetContextProvider()
            }
        }

        var fileEditMap: OrderedDictionary<URL, FileEdit> {
            get { agentEditing.fileEditMap }
            set { agentEditing.fileEditMap = newValue }
        }

        var diffViewerController: DiffViewWindowController? {
            get { agentEditing.diffViewerController }
            set { agentEditing.diffViewerController = newValue }
        }

        var isAgentMode: Bool {
            get { environment.isAgentMode }
            set { environment.isAgentMode = newValue }
        }

        var workspaceURL: URL? {
            get { environment.workspaceURL }
            set { environment.workspaceURL = newValue }
        }

        var selectedAgent: ConversationMode {
            get { environment.selectedAgent }
            set { environment.selectedAgent = newValue }
        }

        /// Not including the one being edited
        var editUserMessageEffectedMessages: [DisplayedChatMessage] {
            conversation.editUserMessageEffectedMessages(for: editor.mode)
        }
        
        // The following messages after check point message will hide on ChatPanel
        var pendingCheckpointMessageId: String? = nil
        // The chat context before the first restoring
        var pendingCheckpointContext: ChatContext? = nil
        var messagesAfterCheckpoint: [DisplayedChatMessage] {
            guard let pendingCheckpointMessageId, let index = history.firstIndex(where: { $0.id == pendingCheckpointMessageId }) else {
                return []
            }
            
            let nextIndex = index + 1
            guard nextIndex < history.count else {
                return []
            }
            
            // The order matters for restoring / redoing file edits
            return Array(history[nextIndex...])
        }
        
        func getMessages(after afterMessageId: String, through throughMessageId: String?) -> [DisplayedChatMessage] {
            guard let afterMessageIdIndex = history.firstIndex(where: { $0.id == afterMessageId }) else {
                return []
            }
            
            let startIndex = afterMessageIdIndex + 1
            
            let endIndex: Int
            if let throughMessageId = throughMessageId,
               let throughMessageIdIndex = history.firstIndex(where: { $0.id == throughMessageId }) {
                endIndex = throughMessageIdIndex + 1
            } else {
                endIndex = history.count
            }
            
            guard startIndex < endIndex, startIndex < history.count else {
                return []
            }
            
            return Array(history[startIndex..<endIndex])
        }
    }

    enum Action: Equatable, BindableAction {
        case binding(BindingAction<State>)

        case appear
        case refresh
        case sendButtonTapped(String)
        case returnButtonTapped
        case updateTypedMessage(String)
        case setEditorMode(EditorMode)
        case stopRespondingButtonTapped
        case clearButtonTap
        case deleteMessageButtonTapped(MessageID)
        case resendMessageButtonTapped(MessageID)
        case setAsExtraPromptButtonTapped(MessageID)
        case focusOnTextField
        case referenceClicked(ConversationReference)
        case upvote(MessageID, ConversationRating)
        case downvote(MessageID, ConversationRating)
        case copyCode(MessageID)
        case insertCode(String)
        case toolCallAccepted(String)
        case toolCallCompleted(String, String)
        case toolCallCancelled(String)

        case observeChatService
        case observeHistoryChange
        case observeIsReceivingMessageChange
        case observeFileEditChange

        case historyChanged
        case isReceivingMessageChanged
        case fileEditChanged

        case chatMenu(ChatMenu.Action)
        
        // File context
        case resetCurrentEditor
        case setCurrentEditor(ConversationFileReference)
        case addReference(ConversationAttachedReference)
        case removeReference(ConversationAttachedReference)
        
        // Image context
        case addSelectedImage(ImageReference)
        case removeSelectedImage(ImageReference)
        
        case followUpButtonClicked(String, String)
        case handOffButtonClicked(HandOff)
        
        // Agent File Edit
        case undoEdits(fileURLs: [URL])
        case keepEdits(fileURLs: [URL])
        case resetEdits
        case discardFileEdits(fileURLs: [URL])
        case openDiffViewWindow(fileURL: URL)
        case setDiffViewerController(chat: StoreOf<Chat>)

        case agentModeChanged(Bool)
        case selectedAgentChanged(ConversationMode)
        
        // Code Review
        case codeReview(ConversationCodeReviewFeature.Action)
        
        // Chat Context
        case reloadNextContext
        case reloadPreviousContext
        case resetContextProvider

        // External Action
        case observeFixErrorNotification
        case fixEditorErrorIssue(EditorErrorIssue)
        
        // Check Point
        case restoreCheckPoint(String)
        case restoreFileEdits
        case undoCheckPoint // Revert the restore
        case discardCheckPoint
        case reloadWorkingset(DisplayedChatMessage)
    }

    let service: ChatService
    let id = UUID()

    enum CancelID: Hashable {
        case observeHistoryChange(UUID)
        case observeIsReceivingMessageChange(UUID)
        case sendMessage(UUID)
        case observeFileEditChange(UUID)
        case observeFixErrorNotification(UUID)
    }

    @Dependency(\.openURL) var openURL
    @AppStorage(\.enableCurrentEditorContext) var enableCurrentEditorContext: Bool
    @AppStorage(\.chatResponseLocale) var chatResponseLocale

    var body: some ReducerOf<Self> {
        BindingReducer()

        Scope(state: \.chatMenu, action: /Action.chatMenu) {
            ChatMenu(service: service)
        }
        
        Scope(state: \.codeReviewState, action: /Action.codeReview) {
            ConversationCodeReviewFeature(service: service)
        }

        Reduce { state, action in
            switch action {
            case .appear:
                return .run { send in
                    if isPreview { return }
                    await send(.observeChatService)
                    await send(.historyChanged)
                    await send(.isReceivingMessageChanged)
                    await send(.focusOnTextField)
                    await send(.refresh)
                    await send(.observeFixErrorNotification)

                    let selectedAgentSubModeId = AppState.shared.getSelectedAgentSubMode()
                    if let modes = await SharedChatService.shared.loadConversationModes(),
                       let currentMode = modes.first(where: { $0.id == selectedAgentSubModeId }) {
                        await send(.selectedAgentChanged(currentMode))
                    }

                    let publisher = NotificationCenter.default.publisher(for: .gitHubCopilotChatModeDidChange)
                    for await _ in publisher.values {
                        let isAgentMode = AppState.shared.isAgentModeEnabled()
                        await send(.agentModeChanged(isAgentMode))

                        let selectedAgentSubModeId = AppState.shared.getSelectedAgentSubMode()
                        if let modes = await SharedChatService.shared.loadConversationModes(),
                           let currentMode = modes.first(where: { $0.id == selectedAgentSubModeId }) {
                            await send(.selectedAgentChanged(currentMode))
                        }
                    }
                }

            case .refresh:
                return .run { send in
                    await send(.chatMenu(.refresh))
                }

            case let .sendButtonTapped(id):
                guard !state.typedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .none }
                let message = state.typedMessage
                let skillSet = state.buildSkillSet(
                    isCurrentEditorContextEnabled: enableCurrentEditorContext
                )
                state.typedMessage = ""
                
                let selectedModel = AppState.shared.getSelectedModel()
                let selectedModelFamily = selectedModel?.modelFamily ?? CopilotModelManager.getDefaultChatModel(
                    scope: AppState.shared.modelScope()
                )?.modelFamily
                let agentMode = AppState.shared.isAgentModeEnabled()
                let selectedAgentSubMode = AppState.shared.getSelectedAgentSubMode()
                let shouldAttachImages = selectedModel?.supportVision ?? CopilotModelManager.getDefaultChatModel(
                    scope: AppState.shared.modelScope()
                )?.supportVision ?? false
                let attachedImages: [ImageReference] = shouldAttachImages ? state.attachedImages : []

                let references = state.attachedReferences
                state.editor.clearAttachedImages()
                
                let toDeleteMessageIds: [String] = {
                    var messageIds: [String] = []
                    if state.editorMode.isEditingUserMessage {
                        messageIds.append(contentsOf: state.editUserMessageEffectedMessages.map { $0.id })
                        if let editingUserMessageId = state.editorMode.editingUserMessageId {
                            messageIds.append(editingUserMessageId)
                        }
                    }
                    return messageIds
                }()
                
                return .run { send in
                    await send(.resetContextProvider)
                    await send(.discardCheckPoint)
                    await service.deleteMessages(ids: toDeleteMessageIds)
                    await send(.setEditorMode(.input))
                    
                    try await service
                        .send(
                            id,
                            content: message,
                            contentImageReferences: attachedImages,
                            skillSet: skillSet,
                            references: references,
                            model: selectedModelFamily,
                            modelProviderName: selectedModel?.providerName,
                            agentMode: agentMode,
                            customChatModeId: selectedAgentSubMode,
                            userLanguage: chatResponseLocale
                        )
                }.cancellable(id: CancelID.sendMessage(self.id))
            
            case let .toolCallAccepted(toolCallId):
                guard !toolCallId.isEmpty else { return .none }
                return .run { _ in
                    service.updateToolCallStatus(toolCallId: toolCallId, status: .accepted)
                }.cancellable(id: CancelID.sendMessage(self.id))
            case let .toolCallCancelled(toolCallId):
                guard !toolCallId.isEmpty else { return .none }
                return .run { _ in
                    service.updateToolCallStatus(toolCallId: toolCallId, status: .cancelled)
                }.cancellable(id: CancelID.sendMessage(self.id))
            case let .toolCallCompleted(toolCallId, result):
                guard !toolCallId.isEmpty else { return .none }
                return .run { _ in
                    service.updateToolCallStatus(toolCallId: toolCallId, status: .completed, payload: result)
                }.cancellable(id: CancelID.sendMessage(self.id))
                
            case let .followUpButtonClicked(id, message):
                guard !message.isEmpty else { return .none }
                let skillSet = state.buildSkillSet(
                    isCurrentEditorContextEnabled: enableCurrentEditorContext
                )
                
                let selectedModel = AppState.shared.getSelectedModel()
                let selectedModelFamily = selectedModel?.modelFamily ?? CopilotModelManager.getDefaultChatModel(
                    scope: AppState.shared.modelScope()
                )?.modelFamily
                let references = state.attachedReferences
                let agentMode = AppState.shared.isAgentModeEnabled()
                let selectedAgentSubMode = AppState.shared.getSelectedAgentSubMode()
                
                return .run { send in
                    await send(.resetContextProvider)
                    await send(.discardCheckPoint)

                    try await service
                        .send(
                            id,
                            content: message,
                            skillSet: skillSet,
                            references: references,
                            model: selectedModelFamily,
                            modelProviderName: selectedModel?.providerName,
                            agentMode: agentMode,
                            customChatModeId: selectedAgentSubMode,
                            userLanguage: chatResponseLocale
                        )
                }.cancellable(id: CancelID.sendMessage(self.id))
            
            case let .handOffButtonClicked(handOff):
                state.handOffClicked = true
                let agent = handOff.agent
                let prompt = handOff.prompt
                let shouldSend = handOff.send ?? false
                
                return .run { send in
                    // Find and switch to the target agent
                    let modes = await SharedChatService.shared.loadConversationModes() ?? []
                    if let targetAgent = modes.first(where: { $0.name.lowercased() == agent.lowercased() }) {
                        await send(.selectedAgentChanged(targetAgent))
                    }
                    
                    // If send is true, send the prompt message
                    if shouldSend && !prompt.isEmpty {
                        await send(.updateTypedMessage(prompt))
                        let id = UUID().uuidString
                        await send(.sendButtonTapped(id))
                    } else if !prompt.isEmpty {
                        // Just populate the message field
                        await send(.updateTypedMessage(prompt))
                    }
                }

            case .returnButtonTapped:
                state.typedMessage += "\n"
                return .none
                
            case let .updateTypedMessage(message):
                state.typedMessage = message
                return .none
                
            case let .setEditorMode(mode):
                
                switch mode {
                case .input:
                    state.editorMode = mode
                    // remove all edit contexts except input mode
                    state.editor.keepOnlyInputContext()
                case .editUserMessage(let messageID):
                    guard let message = state.history.first(where: { $0.id == messageID }),
                          message.role == .user,
                          let projectURL = service.getProjectRootURL()
                    else {
                        return .none
                    }
                    
                    let chatContext: ChatContext = .from(message, projectURL: projectURL)
                    state.editor.setContext(chatContext, for: mode)
                    state.editorMode = mode
                    let isReceivingMessage = service.isReceivingMessage
                    
                    return .run { send in
                        if isReceivingMessage {
                            await send(.stopRespondingButtonTapped)
                        }
                    }
                }
                
                return .none

            case .stopRespondingButtonTapped:
                return .merge(
                    .run { _ in
                        await service.stopReceivingMessage()
                    },
                    .cancel(id: CancelID.sendMessage(id))
                )

            case .clearButtonTap:
                return .run { _ in
                    await service.clearHistory()
                }

            case let .deleteMessageButtonTapped(id):
                return .run { _ in
                    await service.deleteMessages(ids: [id])
                }

            case let .resendMessageButtonTapped(id):
                return .run { _ in
                    try await service.resendMessage(id: id)
                }

            case let .setAsExtraPromptButtonTapped(id):
                return .run { _ in
                    await service.setMessageAsExtraPrompt(id: id)
                }

            case let .referenceClicked(reference):
                guard let fileURL = reference.url else {
                    return .none
                }
                return .run { _ in
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        let terminal = Terminal()
                        do {
                            _ = try await terminal.runCommand(
                                "/bin/bash",
                                arguments: [
                                    "-c",
                                    "xed -l 0 \"${TARGET_CHAT_FILE}\"",
                                ],
                                environment: [
                                    "TARGET_CHAT_FILE": reference.filePath
                                ]
                            )
                        } catch {
                            print(error)
                        }
                    } else if let url = URL(string: reference.uri), url.scheme != nil {
                        await openURL(url)
                    }
                }

            case .focusOnTextField:
                state.focusedField = .textField
                return .none

            case .observeChatService:
                return .run { send in
                    await send(.observeHistoryChange)
                    await send(.observeIsReceivingMessageChange)
                    await send(.observeFileEditChange)
                }

            case .observeHistoryChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$chatHistory.sink { _ in
                            continuation.yield()
                        }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    let debouncedHistoryChange = TimedDebounceFunction(duration: 0.2) {
                        await send(.historyChanged)
                    }
                    
                    for await _ in stream {
                        await debouncedHistoryChange()
                    }
                }.cancellable(id: CancelID.observeHistoryChange(id), cancelInFlight: true)

            case .observeIsReceivingMessageChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$isReceivingMessage
                            .sink { _ in
                                continuation.yield()
                            }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await _ in stream {
                        await send(.isReceivingMessageChanged)
                    }
                }.cancellable(
                    id: CancelID.observeIsReceivingMessageChange(id),
                    cancelInFlight: true
                )
                
            case .observeFileEditChange:
                return .run { send in
                    let stream = AsyncStream<Void> { continuation in
                        let cancellable = service.$fileEditMap
                            .sink { _ in
                                continuation.yield()
                            }
                        continuation.onTermination = { _ in
                            cancellable.cancel()
                        }
                    }
                    for await _ in stream {
                        await send(.fileEditChanged)
                    }
                }.cancellable(
                    id: CancelID.observeFileEditChange(id),
                    cancelInFlight: true
                )

            case .historyChanged:
                state.history = service.chatHistory.flatMap { message in
                    var all = [DisplayedChatMessage]()
                    all.append(.init(
                        id: message.id,
                        role: {
                            switch message.role {
                            case .user: return .user
                            case .assistant: return .assistant
                            case .system: return .ignored
                            }
                        }(),
                        text: message.content,
                        imageReferences: message.contentImageReferences,
                        references: message.references.map {
                            .init(
                                uri: $0.uri,
                                status: $0.status,
                                kind: $0.kind,
                                referenceType: $0.referenceType
                            )
                        },
                        followUp: message.followUp,
                        suggestedTitle: message.suggestedTitle,
                        errorMessages: message.errorMessages,
                        steps: message.steps,
                        editAgentRounds: message.editAgentRounds,
                        parentTurnId: message.parentTurnId,
                        panelMessages: message.panelMessages,
                        codeReviewRound: message.codeReviewRound,
                        fileEdits: message.fileEdits,
                        turnStatus: message.turnStatus,
                        requestType: message.requestType,
                        modelName: message.modelName,
                        billingMultiplier: message.billingMultiplier
                    ))

                    return all
                }
                
                return .none

            case .isReceivingMessageChanged:
                state.isReceivingMessage = service.isReceivingMessage
                state.requestType = service.requestType
                return .none
                
            case .fileEditChanged:
                state.fileEditMap = service.fileEditMap
                let fileEditMap = state.fileEditMap
                
                let diffViewerController = state.diffViewerController
                
                return .run { _ in
                    /// refresh diff view
                    
                    guard let diffViewerController,
                          diffViewerController.diffViewerState == .shown
                    else { return }
                    
                    if fileEditMap.isEmpty {
                        await diffViewerController.hideWindow()
                        return
                    }
                    
                    guard let currentFileEdit = diffViewerController.currentFileEdit
                    else { return }
                    
                    if let updatedFileEdit = fileEditMap[currentFileEdit.fileURL] {
                        if updatedFileEdit != currentFileEdit {
                            if updatedFileEdit.status == .undone,
                               updatedFileEdit.toolName == .createFile
                            {
                                await diffViewerController.hideWindow()
                            } else {
                                await diffViewerController.showDiffWindow(fileEdit: updatedFileEdit)
                            }
                        }
                    } else {
                        await diffViewerController.hideWindow()
                    }
                }

            case .binding:
                return .none

            case .chatMenu:
                return .none
            case let .upvote(id, rating):
                return .run { _ in
                    await service.upvote(id, rating)
                }
            case let .downvote(id, rating):
                return .run { _ in
                    await service.downvote(id, rating)
                }
            case let .copyCode(id):
                return .run { _ in
                    await service.copyCode(id)
                }
                
            case let .insertCode(code):
                 ChatInjector().insertCodeBlock(codeBlock: code)
                 return .none

            // MARK: - Context
            case .resetCurrentEditor:
                state.currentEditor = nil
                return .none
            case let .setCurrentEditor(fileReference):
                state.currentEditor = fileReference
                return .none
            case let .addReference(ref):
                state.editor.addReference(ref)
                return .none
                
            case let .removeReference(ref):
                state.editor.removeReference(ref)
                return .none
                
            // MARK: - Image Context
            case let .addSelectedImage(imageReference):
                guard !state.attachedImages.contains(imageReference) else { return .none }
                state.editor.addImage(imageReference)
                return .run { send in await send(.resetContextProvider) }
            case let .removeSelectedImage(imageReference):
                guard let _ = state.attachedImages.firstIndex(of: imageReference) else { return .none }
                state.editor.removeImage(imageReference)
                return .run { send in await send(.resetContextProvider) }
                
            // MARK: - Agent Edits
                
            case let .undoEdits(fileURLs):
                for fileURL in fileURLs {
                    do {
                        try service.undoFileEdit(for: fileURL)
                    } catch {
                        Logger.service.error("Failed to undo edit, \(error)")
                    }
                }
                
                return .none
                
            case let .keepEdits(fileURLs):
                for fileURL in fileURLs {
                    service.keepFileEdit(for: fileURL)
                }
                
                return .none
            
            case .resetEdits:
                service.resetFileEdits()
                
                return .none
                
            case let .discardFileEdits(fileURLs):
                for fileURL in fileURLs {
                    try? service.discardFileEdit(for: fileURL)
                }
                return .none
                
            case let .openDiffViewWindow(fileURL):
                guard let fileEdit = state.fileEditMap[fileURL],
                      let diffViewerController = state.diffViewerController
                else { return .none }
                
                return .run { _ in
                    await diffViewerController.showDiffWindow(fileEdit: fileEdit)
                }
                
            case let .setDiffViewerController(chat):
                state.diffViewerController = .init(chat: chat)
                return .none

            case let .agentModeChanged(isAgentMode):
                state.isAgentMode = isAgentMode
                return .none

            case let .selectedAgentChanged(mode):
                state.selectedAgent = mode
                state.handOffClicked = false
                return .none

            // MARK: - Code Review
            case let .codeReview(.request(group)):
                return .run { send in
                    await send(.discardCheckPoint)
                }
                
            case .codeReview:
                return .none
                
            // MARK: Chat Context
            case .reloadNextContext:
                guard let context = state.editor.popNextContext() else {
                    return .none
                }
                
                state.chatContext = context
                
                return .run { send in
                    await send(.focusOnTextField)
                }
                
            case .reloadPreviousContext:
                guard let projectURL = service.getProjectRootURL(),
                      let context = state.editor.previousContext(
                        from: state.history,
                        projectURL: projectURL) 
                else {
                    return .none
                }
                
                let currentContext = state.chatContext
                state.chatContext = context
                state.editor.pushContext(currentContext)
                
                return .run { send in
                    await send(.focusOnTextField)
                }
                
            case .resetContextProvider:
                state.editor.resetContextProvider()
                return .none

            // MARK: - External action
                
            case .observeFixErrorNotification:
                return .run { send in 
                    let publisher = NotificationCenter.default.publisher(for: .fixEditorErrorIssue)
                    
                    for await notification in publisher.values {
                        guard service.chatTabInfo.isSelected,
                              let issue = notification.userInfo?["editorErrorIssue"] as? EditorErrorIssue
                        else {
                            continue
                        }
                        
                        await send(.fixEditorErrorIssue(issue))
                    }
                }.cancellable(
                    id: CancelID.observeFixErrorNotification(id), 
                    cancelInFlight: true)
                
            case .fixEditorErrorIssue(let issue):
                guard issue.workspaceURL == service.getWorkspaceURL(),
                      !issue.lineAnnotations.isEmpty
                else {
                    return .none
                }
                
                guard !state.isReceivingMessage else {
                    return .run { _ in
                        await MainActor.run {
                            NotificationCenter.default.post(
                                name: .fixEditorErrorIssueError,
                                object: nil,
                                userInfo: ["error": FixEditorErrorIssueFailure.isReceivingMessage(id: issue.id)]
                            )
                        }
                    }
                }
                
                let errorAnnotationMessage: String = issue.lineAnnotations
                    .map { "❗\($0.originalAnnotation)" }
                    .joined(separator: "\n\n")
                let message = "Analyze and fix the following error(s): \n\n\(errorAnnotationMessage)"
                
                let skillSet = state.buildSkillSet(isCurrentEditorContextEnabled: enableCurrentEditorContext)
                let references: [ConversationAttachedReference] = [.file(.init(url: issue.fileURL))]
                let selectedModel = AppState.shared.getSelectedModel()
                let selectedModelFamily = selectedModel?.modelFamily ?? CopilotModelManager.getDefaultChatModel(
                    scope: AppState.shared.modelScope()
                )?.modelFamily
                let agentMode = AppState.shared.isAgentModeEnabled()
                // TODO: if we need to switch to agent mode or keep the current mode
                let selectedAgentSubMode = AppState.shared.getSelectedAgentSubMode()
                
                return .run { _ in 
                    try await service.send(
                        UUID().uuidString,
                        content: message,
                        skillSet: skillSet,
                        references: references,
                        model: selectedModelFamily,
                        modelProviderName: selectedModel?.providerName,
                        agentMode: agentMode,
                        customChatModeId: selectedAgentSubMode,
                        userLanguage: chatResponseLocale
                    )
                }.cancellable(id: CancelID.sendMessage(self.id))
                
            // MARK: - Check Point
            
            case let .restoreCheckPoint(messageId):
                guard let message = state.history.first(where: { $0.id == messageId }) else {
                    return .none
                }
                
                if state.pendingCheckpointContext == nil {
                    state.pendingCheckpointContext = state.chatContext
                }
                state.pendingCheckpointMessageId = messageId
                
                // Reload the chat context
                let messagesAfterCheckpoint = state.messagesAfterCheckpoint
                if !messagesAfterCheckpoint.isEmpty,
                   let userMessage = messagesAfterCheckpoint.first,
                   userMessage.role == .user,
                   let projectURL = service.getProjectRootURL()
                {
                    state.chatContext = .from(userMessage, projectURL: projectURL)
                }
                
                let isReceivingMessage = state.isReceivingMessage
                return .run { send in
                    await send(.restoreFileEdits)
                    await send(.reloadWorkingset(message))
                    if isReceivingMessage {
                        await send(.stopRespondingButtonTapped)
                    }
                }
                
            case .restoreFileEdits:
                // Revert file edits in messages after checkpoint
                let messagesAfterCheckpoint = state.messagesAfterCheckpoint
                guard !messagesAfterCheckpoint.isEmpty else {
                    return .none
                }
                
                return .run { _ in 
                    var restoredURLs = Set<URL>()
                    let fileManager = FileManager.default
                    
                    // Revert the file edit. From the oldest to newest
                    for message in messagesAfterCheckpoint {
                        let fileEdits = message.fileEdits
                        guard !fileEdits.isEmpty else {
                            continue
                        }
                        
                        for fileEdit in fileEdits {
                            guard !restoredURLs.contains(fileEdit.fileURL) else {
                                continue
                            }
                            restoredURLs.insert(fileEdit.fileURL)
                            
                            do {
                                switch fileEdit.toolName {
                                case .createFile:
                                    try fileManager.removeItem(at: fileEdit.fileURL)
                                case .insertEditIntoFile:
                                    try fileEdit.originalContent.write(to: fileEdit.fileURL, atomically: true, encoding: .utf8)
                                default:
                                    break
                                }
                            } catch {
                                Logger.client.error(">>> Failed to restore file Edit: \(error)")
                            }
                        }
                    }
                }
                
            case .undoCheckPoint:
                if let context = state.pendingCheckpointContext {
                    state.chatContext = context
                    state.pendingCheckpointContext = nil
                }
                let reversedMessagesAfterCheckpoint = Array(state.messagesAfterCheckpoint.reversed())
                
                state.pendingCheckpointMessageId = nil
                
                // Redo file edits in messages after checkpoint
                guard !reversedMessagesAfterCheckpoint.isEmpty else {
                    return .none
                }
                
                return .run { send in 
                    var redoedURL = Set<URL>()
                    let lastMessage = reversedMessagesAfterCheckpoint.first
                    
                    for message in reversedMessagesAfterCheckpoint {
                        let fileEdits = message.fileEdits
                        guard !fileEdits.isEmpty else {
                            continue
                        }
                        
                        for fileEdit in fileEdits {
                            guard !redoedURL.contains(fileEdit.fileURL) else {
                                continue
                            }
                            redoedURL.insert(fileEdit.fileURL)
                            
                            do {
                                switch fileEdit.toolName {
                                case .createFile, .insertEditIntoFile:
                                    try fileEdit.modifiedContent.write(to: fileEdit.fileURL, atomically: true, encoding: .utf8)
                                default:
                                    break
                                }
                            } catch {
                                Logger.client.error(">>> failed to undo fileEdit: \(error)")
                            }
                        }
                    }
                    
                    // Recover fileEdits working set
                    if let lastMessage {
                        await send(.reloadWorkingset(lastMessage))
                    }
                }
                
            case .discardCheckPoint:                
                let messagesAfterCheckpoint = state.messagesAfterCheckpoint
                state.pendingCheckpointMessageId = nil
                state.pendingCheckpointContext = nil
                return .run { _ in 
                    if !messagesAfterCheckpoint.isEmpty {
                        await service.deleteMessages(ids: messagesAfterCheckpoint.map { $0.id })
                    }
                }
                
            case let .reloadWorkingset(message):
                return .run { _ in 
                    service.resetFileEdits()
                    for fileEdit in message.fileEdits {
                        service.updateFileEdits(by: fileEdit)
                    }
                }
            }
        }
    }
}

@Reducer
struct ChatMenu {
    @ObservableState
    struct State: Equatable {
        var systemPrompt: String = ""
        var extraSystemPrompt: String = ""
        var temperatureOverride: Double? = nil
        var chatModelIdOverride: String? = nil
    }

    enum Action: Equatable {
        case appear
        case refresh
        case customCommandButtonTapped(CustomCommand)
    }

    let service: ChatService

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .appear:
                return .run {
                    await $0(.refresh)
                }

            case .refresh:
                return .none

            case let .customCommandButtonTapped(command):
                return .run { _ in
                    try await service.handleCustomCommand(command)
                }
            }
        }
    }
}

private actor TimedDebounceFunction {
    let duration: TimeInterval
    let block: () async -> Void

    var task: Task<Void, Error>?
    var lastFireTime: Date = .init(timeIntervalSince1970: 0)

    init(duration: TimeInterval, block: @escaping () async -> Void) {
        self.duration = duration
        self.block = block
    }

    func callAsFunction() async {
        task?.cancel()
        if lastFireTime.timeIntervalSinceNow < -duration {
            await fire()
            task = nil
        } else {
            task = Task.detached { [weak self, duration] in
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                await self?.fire()
            }
        }
    }
    
    func fire() async {
        lastFireTime = Date()
        await block()
    }
}

public struct EditorErrorIssue: Equatable {
    public let lineAnnotations: [EditorInformation.LineAnnotation]
    public let fileURL: URL
    public let workspaceURL: URL
    public let id: String
    
    public init(
        lineAnnotations: [EditorInformation.LineAnnotation], 
        fileURL: URL, 
        workspaceURL: URL,
        id: String
    ) {
        self.lineAnnotations = lineAnnotations
        self.fileURL = fileURL
        self.workspaceURL = workspaceURL
        self.id = id
    }
}

public enum FixEditorErrorIssueFailure: Equatable {
    case isReceivingMessage(id: String)
}

public extension Notification.Name {
    static let fixEditorErrorIssue = Notification.Name("com.github.CopilotForXcode.fixEditorErrorIssue")
    static let fixEditorErrorIssueError = Notification.Name("com.github.CopilotForXcode.fixEditorErrorIssueError")
}
