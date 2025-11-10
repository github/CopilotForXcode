import Combine
import Foundation
import Perception
import SharedUIComponents
import SwiftUI
import XcodeInspector
import SuggestionBasic
import WorkspaceSuggestionService

@Perceptible
public final class CodeSuggestionProvider: Equatable {
    public static func == (lhs: CodeSuggestionProvider, rhs: CodeSuggestionProvider) -> Bool {
        lhs.code == rhs.code && lhs.language == rhs.language
    }

    public var code: String = ""
    public var language: String = ""
    public var startLineIndex: Int = 0
    public var suggestionCount: Int = 0
    public var currentSuggestionIndex: Int = 0
    public var extraInformation: String = ""

    @PerceptionIgnored public var onSelectPreviousSuggestionTapped: () -> Void
    @PerceptionIgnored public var onSelectNextSuggestionTapped: () -> Void
    @PerceptionIgnored public var onRejectSuggestionTapped: () -> Void
    @PerceptionIgnored public var onAcceptSuggestionTapped: () -> Void
    @PerceptionIgnored public var onDismissSuggestionTapped: () -> Void

    public init(
        code: String = "",
        language: String = "",
        startLineIndex: Int = 0,
        startCharacerIndex: Int = 0,
        suggestionCount: Int = 0,
        currentSuggestionIndex: Int = 0,
        onSelectPreviousSuggestionTapped: @escaping () -> Void = {},
        onSelectNextSuggestionTapped: @escaping () -> Void = {},
        onRejectSuggestionTapped: @escaping () -> Void = {},
        onAcceptSuggestionTapped: @escaping () -> Void = {},
        onDismissSuggestionTapped: @escaping () -> Void = {}
    ) {
        self.code = code
        self.language = language
        self.startLineIndex = startLineIndex
        self.suggestionCount = suggestionCount
        self.currentSuggestionIndex = currentSuggestionIndex
        self.onSelectPreviousSuggestionTapped = onSelectPreviousSuggestionTapped
        self.onSelectNextSuggestionTapped = onSelectNextSuggestionTapped
        self.onRejectSuggestionTapped = onRejectSuggestionTapped
        self.onAcceptSuggestionTapped = onAcceptSuggestionTapped
        self.onDismissSuggestionTapped = onDismissSuggestionTapped
    }

    func selectPreviousSuggestion() { onSelectPreviousSuggestionTapped() }
    func selectNextSuggestion() { onSelectNextSuggestionTapped() }
    func rejectSuggestion() { onRejectSuggestionTapped() }
    func acceptSuggestion() { onAcceptSuggestionTapped() }
    func dismissSuggestion() { onDismissSuggestionTapped() }

    
}

@Perceptible
public final class NESCodeSuggestionProvider: Equatable {
    public static func == (lhs: NESCodeSuggestionProvider, rhs: NESCodeSuggestionProvider) -> Bool {
        lhs.code == rhs.code && lhs.language == rhs.language
    }
    
    public let fileURL: URL
    public let code: String
    public let sourceSnapshot: FilespaceSuggestionSnapshot
    public let range: CursorRange
    public let language: String
    
    @PerceptionIgnored public var onRejectSuggestionTapped: () -> Void
    @PerceptionIgnored public var onAcceptNESSuggestionTapped: () -> Void
    @PerceptionIgnored public var onDismissNESSuggestionTapped: () -> Void
    
    public init(
        fileURL: URL,
        code: String,
        sourceSnapshot: FilespaceSuggestionSnapshot,
        range: CursorRange,
        language: String = "",
        onRejectSuggestionTapped: @escaping () -> Void = {},
        onAcceptNESSuggestionTapped: @escaping () -> Void = {},
        onDismissNESSuggestionTapped: @escaping () -> Void = {}
    ) {
        self.fileURL = fileURL
        self.code = code
        self.sourceSnapshot = sourceSnapshot
        self.range = range
        self.language = language
        self.onRejectSuggestionTapped = onRejectSuggestionTapped
        self.onAcceptNESSuggestionTapped = onAcceptNESSuggestionTapped
        self.onDismissNESSuggestionTapped = onDismissNESSuggestionTapped
    }
    
    func rejectNESSuggestion() { onRejectSuggestionTapped() }
    func acceptNESSuggestion() { onAcceptNESSuggestionTapped() }
    func dismissNESSuggestion() { onDismissNESSuggestionTapped() }
    
    func getOriginalCodeSnippet() -> String? {
        /// The lines is from `EditorContent`, the "\n" is kept there.
        let lines = sourceSnapshot.lines.joined(separator: "").components(separatedBy: .newlines)
        guard range.start.line >= 0,
              range.end.line >= range.start.line,
              range.end.line < lines.count
        else { return nil }
        
        // Single line case
        if range.start.line == range.end.line {
            let line = lines[range.start.line]
            let startIndex = calcStartIndex(of: line, by: range)
            let endIndex = calcEndIndex(of: line, by: range)
            return String(line[startIndex..<endIndex])
        }
        
        // Multi-line case
        var result: [String] = []
        
        // Determine the actual last line to process
        // If end.character is 0, exclude the end line entirely
        let lastLineIndex = range.end.character == 0 ? range.end.line - 1 : range.end.line
        
        for lineIndex in range.start.line...lastLineIndex {
            let line = lines[lineIndex]
            
            if lineIndex == range.start.line {
                // First line: from start.character to end
                let startIndex = calcStartIndex(of: line, by: range)
                result.append(String(line[startIndex...]))
            } else if lineIndex == range.end.line {
                // Last line: from beginning to end.character (only if end.character > 0)
                let endIndex = calcEndIndex(of: line, by: range)
                result.append(String(line[..<endIndex]))
            } else {
                // Middle lines: full line
                result.append(line)
            }
        }
        
        return result.joined(separator: "\n")
    }
    
    private func calcStartIndex(of line: String, by range: CursorRange) -> String.Index {
        return line.index(line.startIndex, offsetBy: range.start.character, limitedBy: line.endIndex) ?? line.endIndex
    }
    
    private func calcEndIndex(of line: String, by range: CursorRange) -> String.Index {
        return line.index(line.startIndex, offsetBy: range.end.character, limitedBy: line.endIndex) ?? line.endIndex
    }
}

