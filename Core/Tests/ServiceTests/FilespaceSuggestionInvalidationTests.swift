import Foundation
import SuggestionBasic
import XCTest
import WorkspaceSuggestionService

@testable import Service
@testable import Workspace

class FilespaceSuggestionInvalidationTests: XCTestCase {
    @WorkspaceActor
    func prepare(
        lines: [String] = [
            "let one = 1\n",
            "\n",
            "let three = 3\n",
        ],
        cursorPosition: CursorPosition = .init(line: 1, character: 0),
        suggestionText: String = "let two = 2",
        range: CursorRange = .init(startPair: (1, 0), endPair: (1, 0))
    ) async throws -> (Filespace, FilespaceSuggestionSnapshot) {
        let pool = WorkspacePool()
        let filespace = Filespace(
                fileURL: URL(fileURLWithPath: "file/path/to.swift"),
                content: "",
                onSave: { _ in },
                onClose: { _ in }
            )
        filespace.suggestions = [
            .init(
                id: "",
                text: suggestionText,
                position: cursorPosition,
                range: range
            ),
        ]
        let snapshot = FilespaceSuggestionSnapshot(lines: lines, cursorPosition: cursorPosition)
        filespace.suggestionSourceSnapshot = snapshot
        return (filespace, snapshot)
    }

    func testUnchangedDocument_IsValid() async throws {
        let (filespace, priorSnapshot) = try await prepare()

        let isValid = await filespace.validateSuggestions(
            lines: [
                "let one = 1\n",
                "\n",
                "let three = 3\n",
            ],
            cursorPosition: .init(line: 1, character: 0)
        )

        XCTAssertTrue(isValid)
        XCTAssertNotNil(filespace.presentingSuggestion)
        let snapshot = await filespace.suggestionSourceSnapshot
        XCTAssertEqual(snapshot, priorSnapshot)
    }

    func testTypingIntoCompletion_IsValid() async throws {
        let (filespace, priorSnapshot) = try await prepare()

        let isValid = await filespace.validateSuggestions(
            lines: [
                "let one = 1\n",
                "let \n",
                "let three = 3\n",
            ],
            cursorPosition: .init(line: 1, character: 4)
        )

        XCTAssertTrue(isValid)
        XCTAssertNotNil(filespace.presentingSuggestion)
        let snapshot = await filespace.suggestionSourceSnapshot
        XCTAssertEqual(snapshot, priorSnapshot)
    }

    func testTypingIntoMultibyteCharacterCompletion_IsValid() async throws {
        let (filespace, priorSnapshot) = try await prepare(
            suggestionText: "let t🎆🎆 = 2"
        )

        let isValid = await filespace.validateSuggestions(
            lines: [
                "let one = 1\n",
                "let t🎆🎆\n",
                "let three = 3\n",
            ],
            cursorPosition: .init(line: 1, character: 7)
        )

        XCTAssertTrue(isValid)
        XCTAssertNotNil(filespace.presentingSuggestion)
        let snapshot = await filespace.suggestionSourceSnapshot
        XCTAssertEqual(snapshot, priorSnapshot)
    }

    func testTypingNonMatchingText_IsInvalid() async throws {
        let (filespace, priorSnapshot) = try await prepare()

        let isValid = await filespace.validateSuggestions(
            lines: [
                "let one = 1\n",
                "var \n",
                "let three = 3\n",
            ],
            cursorPosition: .init(line: 1, character: 4)
        )

        XCTAssertFalse(isValid)
        XCTAssertNil(filespace.presentingSuggestion)
        let snapshot = await filespace.suggestionSourceSnapshot
        XCTAssertNotEqual(snapshot, priorSnapshot)
    }

    func testMiddleOfLinePosition_IsInvalid() async throws {
        let (filespace, priorSnapshot) = try await prepare()

        let isValid = await filespace.validateSuggestions(
            lines: [
                "let one = 1\n",
                "let \n",
                "let three = 3\n",
            ],
            cursorPosition: .init(line: 1, character: 2)
        )

        XCTAssertFalse(isValid)
        XCTAssertNil(filespace.presentingSuggestion)
        let snapshot = await filespace.suggestionSourceSnapshot
        XCTAssertNotEqual(snapshot, priorSnapshot)
    }

