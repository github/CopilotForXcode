import ChatService
import ChatTab
import CodableWrappers
import Combine
import ComposableArchitecture
import DebounceFunction
import Foundation
import ChatAPIService
import Preferences
import SwiftUI
import AppKit
import Workspace
import ConversationServiceProvider

/// A chat tab that provides a context aware chat bot, powered by Chat.
public class ConversationTab: ChatTab {
    
    public static var name: String { "Chat" }

    public let service: ChatService
    let chat: StoreOf<Chat>
    private var cancellable = Set<AnyCancellable>()
    private var observer = NSObject()
    private let updateContentDebounce = DebounceRunner(duration: 0.5)
    private var isRestored: Bool = false
    
    // Get chat tab title. As the tab title is always "Chat" and won't be modified.
    // Use the chat title as the tab title.
    // TODO: modify tab title dynamically
    public func getChatTabTitle() -> String {
        return chat.title
    }

    struct RestorableState: Codable {
        var history: [ChatAPIService.ChatMessage]
    }

    struct Builder: ChatTabBuilder {
        var title: String
        var customCommand: CustomCommand?
        var afterBuild: (ConversationTab) async -> Void = { _ in }

        func build(store: StoreOf<ChatTabItem>) async -> (any ChatTab)? {
            let tab = await ConversationTab(store: store)
            if let customCommand {
                try? await tab.service.handleCustomCommand(customCommand)
            }
            await afterBuild(tab)
            return tab
        }
    }

    public func buildView() -> any View {
        ChatPanel(chat: chat)
    }

    public func buildTabItem() -> any View {
        ChatTabItemView(chat: chat)
    }
    
    public func buildChatConversationItem() -> any View {
        ChatConversationItemView(chat: chat)
    }

    public func buildIcon() -> any View {
        WithPerceptionTracking {
            if self.chat.isReceivingMessage {
                Image(systemName: "ellipsis.message")
            } else {
                Image(systemName: "message")
            }
        }
    }

    public func buildMenu() -> any View {
        ChatContextMenu(store: chat.scope(state: \.chatMenu, action: \.chatMenu))
    }

    public func restorableState() async -> Data {
        let state = RestorableState(
            history: await service.memory.history
        )
        return (try? JSONEncoder().encode(state)) ?? Data()
    }

    public static func restore(
        from data: Data,
        externalDependency: Void
    ) async throws -> any ChatTabBuilder {
        let state = try JSONDecoder().decode(RestorableState.self, from: data)
        let builder = Builder(title: "Chat") { @MainActor tab in
            await tab.service.memory.mutateHistory { history in
                history = state.history
            }
            tab.chat.send(.refresh)
        }
        return builder
    }

    public static func chatBuilders(externalDependency: Void) -> [ChatTabBuilder] {
        let customCommands = UserDefaults.shared.value(for: \.customCommands).compactMap {
            command in
            if case .customChat = command.feature {
                return Builder(title: command.name, customCommand: command)
            }
            return nil
        }

        return [Builder(title: "New Chat", customCommand: nil)] + customCommands
    }

    // store.state is type of ChatTabInfo
    // add the with parameters to avoiding must override the init
    @MainActor
    public init(store: StoreOf<ChatTabItem>, with chatTabInfo: ChatTabInfo? = nil) {
        let info = chatTabInfo ?? store.state
    
        let service = ChatService.service(for: info)
        self.service = service
        chat = .init(initialState: .init(workspaceURL: service.getWorkspaceURL()), reducer: { Chat(service: service) })
        super.init(store: store)
        
        // Start to observe changes of Chat Message
        self.start()
        
        // new created tab do not need restore
        self.isRestored = true
    }
    
    // for restore
    @MainActor
    public init(service: ChatService, store: StoreOf<ChatTabItem>, with chatTabInfo: ChatTabInfo) {
        self.service = service
        chat = .init(initialState: .init(workspaceURL: service.getWorkspaceURL()), reducer: { Chat(service: service) })
        super.init(store: store)
    }
    
    deinit {
        // Cancel all Combine subscriptions
        cancellable.forEach { $0.cancel() }
        cancellable.removeAll()
        
        // Stop the debounce runner
        Task { @MainActor [weak self] in
            await self?.updateContentDebounce.cancel()
        }
        
        // Clear observer
        observer = NSObject()
        
        // The deallocation of ChatService will be called automatically
        // The TCA Store (chat) handles its own cleanup automatically
    }
    
