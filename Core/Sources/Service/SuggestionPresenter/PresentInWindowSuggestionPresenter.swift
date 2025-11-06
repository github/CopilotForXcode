import ChatService
import Foundation
import ChatAPIService
import SuggestionBasic
import SuggestionWidget

struct PresentInWindowSuggestionPresenter {
    func presentSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.suggestCode()
        }
    }
    
    func presentNESSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.suggestNESCode()
        }
    }

    func expandSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.expandSuggestion()
        }
    }
    
    func discardSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.discardSuggestion()
        }
    }
    
    func discardNESSuggestion(fileURL: URL) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.discardNESSuggestion()
        }
    }

    func markAsProcessing(_ isProcessing: Bool) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.markAsProcessing(isProcessing)
        }
    }

    func presentError(_ error: Error) {
        if error is CancellationError { return }
        if let urlError = error as? URLError, urlError.code == URLError.cancelled { return }
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.presentError(error.localizedDescription)
        }
    }

    func presentErrorMessage(_ message: String) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.presentError(message)
        }
    }

    func presentWarningMessage(_ message: String, url: String?) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.presentWarning(message: message, url: url)
        }
    }

    func dismissWarning() {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.dismissWarning()
        }
    }

    func closeChatRoom(fileURL: URL) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.closeChatRoom()
        }
    }

    func presentChatRoom(fileURL: URL) {
        Task { @MainActor in
            let controller = Service.shared.guiController.widgetController
            controller.presentChatRoom()
        }
    }
}

