import ChatAPIService
import Combine
import Foundation
import GitHubCopilotService
import Preferences
import ConversationServiceProvider
import BuiltinExtension
import JSONRPC
import Status
import Persist
import PersistMiddleware
import ChatTab
import Logger
import Workspace
import XcodeInspector
import OrderedCollections
import SystemUtils
import GitHelper
import LanguageServerProtocol
import SuggestionBasic

public protocol ChatServiceType {
    var memory: ContextAwareAutoManagedChatMemory { get set }
    func send(
        _ id: String,
        content: String,
        contentImages: [ChatCompletionContentPartImage],
        contentImageReferences: [ImageReference],
        skillSet: [ConversationSkill],
        references: [ConversationAttachedReference],
        model: String?,
        modelProviderName: String?,
        agentMode: Bool,
        customChatModeId: String?,
        userLanguage: String?,
        turnId: String?
    ) async throws
    func stopReceivingMessage() async
    func upvote(_ id: String, _ rating: ConversationRating) async
    func downvote(_ id: String, _ rating: ConversationRating) async
    func copyCode(_ id: String) async
}

struct ToolCallRequest {
    let requestId: JSONId
    let turnId: String
    let roundId: Int
    let toolCallId: String
    let completion: (AnyJSONRPCResponse) -> Void
}

struct ConversationTurnTrackingState {
    var turnParentMap: [String: String] = [:] // Maps subturn ID to parent turn ID
    var validConversationIds: Set<String> = [] // Tracks all valid conversation IDs including subagents
    
    mutating func reset() {
        turnParentMap.removeAll()
        validConversationIds.removeAll()
    }
}

public final class ChatService: ChatServiceType, ObservableObject {
    
    public var memory: ContextAwareAutoManagedChatMemory
    @Published public internal(set) var chatHistory: [ChatMessage] = []
    @Published public internal(set) var isReceivingMessage = false
    @Published public internal(set) var fileEditMap: OrderedDictionary<URL, FileEdit> = [:]
    public internal(set) var requestType: RequestType? = nil
    public private(set) var chatTabInfo: ChatTabInfo
    private let conversationProvider: ConversationServiceProvider?
    private let conversationProgressHandler: ConversationProgressHandler
    private let conversationContextHandler: ConversationContextHandler = ConversationContextHandlerImpl.shared
    // sync all the files in the workspace to watch for changes.
    private let watchedFilesHandler: WatchedFilesHandler = WatchedFilesHandlerImpl.shared
    private var cancellables = Set<AnyCancellable>()
    private var activeRequestId: String?
    private(set) public var conversationId: String?
    private var skillSet: [ConversationSkill] = []
    private var lastUserRequest: ConversationRequest?
    private var isRestored: Bool = false
    private var pendingToolCallRequests: [String: ToolCallRequest] = [:]
    // Workaround: toolConfirmation request does not have parent turnId
    private var conversationTurnTracking = ConversationTurnTrackingState()
    
    init(provider: any ConversationServiceProvider,
         memory: ContextAwareAutoManagedChatMemory = ContextAwareAutoManagedChatMemory(),
         conversationProgressHandler: ConversationProgressHandler = ConversationProgressHandlerImpl.shared,
         chatTabInfo: ChatTabInfo) {
        self.memory = memory
        self.conversationProvider = provider
        self.conversationProgressHandler = conversationProgressHandler
        self.chatTabInfo = chatTabInfo
        memory.chatService = self
        
        subscribeToNotifications()
        subscribeToConversationContextRequest()
        subscribeToClientToolInvokeEvent()
        subscribeToClientToolConfirmationEvent()
    }
    
    deinit {
        Task { [weak self] in
            await self?.stopReceivingMessage()
        }
        
        // Clear all subscriptions
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
        
        // Memory will be deallocated automatically
    }
    
    public func updateChatTabInfo(_ tabInfo: ChatTabInfo) {
        // Only isSelected need to be updated
        chatTabInfo.isSelected = tabInfo.isSelected
    }
    
    private func subscribeToNotifications() {
        memory.observeHistoryChange { [weak self] in
            Task { [weak self] in
                guard let memory = self?.memory else { return }
                self?.chatHistory = await memory.history
            }
        }
        
        conversationProgressHandler.onBegin.sink { [weak self] (token, progress) in
            self?.handleProgressBegin(token: token, progress: progress)
        }.store(in: &cancellables)
        
        conversationProgressHandler.onProgress.sink { [weak self] (token, progress) in
            self?.handleProgressReport(token: token, progress: progress)
        }.store(in: &cancellables)
        
        conversationProgressHandler.onEnd.sink { [weak self] (token, progress) in
            self?.handleProgressEnd(token: token, progress: progress)
        }.store(in: &cancellables)
    }
    
    private func subscribeToConversationContextRequest() {
        self.conversationContextHandler.onConversationContext.sink(receiveValue: { [weak self] (request, completion) in
            guard let skills = self?.skillSet, !skills.isEmpty, request.params!.conversationId == self?.conversationId else { return }
            skills.forEach { skill in
                if (skill.applies(params: request.params!)) {
                    skill.resolveSkill(request: request, completion: completion)
                }
            }
        }).store(in: &cancellables)
    }

