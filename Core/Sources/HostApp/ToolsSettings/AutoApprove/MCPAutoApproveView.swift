import AppKit
import Combine
import Client
import GitHubCopilotService
import Logger
import Preferences
import SharedUIComponents
import SwiftUI
import UserDefaultsObserver

struct MCPAutoApproveView: View {
    @State private var isExpanded: Bool = true
    @StateObject private var viewModel = ViewModel()

    var body: some View {
        VStack(spacing: 0) {
            DisclosureSettingsRow(
                isExpanded: $isExpanded,
                accessibilityLabel: { $0 ? "Collapse MCP auto-approve section" : "Expand MCP auto-approve section" },
                title: { Text("MCP Auto-Approve").font(.headline) },
                subtitle: { Text("Controls whether MCP tool calls triggered by Copilot are automatically approved. You can enable MCP auto-approval per server or per tool.") }
            )

            if isExpanded {
                Divider()
                AgentTrustToolAnnotationsSetting()
                    .padding(.horizontal, 26)
                    .background(QuaternarySystemFillColor.opacity(0.75))
                    .transition(.opacity.combined(with: .scale(scale: 1, anchor: .top)))
                Divider()
                if #available(macOS 14.0, *) {
                    if viewModel.rows.isEmpty {
                        Text(noRunningServersMessage)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .environment(\.openURL, OpenURLAction { url in
                                if url.scheme == "action", url.host == "open-mcp-tab" {
                                    hostAppStore.send(.setActiveTab(.tools))
                                    hostAppStore.send(.setActiveToolsSubTab(.MCP))
                                    return .handled
                                }
                                NSWorkspace.openFileInXcode(fileURL: url)
                                return .handled
                            })
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                            .background(QuaternarySystemFillColor.opacity(0.75))
                    } else {
                        Table(viewModel.rows, children: \.children) {
                            TableColumn(Text("MCP Server").bold()) { row in
                                HStack(alignment: .center, spacing: 4) {
                                    if case .runAny = row.type {
                                        Image(systemName: "play.rectangle.on.rectangle")
                                            .foregroundColor(.secondary)
                                    } else if case .tool = row.type {
                                        Image(systemName: "play.rectangle.on.rectangle")
                                            .opacity(0)
                                            .accessibilityHidden(true)
                                    }

                                    Text(row.title)
                                    if case .tool = row.type {
                                        Text("without approval")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            TableColumn("Auto-Approve") { row in
                                if case .server = row.type {
                                    EmptyView()
                                } else {
                                    Toggle(isOn: binding(for: row)) {
                                        Text("")
                                    }
                                    .toggleStyle(CheckboxToggleStyle())
                                    .labelsHidden()
                                }
                            }
                            .width(100)
                        }
                        .frame(minHeight: 300, maxHeight: .infinity)
                        .transparentBackground()
                        .padding(.horizontal, 10)
                        .background(QuaternarySystemFillColor.opacity(0.75))
                        .transition(.opacity.combined(with: .scale(scale: 1, anchor: .top)))
                    }
                }
            }
        }
        .settingsContainerStyle(isExpanded: isExpanded)
    }

    private var noRunningServersMessage: AttributedString {
        var text = AttributedString(localized: "No running MCP servers found. Please verify the status in the MCP section or add configs in mcp.json.")
        if let range = text.range(of: "mcp.json") {
            text[range].link = URL(fileURLWithPath: mcpConfigFilePath)
        }
        if let range = text.range(of: "MCP section") {
            text[range].link = URL(string: "action://open-mcp-tab")
        }
        return text
    }

    private func binding(for row: RowItem) -> Binding<Bool> {
        Binding(
            get: {
                switch row.type {
                case .server(let name):
                    return viewModel.isServerAllowed(name)
                case .runAny(let serverName):
                    return viewModel.isServerAllowed(serverName)
                case .tool(let serverName, let toolName):
                    return viewModel.isToolAllowed(serverName: serverName, toolName: toolName)
                }
            },
            set: { newValue in
                switch row.type {
                case .server(let name), .runAny(let name):
                    viewModel.setServerAllowed(name, allowed: newValue)
                case .tool(let serverName, let toolName):
                    viewModel.setToolAllowed(serverName, toolName: toolName, allowed: newValue)
                }
            }
        )
    }
}

struct RowItem: Identifiable {
    let id: String
    let title: String
    let type: ItemType
    var children: [RowItem]?
}

enum ItemType: Equatable {
    case server(String)
    case runAny(serverName: String)
    case tool(serverName: String, toolName: String)
}

extension MCPAutoApproveView {
    @MainActor
    class ViewModel: ObservableObject {
        @Published var rows: [RowItem] = []
        private var serverTools: [MCPServerToolsCollection] = []
        private var approvals: AutoApprovedMCPServers = AutoApprovedMCPServers()
        private var cancellables = Set<AnyCancellable>()

        private let mcpToolManager = CopilotMCPToolManagerObservable.shared
        private var observer: UserDefaultsObserver?

        @Environment(\.toast) private var toast

        init() {
            // Observe tools availability
            mcpToolManager.$availableMCPServerTools
                .sink { [weak self] tools in
                    guard let self = self else { return }
                    self.serverTools = tools
                    self.rebuildRows()
                }
                .store(in: &cancellables)

            // Observe user defaults
            observer = UserDefaultsObserver(
                object: UserDefaults.autoApproval,
                forKeyPaths: [UserDefaultPreferenceKeys().mcpServersGlobalApprovals.key],
                context: nil
            )
            
            observer?.onChange = { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.loadApprovals()
                }
            }

            // Initial load so the table reflects saved state on first appearance.
            loadApprovals()
        }

        private func rebuildRows() {
            rows = serverTools
                .filter { $0.status == .running }
                .map { server in
                let isAllowed = approvals.servers[server.name]?.isServerAllowed ?? false
                var children: [RowItem] = []
                
                // "Run any tool" row
                children.append(RowItem(
                    id: "run-any-\(server.name)",
                    title: "Run any tool without approval",
                    type: .runAny(serverName: server.name),
                    children: nil
                ))

                // Tools rows (only if not allowed globally)
                if !isAllowed {
                    let toolRows = server.tools.map { tool in
                        RowItem(
                            id: "tool-\(server.name)-\(tool.name)",
                            title: tool.name,
                            type: .tool(serverName: server.name, toolName: tool.name),
                            children: nil
                        )
                    }
                    children.append(contentsOf: toolRows)
                }

                return RowItem(
                    id: "server-\(server.name)",
                    title: server.name,
                    type: .server(server.name),
                    children: children
                )
            }
        }

        private func loadApprovals() {
            self.approvals = UserDefaults.autoApproval.value(for: \.mcpServersGlobalApprovals)
            rebuildRows()
        }

        func isServerAllowed(_ serverName: String) -> Bool {
            return approvals.servers[serverName]?.isServerAllowed ?? false
        }
        
        func isToolAllowed(serverName: String, toolName: String) -> Bool {
            return approvals.servers[serverName]?.allowedTools.contains(toolName) ?? false
        }

        func setServerAllowed(_ serverName: String, allowed: Bool) {
            var currentApprovals = UserDefaults.autoApproval.value(for: \.mcpServersGlobalApprovals)
            var serverState = currentApprovals.servers[serverName] ?? MCPServerApprovalState()
            
            serverState.isServerAllowed = allowed
            currentApprovals.servers[serverName] = serverState
            
            save(currentApprovals)
            // Rebuild happens via observer
        }

        func setToolAllowed(_ serverName: String, toolName: String, allowed: Bool) {
            var currentApprovals = UserDefaults.autoApproval.value(for: \.mcpServersGlobalApprovals)
            var serverState = currentApprovals.servers[serverName] ?? MCPServerApprovalState()
            
            if allowed {
                serverState.allowedTools.insert(toolName)
            } else {
                serverState.allowedTools.remove(toolName)
            }
            currentApprovals.servers[serverName] = serverState
            
            save(currentApprovals)
        }

        private func save(_ approvals: AutoApprovedMCPServers) {
            UserDefaults.autoApproval.set(approvals, for: \.mcpServersGlobalApprovals)
            notifyChange()
        }
        
        private func notifyChange() {
            Task {
                do {
                    let service = try getService()
                    try await service.postNotification(
                        name: Notification.Name
                            .gitHubCopilotShouldRefreshEditorInformation.rawValue
                    )
                } catch {
                    toast(error.localizedDescription, .error)
                }
            }
        }
    }
}

struct AgentTrustToolAnnotationsSetting: View {
    @AppStorage(\.trustToolAnnotations) var trustToolAnnotations

    var body: some View {
        SettingsToggle(
            title: "Trust MCP Tool Annotations",
            subtitle: "If enabled, Copilot will use tool annotations to decide whether to automatically approve readonly MCP tool calls.",
            isOn: $trustToolAnnotations
        )
        .onChange(of: trustToolAnnotations) { _ in
            DistributedNotificationCenter
                .default()
                .post(name: .githubCopilotAgentTrustToolAnnotationsDidChange, object: nil)
        }
    }
}
