import ConversationServiceProvider
import Foundation
import Logger

public extension Notification.Name {
    static let gitHubCopilotToolsDidChange = Notification
        .Name("com.github.CopilotForXcode.CopilotToolsDidChange")
    static let gitHubCopilotCustomAgentToolsDidChange = Notification
        .Name("com.github.CopilotForXcode.CustomAgentToolsDidChange")
}

public class CopilotLanguageModelToolManager {
    private static var availableLanguageModelTools: [LanguageModelTool]?

    public static func updateToolsStatus(_ tools: [LanguageModelTool]) {
        // If we have no previous snapshot, just adopt what we received.
        guard let previous = availableLanguageModelTools, !previous.isEmpty else {
            let sorted = sortTools(tools)
            guard sorted != availableLanguageModelTools else { return }
            availableLanguageModelTools = sorted
            DispatchQueue.main.async {
                Logger.client.info("Notify about language model tools change: \(getLanguageModelToolsSummary())")
                DistributedNotificationCenter.default().post(name: .gitHubCopilotToolsDidChange, object: nil)
            }
            return
        }

        // Map previous and new by name for merging.
        let previousByName = Dictionary(previous.map { ($0.name, $0) }) { first, _ in first }
        let incomingByName = Dictionary(tools.map { ($0.name, $0) }) { first, _ in first }

        var merged: [LanguageModelTool] = []

        for (name, oldTool) in previousByName {
            if let updated = incomingByName[name] {
                merged.append(updated)
            } else {
                if oldTool.status == .disabled {
                    merged.append(oldTool) // already disabled, keep as-is
                } else {
                    // Synthesize a disabled copy (all fields same except status).
                    let disabledCopy = LanguageModelTool(
                        id: oldTool.id,
                        type: oldTool.type,
                        toolProvider: oldTool.toolProvider,
                        nameForModel: oldTool.nameForModel,
                        name: oldTool.name,
                        displayName: oldTool.displayName,
                        description: oldTool.description,
                        displayDescription: oldTool.displayDescription,
                        inputSchema: oldTool.inputSchema,
                        annotations: oldTool.annotations,
                        status: .disabled
                    )
                    merged.append(disabledCopy)
                }
            }
        }

        for (name, newTool) in incomingByName {
            if previousByName[name] == nil {
                merged.append(newTool)
            }
        }

        let sorted = sortTools(merged)
        guard sorted != availableLanguageModelTools else { return }
        availableLanguageModelTools = sorted

        DispatchQueue.main.async {
            Logger.client.info("Notify about language model tools change (merged): \(getLanguageModelToolsSummary())")
            DistributedNotificationCenter.default().post(name: .gitHubCopilotToolsDidChange, object: nil)
        }
    }

    // Extracted sorting logic to keep behavior identical.
    private static func sortTools(_ tools: [LanguageModelTool]) -> [LanguageModelTool] {
        tools.sorted { lhs, rhs in
            let lKey = lhs.displayName ?? lhs.name
            let rKey = rhs.displayName ?? rhs.name
            let primary = lKey.localizedCaseInsensitiveCompare(rKey)
            if primary == .orderedSame {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return primary == .orderedAscending
        }
    }
    
    private static func getLanguageModelToolsSummary() -> String {
        guard let tools = availableLanguageModelTools else { return "" }
        return "\(tools.filter { $0.status == .enabled }.count) enabled, \(tools.filter { $0.status == .disabled }.count) disabled."
    }

    public static func getAvailableLanguageModelTools() -> [LanguageModelTool]? {
        return availableLanguageModelTools
    }

    public static func hasLanguageModelTools() -> Bool {
        return availableLanguageModelTools != nil && !availableLanguageModelTools!.isEmpty
    }

    public static func clearLanguageModelTools() {
        availableLanguageModelTools = []
        DispatchQueue.main.async {
            DistributedNotificationCenter.default().post(name: .gitHubCopilotToolsDidChange, object: nil)
        }
    }
}