    private func subscribeToClientToolConfirmationEvent() {
        ClientToolHandlerImpl.shared.onClientToolConfirmationEvent.sink(receiveValue: { [weak self] (request, completion) in
            guard let params = request.params else { return }
            
            // Check if this conversationId is valid (main conversation or subagent conversation)
            guard let validIds = self?.conversationTurnTracking.validConversationIds, validIds.contains(params.conversationId) else {
                return
            }
            
            let parentTurnId = self?.conversationTurnTracking.turnParentMap[params.turnId]
            
            let editAgentRounds: [AgentRound] = [
                AgentRound(roundId: params.roundId,
                           reply: "",
                           toolCalls: [
                            AgentToolCall(id: params.toolCallId, name: params.name, status: .waitForConfirmation, invokeParams: params, title: params.title)
                           ]
                          )
            ]
            self?.appendToolCallHistory(turnId: params.turnId, editAgentRounds: editAgentRounds, parentTurnId: parentTurnId)
            self?.pendingToolCallRequests[params.toolCallId] = ToolCallRequest(
                requestId: request.id,
                turnId: params.turnId,
                roundId: params.roundId,
                toolCallId: params.toolCallId,
                completion: completion)
        }).store(in: &cancellables)
    }

    private func subscribeToClientToolInvokeEvent() {
        ClientToolHandlerImpl.shared.onClientToolInvokeEvent.sink(receiveValue: { [weak self] (request, completion) in
            guard let params = request.params else { return }
            
            // Check if this conversationId is valid (main conversation or subagent conversation)
            guard let validIds = self?.conversationTurnTracking.validConversationIds, validIds.contains(params.conversationId) else {
                return
            }
            
            guard let copilotTool = CopilotToolRegistry.shared.getTool(name: params.name) else {
                completion(AnyJSONRPCResponse(id: request.id,
                                              result: JSONValue.array([
                                                  JSONValue.null,
                                                  JSONValue.hash(
                                                    [
                                                        "code": .number(-32601),
                                                        "message": .string("Tool function not found")
                                                    ])
                                              ])
                                             )
                )
                return
            }

            _ = copilotTool.invokeTool(request, completion: completion, contextProvider: self)
        }).store(in: &cancellables)
    }

    func appendToolCallHistory(turnId: String, editAgentRounds: [AgentRound], fileEdits: [FileEdit] = [], parentTurnId: String? = nil) {
        let chatTabId = self.chatTabInfo.id
        Task {
            let turnStatus: ChatMessage.TurnStatus? = {
                guard let round = editAgentRounds.first, let toolCall = round.toolCalls?.first else {
                    return nil
                }
                
                switch toolCall.status {
                case .waitForConfirmation: return .waitForConfirmation
                case .accepted, .running, .completed, .error: return .inProgress
                case .cancelled: return .cancelled
                }
            }()
            
            let message = ChatMessage(
                assistantMessageWithId: turnId,
                chatTabID: chatTabId,
                editAgentRounds: editAgentRounds,
                parentTurnId: parentTurnId,
                fileEdits: fileEdits,
                turnStatus: turnStatus
            )

            await self.memory.appendMessage(message)
        }
    }

    public func notifyChangeTextDocument(fileURL: URL, content: String, version: Int) async throws {
        try await conversationProvider?.notifyChangeTextDocument(fileURL: fileURL, content: content, version: version, workspaceURL: getWorkspaceURL())
    }

    public static func service(for chatTabInfo: ChatTabInfo) -> ChatService {
        let provider = BuiltinExtensionConversationServiceProvider(
            extension: GitHubCopilotExtension.self
        )
        return ChatService(provider: provider, chatTabInfo: chatTabInfo)
    }
    
    // this will be triggerred in conversation tab if needed
    public func restoreIfNeeded() {
        guard self.isRestored == false else { return }
        
        Task {
            let storedChatMessages = fetchAllChatMessagesFromStorage()
            await mutateHistory { history in
                history.append(contentsOf: storedChatMessages)
            }
        }
        
        self.isRestored = true
    }

    /// Updates the status of a tool call (accepted, cancelled, etc.) and notifies the server
    /// 
    /// This method handles two key responsibilities:
    /// 1. Sends confirmation response back to the server when user accepts/cancels
    /// 2. Updates the tool call status in chat history UI (including subagent tool calls)
    public func updateToolCallStatus(toolCallId: String, status: AgentToolCall.ToolCallStatus, payload: Any? = nil) {
        // Capture the pending request info before removing it from the dictionary
        let toolCallRequest = self.pendingToolCallRequests[toolCallId]
        
        // Step 1: Send confirmation response to server (for accept/cancel actions only)
        if let toolCallRequest = toolCallRequest, status == .accepted || status == .cancelled {
            self.pendingToolCallRequests.removeValue(forKey: toolCallId)
            sendToolConfirmationResponse(toolCallRequest, accepted: status == .accepted)
        }

        // Step 2: Update the tool call status in chat history UI
        Task {
            guard let targetMessage = await ToolCallStatusUpdater.findMessageContainingToolCall(
                toolCallRequest,
                conversationTurnTracking: conversationTurnTracking,
                history: await memory.history
            ) else {
                return
            }
            
            // Search for the tool call in main rounds or subagent rounds
            if let updatedRound = ToolCallStatusUpdater.findAndUpdateToolCall(
                toolCallId: toolCallId,
                newStatus: status,
                in: targetMessage.editAgentRounds
            ) {
                let message = ToolCallStatusUpdater.createMessageUpdate(
                    targetMessage: targetMessage,
                    updatedRound: updatedRound
                )
                await memory.appendMessage(message)
            }
        }
    }
    
    // MARK: - Helper Methods for Tool Call Status Updates
    
    /// Sends the confirmation response (accept/dismiss) back to the server
    private func sendToolConfirmationResponse(_ request: ToolCallRequest, accepted: Bool) {
        let toolResult = LanguageModelToolConfirmationResult(
            result: accepted ? .Accept : .Dismiss
        )
        let jsonResult = try? JSONEncoder().encode(toolResult)
        let jsonValue = (try? JSONDecoder().decode(JSONValue.self, from: jsonResult ?? Data())) ?? JSONValue.null
        
        request.completion(
            AnyJSONRPCResponse(
                id: request.requestId,
                result: JSONValue.array([jsonValue, JSONValue.null])
            )
        )
    }
    
