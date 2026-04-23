import Foundation

public protocol SuggestionWidgetDataSource {
    func suggestionForFile(at url: URL) async -> CodeSuggestionProvider?
    func nesSuggestionForFile(at url: URL) async -> NESCodeSuggestionProvider?
}

struct MockWidgetDataSource: SuggestionWidgetDataSource {
    func suggestionForFile(at url: URL) async -> CodeSuggestionProvider? {
        return CodeSuggestionProvider(
            code: """
            func test() {
                let x = 1
                let y = 2
                let z = x + y
            }
            """,
            language: "swift",
            startLineIndex: 1,
            suggestionCount: 3,
            currentSuggestionIndex: 0
        )
    }
    
    func nesSuggestionForFile(at url: URL) async -> NESCodeSuggestionProvider? {
        return NESCodeSuggestionProvider(
            fileURL: URL(fileURLWithPath: "the/file/path.swift"),
            code: """
            func test() {
                let x = 1
                let y = 2
                let z = x + y
            }
            """,
            sourceSnapshot: .init(
                lines: [""],
                cursorPosition: .init(line: 0, character: 0)
            ),
            range: .init(startPair: (1, 0), endPair: (2, 0)),
            language: "swift"
        )
    }
}

