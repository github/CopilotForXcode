import ActiveApplicationMonitor
import AppKit
import ChatService
import ChatTab
import ComposableArchitecture
import ConversationTab
import GitHubCopilotService
import HostAppActivator
import PersistMiddleware
import SwiftUI

public enum ChatTabBuilderCollection: Equatable {
    case folder(title: String, kinds: [ChatTabKind])
    case kind(ChatTabKind)
}

public struct ChatTabKind: Equatable {
    public var builder: any ChatTabBuilder
    var title: String { builder.title }

    public init(_ builder: any ChatTabBuilder) {
        self.builder = builder
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title
    }
}

public struct WorkspaceIdentifier: Hashable, Codable {
    public let path: String
    public let username: String

    public init(path: String, username: String) {
        self.path = path
        self.username = username
    }
}

@ObservableState
public struct ChatHistory: Equatable {
    public var workspaces: IdentifiedArray<WorkspaceIdentifier, ChatWorkspace>
    public var selectedWorkspacePath: String?
    public var selectedWorkspaceName: String?
    public var currentUsername: String?

    public var currentChatWorkspace: ChatWorkspace? {
        guard let id = selectedWorkspacePath,
              let username = currentUsername
        else { return workspaces.first }
        let identifier = WorkspaceIdentifier(path: id, username: username)
        return workspaces[id: identifier]
    }

    init(workspaces: IdentifiedArray<WorkspaceIdentifier, ChatWorkspace> = [],
         selectedWorkspacePath: String? = nil,
         selectedWorkspaceName: String? = nil,
         currentUsername: String? = nil) {
        self.workspaces = workspaces
        self.selectedWorkspacePath = selectedWorkspacePath
        self.selectedWorkspaceName = selectedWorkspaceName
        self.currentUsername = currentUsername
    }

    mutating func updateHistory(_ workspace: ChatWorkspace) {
        if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
            workspaces[index] = workspace
        }
    }

    mutating func addWorkspace(_ workspace: ChatWorkspace) {
        guard !workspaces.contains(where: { $0.id == workspace.id }) else { return }
        workspaces[id: workspace.id] = workspace
    }
}

@ObservableState
public struct ChatWorkspace: Identifiable, Equatable {
    public var id: WorkspaceIdentifier
    public var tabInfo: IdentifiedArray<String, ChatTabInfo>
    public var tabCollection: [ChatTabBuilderCollection]
    public var selectedTabId: String?

    public var selectedTabInfo: ChatTabInfo? {
        guard let tabId = selectedTabId else { return tabInfo.first }
        return tabInfo[id: tabId]
    }

    public var workspacePath: String { id.path }
    public var username: String { id.username }

    private var onTabInfoDeleted: (String) -> Void

    public init(
        id: WorkspaceIdentifier,
        tabInfo: IdentifiedArray<String, ChatTabInfo> = [],
        tabCollection: [ChatTabBuilderCollection] = [],
        selectedTabId: String? = nil,
        onTabInfoDeleted: @escaping (String) -> Void
    ) {
        self.id = id
        self.tabInfo = tabInfo
        self.tabCollection = tabCollection
        self.selectedTabId = selectedTabId
        self.onTabInfoDeleted = onTabInfoDeleted
    }

    /// Walkaround `Equatable` error for `onTabInfoDeleted`
    public static func == (lhs: ChatWorkspace, rhs: ChatWorkspace) -> Bool {
        lhs.id == rhs.id &&
            lhs.tabInfo == rhs.tabInfo &&
            lhs.tabCollection == rhs.tabCollection &&
            lhs.selectedTabId == rhs.selectedTabId
    }

    public mutating func applyLRULimit(maxSize: Int = 5) {
        guard tabInfo.count > maxSize else { return }

        // Tabs not selected
        let nonSelectedTabs = Array(tabInfo.filter { $0.id != selectedTabId })
        let sortedByUpdatedAt = nonSelectedTabs.sorted { $0.updatedAt < $1.updatedAt }

        let tabsToRemove = Array(sortedByUpdatedAt.prefix(tabInfo.count - maxSize))

        // Remove Tabs
        for tab in tabsToRemove {
            // destroy tab
            onTabInfoDeleted(tab.id)

            // remove from workspace
            tabInfo.remove(id: tab.id)
        }
    }
}

