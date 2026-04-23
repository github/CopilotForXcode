import Foundation
import SuggestionBasic
import Workspace
import XPCShared

public struct FilespaceSuggestionSnapshot: Equatable {
    public let lines: [String]
    public let linesHash: Int
    public let prefixLinesHash: Int
    public let suffixLinesHash: Int
    public let cursorPosition: CursorPosition
    public let currentLine: String

    public init(lines: [String], cursorPosition: CursorPosition) {
        func safeIndex(_ index: Int) -> Int {
            return max(min(index, lines.endIndex), lines.startIndex)
        }

        self.lines = lines
        self.linesHash = lines.hashValue
        self.cursorPosition = cursorPosition
        self.prefixLinesHash = lines[0..<safeIndex(cursorPosition.line)].hashValue
        self.suffixLinesHash = lines[safeIndex(cursorPosition.line + 1)..<lines.endIndex].hashValue
        self.currentLine = cursorPosition.line >= lines.startIndex && cursorPosition.line < lines.endIndex ? lines[safeIndex(cursorPosition.line)] : ""
    }

    public init(content: EditorContent) {
        self.init(lines: content.lines, cursorPosition: content.cursorPosition)
    }

    public func equalOrOnlyCurrentLineDiffers(comparedTo: FilespaceSuggestionSnapshot) -> Bool {
        return prefixLinesHash == comparedTo.prefixLinesHash &&
        suffixLinesHash == comparedTo.suffixLinesHash &&
        cursorPosition.line == comparedTo.cursorPosition.line
    }
}

public struct FilespaceSuggestionSnapshotKey: FilespacePropertyKey {
    public static func createDefaultValue()
        -> FilespaceSuggestionSnapshot { .init(lines: [], cursorPosition: .outOfScope) }
}

public struct FilespaceNESSuggestionSnapshotKey: FilespacePropertyKey {
    public static func createDefaultValue()
        -> FilespaceSuggestionSnapshot { .init(lines: [], cursorPosition: .outOfScope) }
}

public extension FilespacePropertyValues {
    @WorkspaceActor
    var suggestionSourceSnapshot: FilespaceSuggestionSnapshot {
        get { self[FilespaceSuggestionSnapshotKey.self] }
        set { self[FilespaceSuggestionSnapshotKey.self] = newValue }
    }
    
    @WorkspaceActor
    var nesSuggestionSourceSnapshot: FilespaceSuggestionSnapshot {
        get { self[FilespaceNESSuggestionSnapshotKey.self] }
        set { self[FilespaceNESSuggestionSnapshotKey.self] = newValue }
    }
}

public extension Filespace {
    @WorkspaceActor
    func resetSnapshot() {
        // swiftformat:disable redundantSelf
        self.suggestionSourceSnapshot = FilespaceSuggestionSnapshotKey.createDefaultValue()
        // swiftformat:enable all
    }
    
    @WorkspaceActor
    func resetNESSnapshot() {
        // swiftformat:disable redundantSelf
        self.nesSuggestionSourceSnapshot = FilespaceNESSuggestionSnapshotKey.createDefaultValue()
        // swiftformat:enable all
    }

    /// Validate the suggestion is still valid.
    /// - Parameters:
    ///    - lines: lines of the file
    ///    - cursorPosition: cursor position
    /// - Returns: `true` if the suggestion is still valid
    @WorkspaceActor
    func validateSuggestions(lines: [String], cursorPosition: CursorPosition) -> Bool {
        guard let presentingSuggestion else { return false }

        let updatedSnapshot = FilespaceSuggestionSnapshot(lines: lines, cursorPosition: cursorPosition)

        // document state is unchanged
        if updatedSnapshot == self.suggestionSourceSnapshot {
            return true
        }

        // other parts of the document have changed
        if !self.suggestionSourceSnapshot.equalOrOnlyCurrentLineDiffers(comparedTo: updatedSnapshot) {
            reset()
            resetSnapshot()
            return false
        }

        // the suggestion does not start on the current line
        if presentingSuggestion.range.start.line != cursorPosition.line ||
            presentingSuggestion.range.start.character != 0 {
            reset()
            resetSnapshot()
            return false
        }

        // the cursor position is invalid
        if cursorPosition.line >= lines.count {
            reset()
            resetSnapshot()
            return false
        }

        let edit = LineEdit(
                snapshot: self.suggestionSourceSnapshot,
                suggestion: presentingSuggestion,
                lines: lines,
                cursor: cursorPosition
        )
        let suggestionLines = presentingSuggestion.text.split(whereSeparator: \.isNewline)
        let suggestionFirstLine = suggestionLines.first ?? ""

        // there is user-entered text to the right of the cursor
        if edit.userEntered.count > cursorPosition.character {
            reset()
            resetSnapshot()
            return false
        }

        // the replacement range can't be adjusted
        if presentingSuggestion.range.end.line != cursorPosition.line {
            reset()
            resetSnapshot()
            return false
        }

        // typing into the completion
        if edit.line.count < suggestionFirstLine.count && suggestionFirstLine.hasPrefix(edit.userEntered) {
            updateSuggestionsWithSameSelection(edit.updateSuggestions(suggestions))
            return true
        }

        reset()
        resetSnapshot()
        return false
    }
    
    /// Validate the nes suggestion is still valid.
    /// - Parameters:
    ///   - lines: lines of the file
    ///   - cursorPosition: cursor position
    ///   - Returns: `true` if the nes suggestion is still valid
    @WorkspaceActor
    func validateNESSuggestions(lines: [String], cursorPosition: CursorPosition) -> Bool {
        guard let presentingNESSuggestion else { return false }
        
        let updatedSnapshot = FilespaceSuggestionSnapshot(lines: lines, cursorPosition: cursorPosition)
        
        // document state is unchanged
        if updatedSnapshot == self.nesSuggestionSourceSnapshot {
            return true
        }
        
        resetNESSuggestion()
        resetNESSnapshot()
        return false
    }
}