    public enum ChatServiceError: Error, LocalizedError {
        case conflictingImageFormats(String)
        
        public var errorDescription: String? {
            switch self {
            case .conflictingImageFormats(let message):
                return message
            }
        }
    }

    public func send(
        _ id: String,
        content: String,
        contentImages: Array<ChatCompletionContentPartImage> = [],
        contentImageReferences: Array<ImageReference> = [],
        skillSet: Array<ConversationSkill>,
        references: [ConversationAttachedReference],
        model: String? = nil,
        modelProviderName: String? = nil,
        agentMode: Bool = false,
        customChatModeId: String? = nil,
        userLanguage: String? = nil,
        turnId: String? = nil
    ) async throws {
        guard activeRequestId == nil else { return }
        let workDoneToken = UUID().uuidString
        activeRequestId = workDoneToken
        
        let finalImageReferences: [ImageReference]
        let finalContentImages: [ChatCompletionContentPartImage]
        
        if !contentImageReferences.isEmpty {
            // User attached images are all parsed as ImageReference
            finalImageReferences = contentImageReferences
            finalContentImages = contentImageReferences
                .map {
                    ChatCompletionContentPartImage(
                        url: $0.dataURL(imageType: $0.source == .screenshot ? "png" : "")
                    )
                }
        } else {
            // In current implementation, only resend message will have contentImageReferences
            // No need to convert ChatCompletionContentPartImage to ImageReference for persistence
            finalImageReferences = []
            finalContentImages = contentImages
        }
        
        var chatMessage = ChatMessage(
            userMessageWithId: id,
            chatTabId: chatTabInfo.id,
            content: content,
            contentImageReferences: finalImageReferences,
            references: references.toConversationReferences()
        )
        
        let currentEditorSkill = skillSet.first(where: { $0.id == CurrentEditorSkill.ID }) as? CurrentEditorSkill
        let currentFileReadability = currentEditorSkill == nil
            ? nil
            : FileUtils.checkFileReadability(at: currentEditorSkill!.currentFilePath)
        var errorMessage: ChatMessage?
        
        var currentTurnId: String? = turnId
        // If turnId is provided, it is used to update the existing message, no need to append the user message
        if turnId == nil {
            if let currentFileReadability, !currentFileReadability.isReadable {
                // For associating error message with user message
                currentTurnId = UUID().uuidString
                chatMessage.clsTurnID = currentTurnId
                errorMessage = ChatMessage(
                    errorMessageWithId: currentTurnId!,
                    chatTabID: chatTabInfo.id,
                    errorMessages: [
                        currentFileReadability.errorMessage(
                            using: CurrentEditorSkill.readabilityErrorMessageProvider
                        )
                    ].compactMap { $0 }.filter { !$0.isEmpty }
                )
            }
            await memory.appendMessage(chatMessage)
        }
        
        // reset file edits
        self.resetFileEdits()
        
        // persist
        saveChatMessageToStorage(chatMessage)
        
        if content.hasPrefix("/releaseNotes") {
            if let fileURL = Bundle.main.url(forResource: "ReleaseNotes", withExtension: "md"),
                let whatsNewContent = try? String(contentsOf: fileURL)
            {
                // will be persist in resetOngoingRequest()
                // there is no turn id from CLS, just set it as id
                let clsTurnID = UUID().uuidString
                let progressMessage = ChatMessage(
                    assistantMessageWithId: clsTurnID,
                    chatTabID: chatTabInfo.id,
                    content: whatsNewContent
                )
                await memory.appendMessage(progressMessage)
            }
            resetOngoingRequest()
            return
        }
        
        if let errorMessage {
            Task { await memory.appendMessage(errorMessage) }
        }
        
        var activeDoc: Doc?
        var validSkillSet: [ConversationSkill] = skillSet
        if let currentEditorSkill, currentFileReadability?.isReadable == true {
            activeDoc = Doc(uri: currentEditorSkill.currentFile.url.absoluteString)
        } else {
            validSkillSet.removeAll(where: { $0.id == CurrentEditorSkill.ID || $0.id == ProblemsInActiveDocumentSkill.ID })
        }
        
        let request = createConversationRequest(
            workDoneToken: workDoneToken,
            content: content,
            contentImages: finalContentImages,
            activeDoc: activeDoc,
            references: references,
            model: model,
            modelProviderName: modelProviderName,
            agentMode: agentMode,
            customChatModeId: customChatModeId,
            userLanguage: userLanguage,
            turnId: currentTurnId,
            skillSet: validSkillSet
        )
        
        self.lastUserRequest = request
        self.skillSet = validSkillSet
        if let response = try await sendConversationRequest(request) {
            await handleConversationCreateResponse(response)
        }
    }
    
    private func createConversationRequest(
        workDoneToken: String, 
        content: String,
        contentImages: [ChatCompletionContentPartImage] = [],
        activeDoc: Doc?,
        references: [ConversationAttachedReference],
        model: String? = nil,
        modelProviderName: String? = nil,
        agentMode: Bool = false,
        customChatModeId: String? = nil,
        userLanguage: String? = nil,
        turnId: String? = nil,
        skillSet: [ConversationSkill]
    ) -> ConversationRequest {
        let skillCapabilities: [String] = [CurrentEditorSkill.ID, ProblemsInActiveDocumentSkill.ID]
        let supportedSkills: [String] = skillSet.map { $0.id }
        let ignoredSkills: [String] = skillCapabilities.filter {
            !supportedSkills.contains($0)
        }
        
        /// replace the `@workspace` to `@project`
        let newContent = replaceFirstWord(in: content, from: "@workspace", to: "@project")
        
        return ConversationRequest(
            workDoneToken: workDoneToken,
            content: newContent,
            contentImages: contentImages,
            workspaceFolder: "",
            activeDoc: activeDoc,
            skills: skillCapabilities,
            ignoredSkills: ignoredSkills,
            references: references,
            model: model,
            modelProviderName: modelProviderName,
            agentMode: agentMode,
            customChatModeId: customChatModeId,
            userLanguage: userLanguage,
            turnId: turnId
        )
    }
    
