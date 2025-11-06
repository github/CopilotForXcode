import Foundation
import XCTest
import SuggestionBasic

@testable import Workspace
@testable import KeyBindingManager

class TabToAcceptSuggestionTests: XCTestCase {
    
    @WorkspaceActor
    func test_should_accept() {
        let fileURL = URL(string: "file:///test")!
        let workspacePool = FakeWorkspacePool()
        workspacePool.setTestFile(fileURL: fileURL)
        let xcodeInspector = FakeThreadSafeAccessToXcodeInspector(
            activeDocumentURL: fileURL,
            hasActiveXcode: true,
            hasFocusedEditor: true
        )
        assertEqual(
            TabToAcceptSuggestion.shouldAcceptSuggestion(
                event: CGEvent(keyboardEventSource: nil, virtualKey: 48, keyDown: true)!,
                workspacePool: workspacePool,
                xcodeInspector: xcodeInspector
            ), (true, nil, .codeCompletion)
        )
    }

    @WorkspaceActor
    func test_should_not_accept_without_suggestion() {
        let fileURL = URL(string: "file:///test")!
        let workspacePool = FakeWorkspacePool()
        workspacePool.setTestFile(fileURL: fileURL, skipSuggestion: true)
        let xcodeInspector = FakeThreadSafeAccessToXcodeInspector(
            activeDocumentURL: fileURL,
            hasActiveXcode: true,
            hasFocusedEditor: true
        )
        assertEqual(
            TabToAcceptSuggestion.shouldAcceptSuggestion(
                event: CGEvent(keyboardEventSource: nil, virtualKey: 48, keyDown: true)!,
                workspacePool: workspacePool,
                xcodeInspector: xcodeInspector
            ), (false, "No suggestion", nil)
        )
    }

    @WorkspaceActor
    func test_should_not_accept_without_filespace() {
        let fileURL = URL(string: "file:///test")!
        let workspacePool = FakeWorkspacePool()
        let xcodeInspector = FakeThreadSafeAccessToXcodeInspector(
            activeDocumentURL: fileURL,
            hasActiveXcode: true,
            hasFocusedEditor: true
        )
        assertEqual(
            TabToAcceptSuggestion.shouldAcceptSuggestion(
                event: CGEvent(keyboardEventSource: nil, virtualKey: 48, keyDown: true)!,
                workspacePool: workspacePool,
                xcodeInspector: xcodeInspector
            ), (false, "No filespace", nil)
        )
    }

    @WorkspaceActor
    func test_should_not_accept_without_editor_focused() {
        let fileURL = URL(string: "file:///test")!
        let workspacePool = FakeWorkspacePool()
        workspacePool.setTestFile(fileURL: fileURL)
        let xcodeInspector = FakeThreadSafeAccessToXcodeInspector(
            activeDocumentURL: fileURL,
            hasActiveXcode: true,
            hasFocusedEditor: false
        )
        assertEqual(
            TabToAcceptSuggestion.shouldAcceptSuggestion(
                event: CGEvent(keyboardEventSource: nil, virtualKey: 48, keyDown: true)!,
                workspacePool: workspacePool,
                xcodeInspector: xcodeInspector
            ), (false, "No focused editor", nil)
        )
    }

    @WorkspaceActor
    func test_should_not_accept_without_active_xcode() {
        let fileURL = URL(string: "file:///test")!
        let workspacePool = FakeWorkspacePool()
        workspacePool.setTestFile(fileURL: fileURL)
        let xcodeInspector = FakeThreadSafeAccessToXcodeInspector(
            activeDocumentURL: fileURL,
            hasActiveXcode: false,
            hasFocusedEditor: true
        )
        assertEqual(
            TabToAcceptSuggestion.shouldAcceptSuggestion(
                event: createEvent(48),
                workspacePool: workspacePool,
                xcodeInspector: xcodeInspector
            ), (false, "No active Xcode", nil)
        )
    }

    @WorkspaceActor
    func test_should_not_accept_without_active_document() {
        let fileURL = URL(string: "file:///test")!
        let workspacePool = FakeWorkspacePool()
        workspacePool.setTestFile(fileURL: fileURL)
        let xcodeInspector = FakeThreadSafeAccessToXcodeInspector(
            activeDocumentURL: nil,
            hasActiveXcode: true,
            hasFocusedEditor: true
        )
        assertEqual(
            TabToAcceptSuggestion.shouldAcceptSuggestion(
                event: createEvent(48),
                workspacePool: workspacePool,
                xcodeInspector: xcodeInspector
            ), (false, "No active document", nil)
        )
    }

