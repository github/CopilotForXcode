import Foundation
import Logger

public extension Notification.Name {
    static let gitHubCopilotMCPToolsDidChange = Notification
        .Name("com.github.CopilotForXcode.CopilotMCPToolsDidChange")
}

public class CopilotMCPToolManager {
    private static var availableMCPServerTools: [MCPServerToolsCollection]?
    
    public static func updateMCPTools(_ serverToolsCollections: [MCPServerToolsCollection]) {
        let sortedMCPServerTools = serverToolsCollections.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
        guard sortedMCPServerTools != availableMCPServerTools else { return }
        availableMCPServerTools = sortedMCPServerTools
        DispatchQueue.main.async {
            Logger.client.info("Notify about MCP tools change: \(getToolsSummary())")
            DistributedNotificationCenter.default().postNotificationName(
                .gitHubCopilotMCPToolsDidChange,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }

    private static func getToolsSummary() -> String {
        var summary = ""
        guard let tools = availableMCPServerTools else { return summary }
        for server in tools {
            summary += "Server: \(server.name) \(server.status), with \(server.tools.count) tools (\(server.tools.filter { $0._status == .enabled }.count) enabled, \(server.tools.filter { $0._status == .disabled }.count) disabled). "
        }

        return summary
    }

    public static func getAvailableMCPTools() -> [MCPTool]? {
        // Flatten all tools from all servers into a single array
        return availableMCPServerTools?.flatMap { $0.tools }
    }
    
    public static func getAvailableMCPServerToolsCollections() -> [MCPServerToolsCollection]? {
        return availableMCPServerTools
    }

    public static func hasMCPTools() -> Bool {
        return availableMCPServerTools != nil && !availableMCPServerTools!.isEmpty
    }

    public static func clearMCPTools() {
        availableMCPServerTools = []
        DispatchQueue.main.async {
            DistributedNotificationCenter.default().postNotificationName(
                .gitHubCopilotMCPToolsDidChange,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
        }
    }
}
