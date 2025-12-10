import AppKit
import Client
import Foundation
import GitHubCopilotService
import SuggestionBasic
import Workspace
import XCTest
import XPCShared
import LanguageServerProtocol

@testable import Service

func completion(text: String, range: CursorRange, uuid: String = "") -> CodeSuggestion {
    .init(id: uuid, text: text, position: range.start, range: range)
}

class MockSuggestionService: GitHubCopilotSuggestionServiceType {
    func terminate() async {
        fatalError()
    }

    func cancelRequest() async {
        fatalError()
    }

    func notifyOpenTextDocument(fileURL: URL, content: String) async throws {
        fatalError()
    }

    func notifyChangeTextDocument(fileURL: URL, content: String, version: Int, contentChanges: [LanguageServerProtocol.TextDocumentContentChangeEvent]?) async throws {
        fatalError()
    }

    func notifyCloseTextDocument(fileURL: URL) async throws {
        fatalError()
    }

    func notifySaveTextDocument(fileURL: URL) async throws {
        fatalError()
    }

    var completions = [CodeSuggestion]()
    var shown: String?
    var accepted: String?
    var rejected: [String] = []

    init(completions: [CodeSuggestion]) {
        self.completions = completions
    }

    func getCompletions(
        fileURL: URL,
        content: String,
        originalContent: String,
        cursorPosition: SuggestionBasic.CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool
    ) async throws -> [SuggestionBasic.CodeSuggestion] {
        completions
    }

    func getCopilotInlineEdit(
        fileURL: URL,
        content: String,
        cursorPosition: SuggestionBasic.CursorPosition
    ) async throws -> [SuggestionBasic.CodeSuggestion] {
        completions
    }

    func notifyShown(_ completion: SuggestionBasic.CodeSuggestion) async {
        shown = completion.id
    }
    
    func notifyCopilotInlineEditShown(_ completion: SuggestionBasic.CodeSuggestion) async {
        shown = completion.id
    }

    func notifyAccepted(_ completion: CodeSuggestion, acceptedLength: Int? = nil) async {
        accepted = completion.id
    }
    
    func notifyCopilotInlineEditAccepted(_ completion: CodeSuggestion) async {
        accepted = completion.id
    }

    func notifyRejected(_ completions: [CodeSuggestion]) async {
        rejected = completions.map(\.id)
    }
}

