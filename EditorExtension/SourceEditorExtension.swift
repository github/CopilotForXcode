import Client
import Foundation
import GitHubCopilotService
import Preferences
import XcodeKit

#if canImport(PreferencesPlus)
import PreferencesPlus
#endif

class SourceEditorExtension: NSObject, XCSourceEditorExtension {
    var builtin: [[XCSourceEditorCommandDefinitionKey: Any]] {
        [
            AcceptSuggestionCommand(),
            AcceptNESSuggestionCommand(),
            RejectSuggestionCommand(),
            RejectNESSuggestionCommand(),
            GetSuggestionsCommand(),
            NextSuggestionCommand(),
            PreviousSuggestionCommand(),
            SyncTextSettingsCommand(),
            ToggleRealtimeSuggestionsCommand(),
        ].map(makeCommandDefinition)
    }
    
    var chat: [[XCSourceEditorCommandDefinitionKey: Any]] {
        [
            OpenChatCommand()
        ].map(makeCommandDefinition)
    }

    var additionalBuiltin: [[XCSourceEditorCommandDefinitionKey: Any]] {
        [
            OpenSettingsCommand(),
        ].map(makeCommandDefinition)
    }

    var commandDefinitions: [[XCSourceEditorCommandDefinitionKey: Any]] {
        var definitions = builtin
        
        if FeatureFlagNotifierImpl.shared.featureFlags.chat {
            definitions += chat
        }

        definitions += additionalBuiltin
        
        return definitions
    }

    func extensionDidFinishLaunching() {
        #if DEBUG
        // In a debug build, we usually want to use the XPC service run from Xcode.
        #else
        // When the source extension is initialized
        // we can call a random command to wake up the XPC service.
        Task.detached {
            try await Task.sleep(nanoseconds: 1_000_000_000)
            let service = try getService()
            _ = try await service.getXPCServiceVersion()
        }
        #endif
    }
}

let identifierPrefix: String = Bundle.main.bundleIdentifier ?? ""

var customCommandMap = [String: String]()

protocol CommandType: AnyObject {
    var commandClassName: String { get }
    var identifier: String { get }
    var name: String { get }
}

extension CommandType where Self: NSObject {
    var commandClassName: String { Self.className() }
    var identifier: String { commandClassName }
}

extension CommandType {
    func makeCommandDefinition() -> [XCSourceEditorCommandDefinitionKey: Any] {
        [.classNameKey: commandClassName,
         .identifierKey: identifierPrefix + identifier,
         .nameKey: name]
    }
}

func makeCommandDefinition(_ commandType: CommandType)
    -> [XCSourceEditorCommandDefinitionKey: Any]
{
    commandType.makeCommandDefinition()
}
