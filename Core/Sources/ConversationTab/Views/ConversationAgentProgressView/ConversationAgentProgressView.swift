import SwiftUI
import ConversationServiceProvider
import ComposableArchitecture
import Combine
import ChatTab
import ChatService
import SharedUIComponents

struct ProgressAgentRound: View {
    let rounds: [AgentRound]
    let chat: StoreOf<Chat>
    
    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rounds, id: \.roundId) { round in
                    VStack(alignment: .leading, spacing: 8) {
                        ThemedMarkdownText(text: round.reply, chat: chat)
                        if let toolCalls = round.toolCalls, !toolCalls.isEmpty {
                            ProgressToolCalls(tools: toolCalls, chat: chat)
                        }
                        if let subAgentRounds = round.subAgentRounds, !subAgentRounds.isEmpty {
                            SubAgentRounds(rounds: subAgentRounds, chat: chat)
                        }
                    }
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}

struct SubAgentRounds: View {
    let rounds: [AgentRound]
    let chat: StoreOf<Chat>
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(rounds, id: \.roundId) { round in
                    VStack(alignment: .leading, spacing: 8) {
                        ThemedMarkdownText(text: round.reply, chat: chat)
                        if let toolCalls = round.toolCalls, !toolCalls.isEmpty {
                            ProgressToolCalls(tools: toolCalls, chat: chat)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .scaledPadding(.horizontal, 16)
            .scaledPadding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color("SubagentTurnBackground")))
        }
    }
}

struct ProgressToolCalls: View {
    let tools: [AgentToolCall]
    let chat: StoreOf<Chat>
    
    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(tools) { tool in
                    if tool.name == ToolName.runInTerminal.rawValue && tool.invokeParams != nil {
                        RunInTerminalToolView(tool: tool, chat: chat)
                    } else if tool.invokeParams != nil && tool.status == .waitForConfirmation {
                        ToolConfirmationView(tool: tool, chat: chat)
                    } else if tool.isToolcallingLoopContinueTool {
                        // ignore rendering for internal tool calling loop continue tool
                    } else {
                        ToolStatusItemView(tool: tool)
                    }
                }
            }
        }
    }
}

struct ToolConfirmationView: View {
    let tool: AgentToolCall
    let chat: StoreOf<Chat>

    @AppStorage(\.chatFontSize) var chatFontSize

    var body: some View {
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 8) {
                if let title = tool.title {
                    ToolConfirmationTitleView(title: title, fontWeight: .semibold)
                } else {
                    GenericToolTitleView(toolStatus: "Run", toolName: tool.name, fontWeight: .semibold)
                }

                ThemedMarkdownText(text: tool.invokeParams?.message ?? "", chat: chat)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Button(action: {
                        chat.send(.toolCallCancelled(tool.id))
                    }) {
                        Text(tool.isToolcallingLoopContinueTool ? "Cancel" : "Skip")
                            .scaledFont(.body)
                    }
                    
                    Button(action: {
                        chat.send(.toolCallAccepted(tool.id))
                    }) {
                        Text(tool.isToolcallingLoopContinueTool ? "Continue" : "Allow")
                            .scaledFont(.body)
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .scaledPadding(.top, 4)
            }
            .scaledPadding(8)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct ToolConfirmationTitleView: View {
    var title: String
    var fontWeight: Font.Weight = .regular

    @AppStorage(\.chatFontSize) var chatFontSize
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .textSelection(.enabled)
                .scaledFont(size: chatFontSize, weight: fontWeight)
                .foregroundStyle(.primary)
                .background(Color.clear)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GenericToolTitleView: View {
    var toolStatus: String
    var toolName: String
    var fontWeight: Font.Weight = .regular

    @AppStorage(\.chatFontSize) var chatFontSize

    var body: some View {
        HStack(spacing: 4) {
            Text(toolStatus)
                .textSelection(.enabled)
                .scaledFont(size: chatFontSize, weight: fontWeight)
                .foregroundStyle(.primary)
                .background(Color.clear)
            Text(toolName)
                .textSelection(.enabled)
                .scaledFont(size: chatFontSize, weight: fontWeight)
                .foregroundStyle(.primary)
                .scaledPadding(.vertical, 2)
                .scaledPadding(.horizontal, 4)
                .background(Color("ToolTitleHighlightBgColor"))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .inset(by: 0.5)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProgressAgentRound_Preview: PreviewProvider {
    static let agentRounds: [AgentRound] = [
        .init(roundId: 1, reply: "this is agent step", toolCalls: [
            .init(
                id: "toolcall_001",
                name: "Tool Call 1",
                progressMessage: "Read Tool Call 1",
                status: .completed,
                error: nil),
            .init(
                id: "toolcall_002",
                name: "Tool Call 2",
                progressMessage: "Running Tool Call 2",
                status: .running)
            ])
        ]

    static var previews: some View {
        let chatTabInfo = ChatTabInfo(id: "id", workspacePath: "path", username: "name")
        ProgressAgentRound(rounds: agentRounds, chat: .init(initialState: .init(), reducer: { Chat(service: ChatService.service(for: chatTabInfo)) }))
            .frame(width: 300, height: 300)
    }
}