    @MainActor
    public static func restoreConversation(by chatTabInfo: ChatTabInfo, store: StoreOf<ChatTabItem>) -> ConversationTab {
        let service = ChatService.service(for: chatTabInfo)
        let tab = ConversationTab(service: service, store: store, with: chatTabInfo)
        
        // lazy restore conversation tab for not selected
        if chatTabInfo.isSelected {
            tab.restoreIfNeeded()
        }
        
        return tab
    }
    
    @MainActor
    public func restoreIfNeeded() {
        guard self.isRestored == false else { return }
        // restore chat history
        self.service.restoreIfNeeded()
        // start observer
        self.start()
        
        self.isRestored = true
    }

    public func start() {
        observer = .init()
        cancellable = []
        
        chat.send(.setDiffViewerController(chat: chat))

//        chatTabStore.send(.updateTitle("Chat"))

//        do {
//            var lastTrigger = -1
//            observer.observe { [weak self] in
//                guard let self else { return }
//                let trigger = chatTabStore.focusTrigger
//                guard lastTrigger != trigger else { return }
//                lastTrigger = trigger
//                Task { @MainActor [weak self] in
//                    self?.chat.send(.focusOnTextField)
//                }
//            }
//        }

//        do {
//            var lastTitle = ""
//            observer.observe { [weak self] in
//                guard let self else { return }
//                let title = self.chatTabStore.state.title
//                guard lastTitle != title else { return }
//                lastTitle = title
//                Task { @MainActor [weak self] in
//                    self?.chatTabStore.send(.updateTitle(title))
//                }
//            }
//        }
        
        var lastIsReceivingMessage = false

        observer.observe { [weak self] in
            guard let self else { return }
//            let history = chat.history
//            _ = chat.title
//            _ = chat.isReceivingMessage
            
            // As the observer won't check the state if changed, we need to check it manually.
            // Currently, only receciving message is used. If more states are needed, we can add them here.
            let currentIsReceivingMessage = chat.isReceivingMessage
            
            // Only trigger when isReceivingMessage changes
            if lastIsReceivingMessage != currentIsReceivingMessage {
                lastIsReceivingMessage = currentIsReceivingMessage
                Task {
                    await self.updateContentDebounce.debounce { @MainActor [weak self] in
                        guard let self else { return }
                        self.chatTabStore.send(.tabContentUpdated)
                        
                        if let suggestedTitle = chat.history.last?.suggestedTitle {
                            self.chatTabStore.send(.updateTitle(suggestedTitle))
                        }
                        
                        if let CLSConversationID = self.service.conversationId,
                            self.chatTabStore.CLSConversationID != CLSConversationID
                        {
                            self.chatTabStore.send(.setCLSConversationID(CLSConversationID))
                        }
                    }
                }
            }
        }
    }
    
    public func handlePasteEvent() -> Bool {
        let pasteboard = NSPasteboard.general
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], !urls.isEmpty {
            for url in urls {
                // Check if it's a remote URL (http/https)
                if url.scheme == "http" || url.scheme == "https" {
                    return false
                }

                if let isValidFile = try? WorkspaceFile.isValidFile(url), isValidFile {
                    DispatchQueue.main.async {
                        let fileReference = ConversationFileReference(url: url, isCurrentEditor: false)
                        self.chat.send(.addReference(.file(fileReference)))
                    }
                } else if let data = try? Data(contentsOf: url),
                    ["png", "jpeg", "jpg", "bmp", "gif", "tiff", "tif", "webp"].contains(url.pathExtension.lowercased()) {
                    DispatchQueue.main.async {
                        self.chat.send(.addSelectedImage(ImageReference(data: data, fileUrl: url)))
                    }
                }
            }
        } else if let data = pasteboard.data(forType: .png) {
            chat.send(.addSelectedImage(ImageReference(data: data, source: .pasted)))
        } else if let tiffData = pasteboard.data(forType: .tiff),
                let imageRep = NSBitmapImageRep(data: tiffData),
                let pngData = imageRep.representation(using: .png, properties: [:]) {
            chat.send(.addSelectedImage(ImageReference(data: pngData, source: .pasted)))
        } else {
            return false
        }
        
        return true
    }
    
    public func updateChatTabInfo(_ tabInfo: ChatTabInfo) {
        // Sync tabInfo for service
        service.updateChatTabInfo(tabInfo)
    }
}