@Reducer
public struct ChatPanelFeature {
    @ObservableState
    public struct State: Equatable {
        public var chatHistory = ChatHistory()
        public var currentChatWorkspace: ChatWorkspace? {
            return chatHistory.currentChatWorkspace
        }

        var colorScheme: ColorScheme = .light
        public internal(set) var isPanelDisplayed = false
        var isDetached = false
        var isFullScreen = false
    }

    public enum Action: Equatable {
        // Window
        case hideButtonClicked
        case closeActiveTabClicked
        case toggleChatPanelDetachedButtonClicked
        case detachChatPanel
        case attachChatPanel
        case enterFullScreen
        case exitFullScreen
        case presentChatPanel(forceDetach: Bool)
        case switchWorkspace(String, String, String)
        case openSettings

        // Tabs
        case updateChatHistory(ChatWorkspace)
//        case updateChatTabInfo(IdentifiedArray<String, ChatTabInfo>)
//        case createNewTapButtonHovered
        case closeTabButtonClicked(id: String)
        case createNewTapButtonClicked(kind: ChatTabKind?)
        case restoreTabByInfo(info: ChatTabInfo)
        case createNewTabByID(id: String)
        case tabClicked(id: String)
        case appendAndSelectTab(ChatTabInfo)
        case appendTabToWorkspace(ChatTabInfo, ChatWorkspace)
//        case switchToNextTab
//        case switchToPreviousTab
//        case moveChatTab(from: Int, to: Int)
        case focusActiveChatTab

        // Chat History
        case chatHistoryItemClicked(id: String)
        case chatHistoryDeleteButtonClicked(id: String)
        case chatTab(id: String, action: ChatTabItem.Action)

        // persist
        case saveChatTabInfo([ChatTabInfo?], ChatWorkspace)
        case deleteChatTabInfo(id: String, ChatWorkspace)
        case restoreWorkspace(ChatWorkspace)

        case syncChatTabInfo([ChatTabInfo?])

        // ChatWorkspace cleanup
        case scheduleLRUCleanup(ChatWorkspace)
        case performLRUCleanup(ChatWorkspace)
    }

    @Dependency(\.suggestionWidgetControllerDependency) var suggestionWidgetControllerDependency
    @Dependency(\.xcodeInspector) var xcodeInspector
    @Dependency(\.activatePreviousActiveXcode) var activatePreviouslyActiveXcode
    @Dependency(\.activateThisApp) var activateExtensionService
    @Dependency(\.chatTabBuilderCollection) var chatTabBuilderCollection
    @Dependency(\.chatTabPool) var chatTabPool

    @MainActor func toggleFullScreen() {
        let window = suggestionWidgetControllerDependency.windowsController?.windows
            .chatPanelWindow
        window?.toggleFullScreen(nil)
    }

