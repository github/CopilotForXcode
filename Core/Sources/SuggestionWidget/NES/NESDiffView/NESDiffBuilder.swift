import Foundation

struct DiffSegment {
    enum Change {
        case unchanged
        case added
        case removed
    }
    let text: String
    let change: Change
}

enum DiffBuilder {
    static func inlineSegments(oldLine: String, newLine: String) -> [DiffSegment] {
        let oldTokens = tokenizePreservingWhitespace(oldLine)
        let newTokens = tokenizePreservingWhitespace(newLine)
        let condensed = condensedSegments(oldTokens: oldTokens, newTokens: newTokens)
        return mergeInlineWhitespaceSegments(condensed)
    }
    
    static func lineSegments(oldContent: String, newContent: String) -> [DiffSegment] {
        let oldLines = oldContent.components(separatedBy: .newlines)
        let newLines = newContent.components(separatedBy: .newlines)
        return diff(tokensInOld: oldLines, tokensInNew: newLines)
    }
    
    private static func tokenizePreservingWhitespace(_ text: String) -> [String] {
        guard !text.isEmpty else { return [] }
        // This pattern matches either:
        // - a sequence of non-whitespace characters (\\S+) followed by optional whitespace (\\s*), or
        // - a sequence of whitespace characters (\\s+)
        // This ensures that tokens preserve trailing whitespace, or capture standalone whitespace sequences.
        let pattern = "\\S+\\s*|\\s+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return [text]
        }
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, range: fullRange)
        if matches.isEmpty {
            return [text]
        }
        return matches.map { nsText.substring(with: $0.range) }
    }
    
    private static func condensedSegments(oldTokens: [String], newTokens: [String]) -> [DiffSegment] {
        let raw = diff(tokensInOld: oldTokens, tokensInNew: newTokens)
        guard var last = raw.first else { return [] }
        var condensed: [DiffSegment] = []
        for segment in raw.dropFirst() {
            if segment.change == last.change {
                last = DiffSegment(text: last.text + segment.text, change: last.change)
            } else {
                condensed.append(last)
                last = segment
            }
        }
        condensed.append(last)
        return condensed
    }
    
    private static func diff(tokensInOld oldTokens: [String], tokensInNew newTokens: [String]) -> [DiffSegment] {
        let m = oldTokens.count
        let n = newTokens.count
        if m == 0 { return newTokens.map { DiffSegment(text: $0, change: .added) } }
        if n == 0 { return oldTokens.map { DiffSegment(text: $0, change: .removed) } }
        var lcs = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...m {
            for j in 1...n {
                if oldTokens[i - 1] == newTokens[j - 1] {
                    lcs[i][j] = lcs[i - 1][j - 1] + 1
                } else {
                    lcs[i][j] = max(lcs[i - 1][j], lcs[i][j - 1])
                }
            }
        }
        var i = m
        var j = n
        var result: [DiffSegment] = []
        while i > 0 && j > 0 {
            if oldTokens[i - 1] == newTokens[j - 1] {
                result.append(DiffSegment(text: oldTokens[i - 1], change: .unchanged))
                i -= 1
                j -= 1
            } else if lcs[i - 1][j] > lcs[i][j - 1] {
                result.append(DiffSegment(text: oldTokens[i - 1], change: .removed))
                i -= 1
            } else {
                result.append(DiffSegment(text: newTokens[j - 1], change: .added))
                j -= 1
            }
        }
        while i > 0 {
            result.append(DiffSegment(text: oldTokens[i - 1], change: .removed))
            i -= 1
        }
        while j > 0 {
            result.append(DiffSegment(text: newTokens[j - 1], change: .added))
            j -= 1
        }
        return result.reversed()
    }
    
    private static func mergeInlineWhitespaceSegments(_ segments: [DiffSegment]) -> [DiffSegment] {
        guard !segments.isEmpty else { return segments }
        var merged: [DiffSegment] = []
        var index = 0
        while index < segments.count {
            let current = segments[index]
            switch current.change {
            case .added, .removed:
                var combinedText = current.text
                var lookahead = index + 1
                while lookahead + 1 < segments.count,
                      segments[lookahead].change == .unchanged,
                      segments[lookahead].text.isWhitespaceOnly,
                      segments[lookahead + 1].change == current.change {
                    combinedText += segments[lookahead].text + segments[lookahead + 1].text
                    lookahead += 2
                }
                merged.append(DiffSegment(text: combinedText, change: current.change))
                index = lookahead
            case .unchanged:
                merged.append(current)
                index += 1
            }
        }
        return merged
    }
}

private extension String {
    var isWhitespaceOnly: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
