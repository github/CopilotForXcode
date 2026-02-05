import Foundation

public struct MCPServerApprovalState: Codable, Equatable {
    public var isServerAllowed: Bool
    public var allowedTools: Set<String>

    public init(isServerAllowed: Bool = false, allowedTools: Set<String> = []) {
        self.isServerAllowed = isServerAllowed
        self.allowedTools = allowedTools
    }
}

public struct AutoApprovedMCPServers: Codable, Equatable, RawRepresentable {
    public var servers: [String: MCPServerApprovalState]

    public init(servers: [String: MCPServerApprovalState] = [:]) {
        self.servers = servers
    }

    public init?(rawValue: [String: Any]) {
        let serversDict = rawValue["servers"] as? [String: Any] ?? [:]
        var parsedServers: [String: MCPServerApprovalState] = [:]
        
        for (serverName, value) in serversDict {
            if let dict = value as? [String: Any] {
                let isServerAllowed = dict["isServerAllowed"] as? Bool ?? false
                let allowedToolsArray = dict["allowedTools"] as? [String] ?? []
                parsedServers[serverName] = MCPServerApprovalState(
                    isServerAllowed: isServerAllowed, 
                    allowedTools: Set(allowedToolsArray)
                )
            }
        }
        self.servers = parsedServers
    }

    public var rawValue: [String: Any] {
        var serversDict: [String: Any] = [:]
        for (serverName, state) in servers {
            serversDict[serverName] = [
                "isServerAllowed": state.isServerAllowed,
                "allowedTools": Array(state.allowedTools)
            ]
        }
        return ["servers": serversDict]
    }
}