    private func handleConversationCreateResponse(_ response: ConversationCreateResponse) async {
        await memory.mutateHistory { history in
            if let index = history.firstIndex(where: { $0.id == response.turnId && $0.role.isAssistant }) {
                history[index].modelName = response.modelName
                history[index].billingMultiplier = response.billingMultiplier
                
                self.saveChatMessageToStorage(history[index])
            }
        }
    }

    public func sendAndWait(_ id: String, content: String) async throws -> String {
        try await send(id, content: content, skillSet: [], references: [])
        if let reply = await memory.history.last(where: { $0.role == .assistant })?.content {
            return reply
        }
        return ""
    }

    public func stopReceivingMessage() async {
        if let activeRequestId = activeRequestId {
            do {
                try await conversationProvider?.stopReceivingMessage(activeRequestId, workspaceURL: getWorkspaceURL())
            } catch {
                print("Failed to cancel ongoing request with WDT: \(activeRequestId)")
            }
        }
        resetOngoingRequest(with: .cancelled)
    }

    // Not used
    public func clearHistory() async {
        let messageIds = await memory.history.map { $0.id }
        
        await memory.clearHistory()
        if let activeRequestId = activeRequestId {
            do {
                try await conversationProvider?.stopReceivingMessage(activeRequestId, workspaceURL: getWorkspaceURL())
            } catch {
                print("Failed to cancel ongoing request with WDT: \(activeRequestId)")
            }
        }
        
        deleteAllChatMessagesFromStorage(messageIds)
        resetOngoingRequest()
    }
    
    public func deleteMessages(ids: [String]) async {
        let turnIdsFromMessages = await memory.history
            .filter { ids.contains($0.id) }
            .compactMap { $0.clsTurnID }
            .map { String($0) }
        let turnIds = Array(Set(turnIdsFromMessages))
        
        await memory.removeMessages(ids)
        await deleteTurns(turnIds)
        deleteAllChatMessagesFromStorage(ids)
    }

    public func resendMessage(id: String, model: String? = nil, modelProviderName: String? = nil) async throws {
        if let _ = (await memory.history).first(where: { $0.id == id }),
           let lastUserRequest
        {
            // TODO: clean up contents for resend message
            activeRequestId = nil
            try await send(
                id,
                content: lastUserRequest.content,
                contentImages: lastUserRequest.contentImages,
                skillSet: skillSet,
                references: lastUserRequest.references ?? [],
                model: model != nil ? model : lastUserRequest.model,
                modelProviderName: modelProviderName,
                agentMode: lastUserRequest.agentMode,
                customChatModeId: lastUserRequest.customChatModeId,
                userLanguage: lastUserRequest.userLanguage,
                turnId: id
            )
        }
    }

    public func setMessageAsExtraPrompt(id: String) async {
        if let message = (await memory.history).first(where: { $0.id == id })
        {
            await mutateHistory { history in
                let chatMessage: ChatMessage = .init(
                    chatTabID: self.chatTabInfo.id,
                    role: .assistant,
                    content: message.content
                )
                
                history.append(chatMessage)
                self.saveChatMessageToStorage(chatMessage)
            }
        }
    }

    public func mutateHistory(_ mutator: @escaping (inout [ChatMessage]) -> Void) async {
        await memory.mutateHistory(mutator)
    }

    public func handleCustomCommand(_ command: CustomCommand) async throws {
        struct CustomCommandInfo {
            var specifiedSystemPrompt: String?
            var extraSystemPrompt: String?
            var sendingMessageImmediately: String?
            var name: String?
        }

        let info: CustomCommandInfo? = {
            switch command.feature {
            case let .chatWithSelection(extraSystemPrompt, prompt, useExtraSystemPrompt):
                let updatePrompt = useExtraSystemPrompt ?? true
                return .init(
                    extraSystemPrompt: updatePrompt ? extraSystemPrompt : nil,
                    sendingMessageImmediately: prompt,
                    name: command.name
                )
            case let .customChat(systemPrompt, prompt):
                return .init(
                    specifiedSystemPrompt: systemPrompt,
                    extraSystemPrompt: "",
                    sendingMessageImmediately: prompt,
                    name: command.name
                )
            case .promptToCode: return nil
            case .singleRoundDialog: return nil
            }
        }()

        guard let info else { return }

        let templateProcessor = CustomCommandTemplateProcessor()

        if info.specifiedSystemPrompt != nil || info.extraSystemPrompt != nil {
            await mutateHistory { history in
                let chatMessage: ChatMessage = .init(
                    chatTabID: self.chatTabInfo.id,
                    role: .assistant,
                    content: ""
                )
                history.append(chatMessage)
                self.saveChatMessageToStorage(chatMessage)
            }
        }

        if let sendingMessageImmediately = info.sendingMessageImmediately,
           !sendingMessageImmediately.isEmpty
        {
            try await send(UUID().uuidString, content: templateProcessor.process(sendingMessageImmediately), skillSet: [], references: [])
        }
    }

