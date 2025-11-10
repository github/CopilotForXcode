import AppKit
import Combine
import ComposableArchitecture
import ConversationServiceProvider
import MarkdownUI
import ChatAPIService
import SharedUIComponents
import SwiftUI
import ChatService
import SwiftUIFlowLayout
import XcodeInspector
import ChatTab
import Workspace
import Persist
import UniformTypeIdentifiers
import Status
import GitHubCopilotService
import GitHubCopilotViewModel
import LanguageServerProtocol

private let r: Double = 4

public struct ChatPanel: View {
    @Perception.Bindable var chat: StoreOf<Chat>
    @Namespace var inputAreaNamespace

    public var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                
                if chat.history.isEmpty {
                    VStack {
                        Spacer()
                        Instruction(isAgentMode: $chat.isAgentMode)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ChatPanelMessages(chat: chat)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Chat Messages Group")

                    if chat.isAgentMode, let handOffs = chat.selectedAgent.handOffs, !handOffs.isEmpty, 
                       chat.history.contains(where: { $0.role == .assistant && $0.turnStatus != .inProgress }),
                       !chat.handOffClicked {
                        ChatHandOffs(chat: chat)
                            .scaledPadding(.vertical, 8)
                            .scaledPadding(.horizontal, 16)
                            .dimWithExitEditMode(chat)
                    } else if let _ = chat.history.last?.followUp {
                        ChatFollowUp(chat: chat)
                            .scaledPadding(.vertical, 8)
                            .scaledPadding(.horizontal, 16)
                            .dimWithExitEditMode(chat)
                    }
                }
                
                if chat.fileEditMap.count > 0 {
                    WorkingSetView(chat: chat)
                        .dimWithExitEditMode(chat)
                        .scaledPadding(.horizontal, 16)
                }
                
                ChatPanelInputArea(chat: chat, r: r, editorMode: .input)
                    .dimWithExitEditMode(chat)
                    .scaledPadding(.horizontal, 16)
            }
            .scaledPadding(.vertical, 12)
            .background(Color.chatWindowBackgroundColor)
            .onAppear {
                chat.send(.appear)
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                onFileDrop(providers)
            }
        }
    }
    
    private func onFileDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileManager = FileManager.default
        
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                    let url: URL? = {
                        if let data = item as? Data {
                            return URL(dataRepresentation: data, relativeTo: nil)
                        } else if let url = item as? URL {
                            return url
                        }
                        return nil
                    }()
                    
                    guard let url else { return }
                    
                    var isDirectory: ObjCBool = false
                    if let isValidFile = try? WorkspaceFile.isValidFile(url), isValidFile {
                        DispatchQueue.main.async {
                            let fileReference = ConversationFileReference(url: url, isCurrentEditor: false)
                            chat.send(.addReference(.file(fileReference)))
                        }
                    } else if let data = try? Data(contentsOf: url),
                        ["png", "jpeg", "jpg", "bmp", "gif", "tiff", "tif", "webp"].contains(url.pathExtension.lowercased()) {
                        DispatchQueue.main.async {
                            chat.send(.addSelectedImage(ImageReference(data: data, fileUrl: url)))
                        }
                    } else if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                        DispatchQueue.main.async {
                            chat.send(.addReference(.directory(.init(url: url))))
                        }
                    }
                }
            }
        }
        
        return true
    }
}



private struct ScrollViewOffsetPreferenceKey: PreferenceKey {
    static var defaultValue = CGFloat.zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

private struct ListHeightPreferenceKey: PreferenceKey {
    static var defaultValue = CGFloat.zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()
    }
}

struct ChatPanelMessages: View {
    let chat: StoreOf<Chat>
    @State var cancellable = Set<AnyCancellable>()
    @State var isScrollToBottomButtonDisplayed = true
    @State var isPinnedToBottom = true
    @Namespace var bottomID
    @Namespace var topID
    @Namespace var scrollSpace
    @State var scrollOffset: Double = 0
    @State var listHeight: Double = 0
    @State var didScrollToBottomOnAppearOnce = false
    @State var isBottomHidden = true
    @Environment(\.isEnabled) var isEnabled
    @AppStorage(\.fontScale) private var fontScale: Double

