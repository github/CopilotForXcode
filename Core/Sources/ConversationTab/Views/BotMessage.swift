import ComposableArchitecture
import ChatService
import Foundation
import MarkdownUI
import SharedUIComponents
import SwiftUI
import ConversationServiceProvider
import ChatTab
import ChatAPIService

struct BotMessage: View {
    var r: Double { messageBubbleCornerRadius }
    let message: DisplayedChatMessage
    let chat: StoreOf<Chat>
    var id: String {
        message.id
    }
    var text: String { message.text }
    var references: [ConversationReference] { message.references }
    var followUp: ConversationFollowUp? { message.followUp }
    var errorMessages: [String] { message.errorMessages }
    var steps: [ConversationProgressStep] { message.steps }
    var editAgentRounds: [AgentRound] { message.editAgentRounds }
    var panelMessages: [CopilotShowMessageParams] { message.panelMessages }
    var codeReviewRound: CodeReviewRound? { message.codeReviewRound }
    
    @Environment(\.colorScheme) var colorScheme
    @AppStorage(\.chatFontSize) var chatFontSize

    @State var isReferencesPresented = false
    @State var isHovering = false
    
    struct ResponseToolBar: View {
        let id: String
        let chat: StoreOf<Chat>
        let text: String
        
        var body: some View {
            HStack(spacing: 4) {
                
                UpvoteButton { rating in
                    chat.send(.upvote(id, rating))
                }
                
                DownvoteButton { rating in
                    chat.send(.downvote(id, rating))
                }
                
                CopyButton {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    chat.send(.copyCode(id))
                }
            }
        }
    }
    
    struct ReferenceButton: View {
        var r: Double { messageBubbleCornerRadius }
        let references: [ConversationReference]
        let chat: StoreOf<Chat>
        
        @Binding var isReferencesPresented: Bool
        
        @State var isReferencesHovered = false
        
        @AppStorage(\.chatFontSize) var chatFontSize
        
        func MakeReferenceTitle(references: [ConversationReference]) -> String {
            guard !references.isEmpty else {
                return ""
            }
            
            let count = references.count
            let title = count > 1 ? "Used \(count) references" : "Used \(count) reference"
            return title
        }
        
        var referenceIcon: some View {
            Group {
                if !isReferencesPresented {
                    HStack(alignment: .center, spacing: 0) {
                        Image(systemName: "chevron.right")
                    }
                    .scaledPadding(.leading, 4)
                    .scaledPadding(.trailing, 3)
                    .scaledPadding(.vertical, 1.5)
                } else {
                    HStack(alignment: .center, spacing: 0) {
                        Image(systemName: "chevron.down")
                    }
                    .scaledPadding(.top, 4)
                    .scaledPadding(.bottom, 3)
                    .scaledPadding(.horizontal, 1.5)
                    
                }
            }
            .scaledFont(size: chatFontSize - 1, weight: .medium)
            .scaledFrame(width: 16, height: 16, alignment: .center)
        }
        
        var body: some View {
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: {
                        isReferencesPresented.toggle()
                    }, label: {
                        HStack(spacing: 4) {
                            referenceIcon
                            
                            Text(MakeReferenceTitle(references: references))
                                .scaledFont(size: chatFontSize - 1)
                        }
                        .foregroundStyle(.secondary)
                    })
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .padding(.trailing, 4)
                    .background {
                        RoundedRectangle(cornerRadius: r - 4)
                            .fill(isReferencesHovered ? Color.gray.opacity(0.2) : Color.clear)
                    }
                    .accessibilityValue(isReferencesPresented ? "Collapse" : "Expand")
                    
