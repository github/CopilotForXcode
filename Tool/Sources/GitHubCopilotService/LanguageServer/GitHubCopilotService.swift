import AppKit
import Combine
import ConversationServiceProvider
import Foundation
import JSONRPC
import LanguageClient
import LanguageServerProtocol
import Logger
import Preferences
import Status
import SuggestionBasic

public protocol GitHubCopilotAuthServiceType {
    func checkStatus() async throws -> GitHubCopilotAccountStatus
    func signInInitiate() async throws -> (verificationUri: String, userCode: String)
    func signInConfirm(userCode: String) async throws
        -> (username: String, status: GitHubCopilotAccountStatus)
    func signOut() async throws -> GitHubCopilotAccountStatus
    func version() async throws -> String
}

public protocol GitHubCopilotSuggestionServiceType {
    func getCompletions(
        fileURL: URL,
        content: String,
        originalContent: String,
        cursorPosition: CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool
    ) async throws -> [CodeSuggestion]
    func notifyShown(_ completion: CodeSuggestion) async
    func notifyAccepted(_ completion: CodeSuggestion, acceptedLength: Int?) async
    func notifyRejected(_ completions: [CodeSuggestion]) async
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws
    func notifyChangeTextDocument(fileURL: URL, content: String, version: Int) async throws
    func notifyCloseTextDocument(fileURL: URL) async throws
    func notifySaveTextDocument(fileURL: URL) async throws
    func cancelRequest() async
    func terminate() async
}

public protocol GitHubCopilotConversationServiceType {
    func createConversation(_ message: String,
                            workDoneToken: String,
                            workspaceFolder: String,
                            doc: Doc?,
                            skills: [String]) async throws
    func createTurn(_ message: String,
                    workDoneToken: String,
                    conversationId: String,
                    doc: Doc?) async throws
    func rateConversation(turnId: String, rating: ConversationRating) async throws
    func copyCode(turnId: String, codeBlockIndex: Int, copyType: CopyKind, copiedCharacters: Int, totalCharacters: Int, copiedText: String) async throws
    func cancelProgress(token: String) async
}

protocol GitHubCopilotLSP {
    func sendRequest<E: GitHubCopilotRequestType>(_ endpoint: E) async throws -> E.Response
    func sendNotification(_ notif: ClientNotification) async throws
}

public enum GitHubCopilotError: Error, LocalizedError {
    case languageServerNotInstalled
    case languageServerError(ServerError)
    case failedToInstallStartScript

    public var errorDescription: String? {
        switch self {
        case .languageServerNotInstalled:
            return "Language server is not installed."
        case .failedToInstallStartScript:
            return "Failed to install start script."
        case let .languageServerError(error):
            switch error {
            case let .handlerUnavailable(handler):
                return "Language server error: Handler \(handler) unavailable"
            case let .unhandledMethod(method):
                return "Language server error: Unhandled method \(method)"
            case let .notificationDispatchFailed(error):
                return "Language server error: Notification dispatch failed: \(error)"
            case let .requestDispatchFailed(error):
                return "Language server error: Request dispatch failed: \(error)"
            case let .clientDataUnavailable(error):
                return "Language server error: Client data unavailable: \(error)"
            case .serverUnavailable:
                return "Language server error: Server unavailable, please make sure that:\n1. The path to node is correctly set.\n2. The node is not a shim executable.\n3. the node version is high enough."
            case .missingExpectedParameter:
                return "Language server error: Missing expected parameter"
            case .missingExpectedResult:
                return "Language server error: Missing expected result"
            case let .unableToDecodeRequest(error):
                return "Language server error: Unable to decode request: \(error)"
            case let .unableToSendRequest(error):
                return "Language server error: Unable to send request: \(error)"
            case let .unableToSendNotification(error):
                return "Language server error: Unable to send notification: \(error)"
            case let .serverError(code: code, message: message, data: data):
                return "Language server error: Server error: \(code) \(message) \(String(describing: data))"
            case .invalidRequest:
                return "Language server error: Invalid request"
            case .timeout:
                return "Language server error: Timeout, please try again later"
            }
        }
    }
}