    @WorkspaceActor
    func test_should_not_accept_with_shift() {
        let fileURL = URL(string: "file:///test")!
        let workspacePool = FakeWorkspacePool()
        workspacePool.setTestFile(fileURL: fileURL)
        let xcodeInspector = FakeThreadSafeAccessToXcodeInspector(
            activeDocumentURL: fileURL,
            hasActiveXcode: true,
            hasFocusedEditor: true
        )
        assertEqual(
            TabToAcceptSuggestion.shouldAcceptSuggestion(
                event: createEvent(48, flags: .maskShift),
                workspacePool: workspacePool,
                xcodeInspector: xcodeInspector
            ), (false, nil, nil)
        )
    }

    @WorkspaceActor
    func test_should_not_accept_with_command() {
        let fileURL = URL(string: "file:///test")!
        let workspacePool = FakeWorkspacePool()
        workspacePool.setTestFile(fileURL: fileURL)
        let xcodeInspector = FakeThreadSafeAccessToXcodeInspector(
            activeDocumentURL: fileURL,
            hasActiveXcode: true,
            hasFocusedEditor: true
        )
        assertEqual(
            TabToAcceptSuggestion.shouldAcceptSuggestion(
                event: createEvent(48, flags: .maskCommand),
                workspacePool: workspacePool,
                xcodeInspector: xcodeInspector
            ), (false, nil, nil)
        )
    }

    @WorkspaceActor
    func test_should_not_accept_with_control() {
        let fileURL = URL(string: "file:///test")!
        let workspacePool = FakeWorkspacePool()
        workspacePool.setTestFile(fileURL: fileURL)
        let xcodeInspector = FakeThreadSafeAccessToXcodeInspector(
            activeDocumentURL: fileURL,
            hasActiveXcode: true,
            hasFocusedEditor: true
        )
        assertEqual(
            TabToAcceptSuggestion.shouldAcceptSuggestion(
                event: createEvent(48, flags: .maskControl),
                workspacePool: workspacePool,
                xcodeInspector: xcodeInspector
            ), (false, nil, nil)
        )
    }

    @WorkspaceActor
    func test_should_not_accept_with_help() {
        let fileURL = URL(string: "file:///test")!
        let workspacePool = FakeWorkspacePool()
        workspacePool.setTestFile(fileURL: fileURL)
        let xcodeInspector = FakeThreadSafeAccessToXcodeInspector(
            activeDocumentURL: fileURL,
            hasActiveXcode: true,
            hasFocusedEditor: true
        )
        assertEqual(
            TabToAcceptSuggestion.shouldAcceptSuggestion(
                event: createEvent(48, flags: .maskHelp),
                workspacePool: workspacePool,
                xcodeInspector: xcodeInspector
            ), (false, nil, nil)
        )
    }
}

private func assertEqual(
    _ result: (Bool, String?, CodeSuggestionType?),
    _ expected: (Bool, String?, CodeSuggestionType?),
) {
    if result != expected {
        XCTFail("Expected \(expected), got \(result)")
    }
}

private func createEvent(_ keyCode: CGKeyCode, flags: CGEventFlags = []) -> CGEvent {
    let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true)!
    event.flags = flags
    return event
}

private struct FakeThreadSafeAccessToXcodeInspector: ThreadSafeAccessToXcodeInspectorProtocol {
    let activeDocumentURL: URL?
    let hasActiveXcode: Bool
    let hasFocusedEditor: Bool
}

private class FakeWorkspacePool: WorkspacePool {
    private var fileURL: URL?
    private var filespace: Filespace?
    
    @WorkspaceActor
    func setTestFile(fileURL: URL, skipSuggestion: Bool = false) {
        self.fileURL = fileURL
        self.filespace = Filespace(fileURL: fileURL, content: "", onSave: {_ in }, onClose: {_ in })
        if skipSuggestion { return }
        guard let filespace = self.filespace else { return }
        filespace.setSuggestions([.init(id: "id", text: "test", position: .zero, range: .zero)])
    }
    
    override func fetchFilespaceIfExisted(fileURL: URL) -> Filespace? {
        guard fileURL == self.fileURL else { return .none }
        return filespace
    }
}