                    if isReferencesPresented {
                        ReferenceList(references: references, chat: chat)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.gray, lineWidth: 0.2)
                            )
                    }
                }
                .onHover {
                    isReferencesHovered = $0
                }
                
                Spacer()
            }
        }
    }

    var body: some View {
        WithPerceptionTracking {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    if !references.isEmpty {
                        WithPerceptionTracking {
                            ReferenceButton(
                                references: references,
                                chat: chat,
                                isReferencesPresented: $isReferencesPresented
                            )
                        }
                    }
                    
                    // progress step
                    if steps.count > 0 {
                        ProgressStep(steps: steps)
                        
                    }
                    
                    if !panelMessages.isEmpty {
                        WithPerceptionTracking {
                            ForEach(panelMessages.indices, id: \.self) { index in
                                FunctionMessage(text: panelMessages[index].message, chat: chat)
                            }
                        }
                    }
                    
                    if editAgentRounds.count > 0 {
                        ProgressAgentRound(rounds: editAgentRounds, chat: chat)
                    }
                    
                    if !text.isEmpty {
                        Group{
                            ThemedMarkdownText(text: text, chat: chat)
                        }
                        .scaledPadding(.leading, 2)
                        .scaledPadding(.vertical, 4)
                    }
                    
                    if let codeReviewRound = codeReviewRound {
                        CodeReviewMainView(
                            store: chat, round: codeReviewRound
                        )
                        .frame(maxWidth: .infinity)
                    }
                    
                    if !errorMessages.isEmpty {
                        VStack(spacing: 4) {
                            ForEach(errorMessages.indices, id: \.self) { index in
                                if let attributedString = try? AttributedString(markdown: errorMessages[index]) {
                                    NotificationBanner(style: .warning) {
                                        Text(attributedString)
                                    }
                                }
                            }
                        }
                        .scaledPadding(.vertical, 4)
                    }
                    
                    HStack {
                        if shouldShowTurnStatus() {
                            TurnStatusView(message: message)
                        }
                        
                        Spacer()
                        
                        ResponseToolBar(id: id, chat: chat, text: text)
                            .conditionalFontWeight(.medium)
                            .opacity(shouldShowToolBar() ? 1 : 0)
                            .scaledPadding(.trailing, -20)
                    }
                }
                .shadow(color: .black.opacity(0.05), radius: 6)
                .contextMenu {
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    }
                    .scaledFont(.body)
                    
                    Button("Set as Extra System Prompt") {
                        chat.send(.setAsExtraPromptButtonTapped(id))
                    }
                    .scaledFont(.body)
                    
                    Divider()
                    
                    Button("Delete") {
                        chat.send(.deleteMessageButtonTapped(id))
                    }
                    .scaledFont(.body)
                }
                .onHover {
                    isHovering = $0
                }
            }
        }
    }
    
    private func shouldShowTurnStatus() -> Bool {
        guard isLatestAssistantMessage() else {
            return false
        }
        
        if steps.isEmpty && editAgentRounds.isEmpty {
            return true
        }
        
        if !steps.isEmpty {
            return !message.text.isEmpty
        }
        
        return true
    }
    
    private func shouldShowToolBar() -> Bool {
        // Always show toolbar for historical messages
        if !isLatestAssistantMessage() { return isHovering }
        
        // For current message, only show toolbar when message is complete
        return !chat.isReceivingMessage
    }
    
    private func isLatestAssistantMessage() -> Bool {
        let lastMessage = chat.history.last
        return lastMessage?.role == .assistant && lastMessage?.id == id
    }
}

struct ReferenceList: View {
    let references: [ConversationReference]
    let chat: StoreOf<Chat>

    private let maxVisibleItems: Int = 6
    @State private var itemHeight: CGFloat = 16
    
    @AppStorage(\.chatFontSize) var chatFontSize
    
    struct ReferenceView: View {
        let references: [ConversationReference]
        let chat: StoreOf<Chat>
        @AppStorage(\.chatFontSize) var chatFontSize
        @Binding var itemHeight: CGFloat
        
        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<references.endIndex, id: \.self) { index in
                    WithPerceptionTracking {
                        let reference = references[index]

                        Button(action: {
                            chat.send(.referenceClicked(reference))
                        }) {
                            HStack(spacing: 8) {
                                drawFileIcon(reference.url, isDirectory: reference.isDirectory)
                                    .resizable()
                                    .scaledToFit()
                                    .scaledFrame(width: 14, height: 14)
                                Text(reference.fileName)
                                    .truncationMode(.middle)
                                    .lineLimit(1)
                                    .layoutPriority(1)
                                    .scaledFont(size: chatFontSize - 1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(HoverButtonStyle())
                        .background(GeometryReader { geometry in
                            Color.clear.onAppear {
                                itemHeight = geometry.size.height
                            }
                        })
                        .help(reference.getPathRelativeToHome())
                    }
                }
            }
        }
    }