    public func getWorkspaceURL() -> URL? {
        guard !chatTabInfo.workspacePath.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: chatTabInfo.workspacePath)
    }
    
    public func getProjectRootURL() -> URL? {
        guard let workspaceURL = getWorkspaceURL() else { return nil }
        return WorkspaceXcodeWindowInspector.extractProjectURL(
            workspaceURL: workspaceURL, 
            documentURL: nil
        )
    }
    
    public func upvote(_ id: String, _ rating: ConversationRating) async {
        try? await conversationProvider?.rateConversation(turnId: id, rating: rating, workspaceURL: getWorkspaceURL())
    }
    
    public func downvote(_ id: String, _ rating: ConversationRating) async {
        try? await conversationProvider?.rateConversation(turnId: id, rating: rating, workspaceURL: getWorkspaceURL())
    }
    
    public func copyCode(_ id: String) async {
        // TODO: pass copy code info to Copilot server
    }

    // not used
    public func handleSingleRoundDialogCommand(
        systemPrompt: String?,
        overwriteSystemPrompt: Bool,
        prompt: String
    ) async throws -> String {
        let templateProcessor = CustomCommandTemplateProcessor()
        return try await sendAndWait(UUID().uuidString, content: templateProcessor.process(prompt))
    }
    
    private func handleProgressBegin(token: String, progress: ConversationProgressBegin) {
        guard let workDoneToken = activeRequestId, workDoneToken == token else { return }
        // Only update conversationId for main turns, not subagent turns
        // Subagent turns have their own conversation ID which should not replace the parent
        if progress.parentTurnId == nil {
            conversationId = progress.conversationId
        }
        
        // Track all valid conversation IDs for the current turn (main conversation + its subturns)
        conversationTurnTracking.validConversationIds.insert(progress.conversationId)
        
        let turnId = progress.turnId
        let parentTurnId = progress.parentTurnId
        
        // Track parent-subturn relationship
        if let parentTurnId = parentTurnId {
            conversationTurnTracking.turnParentMap[turnId] = parentTurnId
        }
        
        Task {
            if var lastUserMessage = await memory.history.last(where: { $0.role == .user }) {
                
                // Case: New conversation where error message was generated before CLS request
                // Using clsTurnId to associate this error message with the corresponding user message
                // When merging error messages with bot responses from CLS, these properties need to be updated
                await memory.mutateHistory { history in 
                    if let existingBotIndex = history.lastIndex(where: {
                        $0.role == .assistant && $0.clsTurnID == lastUserMessage.clsTurnID
                    }) {
                        history[existingBotIndex].id = turnId
                        history[existingBotIndex].clsTurnID = turnId
                    }
                }
                
                lastUserMessage.clsTurnID = progress.turnId
                saveChatMessageToStorage(lastUserMessage)
            }
            
            /// Display an initial assistant message immediately after the user sends a message.
            /// This improves perceived responsiveness, especially in Agent Mode where the first
            /// ProgressReport may take long time.
            /// Skip creating a new message for subturns - they will be merged into the parent turn
            if parentTurnId == nil {
                let message = ChatMessage(
                    assistantMessageWithId: turnId, 
                    chatTabID: chatTabInfo.id, 
                    turnStatus: .inProgress
                )

                // will persist in resetOngoingRequest()
                await memory.appendMessage(message)
            }
        }
    }

    private func handleProgressReport(token: String, progress: ConversationProgressReport) {
        guard let workDownToken = activeRequestId, workDownToken == token else {
            return
        }
        
        let id = progress.turnId
        var content = ""
        var references: [ConversationReference] = []
        var steps: [ConversationProgressStep] = []
        var editAgentRounds: [AgentRound] = []
        let parentTurnId = progress.parentTurnId

        if let reply = progress.reply {
            content = reply
        }
        
        if let progressReferences = progress.references, !progressReferences.isEmpty {
            references = progressReferences.toConversationReferences()
        }
        
        if let progressSteps = progress.steps, !progressSteps.isEmpty {
            steps = progressSteps
        }
        
        if let progressAgentRounds = progress.editAgentRounds, !progressAgentRounds.isEmpty {
            editAgentRounds = progressAgentRounds
        }
        
        if content.isEmpty && references.isEmpty && steps.isEmpty && editAgentRounds.isEmpty && parentTurnId == nil {
            return
        }
        
        let messageContent = content
        let messageReferences = references
        let messageSteps = steps
        let messageAgentRounds = editAgentRounds
        let messageParentTurnId = parentTurnId

        Task {
            let message = ChatMessage(
                assistantMessageWithId: id,
                chatTabID: chatTabInfo.id,
                content: messageContent,
                references: messageReferences,
                steps: messageSteps,
                editAgentRounds: messageAgentRounds,
                parentTurnId: messageParentTurnId,
                turnStatus: .inProgress
            )

            await memory.appendMessage(message)
        }
    }

    private func handleProgressEnd(token: String, progress: ConversationProgressEnd) {
        guard let workDoneToken = activeRequestId, workDoneToken == token else { return }
        let followUp = progress.followUp
        
        if let CLSError = progress.error {
            // CLS Error Code 402: reached monthly chat messages limit
            if CLSError.code == 402 {
                Task {
                    let selectedModel = lastUserRequest?.model
                    let selectedModelProviderName = lastUserRequest?.modelProviderName
                    
                    var errorMessageText: String
                    if let selectedModel = selectedModel, let selectedModelProviderName = selectedModelProviderName {
                        errorMessageText = "You've reached your quota limit for your BYOK model \(selectedModel). Please check with \(selectedModelProviderName) for more information."
                    } else {
                        errorMessageText = CLSError.message
                    }

                    await Status.shared
                        .updateCLSStatus(.warning, busy: false, message: errorMessageText)
                    let errorMessage = ChatMessage(
                        errorMessageWithId: progress.turnId,
                        chatTabID: chatTabInfo.id,
                        panelMessages: [.init(type: .error, title: String(CLSError.code ?? 0), message: errorMessageText, location: .Panel)]
                    )
                    // will persist in resetongoingRequest()
                    await memory.appendMessage(errorMessage)
                    
                    if let lastUserRequest,
                       let currentUserPlan = await Status.shared.currentUserPlan(),
                       currentUserPlan != "free" {
                        guard let fallbackModel = CopilotModelManager.getFallbackLLM(
                            scope: lastUserRequest.agentMode ? .agentPanel : .chatPanel
                        ) else {
                            resetOngoingRequest(with: .error)
                            return
                        }
                        do {
                            CopilotModelManager.switchToFallbackModel()
                            try await resendMessage(
                                id: progress.turnId,
                                model: fallbackModel.id,
                                modelProviderName: nil
                            )
                        } catch {
                            Logger.gitHubCopilot.error(error)
                            resetOngoingRequest(with: .error)
                        }
                        return
                    }
                }
            } else if CLSError.code == 400 && CLSError.message.contains("model is not supported") {
                Task {
                    let errorMessage = ChatMessage(
                        errorMessageWithId: progress.turnId,
                        chatTabID: chatTabInfo.id,
                        errorMessages: ["Oops, the model is not supported. Please enable it first in [GitHub Copilot settings](https://github.com/settings/copilot)."]
                    )
                    await memory.appendMessage(errorMessage)
                    resetOngoingRequest(with: .error)
                    return
                }
            } else {
                Task {
                    var clsErrorMessage = CLSError.message
                    if CLSError.code == ConversationErrorCode.toolRoundExceedError.rawValue {
                        // TODO: Remove this after `Continue` is supported.
                        clsErrorMessage = HardCodedToolRoundExceedErrorMessage
                    }
                    
                    let errorMessage = ChatMessage(
                        errorMessageWithId: progress.turnId,
                        chatTabID: chatTabInfo.id,
                        errorMessages: [clsErrorMessage]
                    )
                    // will persist in resetOngoingRequest()
                    await memory.appendMessage(errorMessage)
                    resetOngoingRequest(with: .error)
                    return
                }
            }
        }
        
        Task {
            let message = ChatMessage(
                assistantMessageWithId: progress.turnId, 
                chatTabID: chatTabInfo.id,
                followUp: followUp,
                suggestedTitle: progress.suggestedTitle,
                turnStatus: .success
            )
            // will persist in resetOngoingRequest()
            await memory.appendMessage(message)
            resetOngoingRequest(with: .success)
        }
    }
    
    private func resetOngoingRequest(with turnStatus: ChatMessage.TurnStatus = .success) {
        activeRequestId = nil
        isReceivingMessage = false
        requestType = nil
        
        // Clear turn tracking data
        conversationTurnTracking.reset()

        // cancel all pending tool call requests
        for (_, request) in pendingToolCallRequests {
            pendingToolCallRequests.removeValue(forKey: request.toolCallId)
            let toolResult = LanguageModelToolConfirmationResult(result: .Dismiss)
            let jsonResult = try? JSONEncoder().encode(toolResult)
            let jsonValue = (try? JSONDecoder().decode(JSONValue.self, from: jsonResult ?? Data())) ?? JSONValue.null
            request.completion(
                AnyJSONRPCResponse(
                    id: request.requestId,
                    result: JSONValue.array([
                        jsonValue,
                        JSONValue.null
                    ])
                )
            )
        }
        
        Task {
            // mark running steps to cancelled
            await mutateHistory({ history in
                guard !history.isEmpty,
                      let lastIndex = history.indices.last,
                      history[lastIndex].role == .assistant else { return }
                
                for i in 0..<history[lastIndex].steps.count {
                    if history[lastIndex].steps[i].status == .running {
                        history[lastIndex].steps[i].status = .cancelled
                    }
                }
                
                for i in 0..<history[lastIndex].editAgentRounds.count {
                    if history[lastIndex].editAgentRounds[i].toolCalls == nil {
                        continue
                    }

                    for j in 0..<history[lastIndex].editAgentRounds[i].toolCalls!.count {
                        if history[lastIndex].editAgentRounds[i].toolCalls![j].status == .running
                            || history[lastIndex].editAgentRounds[i].toolCalls![j].status == .waitForConfirmation {
                            history[lastIndex].editAgentRounds[i].toolCalls![j].status = .cancelled
                        }
                    }
                    
                    // Cancel tool calls in subagent rounds
                    if let subAgentRounds = history[lastIndex].editAgentRounds[i].subAgentRounds {
                        for k in 0..<subAgentRounds.count {
                            if let toolCalls = subAgentRounds[k].toolCalls {
                                for l in 0..<toolCalls.count {
                                    if toolCalls[l].status == .running
                                        || toolCalls[l].status == .waitForConfirmation {
                                        history[lastIndex].editAgentRounds[i].subAgentRounds![k].toolCalls![l].status = .cancelled
                                    }
                                }
                            }
                        }
                    }
                }
                
                if history[lastIndex].codeReviewRound != nil,
                   (
                    history[lastIndex].codeReviewRound!.status == .waitForConfirmation
                    || history[lastIndex].codeReviewRound!.status == .running
                   )
                {
                    history[lastIndex].codeReviewRound!.status = .cancelled
                }
                
                history[lastIndex].turnStatus = turnStatus
            })

            // The message of progress report could change rapidly
            // Directly upsert the last chat message of history here
            // Possible repeat upsert, but no harm.
            if let message = await memory.history.last {
                saveChatMessageToStorage(message)
            }
        }
    }
    
    private func sendConversationRequest(_ request: ConversationRequest) async throws -> ConversationCreateResponse? {
        guard !isReceivingMessage else { throw CancellationError() }
        isReceivingMessage = true
        requestType = .conversation
        
        do {
            if let conversationId = conversationId {
                return try await conversationProvider?
                    .createTurn(
                        with: conversationId,
                        request: request,
                        workspaceURL: getWorkspaceURL()
                    )
            } else {
                var requestWithTurns = request
                
                var chatHistory = self.chatHistory
                // remove the last user message
                let _ = chatHistory.popLast()
                if chatHistory.count > 0 {
                    // invoke history turns
                    let turns = chatHistory.toTurns()
                    requestWithTurns.turns = turns
                }
                
                return try await conversationProvider?.createConversation(requestWithTurns, workspaceURL: getWorkspaceURL())
            }
        } catch {
            resetOngoingRequest(with: .error)
            throw error
        }
    }
    
    private func deleteTurns(_ turnIds: [String]) async {
        guard !turnIds.isEmpty, let conversationId = conversationId else {
            return
        }
        
        let workspaceURL = getWorkspaceURL()
        
        for turnId in turnIds {
            do {
                try await conversationProvider?
                    .deleteTurn(with: conversationId, turnId: turnId, workspaceURL: workspaceURL)
            } catch {
                Logger.client.error("Failed to delete turn: \(error)")
            }
        }
    }
}


