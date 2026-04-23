import Client
import ConversationServiceProvider
import HostAppActivator
import Logger
import Persist
import SwiftUI

struct AgentModeDropdown: View {
    @Binding var modes: [ConversationMode]
    @Binding var selectedMode: ConversationMode

    public init(modes: Binding<[ConversationMode]>, selectedMode: Binding<ConversationMode>) {
        _modes = modes
        _selectedMode = selectedMode
    }

    var builtInModes: [ConversationMode] {
        modes.filter { $0.isBuiltIn }
    }

    var customModes: [ConversationMode] {
        modes.filter { !$0.isBuiltIn }
    }

    var body: some View {
        Picker(selection: Binding(
            get: { selectedMode.id },
            set: { newId in
                if let mode = modes.first(where: { $0.id == newId }) {
                    selectedMode = mode
                }
            }
        )) {
            ForEach(builtInModes, id: \.id) { mode in
                Text(mode.name).tag(mode.id)
            }

            if !customModes.isEmpty {
                Divider()
                ForEach(customModes, id: \.id) { mode in
                    Text(mode.name).tag(mode.id)
                }
            }
        } label: {
            Text("Applied for").fontWeight(.bold)
        }
        .pickerStyle(.menu)
        .frame(maxWidth: 300, alignment: .leading)
        .padding(.leading, -4)
        .onAppear {
            loadModes()
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: .selectedAgentSubModeDidChange)) { notification in
            if let userInfo = notification.userInfo as? [String: String],
               let newModeId = userInfo["agentSubMode"],
               newModeId != selectedMode.id,
               let mode = modes.first(where: { $0.id == newModeId }) {
                Logger.client.info("AgentModeDropdown: Mode changed to: \(newModeId)")
                selectedMode = mode
            }
        }
    }

    // MARK: - Helper Methods

    private func loadModes() {
        Task {
            do {
                let service = try getService()
                let workspaceFolders = await getWorkspaceFolders()
                if let fetchedModes = try await service.getModes(workspaceFolders: workspaceFolders) {
                    Logger.client.info("AgentModeDropdown: Fetched \(fetchedModes.count) modes")
                    await MainActor.run {
                        modes = fetchedModes.filter { $0.kind == .Agent }

                        if !modes.contains(where: { $0.id == selectedMode.id }),
                           let firstMode = modes.first {
                            selectedMode = firstMode
                        }
                    }
                }
            } catch {
                Logger.client.error("AgentModeDropdown: Failed to load modes: \(error.localizedDescription)")
            }
        }
    }
}
