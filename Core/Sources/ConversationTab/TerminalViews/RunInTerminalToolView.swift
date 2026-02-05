import ChatService
import ComposableArchitecture
import ConversationServiceProvider
import GitHubCopilotService
import SharedUIComponents
import SwiftUI
import Terminal
import XcodeInspector

struct RunInTerminalToolView: View {
    let tool: AgentToolCall
    let command: String?
    let explanation: String?
    let isBackground: Bool?
    let chat: StoreOf<Chat>
    private var title: String = "Run command in terminal"

    @AppStorage(\.codeBackgroundColorLight) var codeBackgroundColorLight
    @AppStorage(\.codeForegroundColorLight) var codeForegroundColorLight
    @AppStorage(\.codeBackgroundColorDark) var codeBackgroundColorDark
    @AppStorage(\.codeForegroundColorDark) var codeForegroundColorDark
    @AppStorage(\.chatFontSize) var chatFontSize
    @Environment(\.colorScheme) var colorScheme
    
    init(tool: AgentToolCall, chat: StoreOf<Chat>) {
        self.tool = tool
        self.chat = chat
        
        let input = (tool.invokeParams?.input as? [String: AnyCodable]) ?? tool.input

        if let input {
            self.command = input["command"]?.value as? String
            self.explanation = input["explanation"]?.value as? String
            self.isBackground = input["isBackground"]?.value as? Bool
            self.title = (isBackground != nil && isBackground!) ? "Run command in background terminal" : "Run command in terminal"
        } else {
            self.command = nil
            self.explanation = nil
            self.isBackground = nil
        }
    }

    var terminalSession: TerminalSession? {
        return TerminalSessionManager.shared.getSession(for: tool.id)
    }

    var statusIcon: some View {
        Group {
            switch tool.status {
            case .running:
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            case .completed:
                Image(systemName: "checkmark")
                    .foregroundColor(.green.opacity(0.5))
            case .error:
                Image(systemName: "xmark.circle")
                    .foregroundColor(.red.opacity(0.5))
            case .cancelled:
                Image(systemName: "slash.circle")
                    .foregroundColor(.gray.opacity(0.5))
            case .waitForConfirmation:
                EmptyView()
            case .accepted:
                EmptyView()
            }
        }
    }
    
