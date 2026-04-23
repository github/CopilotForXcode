import Foundation
import ConversationServiceProvider
import SwiftTreeSitter
import SwiftTreeSitterLayer
import TreeSitterBash

extension ToolAutoApprovalManager {
    private static let mcpToolCallPattern = try? NSRegularExpression(
        pattern: #"Confirm MCP Tool: .+ - (.+)\(MCP Server\)"#,
        options: []
    )

    private static let sensitiveRuleDescriptionRegex = try? NSRegularExpression(
        pattern: #"^(.*?)\s*needs confirmation\."#,
        options: [.caseInsensitive]
    )

    private static let sensitiveRulePatternRegex = try? NSRegularExpression(
        pattern: #"matching pattern\s+`([^`]+)`"#,
        options: [.caseInsensitive]
    )

    public struct SensitiveFileConfirmationInfo: Sendable, Equatable {
        public let description: String
        // Optional pattern for create_file operations only
        public let pattern: String?

        public var sessionKey: String {
            if let pattern, !pattern.isEmpty {
                return pattern
            }
            if !description.isEmpty {
                return description.lowercased()
            }
            return "sensitive files"
        }
    }

    public nonisolated static func extractMCPServerName(from message: String) -> String? {
        let fullRange = NSRange(message.startIndex ..< message.endIndex, in: message)

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

    public nonisolated static func isTerminalOperation(name: String) -> Bool {
        name == ToolName.runInTerminal.rawValue
    }

    public nonisolated static func extractSensitiveFileConfirmationInfo(from message: String) -> SensitiveFileConfirmationInfo {
        let fullRange = NSRange(message.startIndex ..< message.endIndex, in: message)

        var description = ""
        if let regex = sensitiveRuleDescriptionRegex,
           let match = regex.firstMatch(in: message, options: [], range: fullRange),
           match.numberOfRanges >= 2,
           let range = Range(match.range(at: 1), in: message) {
            description = String(message[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var pattern: String?
        if let regex = sensitiveRulePatternRegex,
           let match = regex.firstMatch(in: message, options: [], range: fullRange),
           match.numberOfRanges >= 2,
           let range = Range(match.range(at: 1), in: message) {
            let extracted = String(message[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !extracted.isEmpty {
                pattern = extracted
            }
        }

        return SensitiveFileConfirmationInfo(description: description, pattern: pattern)
    }

    public nonisolated static func sensitiveFileKey(from message: String) -> String {
        extractSensitiveFileConfirmationInfo(from: message).sessionKey
    }

    // MARK: - Terminal command parsing

    /// Best-effort splitter for injection protection.
    ///
    /// Splits a command line into sub-commands on common shell separators while respecting
    /// basic quoting and escaping rules.
    public nonisolated static func splitTerminalCommandLineIntoSubCommands(_ commandLine: String) -> [String] {
        let input = commandLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return [] }

        var subCommands: [String] = []
        var current = ""

        var isInSingleQuotes = false
        var isInDoubleQuotes = false
        var isEscaping = false

        func flushCurrent() {
            let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                subCommands.append(trimmed)
            }
            current = ""
        }

        let scalars = Array(input.unicodeScalars)
        var i = 0

        while i < scalars.count {
            let scalar = scalars[i]
            let ch = Character(scalar)

            if isEscaping {
                current.append(ch)
                isEscaping = false
                i += 1
                continue
            }

            if ch == "\\" {
                // Honor backslash escaping outside single-quotes, and inside double-quotes.
                if !isInSingleQuotes {
                    isEscaping = true
                }
                current.append(ch)
                i += 1
                continue
            }

            if ch == "\"" && !isInSingleQuotes {
                isInDoubleQuotes.toggle()
                current.append(ch)
                i += 1
                continue
            }

            if ch == "'" && !isInDoubleQuotes {
                isInSingleQuotes.toggle()
                current.append(ch)
                i += 1
                continue
            }

            if !isInSingleQuotes && !isInDoubleQuotes {
                // Separators: newline, semicolon, pipe, &&, ||
                if ch == "\n" || ch == ";" {
                    flushCurrent()
                    i += 1
                    continue
                }

                if ch == "&" {
                    if i + 1 < scalars.count, Character(scalars[i + 1]) == "&" {
                        flushCurrent()
                        i += 2
                        continue
                    }

                    // Check for &> (Redirection to stdout+stderr)
                    if i + 1 < scalars.count, Character(scalars[i + 1]) == ">" {
                        current.append(ch)
                        i += 1
                        continue
                    }

                    // Check for >& (Redirection, e.g. 2>&1)
                    if current.last == ">" {
                        current.append(ch)
                        i += 1
                        continue
                    }

                    flushCurrent()
                    i += 1
                    continue
                }

                if ch == "|" {
                    if i + 1 < scalars.count, Character(scalars[i + 1]) == "|" {
                        flushCurrent()
                        i += 2
                        continue
                    }
                    flushCurrent()
                    i += 1
                    continue
                }

                if ch == "(" || ch == ")" {
                    flushCurrent()
                    i += 1
                    continue
                }
            }

            current.append(ch)
            i += 1
        }

        flushCurrent()
        return subCommands
    }

    /// Extracts command names (e.g. `git`, `brew`) from a potentially compound command line.
    public nonisolated static func extractTerminalCommandNames(from commandLine: String) -> [String] {
        extractSubCommandsWithTreeSitter(commandLine)
            .compactMap { extractTerminalCommandName(fromSubCommand: $0) }
    }

    /// Extracts the best-effort primary command name from a sub-command.
    public nonisolated static func extractTerminalCommandName(fromSubCommand subCommand: String) -> String? {
        let trimmed = subCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
        guard !parts.isEmpty else { return nil }

        func isEnvAssignment(_ token: Substring) -> Bool {
            guard let eq = token.firstIndex(of: "=") else { return false }
            let key = token[..<eq]
            guard !key.isEmpty else { return false }
            guard let first = key.first, first == "_" || first.isLetter else { return false }
            return key.allSatisfy { $0 == "_" || $0.isLetter || $0.isNumber }
        }

        var index = 0

        // Skip sudo.
        if index < parts.count, parts[index] == "sudo" {
            index += 1
        }

        // Skip env + any leading assignments.
        if index < parts.count, parts[index] == "env" {
            index += 1
            while index < parts.count, isEnvAssignment(parts[index]) {
                index += 1
            }
        }

        // Also skip leading assignments (without explicit `env`).
        while index < parts.count, isEnvAssignment(parts[index]) {
            index += 1
        }

        guard index < parts.count else { return nil }
        return String(parts[index])
    }

    // MARK: - TreeSitter Extraction

    private static func loadBashLanguage() -> Language {
        return Language(language: tree_sitter_bash())
    }

    public nonisolated static func extractSubCommandsWithTreeSitter(_ commandLine: String) -> [String] {
        // macOS typically uses zsh or bash, both are close enough for basic command extraction using tree-sitter-bash
        do {
            let treeSitterLanguage = loadBashLanguage()
            let parser = Parser()
            try parser.setLanguage(treeSitterLanguage)

            guard let tree = parser.parse(commandLine) else {
                return [commandLine.trimmingCharacters(in: .whitespacesAndNewlines)]
            }

            let queryData = "(simple_command) @command".data(using: .utf8)!
            let query = try Query(language: treeSitterLanguage, data: queryData)

            let matches = query.execute(in: tree)
            let captures = matches.flatMap(\.captures)

            let subCommands = captures
                .filter { query.captureName(for: $0.index) == "command" }
                .compactMap { capture -> String? in
                    let node = capture.node
                    let startByte = Int(node.byteRange.lowerBound)
                    let endByte = Int(node.byteRange.upperBound)

                    let utf8 = commandLine.utf8
                    guard let startIndex = utf8.index(utf8.startIndex, offsetBy: startByte, limitedBy: utf8.endIndex),
                          let endIndex = utf8.index(utf8.startIndex, offsetBy: endByte, limitedBy: utf8.endIndex),
                          let cmd = String(utf8[startIndex ..< endIndex]) else { return nil }

                    let trimmed = cmd.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }

            return subCommands
            // return subCommands.isEmpty ? splitTerminalCommandLineIntoSubCommands(commandLine) : subCommands

        } catch {
            // Fallback
            return splitTerminalCommandLineIntoSubCommands(commandLine)
        }
    }
}