    var body: some View {
        WithPerceptionTracking {
            ScrollViewReader { proxy in
                GeometryReader { listGeo in
                    List {
                        Group {

                            ChatHistory(chat: chat)
                                .fixedSize(horizontal: false, vertical: true)

                            ExtraSpacingInResponding(chat: chat)

                            Spacer(minLength: 12)
                                .id(bottomID)
                                .listRowInsets(EdgeInsets())
                                .onAppear {
                                    isBottomHidden = false
                                    if !didScrollToBottomOnAppearOnce {
                                        proxy.scrollTo(bottomID, anchor: .bottom)
                                        didScrollToBottomOnAppearOnce = true
                                    }
                                }
                                .onDisappear {
                                    isBottomHidden = true
                                }
                                .background(GeometryReader { geo in
                                    let offset = geo.frame(in: .named(scrollSpace)).minY
                                    Color.clear.preference(
                                        key: ScrollViewOffsetPreferenceKey.self,
                                        value: offset
                                    )
                                })
                        }
                        .modify { view in
                            if #available(macOS 13.0, *) {
                                view
                                    .listRowSeparator(.hidden)
                            } else {
                                view
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scaledPadding(.leading, 8)
                    .listRowBackground(EmptyView())
                    .modify { view in
                        if #available(macOS 13.0, *) {
                            view.scrollContentBackground(.hidden)
                        } else {
                            view
                        }
                    }
                    .coordinateSpace(name: scrollSpace)
                    .preference(
                        key: ListHeightPreferenceKey.self,
                        value: listGeo.size.height
                    )
                    .onPreferenceChange(ListHeightPreferenceKey.self) { value in
                        listHeight = value
                        updatePinningState()
                    }
                    .onPreferenceChange(ScrollViewOffsetPreferenceKey.self) { value in
                        scrollOffset = value
                        updatePinningState()
                    }
                    .overlay(alignment: .bottomTrailing) {
                        scrollToBottomButton(proxy: proxy)
                            .scaledPadding(4)
                    }
                    .background {
                        PinToBottomHandler(
                            chat: chat,
                            isBottomHidden: isBottomHidden,
                            pinnedToBottom: $isPinnedToBottom
                        ) {
                            proxy.scrollTo(bottomID, anchor: .bottom)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                    .task {
                        proxy.scrollTo(bottomID, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                trackScrollWheel()
            }
            .onDisappear {
                cancellable.forEach { $0.cancel() }
                cancellable = []
            }
        }
    }

    func trackScrollWheel() {
        NSApplication.shared.publisher(for: \.currentEvent)
            .filter {
                if !isEnabled { return false }
                return $0?.type == .scrollWheel
            }
            .compactMap { $0 }
            .sink { event in
                guard isPinnedToBottom else { return }
                let delta = event.deltaY
                let scrollUp = delta > 0
                if scrollUp {
                    isPinnedToBottom = false
                }
            }
            .store(in: &cancellable)
    }

    private let listRowSpacing: CGFloat = 32
    private let scrollButtonBuffer: CGFloat = 32
    
    @MainActor
    func updatePinningState() {
        // where does the 32 come from?
        withAnimation(.linear(duration: 0.1)) {
            // Ensure listHeight is greater than 0 to avoid invalid calculations or division by zero.
            // This guard clause prevents unnecessary updates when the list height is not yet determined.
            guard listHeight > 0 else {
                isScrollToBottomButtonDisplayed = false
                return
            }
            
            isScrollToBottomButtonDisplayed = scrollOffset > listHeight + (listRowSpacing + scrollButtonBuffer) * fontScale
        }
    }

    @ViewBuilder
    func scrollToBottomButton(proxy: ScrollViewProxy) -> some View {
        Button(action: {
            isPinnedToBottom = true
            withAnimation(.easeInOut(duration: 0.1)) {
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
        }) {
            Image(systemName: "chevron.down")
                .scaledFrame(width: 12, height: 12)
                .scaledPadding(4)
                .background {
                    Circle()
                        .fill(Color.chatWindowBackgroundColor)
                }
                .overlay {
                    Circle().stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                }
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.downArrow, modifiers: [.command])
        .opacity(isScrollToBottomButtonDisplayed ? 1 : 0)
        .help("Scroll Down")
    }

    struct ExtraSpacingInResponding: View {
        let chat: StoreOf<Chat>
        
        @AppStorage(\.fontScale) private var fontScale: Double

        var body: some View {
            WithPerceptionTracking {
                if chat.isReceivingMessage {
                    Spacer(minLength: 12 * fontScale)
                }
            }
        }
    }

    struct PinToBottomHandler: View {
        let chat: StoreOf<Chat>
        let isBottomHidden: Bool
        @Binding var pinnedToBottom: Bool
        let scrollToBottom: () -> Void

        @State var isInitialLoad = true
        
        var body: some View {
            WithPerceptionTracking {
                EmptyView()
                    .onChange(of: chat.isReceivingMessage) { isReceiving in
                        if isReceiving {
                            Task {
                                pinnedToBottom = true
                                await Task.yield()
                                withAnimation(.easeInOut(duration: 0.1)) {
                                    scrollToBottom()
                                }
                            }
                        } else {
                            Task {
                                // Scoll to bottom when `isReceiving` changes to `false`
                                if pinnedToBottom {
                                    await Task.yield()
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        scrollToBottom()
                                    }
                                }
                                pinnedToBottom = false
                            }
                        }
                    }
                    .onChange(of: chat.history.last) { _ in
                        if pinnedToBottom || isInitialLoad {
                            if isInitialLoad {
                                isInitialLoad = false
                            }
                            Task {
                                await Task.yield()
                                if !chat.editorMode.isEditingUserMessage {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        scrollToBottom()
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: isBottomHidden) { value in
                        // This is important to prevent it from jumping to the top!
                        if value, pinnedToBottom {
                            scrollToBottom()
                        }
                    }
            }
        }
    }
}

struct ChatHistory: View {
    let chat: StoreOf<Chat>
    
    var filteredHistory: [DisplayedChatMessage] {
        guard let pendingCheckpointMessageId = chat.pendingCheckpointMessageId else {
            return chat.history
        }
        
        if let checkPointMessageIndex = chat.history.firstIndex(where: { $0.id == pendingCheckpointMessageId }) {
            return Array(chat.history.prefix(checkPointMessageIndex + 1))
        }
        
        return chat.history
    }
    
    var editUserMessageEffectedMessageIds: Set<String> {
        Set(chat.editUserMessageEffectedMessages.map { $0.id })
    }

    var body: some View {
        WithPerceptionTracking {
            let currentFilteredHistory = filteredHistory
            let pendingCheckpointMessageId = chat.pendingCheckpointMessageId
            
            VStack(spacing: 16) {
                ForEach(Array(currentFilteredHistory.enumerated()), id: \.element.id) { index, message in
                    VStack(spacing: 8) {
                        WithPerceptionTracking {
                            ChatHistoryItem(chat: chat, message: message)
                                .id(message.id)
                        }
                        
                        if message.role != .ignored && index < currentFilteredHistory.count - 1 {
                            if message.role == .assistant && message.parentTurnId == nil {
                                let nextMessage = currentFilteredHistory[index + 1]
                                let hasContent = !message.text.isEmpty || !message.editAgentRounds.isEmpty
                                let nextIsNotSubturn = nextMessage.parentTurnId != message.id
                                
                                if hasContent && nextIsNotSubturn {
                                    CheckPoint(chat: chat, messageId: message.id)
                                        .padding(.vertical, 8)
                                        .padding(.trailing, 8)
                                }
                            }
                        }
                        
                        // Show up check point for redo
                        if message.id == pendingCheckpointMessageId {
                            CheckPoint(chat: chat, messageId: message.id)
                                .padding(.vertical, 8)
                                .padding(.trailing, 8)
                        }
                    }
                    .dimWithExitEditMode(
                        chat,
                        applyTo: message.id,
                        isDimmed: editUserMessageEffectedMessageIds.contains(message.id),
                        allowTapToExit: chat.editorMode.isEditingUserMessage && chat.editorMode.editingUserMessageId != message.id
                    )
                }
            }
        }
    }
}

struct ChatHistoryItem: View {
    let chat: StoreOf<Chat>
    let message: DisplayedChatMessage

    var body: some View {
        WithPerceptionTracking {
            let text = message.text
            switch message.role {
            case .user:
                UserMessage(
                    id: message.id,
                    text: text,
                    imageReferences: message.imageReferences,
                    chat: chat,
                    editorCornerRadius: r,
                    requestType: message.requestType
                )
                .scaledPadding(.leading, chat.editorMode.isEditingUserMessage && chat.editorMode.editingUserMessageId == message.id ? 0 : 20)
                .scaledPadding(.trailing, 8)
            case .assistant:
                BotMessage(
                    message: message,
                    chat: chat
                )
                .scaledPadding(.trailing, 20)
            case .ignored:
                EmptyView()
            }
        }
    }
}

struct ChatFollowUp: View {
    let chat: StoreOf<Chat>
    @AppStorage(\.chatFontSize) var chatFontSize
    
    var body: some View {
        WithPerceptionTracking {
            HStack {
                if let followUp = chat.history.last?.followUp {
                    Button(action: {
                        chat.send(.followUpButtonClicked(UUID().uuidString, followUp.message))
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .scaledFont(.body)
                                .foregroundColor(.blue)
                            
                            Text(followUp.message)
                                .scaledFont(size: chatFontSize)
                                .foregroundColor(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .onHover { isHovered in
                        DispatchQueue.main.async {
                            if isHovered {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                    .onDisappear {
                        NSCursor.pop()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ChatHandOffs: View {
    let chat: StoreOf<Chat>
    @AppStorage(\.chatFontSize) var chatFontSize

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading) {
                Text("PROCEED FROM \(chat.selectedAgent.name.uppercased())")
                    .foregroundStyle(.secondary)
                    .scaledPadding(.horizontal, 4)
                    .scaledPadding(.bottom, -4)

                FlowLayout(mode: .vstack, items: chat.selectedAgent.handOffs ?? [], itemSpacing: 4) { item in
                    Button(action: {
                        chat.send(.handOffButtonClicked(item))
                    }) {
                        Text(item.label)
                    }
                    .buttonStyle(.bordered)
                    .onHover { isHovered in
                        DispatchQueue.main.async {
                            if isHovered {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                    .onDisappear {
                        NSCursor.pop()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ChatCLSError: View {
    let chat: StoreOf<Chat>
    @AppStorage(\.chatFontSize) var chatFontSize
    
    var body: some View {
        WithPerceptionTracking {
            HStack(alignment: .top) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.blue)
                    .padding(.leading, 8)
                
                Text("Monthly chat limit reached. [Upgrade now](https://github.com/github-copilot/signup/copilot_individual) or wait until your usage resets.")
                    .font(.system(size: chatFontSize))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .background(
                RoundedCorners(tl: r, tr: r, bl: 0, br: 0)
                    .fill(.ultraThickMaterial)
            )
            .overlay(
                RoundedCorners(tl: r, tr: r, bl: 0, br: 0)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .padding(.top, 4)
        }
    }
}

extension URL {
    func getPathRelativeToHome() -> String {
        let filePath = self.path
        guard !filePath.isEmpty else { return "" }
        
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        if !homeDirectory.isEmpty {
            return filePath.replacingOccurrences(of: homeDirectory, with: "~")
        }
        
        return filePath
    }
}
// MARK: - Previews

struct ChatPanel_Preview: PreviewProvider {
    static let history: [DisplayedChatMessage] = [
        .init(
            id: "1",
            role: .user,
            text: "**Hello**",
            references: [],
            requestType: .conversation
        ),
        .init(
            id: "2",
            role: .assistant,
            text: """
            ```swift
            func foo() {}
            ```
            **Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?
            """,
            references: [
                .init(
                    uri: "Hi Hi Hi Hi",
                    status: .included,
                    kind: .class,
                    referenceType: .file
                ),
            ],
            requestType: .conversation
        ),
        .init(
            id: "7",
            role: .ignored,
            text: "Ignored",
            references: [],
            requestType: .conversation
        ),
        .init(
            id: "5",
            role: .assistant,
            text: "Yooo",
            references: [],
            requestType: .conversation
        ),
        .init(
            id: "4",
            role: .user,
            text: "Yeeeehh",
            references: [],
            requestType: .conversation
        ),
        .init(
            id: "3",
            role: .user,
            text: #"""
            Please buy me a coffee!
            | Coffee | Milk |
            |--------|------|
            | Espresso | No |
            | Latte | Yes |

            ```swift
            func foo() {}
            ```
            ```objectivec
            - (void)bar {}
            ```
            """#,
            references: [],
            followUp: .init(message: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce turpis dolor, malesuada quis fringilla sit amet, placerat at nunc. Suspendisse orci tortor, tempor nec blandit a, malesuada vel tellus. Nunc sed leo ligula. Ut at ligula eget turpis pharetra tristique. Integer luctus leo non elit rhoncus fermentum.", id: "3", type: "type"),
            requestType: .conversation
        ),
    ]
    
    static let chatTabInfo = ChatTabInfo(id: "", workspacePath: "path", username: "name")

    static var previews: some View {
        ChatPanel(chat: .init(
            initialState: .init(history: ChatPanel_Preview.history, isReceivingMessage: true),
            reducer: { Chat(service: ChatService.service(for: chatTabInfo)) }
        ))
        .frame(width: 450, height: 1200)
        .colorScheme(.dark)
    }
}

struct ChatPanel_EmptyChat_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(chat: .init(
            initialState: .init(history: [DisplayedChatMessage](), isReceivingMessage: false),
            reducer: { Chat(service: ChatService.service(for: ChatPanel_Preview.chatTabInfo)) }
        ))
        .padding()
        .frame(width: 450, height: 600)
        .colorScheme(.dark)
    }
}

struct ChatPanel_InputText_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(chat: .init(
            initialState: .init(history: ChatPanel_Preview.history, isReceivingMessage: false),
            reducer: { Chat(service: ChatService.service(for: ChatPanel_Preview.chatTabInfo)) }
        ))
        .padding()
        .frame(width: 450, height: 600)
        .colorScheme(.dark)
    }
}

struct ChatPanel_InputMultilineText_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(
            chat: .init(
                initialState: .init(
                    editorModeContexts: [Chat.EditorMode.input: ChatContext(
                        typedMessage: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce turpis dolor, malesuada quis fringilla sit amet, placerat at nunc. Suspendisse orci tortor, tempor nec blandit a, malesuada vel tellus. Nunc sed leo ligula. Ut at ligula eget turpis pharetra tristique. Integer luctus leo non elit rhoncus fermentum.")],
                    history: ChatPanel_Preview.history,
                    isReceivingMessage: false
                ),
                reducer: { Chat(service: ChatService.service(for: ChatPanel_Preview.chatTabInfo)) }
            )
        )
        .padding()
        .frame(width: 450, height: 600)
        .colorScheme(.dark)
    }
}

struct ChatPanel_Light_Preview: PreviewProvider {
    static var previews: some View {
        ChatPanel(chat: .init(
            initialState: .init(history: ChatPanel_Preview.history, isReceivingMessage: true),
            reducer: { Chat(service: ChatService.service(for: ChatPanel_Preview.chatTabInfo)) }
        ))
        .padding()
        .frame(width: 450, height: 600)
        .colorScheme(.light)
    }
}