    var body: some View {
        WithPerceptionTracking {
            if tool.status == .waitForConfirmation || terminalSession != nil {
                VStack {
                    HStack {
                        Image("Terminal")
                            .resizable()
                            .scaledToFit()
                            .scaledFrame(width: 16, height: 16)

                        Text(self.title)
                            .scaledFont(size: chatFontSize, weight: .semibold)
                            .foregroundStyle(.primary)
                            .background(Color.clear)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    toolView
                }
                .scaledPadding(8)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            } else {
                toolView
            }
        }
    }

    var codeBackgroundColor: Color {
        if colorScheme == .light, let color = codeBackgroundColorLight.value {
            return color.swiftUIColor
        } else if let color = codeBackgroundColorDark.value {
            return color.swiftUIColor
        }
        return Color(nsColor: .textBackgroundColor).opacity(0.7)
    }

    var codeForegroundColor: Color {
        if colorScheme == .light, let color = codeForegroundColorLight.value {
            return color.swiftUIColor
        } else if let color = codeForegroundColorDark.value {
            return color.swiftUIColor
        }
        return Color(nsColor: .textColor)
    }

    var toolView: some View {
        WithPerceptionTracking {
            VStack {
                if command != nil {
                    HStack(spacing: 4) {
                        statusIcon
                            .scaledFrame(width: 16, height: 16)

                        Text(command!)
                            .lineLimit(nil)
                            .textSelection(.enabled)
                            .scaledFont(size: chatFontSize, design: .monospaced)
                            .scaledPadding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .foregroundStyle(codeForegroundColor)
                            .background(codeBackgroundColor)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay {
                                RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.05), lineWidth: 1)
                            }
                    }
                } else {
                    Text("Invalid parameter in the toolcall for runInTerminal")
                }

                if let terminalSession = terminalSession {
                    XTermView(
                        terminalSession: terminalSession,
                        onTerminalInput: terminalSession.handleTerminalInput
                    )
                    .scaledFrame(minHeight: 200, maxHeight: 400)
                } else if tool.status == .waitForConfirmation {
                    ThemedMarkdownText(text: explanation ?? "", chat: chat)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Button(action: {
                            chat.send(.toolCallCancelled(tool.id))
                        }) {
                            Text("Skip")
                                .scaledFont(.body)
                        }

                        if #available(macOS 13.0, *),
                           FeatureFlagNotifierImpl.shared.featureFlags.agentModeAutoApproval &&
                           CopilotPolicyNotifierImpl.shared.copilotPolicy.agentModeAutoApprovalEnabled,
                           let command, !command.isEmpty {
                            SplitButton(
                                title: "Allow",
                                isDisabled: false,
                                primaryAction: {
                                    chat.send(.toolCallAccepted(tool.id))
                                },
                                menuItems: terminalMenuItems(command: command),
                                style: .prominent
                            )
                        } else {
                            Button(action: {
                                chat.send(.toolCallAccepted(tool.id))
                            }) {
                                Text("Allow")
                                    .scaledFont(.body)
                            }
                            .buttonStyle(BorderedProminentButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaledPadding(.top, 4)
                }
            }
        }
    }

    @available(macOS 13.0, *)
    private func terminalMenuItems(command: String) -> [SplitButtonMenuItem] {
        var items: [SplitButtonMenuItem] = []

        let subCommands = ToolAutoApprovalManager.extractSubCommandsWithTreeSitter(command)
        let commandNames = extractCommandNamesForMenu(subCommands)
        let commandNamesLabel = formatCommandNameListForMenu(commandNames)

        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubCommands = subCommands
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let shouldShowExactCommandLineItems = !(
            trimmedSubCommands.count == 1 &&
                trimmedSubCommands[0] == trimmedCommand &&
                commandNames.contains(trimmedCommand)
        )
        
        let conversationId = tool.invokeParams?.conversationId ?? ""
        let hasConversationId = !conversationId.isEmpty

        // Session-scoped
        if hasConversationId, !commandNames.isEmpty {
            items.append(
                SplitButtonMenuItem(title: sessionAllowCommandsTitle(commandNamesLabel: commandNamesLabel, commandCount: commandNames.count)) {
                    chat.send(
                        .toolCallAcceptedWithApproval(
                            tool.id,
                            .terminal(
                                scope: .session(conversationId),
                                commands: commandNames
                            )
                        )
                    )
                }
            )
        }

        // Global
        if !commandNames.isEmpty {
            items.append(
                SplitButtonMenuItem(title: alwaysAllowCommandsTitle(commandNamesLabel: commandNamesLabel, commandCount: commandNames.count)) {
                    chat.send(
                        .toolCallAcceptedWithApproval(
                            tool.id,
                            .terminal(
                                scope: .global,
                                commands: commandNames
                            )
                        )
                    )
                }
            )
        }

        items.append(.divider())

        if shouldShowExactCommandLineItems {
            // Session-scoped exact command line
            if hasConversationId {
                items.append(
                    SplitButtonMenuItem(title: "Allow Exact Command Line in this Session") {
                        chat.send(
                            .toolCallAcceptedWithApproval(
                                tool.id,
                                .terminal(
                                    scope: .session(conversationId),
                                    commands: [command]
                                )
                            )
                        )
                    }
                )
            }

            // Global exact command line
            items.append(
                SplitButtonMenuItem(title: "Always Allow Exact Command Line") {
                    chat.send(
                        .toolCallAcceptedWithApproval(
                            tool.id,
                            .terminal(
                                scope: .global,
                                commands: [command]
                            )
                        )
                    )
                }
            )

            items.append(.divider())
        }

        // Session-scoped allow all
        if hasConversationId {
            items.append(
                SplitButtonMenuItem(title: "Allow All Commands in this Session") {
                    chat.send(
                        .toolCallAcceptedWithApproval(
                            tool.id,
                            .terminal(
                                scope: .session(conversationId),
                                commands: []
                            )
                        )
                    )
                }
            )
        }

        items.append(.divider())
        items.append(
            SplitButtonMenuItem(title: "Configure Auto Approve...") {
                chat.send(.openAutoApproveSettings)
            }
        )

        return items
    }

    private func formatSubCommandListForMenu(_ subCommands: [String]) -> String {
        let trimmed = subCommands.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return "(none)" }
        return trimmed.joined(separator: ", ")
    }

    private func extractCommandNamesForMenu(_ subCommands: [String]) -> [String] {
        var result: [String] = []
        var seen: Set<String> = []

        for subCommand in subCommands {
            guard let name = ToolAutoApprovalManager.extractTerminalCommandName(fromSubCommand: subCommand) else {
                continue
            }
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard !seen.contains(trimmed) else { continue }
            seen.insert(trimmed)
            result.append(trimmed)
        }

        return result
    }

    private func formatCommandNameListForMenu(_ commandNames: [String]) -> String {
        let trimmed = commandNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return "(none)" }

        func suffixEllipsis(_ name: String) -> String { "`\(name) ...`" }

        return trimmed.map(suffixEllipsis).joined(separator: ", ")
    }

    private func sessionAllowCommandsTitle(commandNamesLabel: String, commandCount: Int) -> String {
        if commandCount == 1 {
            return "Allow \(commandNamesLabel) in this Session"
        }
        return "Allow Commands \(commandNamesLabel) in this Session"
    }

    private func alwaysAllowCommandsTitle(commandNamesLabel: String, commandCount: Int) -> String {
        if commandCount == 1 {
            return "Always Allow \(commandNamesLabel)"
        }
        return "Always Allow Commands \(commandNamesLabel)"
    }
}
