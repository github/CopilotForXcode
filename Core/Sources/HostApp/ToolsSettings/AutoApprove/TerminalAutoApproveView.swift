import AppKit
import Client
import Logger
import Preferences
import SharedUIComponents
import SwiftUI
import UserDefaultsObserver
import ComposableArchitecture

struct TerminalAutoApproveView: View {
    @State private var isExpanded: Bool = true
    @StateObject private var viewModel = ViewModel()
    @State private var selection = Set<ViewModel.Rule.ID>()

    let rowHeight: CGFloat = 28

    private var canRemoveSelection: Bool {
        !selection.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            DisclosureSettingsRow(
                isExpanded: $isExpanded,
                accessibilityLabel: { $0 ? "Collapse terminal auto-approve section" : "Expand terminal auto-approve section" },
                title: { Text("Terminal Auto-Approve").font(.headline) },
                subtitle: {
                    Text(
                        "Controls whether chat-initiated terminal commands are automatically approved. Set to **true** to auto-approve matching commands; set to **false** to always require explicit approval."
                    )
                }
            )

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()

                    rulesTable

                    Divider()

                    toolbar
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(QuaternarySystemFillColor.opacity(0.75))
                .transition(.opacity.combined(with: .scale(scale: 1, anchor: .top)))
            }
        }
        .settingsContainerStyle(isExpanded: isExpanded)
        .onAppear {
            viewModel.loadRules()
        }
    }

    @ViewBuilder
    private var rulesTable: some View {
        Table(viewModel.rules, selection: $selection) {
            TableColumn("Command") { rule in
                EditableText("Command", text: rule.command) { newText in
                    viewModel.updateRule(id: rule.id, command: newText)
                }
                .help("Click to edit command")
            }
            TableColumn("Auto-Approve") { rule in
                Toggle("", isOn: Binding(
                    get: { rule.autoApprove },
                    set: { viewModel.updateRule(id: rule.id, autoApprove: $0) }
                ))
            }
        }
        .frame(height: CGFloat(max(viewModel.rules.count, 1)) * rowHeight + 42)
        .padding(.horizontal, 20)
        .transparentBackground()
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 8) {
            Button(action: { viewModel.addRule() }) {
                Image(systemName: "plus")
            }
            .foregroundColor(.primary)
            .buttonStyle(.borderless)
            .padding(.leading, 8)

            Divider()

            Group {
                if canRemoveSelection {
                    Button(action: {
                        viewModel.removeRules(ids: selection)
                        selection.removeAll()
                    }) {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.borderless)
                } else {
                    Image(systemName: "minus")
                }
            }
            .foregroundColor(
                canRemoveSelection ? .primary : Color(
                    nsColor: .quaternaryLabelColor
                )
            )
            .help("Remove selected rules")

            Spacer()
        }
        .frame(height: 24)
        .background(TertiarySystemFillColor)
    }
}

extension TerminalAutoApproveView {
    final class ViewModel: ObservableObject {
        @Dependency(\.toast) var toast

        struct Rule: Identifiable {
            var id = UUID()
            var command: String
            var autoApprove: Bool
        }

        @Published var rules: [Rule] = []

        private let defaults = UserDefaults.autoApproval
        private var observer = UserDefaultsObserver(
            object: UserDefaults.autoApproval,
            forKeyPaths: [UserDefaultPreferenceKeys().terminalCommandsGlobalApprovals.key],
            context: nil
        )

        init() {
            observer.onChange = { [weak self] in
                DispatchQueue.main.async {
                    self?.loadRules()
                }
            }
        }

        func loadRules() {
            let state = defaults.value(for: \.terminalCommandsGlobalApprovals)
            let savedRules = state.commands

            func findExistingID(command: String) -> UUID {
                rules.first(where: { $0.command == command })?.id ?? UUID()
            }

            var loadedRules: [Rule] = []
            for (commandKey, autoApprove) in savedRules {
                loadedRules.append(
                    Rule(id: findExistingID(command: commandKey), command: commandKey, autoApprove: autoApprove)
                )
            }

            rules = loadedRules.sorted { $0.command.localizedCaseInsensitiveCompare($1.command) == .orderedAscending }
        }

        func addRule() {
            var counter = 0
            var newCommand = "New Command"
            while rules.contains(where: { $0.command == newCommand }) {
                counter += 1
                newCommand = "New Command \(counter)"
            }
            rules.append(Rule(command: newCommand, autoApprove: false))
            saveRules()
        }

        func removeRules(ids: Set<UUID>) {
            rules.removeAll { ids.contains($0.id) }
            saveRules()
        }

        @discardableResult
        func updateRule(id: UUID, command: String? = nil, autoApprove: Bool? = nil) -> Bool {
            guard let index = rules.firstIndex(where: { $0.id == id }) else { return false }

            if let command {
                var newCommand = command.filter { !$0.isNewline }
                newCommand = newCommand.trimmingCharacters(in: .whitespacesAndNewlines)

                guard !newCommand.isEmpty else {
                    toast("Command cannot be empty.", .warning)
                    return false
                }

                if !rules.contains(where: { $0.id != id && $0.command == newCommand }) {
                    rules[index].command = newCommand
                } else {
                    toast("Duplicate commands are not allowed. Please ensure each rule has a unique command.", .warning)
                    return false
                }
            }
            if let autoApprove { rules[index].autoApprove = autoApprove }

            saveRules()
            return true
        }

        func saveRules() {
            let commands = rules.map(\.command)
            let uniqueCommands = Set(commands)
            if commands.count != uniqueCommands.count {
                return
            }
            if commands.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                toast("Command cannot be empty.", .warning)
                return
            }

            var state = defaults.value(for: \.terminalCommandsGlobalApprovals)
            var newRules: [String: Bool] = [:]
            for rule in rules {
                newRules[rule.command] = rule.autoApprove
            }
            state.commands = newRules
            defaults.set(state, for: \.terminalCommandsGlobalApprovals)

            Task {
                do {
                    let service = try getService()
                    try await service.postNotification(
                        name: Notification.Name.githubCopilotAgentAutoApprovalDidChange.rawValue
                    )
                } catch {
                    toast(error.localizedDescription, .error)
                }
            }
        }
    }
}