public final class SharedChatService {
    public var chatTemplates: [ChatTemplate]? = nil
    public var chatAgents: [ChatAgent]? = nil
    public var conversationModes: [ConversationMode]? = nil
    private let conversationProvider: ConversationServiceProvider?
    
    public static let shared = SharedChatService.service()
    
    init(provider: any ConversationServiceProvider) {
        self.conversationProvider = provider
    }
    
    public static func service() -> SharedChatService {
        let provider = BuiltinExtensionConversationServiceProvider(
            extension: GitHubCopilotExtension.self
        )
        return SharedChatService(provider: provider)
    }
    
    public func loadChatTemplates() async -> [ChatTemplate]? {
        do {
            if let templates = (try await conversationProvider?.templates()) {
                self.chatTemplates = templates
                return templates
            }
        } catch {
            // handle error if desired
        }

        return nil
    }
    
    public func loadConversationModes() async -> [ConversationMode]? {
        do {
            if let modes = (try await conversationProvider?.modes()) {
                self.conversationModes = modes
                return modes
            }
        } catch {
            // handle error if desired
        }

        return nil
    }
    
    public func copilotModels() async -> [CopilotModel] {
        guard let models = try? await conversationProvider?.models() else { return [] }
        return models
    }
    
    public func loadChatAgents() async -> [ChatAgent]? {
        guard self.chatAgents == nil else { return self.chatAgents }
        
        do {
            if let chatAgents = (try await conversationProvider?.agents()) {
                self.chatAgents = chatAgents
                return chatAgents
            }
        } catch {
            // handle error if desired
        }

        return nil
    }
}


