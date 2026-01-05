import Foundation

extension ToolAutoApprovalManager {
    private static let mcpToolCallPattern = try? NSRegularExpression(
        pattern: #"Confirm MCP Tool: .+ - (.+)\(MCP Server\)"#,
        options: []
    )

    private static let sensitiveRuleDescriptionRegex = try? NSRegularExpression(
        pattern: #"^(.*?)\s*needs confirmation\."#,
        options: [.caseInsensitive]
    )

    public nonisolated static func extractMCPServerName(from message: String) -> String? {
        let fullRange = NSRange(message.startIndex..<message.endIndex, in: message)

        if let regex = mcpToolCallPattern,
           let match = regex.firstMatch(in: message, options: [], range: fullRange),
           match.numberOfRanges >= 2,
           let range = Range(match.range(at: 1), in: message) {
            return String(message[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return nil
    }

    public nonisolated static func isSensitiveFileOperation(message: String) -> Bool {
        message.range(of: "sensitive files", options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    public nonisolated static func sensitiveFileKey(from message: String) -> String {
        let fullRange = NSRange(message.startIndex..<message.endIndex, in: message)

        // TODO: Update confirmation message in CLS to include rules
        if let regex = sensitiveRuleDescriptionRegex,
           let match = regex.firstMatch(in: message, options: [], range: fullRange),
           match.numberOfRanges >= 2,
           let range = Range(match.range(at: 1), in: message) {
            let description = String(message[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !description.isEmpty {
                return description.lowercased()
            }
        }

        return "sensitive files"
    }
}
