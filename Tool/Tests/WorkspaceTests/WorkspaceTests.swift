import XCTest
import Foundation
import LanguageServerProtocol
@testable import Workspace

class WorkspaceTests: XCTestCase {
    func testCalculateIncrementalChanges_IdenticalContent() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = "Hello World"
        let newContent = "Hello World"
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNil(changes, "Identical content should return nil")
    }
    
    func testCalculateIncrementalChanges_EmptyOldContent() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = ""
        let newContent = "New content"
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.count, 1)
        XCTAssertEqual(changes?[0].range, LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 0)))
        XCTAssertEqual(changes?[0].text, "New content")
    }
    
    func testCalculateIncrementalChanges_EmptyNewContent() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = "Old content"
        let newContent = ""
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.count, 1)
        XCTAssertEqual(changes?[0].text, "")
        XCTAssertEqual(changes?[0].range?.start.line, 0)
        XCTAssertEqual(changes?[0].range?.start.character, 0)
        XCTAssertEqual(changes?[0].rangeLength, oldContent.utf16.count)
    }
    
    func testCalculateIncrementalChanges_InsertAtBeginning() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = "World"
        let newContent = "Hello World"
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.count, 1)
        XCTAssertEqual(changes?[0].range?.start.line, 0)
        XCTAssertEqual(changes?[0].range?.start.character, 0)
        XCTAssertEqual(changes?[0].text, "Hello ")
    }
    
    func testCalculateIncrementalChanges_InsertAtEnd() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = "Hello"
        let newContent = "Hello World"
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.count, 1)
        XCTAssertEqual(changes?[0].range?.start.line, 0)
        XCTAssertEqual(changes?[0].range?.start.character, 5)
        XCTAssertEqual(changes?[0].text, " World")
    }
    
    func testCalculateIncrementalChanges_InsertInMiddle() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = "Hello World"
        let newContent = "Hello Beautiful World"
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.count, 1)
        XCTAssertEqual(changes?[0].range?.start.line, 0)
        XCTAssertEqual(changes?[0].range?.start.character, 6)
        XCTAssertEqual(changes?[0].text, "Beautiful ")
    }
    
    func testCalculateIncrementalChanges_DeleteFromBeginning() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = "Hello World"
        let newContent = "World"
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.count, 1)
        XCTAssertEqual(changes?[0].range?.start.line, 0)
        XCTAssertEqual(changes?[0].range?.start.character, 0)
        XCTAssertEqual(changes?[0].range?.end.character, 6)
        XCTAssertEqual(changes?[0].text, "")
    }
    
    func testCalculateIncrementalChanges_DeleteFromEnd() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = "Hello World"
        let newContent = "Hello"
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.count, 1)
        XCTAssertEqual(changes?[0].range?.start.line, 0)
        XCTAssertEqual(changes?[0].range?.start.character, 5)
        XCTAssertEqual(changes?[0].text, "")
    }
    
    func testCalculateIncrementalChanges_ReplaceMiddle() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = "Hello World"
        let newContent = "Hello Swift"
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.count, 1)
        XCTAssertEqual(changes?[0].range?.start.line, 0)
        XCTAssertEqual(changes?[0].range?.start.character, 6)
        XCTAssertEqual(changes?[0].text, "Swift")
    }
    
    func testCalculateIncrementalChanges_MultilineInsert() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = "Line 1\nLine 3"
        let newContent = "Line 1\nLine 2\nLine 3"
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.count, 1)
        XCTAssertEqual(changes?[0].range?.start.line, 1)
        XCTAssertEqual(changes?[0].range?.start.character, 5)
        XCTAssertEqual(changes?[0].text, "2\nLine ")
    }
    
    func testCalculateIncrementalChanges_MultilineDelete() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = "Line 1\nLine 2\nLine 3"
        let newContent = "Line 1\nLine 3"
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.count, 1)
        XCTAssertEqual(changes?[0].range?.start.line, 1)
        XCTAssertEqual(changes?[0].range?.start.character, 5)
        XCTAssertEqual(changes?[0].range?.end.line, 2)
        XCTAssertEqual(changes?[0].text, "")
    }
    
    func testCalculateIncrementalChanges_MultilineReplace() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = "Line 1\nOld Line\nLine 3"
        let newContent = "Line 1\nNew Line\nLine 3"
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.count, 1)
        XCTAssertEqual(changes?[0].range?.start.line, 1)
        XCTAssertEqual(changes?[0].text, "New")
    }
    
    func testCalculateIncrementalChanges_UTF16Characters() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = "Hello 世界"
        let newContent = "Hello 🌍 世界"
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.count, 1)
        XCTAssertEqual(changes?[0].range?.start.line, 0)
        XCTAssertEqual(changes?[0].range?.start.character, 6)
        XCTAssertEqual(changes?[0].text, "🌍 ")
    }
    
    func testCalculateIncrementalChanges_VeryLargeContent() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = String(repeating: "a", count: 20000)
        let newContent = String(repeating: "b", count: 20000)
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        // Should fallback to nil for very large contents (> 10000 characters)
        XCTAssertNil(changes, "Very large content should return nil for fallback")
    }
    
    func testCalculateIncrementalChanges_ComplexEdit() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = """
    func hello() {
        print("Hello")
    }
    """
        let newContent = """
    func hello(name: String) {
        print("Hello, \\(name)!")
    }
    """
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.count, 1)
        // Verify that a change was detected
        XCTAssertFalse(changes?[0].text.isEmpty ?? true)
    }
    
    func testCalculateIncrementalChanges_NewlineVariations() {
        let workspace = Workspace(workspaceURL: URL(fileURLWithPath: "/test"))
        let oldContent = "Line 1\nLine 2"
        let newContent = "Line 1\nLine 2\n"
        
        let changes = workspace.calculateIncrementalChanges(oldContent: oldContent, newContent: newContent)
        
        XCTAssertNotNil(changes)
        XCTAssertEqual(changes?.count, 1)
        XCTAssertEqual(changes?[0].range?.start.line, 1)
        XCTAssertEqual(changes?[0].text, "\n")
    }
}