    func testCompletingBracesAfterCursor_IsValid() async throws {
        let (filespace, priorSnapshot) = try await prepare(
            suggestionText: "let two = (2, 2)"
        )

        let isValid = await filespace.validateSuggestions(
            lines: [
                "let one = 1\n",
                "let two = (2)\n",
                "let three = 3\n",
            ],
            cursorPosition: .init(line: 1, character: 12)
        )

        XCTAssertTrue(isValid)
        XCTAssertNotNil(filespace.presentingSuggestion)
        let snapshot = await filespace.suggestionSourceSnapshot
        XCTAssertEqual(snapshot, priorSnapshot)
    }

    func testTypingFullCompletion_IsInvalid() async throws {
        let (filespace, priorSnapshot) = try await prepare()

        let isValid = await filespace.validateSuggestions(
            lines: [
                "let one = 1\n",
                "let two = 2\n",
                "let three = 3\n",
            ],
            cursorPosition: .init(line: 1, character: 11)
        )

        XCTAssertFalse(isValid)
        XCTAssertNil(filespace.presentingSuggestion)
        let snapshot = await filespace.suggestionSourceSnapshot
        XCTAssertNotEqual(snapshot, priorSnapshot)
    }

    func testTypingPastCompletion_IsInvalid() async throws {
        let (filespace, priorSnapshot) = try await prepare()

        let isValid = await filespace.validateSuggestions(
            lines: [
                "let one = 1\n",
                "let two = 22\n",
                "let three = 3\n",
            ],
            cursorPosition: .init(line: 1, character: 12)
        )

        XCTAssertFalse(isValid)
        XCTAssertNil(filespace.presentingSuggestion)
        let snapshot = await filespace.suggestionSourceSnapshot
        XCTAssertNotEqual(snapshot, priorSnapshot)
    }

    func testAlteringOtherDocumentParts_IsInvalid() async throws {
        let (filespace, priorSnapshot) = try await prepare()

        let isValid = await filespace.validateSuggestions(
            lines: [
                "let one = 1\n",
                "\n",
            ],
            cursorPosition: .init(line: 1, character: 0)
        )

        XCTAssertFalse(isValid)
        XCTAssertNil(filespace.presentingSuggestion)
        let snapshot = await filespace.suggestionSourceSnapshot
        XCTAssertNotEqual(snapshot, priorSnapshot)
    }
    
    func testNotPresentingSuggestion_IsInvalid() async throws {
        let (filespace, _) = try await prepare()
        await filespace.reset()

        let isValid = await filespace.validateSuggestions(
            lines: [
                "let one = 1\n",
                "\n",
                "let three = 3\n",
            ],
            cursorPosition: .init(line: 1, character: 0)
        )

        XCTAssertFalse(isValid)
    }

    func testCompletionNotAtStartOfLine_IsInvalid() async throws {
        let (filespace, priorSnapshot) = try await prepare(
            lines: [
                "let one = 1\n",
                "var \n",
                "let three = 3\n",
            ],
            cursorPosition: .init(line: 1, character: 4),
            suggestionText: "two = 2",
            range: .init(startPair: (1, 4), endPair: (1, 4))
        )

        let isValid = await filespace.validateSuggestions(
            lines: [
                "let one = 1\n",
                "let \n",
                "let three = 3\n",
            ],
            cursorPosition: .init(line: 1, character: 4)
        )

        XCTAssertFalse(isValid)
        XCTAssertNil(filespace.presentingSuggestion)
        let snapshot = await filespace.suggestionSourceSnapshot
        XCTAssertNotEqual(snapshot, priorSnapshot)
    }

    func testCompletionReplacingBracesAfterCursor_IsValid() async throws {
        let (filespace, priorSnapshot) = try await prepare(
            lines: [
                "let one = 1\n",
                "let two = (2, (2))\n",
                "let three = 3\n",
            ],
            cursorPosition: .init(line: 1, character: 16),
            suggestionText: "let two = (2, (2, 2))",
            range: .init(startPair: (1, 0), endPair: (1, 18))
        )

        let isValid = await filespace.validateSuggestions(
            lines: [
                "let one = 1\n",
                "let two = (2, (2,))\n",
                "let three = 3\n",
            ],
            cursorPosition: .init(line: 1, character: 17)
        )

        XCTAssertTrue(isValid)
        XCTAssertNotNil(filespace.presentingSuggestion)
        let snapshot = await filespace.suggestionSourceSnapshot
        XCTAssertEqual(snapshot, priorSnapshot)
    }
}

