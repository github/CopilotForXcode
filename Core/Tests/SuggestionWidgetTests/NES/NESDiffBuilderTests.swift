import XCTest

@testable import SuggestionWidget

final class NESDiffBuilderTests: XCTestCase {
    func testInlineSegmentsIdentifiesChangesWithinLine() {
        let oldLine = "    let foo = 1"
        let newLine = "    let bar = 2"

        let segments = DiffBuilder.inlineSegments(oldLine: oldLine, newLine: newLine)

        XCTAssertEqual(segments.count, 6)
        XCTAssertEqual(
            segments.map(\.change),
            [.unchanged, .removed, .added, .unchanged, .removed, .added]
        )
        XCTAssertEqual(
            segments.map(\.text),
            ["    let ", "foo ", "bar ", "= ", "1", "2"]
        )
    }

    func testInlineSegmentsWhenOldLineIsEmptyTreatsNewContentAsAdded() {
        let segments = DiffBuilder.inlineSegments(oldLine: "", newLine: "value")

        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.first?.change, .added)
        XCTAssertEqual(segments.first?.text, "value")
    }

    func testLineSegmentsReturnsDiffAcrossLineBoundaries() {
        let oldContent = [
            "line1",
            "line2",
            "line3"
        ].joined(separator: "\n")
        let newContent = [
            "line1",
            "line3"
        ].joined(separator: "\n")

        let segments = DiffBuilder.lineSegments(oldContent: oldContent, newContent: newContent)

        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(
            segments.map(\.change),
            [.unchanged, .removed, .unchanged]
        )
        XCTAssertEqual(
            segments.map(\.text),
            ["line1", "line2", "line3"]
        )
    }
}