    var body: some View {
        WithPerceptionTracking {
            if references.count <= maxVisibleItems {
                ReferenceView(references: references,  chat: chat, itemHeight: $itemHeight)
            } else {
                HoverScrollView {
                    ReferenceView(references: references,  chat: chat, itemHeight: $itemHeight)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: maxViewHeight)

    }
    
    private var maxViewHeight: CGFloat {
        let totalHeight = CGFloat(references.count) * itemHeight
        let maxHeight = CGFloat(maxVisibleItems) * itemHeight
        return min(totalHeight, maxHeight)
    }
}

private struct TurnStatusView: View {
    
    let message: DisplayedChatMessage
    
    @AppStorage(\.chatFontSize) var chatFontSize
    
    var body: some View {
        HStack(spacing: 0) {
            if let turnStatus = message.turnStatus {
                switch turnStatus {
                case .inProgress:
                    inProgressStatus
                case .success:
                    completedStatus
                case .cancelled:
                    cancelStatus
                case .error:
                    EmptyView()
                case .waitForConfirmation:
                    waitForConfirmationStatus
                }
                
                Spacer()
            }
        }
    }
    
    private var inProgressStatus: some View {
        HStack(spacing: 4) {
            ProgressView()
                .controlSize(.small)
                .scaledFont(size: chatFontSize - 1)
                .conditionalFontWeight(.medium)
            
            Text("Generating...")
                .scaledFont(size: chatFontSize - 1)
                .foregroundColor(.secondary)
        }
    }
    
    private var completedStatus: some View {
        statusView(icon: "checkmark.circle.fill", iconColor: .successLightGreen, text: "Completed")
    }
    
    private var waitForConfirmationStatus: some View {
        statusView(icon: "clock.fill", iconColor: .brown, text: "Waiting for your response")
    }
    
    private var cancelStatus: some View {
        statusView(icon: "slash.circle", iconColor: .secondary, text: "Stopped")
    }
    
    private var errorStatus: some View {
        statusView(icon: "xmark.circle.fill", iconColor: .red, text: "Error Occurred")
    }
    
    private func statusView(icon: String, iconColor: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .scaledFont(size: chatFontSize)
                .foregroundColor(iconColor)
                .conditionalFontWeight(.medium)
            
            Text(text)
                .scaledFont(size: chatFontSize - 1)
                .foregroundColor(.secondary)
        }
    }
}

struct BotMessage_Previews: PreviewProvider {
    static let steps: [ConversationProgressStep] = [
        .init(id: "001", title: "running step", description: "this is running step", status: .running, error: nil),
        .init(id: "002", title: "completed step", description: "this is completed step", status: .completed, error: nil),
        .init(id: "003", title: "failed step", description: "this is failed step", status: .failed, error: nil),
        .init(id: "004", title: "cancelled step", description: "this is cancelled step", status: .cancelled, error: nil)
    ]

    static let agentRounds: [AgentRound] = [
        .init(roundId: 1, reply: "this is agent step 1", toolCalls: [
            .init(
                id: "toolcall_001",
                name: "Tool Call 1",
                progressMessage: "Read Tool Call 1",
                status: .completed,
                error: nil)
            ]),
        .init(roundId: 2, reply: "this is agent step 2", toolCalls: [
            .init(
                id: "toolcall_002",
                name: "Tool Call 2",
                progressMessage: "Running Tool Call 2",
                status: .running)
            ])
        ]

    static var previews: some View {
        let chatTabInfo = ChatTabInfo(id: "id", workspacePath: "path", username: "name")
        BotMessage(
            message: .init(
                id: "1",
                role: .assistant,
                text: """
                    **Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?**Hey**! What can I do for you?
                    ```swift
                    func foo() {}
                    ```
                    """,
                references: .init(
                    repeating: .init(
                    uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                    status: .included,
                    kind: .class,
                    referenceType: .file),
                    count: 2
                ),
                followUp: ConversationFollowUp(message: "followup question", id: "id", type: "type"),
                errorMessages: ["Sorry, an error occurred while generating a response."],
                steps: steps,
                editAgentRounds: agentRounds,
                panelMessages: [],
                codeReviewRound: nil,
                requestType: .conversation
            ),
            chat: .init(initialState: .init(), reducer: { Chat(service: ChatService.service(for: chatTabInfo)) }),
        )
        .padding()
        .fixedSize(horizontal: true, vertical: true)
    }
}

struct ReferenceList_Previews: PreviewProvider {
    static var previews: some View {
        let chatTabInfo = ChatTabInfo(id: "id", workspacePath: "path", username: "name")
        ReferenceList(references: [
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .class,
                referenceType: .file
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views",
                status: .included,
                kind: .struct,
                referenceType: .file
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .function,
                referenceType: .file
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .case,
                referenceType: .file
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .extension,
                referenceType: .file
            ),
            .init(
                uri: "/Core/Sources/ConversationTab/Views/BotMessage.swift",
                status: .included,
                kind: .webpage,
                referenceType: .file
            ),
        ], chat: .init(initialState: .init(), reducer: { Chat(service: ChatService.service(for: chatTabInfo)) }))
    }
}
