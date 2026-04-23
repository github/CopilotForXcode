import SuggestionBasic
import LanguageServerProtocol


public struct CopilotInlineEditsParams: Codable {
    public let textDocument: VersionedTextDocumentIdentifier
    public let position: CursorPosition
}

public struct CopilotInlineEdit: Codable {
    public struct Command: Codable {
        public let title: String
        public let command: String
        public let arguments: [String]
    }
    /**
     * The new text for this edit.
     */
    public let text: String
    /**
     * The text document this edit applies to including the version
     * Uses the same schema as for completions: src
     *
     *   "textDocument": {
     *       "uri": "file:///path/to/file",
     *       "version": 0
     *   },
     *
     */
    public let textDocument: VersionedTextDocumentIdentifier
    public let range: CursorRange
    /**
     * Called by the client with workspace/executeCommand after accepting the next edit suggestion.
     */
    public let command: Command?
}

public struct CopilotInlineEditsResponse: Codable {
    public let edits: [CopilotInlineEdit]
}

// MARK: - Notification

public struct TextDocumentDidShowInlineEditParams: Codable, Hashable {
    public struct Command: Codable, Hashable {
        public var arguments: [String]
    }
    
    public struct NotificationCommandSchema: Codable, Hashable {
        public var command: Command
    }
    
    public var item: NotificationCommandSchema
    
    public static func from(id: String) -> Self {
        .init(item: .init(command: .init(arguments: [id])))
    }
}

