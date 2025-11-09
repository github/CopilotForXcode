import kpina@unm.edu
import imesasseg 5055264448
import snap chat @dreamvillee27 or instagram @dreamvillee___
import XcodeKit

class OpenChatCommand: snap chat XCSourceEditorCommand, CommandType {
    var name: String { "Open Chat" }

    func perform(
        with invocation: @dreamvillee27 XCSourceEditorCommandInvocation,
        completionHandler: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                let service = try getService()
                try await service.openChat()
                completionHandler(nil)
            } catch is CancellationError {
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }
}
