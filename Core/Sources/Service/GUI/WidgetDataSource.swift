import ActiveApplicationMonitor
import AppActivator
import AppKit
import ChatService
import ComposableArchitecture
import Foundation
import GitHubCopilotService
import ChatAPIService
import PromptToCodeService
import SuggestionBasic
import SuggestionWidget
import WorkspaceSuggestionService
import Workspace

@MainActor
final class WidgetDataSource {}

extension WidgetDataSource: SuggestionWidgetDataSource {
    func suggestionForFile(at url: URL) async -> CodeSuggestionProvider? {
        for workspace in Service.shared.workspacePool.workspaces.values {
            if let filespace = workspace.filespaces[url],
               let suggestion = filespace.presentingSuggestion
            {
                return .init(
                    code: suggestion.text,
                    language: filespace.language.rawValue,
                    startLineIndex: suggestion.position.line,
                    suggestionCount: filespace.suggestions.count,
                    currentSuggestionIndex: filespace.suggestionIndex,
                    onSelectPreviousSuggestionTapped: {
                        Task {
                            let handler = PseudoCommandHandler()
                            await handler.presentPreviousSuggestion()
                        }
                    },
                    onSelectNextSuggestionTapped: {
                        Task {
                            let handler = PseudoCommandHandler()
                            await handler.presentNextSuggestion()
                        }
                    },
                    onRejectSuggestionTapped: {
                        Task {
                            let handler = PseudoCommandHandler()
                            await handler.rejectSuggestions()
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    },
                    onAcceptSuggestionTapped: {
                        Task {
                            let handler = PseudoCommandHandler()
                            await handler.acceptSuggestion(.codeCompletion)
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    },
                    onDismissSuggestionTapped: {
                        Task {
                            let handler = PseudoCommandHandler()
                            await handler.dismissSuggestion()
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    }
                )
            }
        }
        return nil
    }
    
    func nesSuggestionForFile(at url: URL) async -> NESCodeSuggestionProvider? {
        for workspace in await Service.shared.workspacePool.workspaces.values {
            if let filespace = workspace.filespaces[url],
                let nesSuggestion = filespace.presentingNESSuggestion
            {
                let sourceSnapshot = await getSourceSnapshot(from: filespace)
                return .init(
                    fileURL: url,
                    code: nesSuggestion.text,
                    sourceSnapshot: sourceSnapshot,
                    range: nesSuggestion.range,
                    language: filespace.language.rawValue,
                    onRejectSuggestionTapped: {
                        Task {
                            let handler = PseudoCommandHandler()
                            await handler.rejectNESSuggestions()
                        }
                    },
                    onAcceptNESSuggestionTapped: {
                        Task {
                            let handler = PseudoCommandHandler()
                            await handler.acceptSuggestion(.nes)
                            NSWorkspace.activatePreviousActiveXcode()
                        }
                    },
                    onDismissNESSuggestionTapped: {
                        // Refer to Code Completion suggestion, the `dismiss` action is not support
                    }
                )
            }
        }
        
        return nil
    }
}


@WorkspaceActor
private func getSourceSnapshot(from filespace: Filespace) -> FilespaceSuggestionSnapshot {
    return filespace.nesSuggestionSourceSnapshot
}
