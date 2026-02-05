import Foundation

public struct SensitiveFileRule: Codable, Equatable {
    public var description: String
    public var autoApprove: Bool

    public init(description: String, autoApprove: Bool) {
        self.description = description
        self.autoApprove = autoApprove
    }
}

public struct SensitiveFilesRules: Codable, Equatable, RawRepresentable {
    public var rules: [String: SensitiveFileRule]

    public init(rules: [String: SensitiveFileRule] = [:]) {
        self.rules = rules
    }

    public init?(rawValue: [String: Any]) {
        let rulesDict = rawValue["rules"] as? [String: Any] ?? [:]
        var parsedRules: [String: SensitiveFileRule] = [:]
        for (key, value) in rulesDict {
             if let dict = value as? [String: Any] {
                 let description = dict["description"] as? String ?? ""
                 let autoApprove = dict["autoApprove"] as? Bool ?? false
                 parsedRules[key] = SensitiveFileRule(description: description, autoApprove: autoApprove)
             }
        }
        self.rules = parsedRules
    }

    public var rawValue: [String: Any] {
        var rulesDict: [String: Any] = [:]
        for (pattern, rule) in rules {
            rulesDict[pattern] = [
                "description": rule.description,
                "autoApprove": rule.autoApprove
            ]
        }
        return ["rules": rulesDict]
    }
}
