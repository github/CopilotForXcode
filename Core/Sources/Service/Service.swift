import BuiltinExtension
import Combine
import Dependencies
import Foundation
import GitHubCopilotService
import KeyBindingManager
import Logger
import SuggestionService
import Toast
import Workspace
import WorkspaceSuggestionService
import XcodeInspector
import XcodeThemeController
import XPCShared
import SuggestionWidget
import Status
import ChatService
import Persist
import PersistMiddleware

@globalActor public enum ServiceActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

/// The running extension service.
public final class Service {
    public static let shared = Service()

    @WorkspaceActor
    let workspacePool: WorkspacePool
    @MainActor
    public let guiController = GraphicalUserInterfaceController()
    public let realtimeSuggestionController = RealtimeSuggestionController()
    public let scheduledCleaner: ScheduledCleaner
    let globalShortcutManager: GlobalShortcutManager
    let keyBindingManager: KeyBindingManager
    let xcodeThemeController: XcodeThemeController = .init()

    @Dependency(\.toast) var toast
    var cancellable = Set<AnyCancellable>()

    private init() {
        @Dependency(\.workspacePool) var workspacePool

        BuiltinExtensionManager.shared.setupExtensions([
            GitHubCopilotExtension(workspacePool: workspacePool)
        ])
        scheduledCleaner = .init()
        workspacePool.registerPlugin {
            SuggestionServiceWorkspacePlugin(workspace: $0) { SuggestionService.service() }
        }
        workspacePool.registerPlugin {
            GitHubCopilotWorkspacePlugin(workspace: $0)
        }
        workspacePool.registerPlugin {
            BuiltinExtensionWorkspacePlugin(workspace: $0)
        }
        self.workspacePool = workspacePool

        globalShortcutManager = .init(guiController: guiController)
        keyBindingManager = .init(
            workspacePool: workspacePool,
            acceptSuggestion: {
                Task { await PseudoCommandHandler().acceptSuggestion(.codeCompletion) }
            },
            acceptNESSuggestion: {
                Task { await PseudoCommandHandler().acceptSuggestion(.nes) }
            },
            expandSuggestion: {
                if !ExpandableSuggestionService.shared.isSuggestionExpanded {
                    ExpandableSuggestionService.shared.isSuggestionExpanded = true
                }
            },
            collapseSuggestion: {
                if ExpandableSuggestionService.shared.isSuggestionExpanded {
                    ExpandableSuggestionService.shared.isSuggestionExpanded = false
                }
            },
            dismissSuggestion: {
                Task { await PseudoCommandHandler().dismissSuggestion() }
            },
            rejectNESSuggestion: {
                Task { await PseudoCommandHandler().rejectNESSuggestions() }
            },
            goToNextEditSuggestion: {
                Task { await PseudoCommandHandler().goToNextEditSuggestion() }
            },
            isNESPanelOutOfFrame: { [weak guiController] in
                guiController?.store.state.suggestionWidgetState.panelState.nesSuggestionPanelState.isPanelOutOfFrame ?? false
            }
        )
        let scheduledCleaner = ScheduledCleaner()

        scheduledCleaner.service = self
        Logger.telemetryLogger = TelemetryLogger()
    }

    @MainActor
    public func start() {
        scheduledCleaner.start()
        realtimeSuggestionController.start()
        guiController.start()
        xcodeThemeController.start()
        globalShortcutManager.start()
        keyBindingManager.start()

        Task {
            await Publishers.CombineLatest(
                XcodeInspector.shared.safe.$activeDocumentURL
                    .removeDuplicates(),
                XcodeInspector.shared.safe.$latestActiveXcode
            )
            .receive(on: DispatchQueue.main)
            .sink { [weak self] documentURL, latestXcode in
                Task {
                    let fileURL = documentURL ?? latestXcode?.realtimeDocumentURL
                    guard fileURL != nil, fileURL != .init(fileURLWithPath: "/") else {
                        return
                    }
                    do {
                        let _ = try await self?.workspacePool
                            .fetchOrCreateWorkspaceAndFilespace(
                                fileURL: fileURL!
                            )
                    } catch let error as Workspace.WorkspaceFileError {
                        Logger.workspacePool
                            .info(error.localizedDescription)
                    }
                    catch {
                        Logger.workspacePool.error(error)
                    }
                }
            }.store(in: &cancellable)
            
            // Combine both workspace and auth status changes into a single stream
            await Publishers.CombineLatest3(
                XcodeInspector.shared.safe.$latestActiveXcode,
                XcodeInspector.shared.safe.$activeWorkspaceURL
                    .removeDuplicates(),
                StatusObserver.shared.$authStatus
                    .removeDuplicates()
                )
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newXcode, newURL, newStatus in
                    // First check for realtimeWorkspaceURL if activeWorkspaceURL is nil
                    if let realtimeURL = newXcode?.realtimeWorkspaceURL, newURL == nil {
                        self?.onNewActiveWorkspaceURLOrAuthStatus(
                            newURL: realtimeURL,
                            newStatus: newStatus
                        )
                    } else if let newURL = newURL {
                        // Then use activeWorkspaceURL if available
                        self?.onNewActiveWorkspaceURLOrAuthStatus(
                            newURL: newURL,
                            newStatus: newStatus
                        )
                    }
                }
                .store(in: &cancellable)
        }
    }

    @MainActor
    public func prepareForExit() async {
        Logger.service.info("Prepare for exit.")
        keyBindingManager.stopForExit()
        await scheduledCleaner.closeAllChildProcesses()
    }

    private func getDisplayNameOfXcodeWorkspace(url: URL) -> String {
        var name = url.lastPathComponent
        let suffixes = [".xcworkspace", ".xcodeproj", ".playground"]
        for suffix in suffixes {
            if name.hasSuffix(suffix) {
                name = String(name.dropLast(suffix.count))
                break
            }
        }
        return name
    }
}

public extension Service {
    func handleXPCServiceRequests(
        endpoint: String,
        requestBody: Data,
        reply: @escaping (Data?, Error?) -> Void
    ) {
        reply(nil, XPCRequestNotHandledError())
    }
}

// internal extension
extension Service {
    
    func onNewActiveWorkspaceURLOrAuthStatus(newURL: URL?, newStatus: AuthStatus) {
        Task { @MainActor in
                  // check path
            guard let path = newURL?.path, path != "/",
                  // check auth status
                  newStatus.status == .loggedIn,
                  let username = newStatus.username, !username.isEmpty,
                  // Switch workspace only when the `workspace` or `username` is not the same as the current one
                  (
                    self.guiController.store.chatHistory.selectedWorkspacePath != path ||
                    self.guiController.store.chatHistory.currentUsername != username
                  )
            else { return }
            
            await self.doSwitchWorkspace(workspaceURL: newURL!, username: username)
        }
    }
    
    /// - Parameters:
    ///   - workspaceURL: The  active workspace URL that need switch to
    ///   - path: Path of the workspace URL
    ///   - username: Curent github username
    @MainActor
    func doSwitchWorkspace(workspaceURL: URL, username: String) async {
        // get workspace display name
        let name = self.getDisplayNameOfXcodeWorkspace(url: workspaceURL)
        let path = workspaceURL.path
        
        // switch workspace and username and wait for it to complete
        await self.guiController.store.send(.switchWorkspace(path: path, name: name, username: username)).finish()
        // restore if needed
        await self.guiController.restore(path: path, name: name, username: username)
        // init chat tab if no history tab (only after workspace is fully switched and restored)
        await self.guiController.store.send(.initWorkspaceChatTabIfNeeded(path: path, username: username)).finish()
    }
}