    public var body: some ReducerOf<Self> {
        Reduce {
            state, action in
            switch action {
            case .hideButtonClicked:
                state.isPanelDisplayed = false

                if state.isFullScreen {
                    return .run { _ in
                        await MainActor.run { toggleFullScreen() }
                        activatePreviouslyActiveXcode()
                    }
                }

                return .run { _ in
                    activatePreviouslyActiveXcode()
                }

            case .closeActiveTabClicked:
                if let id = state.currentChatWorkspace?.selectedTabId {
                    return .run { send in
                        await send(.closeTabButtonClicked(id: id))
                    }
                }

                state.isPanelDisplayed = false
                return .none

            case .toggleChatPanelDetachedButtonClicked:
                if state.isFullScreen,
                   state.isDetached {
                    return .run { send in
                        await send(.attachChatPanel)
                    }
                }

                state.isDetached.toggle()
                return .none

            case .detachChatPanel:
                state.isDetached = true
                return .none

            case .attachChatPanel:
                if state.isFullScreen {
                    return .run { send in
                        await MainActor.run { toggleFullScreen() }
                        try await Task.sleep(nanoseconds: 1000000000)
                        await send(.attachChatPanel)
                    }
                }

                state.isDetached = false
                return .none

            case .enterFullScreen:
                state.isFullScreen = true
                return .run { send in
                    await send(.detachChatPanel)
                }

            case .exitFullScreen:
                state.isFullScreen = false
                return .none

            case let .presentChatPanel(forceDetach):
                if forceDetach {
                    state.isDetached = true
                }
                state.isPanelDisplayed = true
                return .run { send in
                    activateExtensionService()
                    await send(.focusActiveChatTab)
                }
            case let .switchWorkspace(path, name, username):
                state.chatHistory.selectedWorkspacePath = path
                state.chatHistory.selectedWorkspaceName = name
                state.chatHistory.currentUsername = username
                if state.chatHistory.currentChatWorkspace == nil {
                    let identifier = WorkspaceIdentifier(path: path, username: username)
                    state.chatHistory.addWorkspace(
                        ChatWorkspace(id: identifier) { chatTabPool.removeTab(of: $0) }
                    )
                }
                return .none
            case .openSettings:
                try? launchHostAppSettings()
                return .none
            case let .updateChatHistory(chatWorkspace):
                state.chatHistory.updateHistory(chatWorkspace)
                return .none
//            case let .updateChatTabInfo(chatTabInfo):
//                let previousSelectedIndex = state.chatTabGroup.tabInfo
//                    .firstIndex(where: { $0.id == state.chatTabGroup.selectedTabId })
//                state.chatTabGroup.tabInfo = chatTabInfo
//                if !chatTabInfo.contains(where: { $0.id == state.chatTabGroup.selectedTabId }) {
//                    if let previousSelectedIndex {
//                        let proposedSelectedIndex = previousSelectedIndex - 1
//                        if proposedSelectedIndex >= 0,
//                           proposedSelectedIndex < chatTabInfo.endIndex
//                        {
//                            state.chatTabGroup.selectedTabId = chatTabInfo[proposedSelectedIndex].id
//                        } else {
//                            state.chatTabGroup.selectedTabId = chatTabInfo.first?.id
//                        }
//                    } else {
//                        state.chatTabGroup.selectedTabId = nil
//                    }
//                }
//                return .none

            case let .closeTabButtonClicked(id):
                guard var currentChatWorkspace = state.currentChatWorkspace else {
                    return .none
                }
                let firstIndex = currentChatWorkspace.tabInfo.firstIndex { $0.id == id }
                let nextIndex = {
                    guard let firstIndex else { return 0 }
                    let nextIndex = firstIndex - 1
                    return max(nextIndex, 0)
                }()
                currentChatWorkspace.tabInfo.removeAll { $0.id == id }
                if currentChatWorkspace.tabInfo.isEmpty {
                    state.isPanelDisplayed = false
                }
                if nextIndex < currentChatWorkspace.tabInfo.count {
                    currentChatWorkspace.selectedTabId = currentChatWorkspace.tabInfo[nextIndex].id
                } else {
                    currentChatWorkspace.selectedTabId = nil
                }
                state.chatHistory.updateHistory(currentChatWorkspace)
                return .none

            case let .chatHistoryDeleteButtonClicked(id):
                // the current chat should not be deleted
                guard var currentChatWorkspace = state.currentChatWorkspace,
                      id != currentChatWorkspace.selectedTabId else {
                    return .none
                }
                let CLSConversationID = currentChatWorkspace.tabInfo.first {
                    $0.id == id
                }?.CLSConversationID
                currentChatWorkspace.tabInfo.removeAll { $0.id == id }
                state.chatHistory.updateHistory(currentChatWorkspace)

                let chatWorkspace = currentChatWorkspace
                return .run { send in
                    await send(.deleteChatTabInfo(id: id, chatWorkspace))
                    await ToolAutoApprovalManager.shared.clearConversationData(conversationId: CLSConversationID)
                }

//            case .createNewTapButtonHovered:
//                state.chatTabGroup.tabCollection = chatTabBuilderCollection()
//                return .none

            case .createNewTapButtonClicked:
                return .none // handled in GUI Reducer

            case .restoreTabByInfo:
                return .none // handled in GUI Reducer

            case .createNewTabByID:
                return .none // handled in GUI Reducer

            case let .tabClicked(id):
                guard var currentChatWorkspace = state.currentChatWorkspace,
                      var chatTabInfo = currentChatWorkspace.tabInfo.first(where: { $0.id == id }) else {
//                    chatTabGroup.selectedTabId = nil
                    return .none
                }

                let (originalTab, currentTab) = currentChatWorkspace.switchTab(to: &chatTabInfo)
                state.chatHistory.updateHistory(currentChatWorkspace)

                let workspace = currentChatWorkspace
                return .run { send in
                    await send(.focusActiveChatTab)
                    await send(.saveChatTabInfo([originalTab, currentTab], workspace))
                    await send(.syncChatTabInfo([originalTab, currentTab]))
                }

            case let .chatHistoryItemClicked(id):
                guard var chatWorkspace = state.currentChatWorkspace,
                      // No Need to swicth selected Tab when already selected
                      id != chatWorkspace.selectedTabId
                else { return .none }

                // Try to find the tab in three places:
                // 1. In current workspace's open tabs
                let existingTab = chatWorkspace.tabInfo.first(where: { $0.id == id })

                // 2. In persistent storage
                let storedTab = existingTab == nil
                    ? ChatTabInfoStore.getByID(id, with: .init(workspacePath: chatWorkspace.workspacePath, username: chatWorkspace.username))
                    : nil

                if var tabInfo = existingTab ?? storedTab {
                    // Tab found in workspace or storage - switch to it
                    let (originalTab, currentTab) = chatWorkspace.switchTab(to: &tabInfo)
                    state.chatHistory.updateHistory(chatWorkspace)

                    let workspace = chatWorkspace
                    let info = tabInfo
                    return .run { send in
                        // For stored tabs that aren't in the workspace yet, restore them first
                        if storedTab != nil {
                            await send(.restoreTabByInfo(info: info))
                        }

                        // as converstaion tab is lazy restore
                        // should restore tab when switching
                        if let chatTab = chatTabPool.getTab(of: id),
                           let conversationTab = chatTab as? ConversationTab {
                            await conversationTab.restoreIfNeeded()
                        }

                        await send(.saveChatTabInfo([originalTab, currentTab], workspace))

                        await send(.syncChatTabInfo([originalTab, currentTab]))
                    }
                }

                // 3. Tab not found - create a new one
                return .run { send in
                    await send(.createNewTabByID(id: id))
                }

            case var .appendAndSelectTab(tab):
                guard var chatWorkspace = state.currentChatWorkspace,
                      !chatWorkspace.tabInfo.contains(where: { $0.id == tab.id })
                else { return .none }

                chatWorkspace.tabInfo.append(tab)
                let (originalTab, currentTab) = chatWorkspace.switchTab(to: &tab)
                state.chatHistory.updateHistory(chatWorkspace)

                let currentChatWorkspace = chatWorkspace
                return .run { send in
                    await send(.focusActiveChatTab)
                    await send(.saveChatTabInfo([originalTab, currentTab], currentChatWorkspace))
                    await send(.scheduleLRUCleanup(currentChatWorkspace))
                    await send(.syncChatTabInfo([originalTab, currentTab]))
                }
            case .appendTabToWorkspace(var tab, let chatWorkspace):
                guard !chatWorkspace.tabInfo.contains(where: { $0.id == tab.id })
                else { return .none }
                var targetWorkspace = chatWorkspace
                targetWorkspace.tabInfo.append(tab)
                let (originalTab, currentTab) = targetWorkspace.switchTab(to: &tab)
                state.chatHistory.updateHistory(targetWorkspace)

                let currentChatWorkspace = targetWorkspace
                return .run { send in
                    await send(.saveChatTabInfo([originalTab, currentTab], currentChatWorkspace))
                    await send(.scheduleLRUCleanup(currentChatWorkspace))
                    await send(.syncChatTabInfo([originalTab, currentTab]))
                }

//            case .switchToNextTab:
//                let selectedId = state.chatTabGroup.selectedTabId
//                guard let index = state.chatTabGroup.tabInfo
//                    .firstIndex(where: { $0.id == selectedId })
//                else { return .none }
//                let nextIndex = index + 1
//                if nextIndex >= state.chatTabGroup.tabInfo.endIndex {
//                    return .none
//                }
//                let targetId = state.chatTabGroup.tabInfo[nextIndex].id
//                state.chatTabGroup.selectedTabId = targetId
//                return .run { send in
//                    await send(.focusActiveChatTab)
//                }

//            case .switchToPreviousTab:
//                let selectedId = state.chatTabGroup.selectedTabId
//                guard let index = state.chatTabGroup.tabInfo
//                    .firstIndex(where: { $0.id == selectedId })
//                else { return .none }
//                let previousIndex = index - 1
//                if previousIndex < 0 || previousIndex >= state.chatTabGroup.tabInfo.endIndex {
//                    return .none
//                }
//                let targetId = state.chatTabGroup.tabInfo[previousIndex].id
//                state.chatTabGroup.selectedTabId = targetId
//                return .run { send in
//                    await send(.focusActiveChatTab)
//                }

//            case let .moveChatTab(from, to):
//                guard from >= 0, from < state.chatTabGroup.tabInfo.endIndex, to >= 0,
//                      to <= state.chatTabGroup.tabInfo.endIndex
//                else {
//                    return .none
//                }
//                let tab = state.chatTabGroup.tabInfo[from]
//                state.chatTabGroup.tabInfo.remove(at: from)
//                state.chatTabGroup.tabInfo.insert(tab, at: to)
//                return .none

            case .focusActiveChatTab:
                guard FeatureFlagNotifierImpl.shared.featureFlags.chat else {
                    return .none
                }
                let id = state.currentChatWorkspace?.selectedTabInfo?.id
                guard let id else { return .none }
                return .run { send in
                    await send(.chatTab(id: id, action: .focus))
                }

//            case let .chatTab(id, .close):
//                return .run { send in
//                    await send(.closeTabButtonClicked(id: id))
//                }

            // MARK: - ChatTabItem action

            case let .chatTab(id, .tabContentUpdated):
                guard var currentChatWorkspace = state.currentChatWorkspace,
                      var info = state.currentChatWorkspace?.tabInfo[id: id]
                else { return .none }

                info.updatedAt = .now
                currentChatWorkspace.tabInfo[id: id] = info
                state.chatHistory.updateHistory(currentChatWorkspace)

                let chatTabInfo = info
                let chatWorkspace = currentChatWorkspace
                return .run { send in
                    await send(.saveChatTabInfo([chatTabInfo], chatWorkspace))
                }

            case let .chatTab(id, .setCLSConversationID(CID)):
                guard var currentChatWorkspace = state.currentChatWorkspace,
                      var info = state.currentChatWorkspace?.tabInfo[id: id]
                else { return .none }

                info.CLSConversationID = CID
                currentChatWorkspace.tabInfo[id: id] = info
                state.chatHistory.updateHistory(currentChatWorkspace)

                let chatTabInfo = info
                let chatWorkspace = currentChatWorkspace
                return .run { send in
                    await send(.saveChatTabInfo([chatTabInfo], chatWorkspace))
                }

            case let .chatTab(id, .updateTitle(title)):
                guard var currentChatWorkspace = state.currentChatWorkspace,
                      var info = state.currentChatWorkspace?.tabInfo[id: id],
                      !info.isTitleSet
                else { return .none }

                info.title = title
                info.updatedAt = .now
                currentChatWorkspace.tabInfo[id: id] = info
                state.chatHistory.updateHistory(currentChatWorkspace)

                let chatTabInfo = info
                let chatWorkspace = currentChatWorkspace
                return .run { send in
                    await send(.saveChatTabInfo([chatTabInfo], chatWorkspace))
                }

            case .chatTab:
                return .none

            // MARK: - Persist

            case let .saveChatTabInfo(chatTabInfos, chatWorkspace):
                let toSaveInfo = chatTabInfos.compactMap { $0 }
                guard toSaveInfo.count > 0 else { return .none }
                let workspacePath = chatWorkspace.workspacePath
                let username = chatWorkspace.username

                return .run { _ in
                    Task(priority: .background) {
                        ChatTabInfoStore.saveAll(toSaveInfo, with: .init(workspacePath: workspacePath, username: username))
                    }
                }

            case let .deleteChatTabInfo(id, chatWorkspace):
                let workspacePath = chatWorkspace.workspacePath
                let username = chatWorkspace.username

                ChatTabInfoStore.delete(by: id, with: .init(workspacePath: workspacePath, username: username))
                return .none
            case var .restoreWorkspace(chatWorkspace):
                // chat opened before finishing restoration
                if var existChatWorkspace = state.chatHistory.workspaces[id: chatWorkspace.id] {
                    if var selectedChatTabInfo = chatWorkspace.tabInfo.first(where: { $0.id == chatWorkspace.selectedTabId }) {
                        // Keep the selection state when restoring
                        selectedChatTabInfo.isSelected = true
                        chatWorkspace.tabInfo[id: selectedChatTabInfo.id] = selectedChatTabInfo

                        // Update the existing workspace's selected tab to match
                        existChatWorkspace.selectedTabId = selectedChatTabInfo.id

                        // merge tab info
                        existChatWorkspace.tabInfo.append(contentsOf: chatWorkspace.tabInfo)
                        state.chatHistory.updateHistory(existChatWorkspace)

                        let chatTabInfo = selectedChatTabInfo
                        let workspace = existChatWorkspace
                        return .run { send in
                            // update chat tab info
                            await send(.saveChatTabInfo([chatTabInfo], workspace))
                            await send(.scheduleLRUCleanup(workspace))
                        }
                    }

                    // merge tab info
                    existChatWorkspace.tabInfo.append(contentsOf: chatWorkspace.tabInfo)
                    state.chatHistory.updateHistory(existChatWorkspace)

                    let workspace = existChatWorkspace
                    return .run { send in
                        await send(.scheduleLRUCleanup(workspace))
                    }
                }

                state.chatHistory.addWorkspace(chatWorkspace)
                return .none

            case let .syncChatTabInfo(tabInfos):
                for tabInfo in tabInfos {
                    guard let tabInfo = tabInfo else { continue }
                    if let conversationTab = chatTabPool.getTab(of: tabInfo.id) as? ConversationTab {
                        conversationTab.updateChatTabInfo(tabInfo)
                    }
                }
                return .none

            // MARK: - Clean up ChatWorkspace

            case let .scheduleLRUCleanup(chatWorkspace):
                return .run { send in
                    await send(.performLRUCleanup(chatWorkspace))
                }.cancellable(id: "lru-cleanup-\(chatWorkspace.id)", cancelInFlight: true) // apply built-in race condition prevention

            case var .performLRUCleanup(chatWorkspace):
                chatWorkspace.applyLRULimit()
                state.chatHistory.updateHistory(chatWorkspace)
                return .none
            }
        }
//        .forEach(\.chatGroupCollection.selectedChatGroup?.tabInfo, action: /Action.chatTab) {
//            ChatTabItem()
//        }
    }
}