public extension Notification.Name {
    static let gitHubCopilotShouldRefreshEditorInformation = Notification
        .Name("com.github.CopilotForXcode.GitHubCopilotShouldRefreshEditorInformation")
}

public class GitHubCopilotBaseService {
    let projectRootURL: URL
    var server: GitHubCopilotLSP
    var localProcessServer: CopilotLocalProcessServer?

    init(designatedServer: GitHubCopilotLSP) {
        projectRootURL = URL(fileURLWithPath: "/")
        server = designatedServer
    }

    init(projectRootURL: URL) throws {
        self.projectRootURL = projectRootURL
        let (server, localServer) = try {
            let urls = try GitHubCopilotBaseService.createFoldersIfNeeded()
            var path = SystemInfo().binaryPath()
            var args = ["--stdio"]
            let home = ProcessInfo.processInfo.homePath
            let versionNumber = JSONValue(stringLiteral: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
            let xcodeVersion = JSONValue(stringLiteral: SystemInfo().xcodeVersion() ?? "")
            let nodeExtraCaCerts: String = UserDefaults.shared.value(for: \.nodeExtraCaCerts)
            let nodeExtraCaCertMap: [String: String] = nodeExtraCaCerts.isEmpty ? [:] : ["NODE_EXTRA_CA_CERTS": nodeExtraCaCerts]

            #if DEBUG
            // Use local language server if set and available
            if let languageServerPath = Bundle.main.infoDictionary?["LANGUAGE_SERVER_PATH"] as? String {
                let jsPath = URL(fileURLWithPath: NSString(string: languageServerPath).expandingTildeInPath)
                    .appendingPathComponent("dist")
                    .appendingPathComponent("language-server.js")
                let nodePath = Bundle.main.infoDictionary?["NODE_PATH"] as? String ?? "node"
                if FileManager.default.fileExists(atPath: jsPath.path) {
                    path = "/usr/bin/env"
                    args = [nodePath, jsPath.path, "--stdio"]
                    Logger.debug.info("Using local language server \(path) \(args)")
                }
            }
            // Set debug port and verbose when running in debug
            let environment: [String: String] = ["HOME": home, "GH_COPILOT_DEBUG_UI_PORT": "8080", "GH_COPILOT_VERBOSE": "true"].merging(nodeExtraCaCertMap) { _, new in new }
            #else
            let environment: [String: String] = (if UserDefaults.shared.value(for: \.verboseLoggingEnabled) {
                ["HOME": home, "GH_COPILOT_VERBOSE": "true"]
            } else {
                ["HOME": home]
            }).merging(nodeExtraCaCertMap) { _, new in new }
            #endif

            let executionParams = Process.ExecutionParameters(
                path: path,
                arguments: args,
                environment: environment,
                currentDirectoryURL: urls.supportURL
            )

            Logger.gitHubCopilot.info("Starting language server in \(urls.supportURL), \(environment)")
            Logger.gitHubCopilot.info("Running on Xcode \(xcodeVersion), extension version \(versionNumber)")

            let localServer = CopilotLocalProcessServer(executionParameters: executionParams)
            localServer.notificationHandler = { _, respond in
                respond(.timeout)
            }
            let server = InitializingServer(server: localServer)
            server.initializeParamsProvider = {
                let capabilities = ClientCapabilities(
                    workspace: nil,
                    textDocument: nil,
                    window: nil,
                    general: nil,
                    experimental: nil
                )

                return InitializeParams(
                    processId: Int(ProcessInfo.processInfo.processIdentifier),
                    locale: nil,
                    rootPath: projectRootURL.path,
                    rootUri: projectRootURL.path,
                    initializationOptions: [
                        "editorInfo": [
                            "name": "Xcode",
                            "version": xcodeVersion,
                        ],
                        "editorPluginInfo": [
                            "name": "copilot-xcode",
                            "version": versionNumber,
                        ]
                    ],
                    capabilities: capabilities,
                    trace: .off,
                    workspaceFolders: [WorkspaceFolder(
                        uri: projectRootURL.path,
                        name: projectRootURL.lastPathComponent
                    )]
                )
            }

            return (server, localServer)
        }()

        self.server = server
        localProcessServer = localServer

        let notifications = NotificationCenter.default
            .notifications(named: .gitHubCopilotShouldRefreshEditorInformation)
        Task { [weak self] in
            // Send workspace/didChangeConfiguration once after initalize
            _ = try? await server.sendNotification(
                .workspaceDidChangeConfiguration(
                    .init(settings: editorConfiguration())
                )
            )
            for await _ in notifications {
                guard self != nil else { return }
                _ = try? await server.sendNotification(
                    .workspaceDidChangeConfiguration(
                        .init(settings: editorConfiguration())
                    )
                )
            }
        }
    }


    public static func createFoldersIfNeeded() throws -> (
        applicationSupportURL: URL,
        gitHubCopilotURL: URL,
        executableURL: URL,
        supportURL: URL
    ) {
        guard let supportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent(
            Bundle.main
                .object(forInfoDictionaryKey: "APPLICATION_SUPPORT_FOLDER") as? String
            ?? "com.github.CopilotForXcode"
        ) else {
            throw CancellationError()
        }

        if !FileManager.default.fileExists(atPath: supportURL.path) {
            try? FileManager.default
                .createDirectory(at: supportURL, withIntermediateDirectories: false)
        }
        let gitHubCopilotFolderURL = supportURL.appendingPathComponent("GitHub Copilot")
        if !FileManager.default.fileExists(atPath: gitHubCopilotFolderURL.path) {
            try? FileManager.default
                .createDirectory(at: gitHubCopilotFolderURL, withIntermediateDirectories: false)
        }
        let supportFolderURL = gitHubCopilotFolderURL.appendingPathComponent("support")
        if !FileManager.default.fileExists(atPath: supportFolderURL.path) {
            try? FileManager.default
                .createDirectory(at: supportFolderURL, withIntermediateDirectories: false)
        }
        let executableFolderURL = gitHubCopilotFolderURL.appendingPathComponent("executable")
        if !FileManager.default.fileExists(atPath: executableFolderURL.path) {
            try? FileManager.default
                .createDirectory(at: executableFolderURL, withIntermediateDirectories: false)
        }

        return (supportURL, gitHubCopilotFolderURL, executableFolderURL, supportFolderURL)
    }
}

@globalActor public enum GitHubCopilotSuggestionActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

public final class GitHubCopilotService: GitHubCopilotBaseService,
                                          GitHubCopilotSuggestionServiceType, GitHubCopilotConversationServiceType, GitHubCopilotAuthServiceType
{

    private var ongoingTasks = Set<Task<[CodeSuggestion], Error>>()
    private var serverNotificationHandler: ServerNotificationHandler = ServerNotificationHandlerImpl.shared
    private var cancellables = Set<AnyCancellable>()
    private var statusWatcher: CopilotAuthStatusWatcher?

    override init(designatedServer: any GitHubCopilotLSP) {
        super.init(designatedServer: designatedServer)
    }

    override public init(projectRootURL: URL = URL(fileURLWithPath: "/")) throws {
        try super.init(projectRootURL: projectRootURL)
        localProcessServer?.notificationPublisher.sink(receiveValue: { [weak self] notification in
            self?.serverNotificationHandler.handleNotification(notification)
        }).store(in: &cancellables)
        updateStatusInBackground()
    }

    @GitHubCopilotSuggestionActor
    public func getCompletions(
        fileURL: URL,
        content: String,
        originalContent: String,
        cursorPosition: SuggestionBasic.CursorPosition,
        tabSize: Int,
        indentSize: Int,
        usesTabsForIndentation: Bool
    ) async throws -> [CodeSuggestion] {
        ongoingTasks.forEach { $0.cancel() }
        ongoingTasks.removeAll()
        await localProcessServer?.cancelOngoingTasks()

        func sendRequest(maxTry: Int = 5) async throws -> [CodeSuggestion] {
            do {
                let completions = try await self
                    .sendRequest(GitHubCopilotRequest.InlineCompletion(doc: .init(
                        textDocument: .init(uri: fileURL.path, version: 1),
                        position: cursorPosition,
                        formattingOptions: .init(
                            tabSize: tabSize,
                            insertSpaces: !usesTabsForIndentation
                        ),
                        context: .init(triggerKind: .invoked)
                    )))
                    .items
                    .compactMap { (item: _) -> CodeSuggestion? in
                        guard let range = item.range else { return nil }
                        let suggestion = CodeSuggestion(
                            id: item.command?.arguments?.first ?? UUID().uuidString,
                            text: item.insertText,
                            position: cursorPosition,
                            range: .init(start: range.start, end: range.end)
                        )
                        return suggestion
                    }
                try Task.checkCancellation()
                return completions
            } catch let error as ServerError {
                switch error {
                case .serverError:
                    // sometimes the content inside language server is not new enough, which can
                    // lead to an version mismatch error. We can try a few times until the content
                    // is up to date.
                    if maxTry <= 0 { break }
                    Logger.gitHubCopilot.error(
                        "Try getting suggestions again: \(GitHubCopilotError.languageServerError(error).localizedDescription)"
                    )
                    try await Task.sleep(nanoseconds: 200_000_000)
                    return try await sendRequest(maxTry: maxTry - 1)
                default:
                    break
                }
                throw GitHubCopilotError.languageServerError(error)
            } catch {
                throw error
            }
        }

        func recoverContent() async {
            try? await notifyChangeTextDocument(
                fileURL: fileURL,
                content: originalContent,
                version: 0
            )
        }

        // since when the language server is no longer using the passed in content to generate
        // suggestions, we will need to update the content to the file before we do any request.
        //
        // And sometimes the language server's content was not up to date and may generate
        // weird result when the cursor position exceeds the line.
        let task = Task { @GitHubCopilotSuggestionActor in
            try? await notifyChangeTextDocument(
                fileURL: fileURL,
                content: content,
                version: 1
            )

            do {
                try Task.checkCancellation()
                return try await sendRequest()
            } catch let error as CancellationError {
                if ongoingTasks.isEmpty {
                    await recoverContent()
                }
                throw error
            } catch {
                await recoverContent()
                throw error
            }
        }

        ongoingTasks.insert(task)

        return try await task.value
    }

    @GitHubCopilotSuggestionActor
    public func createConversation(_ message: String,
                                   workDoneToken: String,
                                   workspaceFolder: String,
                                   doc: Doc?,
                                   skills: [String]) async throws {
        let params = ConversationCreateParams(workDoneToken: workDoneToken,
                                              turns: [ConversationTurn(request: message)],
                                              capabilities: ConversationCreateParams.Capabilities(
                                                skills: skills,
                                                allSkills: false),
                                              doc: doc,
                                              source: .panel,
                                              workspaceFolder: workspaceFolder)
        do {
            let _ = try await sendRequest(
                GitHubCopilotRequest.CreateConversation(params: params)
            )
        } catch {
            print("Failed to create conversation. Error: \(error)")
            throw error
        }
    }

    @GitHubCopilotSuggestionActor
    public func createTurn(_ message: String, workDoneToken: String, conversationId: String, doc: Doc?) async throws {
        do {
            let params = TurnCreateParams(workDoneToken: workDoneToken, conversationId: conversationId, message: message, doc: doc)
            let _ = try await sendRequest(
                GitHubCopilotRequest.CreateTurn(params: params)
            )
        } catch {
            print("Failed to create turn. Error: \(error)")
            throw error
        }
    }

    @GitHubCopilotSuggestionActor
    public func rateConversation(turnId: String, rating: ConversationRating) async throws {
        do {
            let params = ConversationRatingParams(turnId: turnId, rating: rating)
            let _ = try await sendRequest(
                GitHubCopilotRequest.ConversationRating(params: params)
            )
        } catch {
            throw error
        }
    }

    @GitHubCopilotSuggestionActor
    public func copyCode(turnId: String, codeBlockIndex: Int, copyType: CopyKind, copiedCharacters: Int, totalCharacters: Int, copiedText: String) async throws {
        let params = CopyCodeParams(turnId: turnId, codeBlockIndex: codeBlockIndex, copyType: copyType, copiedCharacters: copiedCharacters, totalCharacters: totalCharacters, copiedText: copiedText)
        do {
            let _ = try await sendRequest(
                GitHubCopilotRequest.CopyCode(params: params)
            )
        } catch {
            print("Failed to register copied code block. Error: \(error)")
            throw error
        }
    }

    @GitHubCopilotSuggestionActor
    public func cancelRequest() async {
        ongoingTasks.forEach { $0.cancel() }
        ongoingTasks.removeAll()
        await localProcessServer?.cancelOngoingTasks()
    }

    @GitHubCopilotSuggestionActor
    public func cancelProgress(token: String) async {
        await localProcessServer?.cancelOngoingTask(token)
    }

    @GitHubCopilotSuggestionActor
    public func notifyShown(_ completion: CodeSuggestion) async {
        _ = try? await sendRequest(
            GitHubCopilotRequest.NotifyShown(completionUUID: completion.id)
        )
    }

    @GitHubCopilotSuggestionActor
    public func notifyAccepted(_ completion: CodeSuggestion, acceptedLength: Int? = nil) async {
        _ = try? await sendRequest(
            GitHubCopilotRequest.NotifyAccepted(completionUUID: completion.id, acceptedLength: acceptedLength)
        )
    }

    @GitHubCopilotSuggestionActor
    public func notifyRejected(_ completions: [CodeSuggestion]) async {
        _ = try? await sendRequest(
            GitHubCopilotRequest.NotifyRejected(completionUUIDs: completions.map(\.id))
        )
    }

    @GitHubCopilotSuggestionActor
    public func notifyOpenTextDocument(
        fileURL: URL,
        content: String
    ) async throws {
        let languageId = languageIdentifierFromFileURL(fileURL)
        let uri = "file://\(fileURL.path)"
        //        Logger.service.debug("Open \(uri), \(content.count)")
        try await server.sendNotification(
            .didOpenTextDocument(
                DidOpenTextDocumentParams(
                    textDocument: .init(
                        uri: uri,
                        languageId: languageId.rawValue,
                        version: 0,
                        text: content
                    )
                )
            )
        )
    }

    @GitHubCopilotSuggestionActor
    public func notifyChangeTextDocument(
        fileURL: URL,
        content: String,
        version: Int
    ) async throws {
        let uri = "file://\(fileURL.path)"
        //        Logger.service.debug("Change \(uri), \(content.count)")
        try await server.sendNotification(
            .didChangeTextDocument(
                DidChangeTextDocumentParams(
                    uri: uri,
                    version: version,
                    contentChange: .init(
                        range: nil,
                        rangeLength: nil,
                        text: content
                    )
                )
            )
        )
    }

    @GitHubCopilotSuggestionActor
    public func notifySaveTextDocument(fileURL: URL) async throws {
        let uri = "file://\(fileURL.path)"
        //        Logger.service.debug("Save \(uri)")
        try await server.sendNotification(.didSaveTextDocument(.init(uri: uri)))
    }

    @GitHubCopilotSuggestionActor
    public func notifyCloseTextDocument(fileURL: URL) async throws {
        let uri = "file://\(fileURL.path)"
        //        Logger.service.debug("Close \(uri)")
        try await server.sendNotification(.didCloseTextDocument(.init(uri: uri)))
    }

    @GitHubCopilotSuggestionActor
    public func terminate() async {
        // automatically handled
    }

    @GitHubCopilotSuggestionActor
    public func checkStatus() async throws -> GitHubCopilotAccountStatus {
        do {
            let response = try await sendRequest(GitHubCopilotRequest.CheckStatus())
            await updateServiceAuthStatus(response)
            return response.status
        } catch let error as ServerError {
            throw GitHubCopilotError.languageServerError(error)
        } catch {
            throw error
        }
    }

    public func updateStatusInBackground() {
        Task { @GitHubCopilotSuggestionActor in
            try? await checkStatus()
        }
    }

    private func updateServiceAuthStatus(_ status: GitHubCopilotRequest.CheckStatus.Response) async {
        Logger.gitHubCopilot.info("check status response: \(status)")
        if status.status == .ok || status.status == .maybeOk {
            await Status.shared.updateAuthStatus(.loggedIn, username: status.user)
            await unwatchAuthStatus()
        } else {
            await Status.shared.updateAuthStatus(.notLoggedIn, message: status.status.description)
            await watchAuthStatus()
        }
    }

    @GitHubCopilotSuggestionActor
    private func watchAuthStatus() {
        guard statusWatcher == nil else { return }
        statusWatcher = CopilotAuthStatusWatcher(self)
    }

    @GitHubCopilotSuggestionActor
    private func unwatchAuthStatus() {
        statusWatcher = nil
    }

    @GitHubCopilotSuggestionActor
    public func signInInitiate() async throws -> (verificationUri: String, userCode: String) {
        do {
            let result = try await sendRequest(GitHubCopilotRequest.SignInInitiate())
            return (result.verificationUri, result.userCode)
        } catch let error as ServerError {
            throw GitHubCopilotError.languageServerError(error)
        } catch {
            throw error
        }
    }

    @GitHubCopilotSuggestionActor
    public func signInConfirm(userCode: String) async throws
    -> (username: String, status: GitHubCopilotAccountStatus)
    {
        do {
            let result = try await sendRequest(GitHubCopilotRequest.SignInConfirm(userCode: userCode))
            return (result.user, result.status)
        } catch let error as ServerError {
            throw GitHubCopilotError.languageServerError(error)
        } catch {
            throw error
        }
    }

    @GitHubCopilotSuggestionActor
    public func signOut() async throws -> GitHubCopilotAccountStatus {
        do {
            return try await sendRequest(GitHubCopilotRequest.SignOut()).status
        } catch let error as ServerError {
            throw GitHubCopilotError.languageServerError(error)
        } catch {
            throw error
        }
    }

    @GitHubCopilotSuggestionActor
    public func version() async throws -> String {
        do {
            return try await sendRequest(GitHubCopilotRequest.GetVersion()).version
        } catch let error as ServerError {
            throw GitHubCopilotError.languageServerError(error)
        } catch {
            throw error
        }
    }

    @GitHubCopilotSuggestionActor
    public func shutdown() async throws {
        let stream = AsyncThrowingStream<Void, Error> { continuation in
            if let localProcessServer {
                localProcessServer.shutdown() { err in
                    continuation.finish(throwing: err)
                }
            } else {
                continuation.finish(throwing: GitHubCopilotError.languageServerError(ServerError.serverUnavailable))
            }
        }
        for try await _ in stream {
            return
        }
    }

    @GitHubCopilotSuggestionActor
    public func exit() async throws {
        let stream = AsyncThrowingStream<Void, Error> { continuation in
            if let localProcessServer {
                localProcessServer.exit() { err in
                    continuation.finish(throwing: err)
                }
            } else {
                continuation.finish(throwing: GitHubCopilotError.languageServerError(ServerError.serverUnavailable))
            }
        }
        for try await _ in stream {
            return
        }
    }

    private func sendRequest<E: GitHubCopilotRequestType>(_ endpoint: E) async throws -> E.Response {
        do {
            return try await server.sendRequest(endpoint)
        } catch let error as ServerError {
            if let info = CLSErrorInfo(for: error) {
                // update the auth status if the error indicates it may have changed, and then rethrow
                if info.affectsAuthStatus && !(endpoint is GitHubCopilotRequest.CheckStatus) {
                    updateStatusInBackground()
                }
            }
            throw error
        }
    }
}

extension InitializingServer: GitHubCopilotLSP {
    func sendRequest<E: GitHubCopilotRequestType>(_ endpoint: E) async throws -> E.Response {
        try await sendRequest(endpoint.request)
    }
}