extension ChatService {
    
    // do storage operatoin in the background
    private func runInBackground(_ operation: @escaping () -> Void) {
        Task.detached(priority: .utility) {
            operation()
        }
    }
    
    func saveChatMessageToStorage(_ message: ChatMessage) {
        runInBackground {
            ChatMessageStore.save(message, with: .init(workspacePath: self.chatTabInfo.workspacePath, username: self.chatTabInfo.username))
        }
    }
    
    func deleteChatMessageFromStorage(_ id: String) {
        runInBackground {
                ChatMessageStore.delete(by: id, with: .init(workspacePath: self.chatTabInfo.workspacePath, username: self.chatTabInfo.username))
        }
    }
    func deleteAllChatMessagesFromStorage(_ ids: [String]) {
        runInBackground {
            ChatMessageStore.deleteAll(by: ids, with: .init(workspacePath: self.chatTabInfo.workspacePath, username: self.chatTabInfo.username))
        }
    }
    
    func fetchAllChatMessagesFromStorage() -> [ChatMessage] {
        return ChatMessageStore.getAll(by: self.chatTabInfo.id, metadata: .init(workspacePath: self.chatTabInfo.workspacePath, username: self.chatTabInfo.username))
    }
}

func replaceFirstWord(in content: String, from oldWord: String, to newWord: String) -> String {
    let pattern = "^\(oldWord)\\b"
    
    if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
        let range = NSRange(location: 0, length: content.utf16.count)
        return regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: newWord)
    }
    
    return content
}

extension Array where Element == FileReference {
    func toConversationReferences() -> [ConversationReference] {
        return self.map {
            .init(uri: $0.uri, status: .included, kind: .reference($0), referenceType: .file)
        }
    }
}

extension Array where Element == ConversationAttachedReference {
    func toConversationReferences() -> [ConversationReference] {
        return self.map {
            switch $0 {
            case .file(let fileRef): 
                    .init(
                        uri: fileRef.url.path,
                        status: .included,
                        kind: .fileReference($0),
                        referenceType: .file)
            case .directory(let directoryRef): 
                    .init(
                        uri: directoryRef.url.path,
                        status: .included,
                        kind: .fileReference($0),
                        referenceType: .directory)
            }
        }
    }
}

extension [ChatMessage] {
    // transfer chat messages to turns
    // used to restore chat history for CLS
    func toTurns() -> [TurnSchema] {
        var turns: [TurnSchema] = []
        let count = self.count
        var index = 0
        
        while index < count {
            let message = self[index]
            if case .user = message.role {
                var turn = TurnSchema(request: message.content, turnId: message.clsTurnID)
                // has next message
                if index + 1 < count {
                    let nextMessage = self[index + 1]
                    if nextMessage.role == .assistant {
                        turn.response = nextMessage.content + extractContentFromEditAgentRounds(nextMessage.editAgentRounds)
                        index += 1
                    }
                }
                turns.append(turn)
            }
            index += 1
        }
        
        return turns
    }
    
