import Foundation

public struct TerminalCommandsRules: Codable, Equatable, RawRepresentable {
    public var commands: [String: Bool]

    public init(commands: [String: Bool] = [:]) {
        self.commands = commands
    }

    public init?(rawValue: [String: Any]) {
        let rulesDict = rawValue["commands"] as? [String: Any] ?? [:]
        var parsedRules: [String: Bool] = [:]
        for (key, value) in rulesDict {
            if let autoApprove = value as? Bool {
                parsedRules[key] = autoApprove
            }
        }
        self.commands = parsedRules
    }

    public var rawValue: [String: Any] {
        return ["commands": commands]
    }
}