extension ChatPanelFeature {
    func restoreConversationTabIfNeeded(_ id: String) async {
        if let chatTab = chatTabPool.getTab(of: id),
           let conversationTab = chatTab as? ConversationTab {
            await conversationTab.restoreIfNeeded()
        }
    }
}

extension ChatWorkspace {
    public mutating func switchTab(to chatTabInfo: inout ChatTabInfo) -> (originalTab: ChatTabInfo?, currentTab: ChatTabInfo) {
        guard selectedTabId != chatTabInfo.id else { return (nil, chatTabInfo) }

        // get original selected tab info to update its isSelected
        var originalTabInfo: ChatTabInfo?
        if selectedTabId != nil {
            originalTabInfo = tabInfo[id: selectedTabId!]
        }

        // fresh selected info in chatWorksapce and tabInfo
        selectedTabId = chatTabInfo.id
        originalTabInfo?.isSelected = false
        chatTabInfo.isSelected = true

        // update tab back to chatWorkspace
        let isNewTab = tabInfo[id: chatTabInfo.id] == nil
        tabInfo[id: chatTabInfo.id] = chatTabInfo
        if isNewTab {
            applyLRULimit()
        }

        if let originalTabInfo {
            tabInfo[id: originalTabInfo.id] = originalTabInfo
        }

        return (originalTabInfo, chatTabInfo)
    }
}