    private func extractContentFromEditAgentRounds(_ editAgentRounds: [AgentRound]) -> String {
        var content = ""
        for round in editAgentRounds {
            if !round.reply.isEmpty {
                content += round.reply
            }
        }
        return content
    }
}

// MARK: Copilot Code Review

extension ChatService {
    
    public func requestCodeReview(_ group: GitDiffGroup) async throws {
        guard activeRequestId == nil else { return }
        activeRequestId = UUID().uuidString
        
        guard !isReceivingMessage else {
            activeRequestId = nil
            throw CancellationError() 
        }
        isReceivingMessage = true
        requestType = .codeReview
        let turnId = UUID().uuidString
        
        do {
            await CodeReviewService.shared.resetComments()
            
            await addCodeReviewUserMessage(id: UUID().uuidString, turnId: turnId, group: group)
            
            let initialBotMessage = ChatMessage(
                assistantMessageWithId: turnId, 
                chatTabID: chatTabInfo.id,
                turnStatus: .inProgress,
                requestType: .codeReview
            )
            await memory.appendMessage(initialBotMessage)
            
            guard let projectRootURL = getProjectRootURL()
            else {
                let round = CodeReviewRound.fromError(turnId: turnId, error: "Invalid git repository.")
                await appendCodeReviewRound(round)
                resetOngoingRequest(with: .error)
                return
            }
            
            let prChanges = await CurrentChangeService.getPRChanges(
                projectRootURL, 
                group: group,
                shouldIncludeFile: shouldIncludeFileForReview
            )
            guard !prChanges.isEmpty else {
                let round = CodeReviewRound.fromError(
                    turnId: turnId, 
                    error: group == .index ? "No staged changes found to review." : "No unstaged changes found to review."
                )
                await appendCodeReviewRound(round)
                resetOngoingRequest()
                return
            }
                        
            let round: CodeReviewRound = .init(
                turnId: turnId,
                status: .waitForConfirmation,
                request: .from(prChanges)
            )
            await appendCodeReviewRound(round, turnStatus: .waitForConfirmation)
        } catch {
            resetOngoingRequest(with: .error)
            throw error
        }
    }
    
    private func shouldIncludeFileForReview(url: URL) -> Bool {
        let codeLanguage = CodeLanguage(fileURL: url)
        
        if case .builtIn = codeLanguage {
            return true
        } else {
            return false
        }
    }

    private func appendCodeReviewRound(
        _ round: CodeReviewRound,
        turnStatus: ChatMessage.TurnStatus? = nil
    ) async {
        let message = ChatMessage(
            assistantMessageWithId: round.turnId,
            chatTabID: chatTabInfo.id,
            codeReviewRound: round,
            turnStatus: turnStatus
        )
        
        await memory.appendMessage(message)
    }
    
    private func getCurrentCodeReviewRound(_ id: String) async -> CodeReviewRound? {
        guard let lastBotMessage = await memory.history.last, 
              lastBotMessage.role == .assistant,
              let codeReviewRound = lastBotMessage.codeReviewRound,
              codeReviewRound.id == id
        else {
            return nil
        }
        
        return codeReviewRound
    }
    
    public func acceptCodeReview(_ id: String, selectedFileUris: [DocumentUri]) async {
        guard activeRequestId != nil, isReceivingMessage else { return }
        
        guard var round = await getCurrentCodeReviewRound(id),
              var request = round.request,
              round.status.canTransitionTo(.accepted)
        else { return }
        
        guard selectedFileUris.count > 0 else {
            round = round.withError("No files are selected to review.")
            await appendCodeReviewRound(round)
            resetOngoingRequest()
            return
        }
        
        round.status = .accepted
        request.updateSelectedChanges(by: selectedFileUris)
        round.request = request
        await appendCodeReviewRound(round, turnStatus: .inProgress)
        
        round.status = .running
        await appendCodeReviewRound(round)
        
        let (fileComments, errorMessage) = await CodeReviewProvider.invoke(
            request,
            context: CodeReviewServiceProvider(conversationServiceProvider: conversationProvider)
        )
        
        if let errorMessage = errorMessage {
            round = round.withError(errorMessage)
            await appendCodeReviewRound(round)
            resetOngoingRequest(with: .error)
            return
        } 
        
        round = round.withResponse(.init(fileComments: fileComments))
        await CodeReviewService.shared.updateComments(fileComments)
        await appendCodeReviewRound(round)
        
        round.status = .completed
        await appendCodeReviewRound(round)
        
        resetOngoingRequest()
    }
    
    public func cancelCodeReview(_ id: String) async {
        guard activeRequestId != nil, isReceivingMessage else { return }
        
        guard var round = await getCurrentCodeReviewRound(id),
              round.status.canTransitionTo(.cancelled)
        else { return }
        
        round.status = .cancelled
        await appendCodeReviewRound(round)
        
        resetOngoingRequest(with: .cancelled)
    }
    
    private func addCodeReviewUserMessage(id: String, turnId: String, group: GitDiffGroup) async {
        let content = group == .index
            ? "Code review for staged changes."
            : "Code review for unstaged changes."
        let chatMessage = ChatMessage(
            userMessageWithId: id,
            chatTabId: chatTabInfo.id,
            content: content,
            requestType: .codeReview
        )
        await memory.appendMessage(chatMessage)
        saveChatMessageToStorage(chatMessage)
    }
}
