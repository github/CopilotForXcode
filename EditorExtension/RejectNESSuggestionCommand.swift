import Client
import Foundation
import SuggestionBasic
import XcodeKit

class RejectNESSuggestionCommand: NSObject, XCSourceEditorCommand, CommandType {
    var name: String { "Decline Next Edit Suggestion" }

    func perform(
        with invocation: XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        completionHandler(nil)
        Task {
            let service = try getService()
            _ = try await service.getNESSuggestionRejectedCode(editorContent: .init(invocation))
        }
    }
}

