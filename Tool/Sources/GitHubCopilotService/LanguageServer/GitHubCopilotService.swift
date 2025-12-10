import AppKit
import TelemetryServiceProvider
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
import SystemUtils
import Persist

public protocol GitHubCopilotAuthServiceType {
    func checkStatus() async throws -> GitHubCopilotAccountStatus
    func checkQuota() async throws -> GitHubCopilotQuotaInfo
    func signInInitiate() async throws -> (status: SignInInitiateStatus, verificationUri: String?, userCode: String?, user: String?)
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
    func getCopilotInlineEdit(
        fileURL: URL,
        content: String,
        cursorPosition: CursorPosition
    ) async throws -> [CodeSuggestion]
    func notifyShown(_ completion: CodeSuggestion) async
    func notifyCopilotInlineEditShown(_ completion: CodeSuggestion) async
    func notifyAccepted(_ completion: CodeSuggestion, acceptedLength: Int?) async
    func notifyCopilotInlineEditAccepted(_ completion: CodeSuggestion) async
    func notifyRejected(_ completions: [CodeSuggestion]) async
    func notifyOpenTextDocument(fileURL: URL, content: String) async throws
    func notifyChangeTextDocument(
        fileURL: URL,
        content: String,
        version: Int,
        contentChanges: [TextDocumentContentChangeEvent]?
    ) async throws
    func notifyCloseTextDocument(fileURL: URL) async throws
    func notifySaveTextDocument(fileURL: URL) async throws
    func cancelRequest() async
    func terminate() async
}

public protocol GitHubCopilotTelemetryServiceType {
    func sendError(transaction: String?,
                                stacktrace: String?,
                                properties: [String: String]?,
                                platform: String?,
                                exceptionDetail: [ExceptionDetail]?) async throws
}

public protocol GitHubCopilotConversationServiceType {
    func createConversation(_ message: MessageContent,
                            workDoneToken: String,
                            workspaceFolder: String,
                            workspaceFolders: [WorkspaceFolder]?,
                            activeDoc: Doc?,
                            skills: [String],
                            ignoredSkills: [String]?,
                            references: [ConversationAttachedReference],
                            model: String?,
                            modelProviderName: String?,
                            turns: [TurnSchema],
                            agentMode: Bool,
                            customChatModeId: String?,
                            userLanguage: String?) async throws -> ConversationCreateResponse
    func createTurn(_ message: MessageContent,
                    workDoneToken: String,
                    conversationId: String,
                    turnId: String?,
                    activeDoc: Doc?,
                    ignoredSkills: [String]?,
                    references: [ConversationAttachedReference],
                    model: String?,
                    modelProviderName: String?,
                    workspaceFolder: String,
                    workspaceFolders: [WorkspaceFolder]?,
                    agentMode: Bool,
                    customChatModeId: String?) async throws -> ConversationCreateResponse
    func deleteTurn(conversationId: String, turnId: String) async throws
    func rateConversation(turnId: String, rating: ConversationRating) async throws
    func copyCode(turnId: String, codeBlockIndex: Int, copyType: CopyKind, copiedCharacters: Int, totalCharacters: Int, copiedText: String) async throws
    func cancelProgress(token: String) async
    func templates(workspaceFolders: [WorkspaceFolder]?) async throws -> [ChatTemplate]
    func modes(workspaceFolders: [WorkspaceFolder]?) async throws -> [ConversationMode]
    func models() async throws -> [CopilotModel]
    func registerTools(tools: [LanguageModelToolInformation]) async throws -> [LanguageModelTool]
    func updateToolsStatus(params: UpdateToolsStatusParams) async throws -> [LanguageModelTool]
}

protocol GitHubCopilotLSP {
    var eventSequence: ServerConnection.EventSequence { get }
    func sendRequest<E: GitHubCopilotRequestType>(_ endpoint: E) async throws -> E.Response
    func sendNotification(_ notif: ClientNotification) async throws
}

protocol GitHubCopilotLSPNotification {
    func sendCopilotNotification(_ notif: CopilotClientNotification) async throws
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
            case .unknownError:
                return "Language server error: An unknown error occurred: \(error)"
            }
        }
    }
}

public extension Notification.Name {
    static let gitHubCopilotShouldRefreshEditorInformation = Notification
        .Name("com.github.CopilotForXcode.GitHubCopilotShouldRefreshEditorInformation")
    static let githubCopilotAgentMaxToolCallingLoopDidChange = Notification
        .Name("com.github.CopilotForXcode.GithubCopilotAgentMaxToolCallingLoopDidChange")
}

public class GitHubCopilotBaseService {
    let projectRootURL: URL
    var server: GitHubCopilotLSP
    var localProcessServer: CopilotLocalProcessServer?
    let sessionId: String

    init(designatedServer: GitHubCopilotLSP) {
        projectRootURL = URL(fileURLWithPath: "/")
        server = designatedServer
        sessionId = UUID().uuidString
    }

    init(projectRootURL: URL, workspaceURL: URL = URL(fileURLWithPath: "/")) throws {
        self.projectRootURL = projectRootURL
        self.sessionId = UUID().uuidString
        let (server, localServer) = try {
            let urls = try GitHubCopilotBaseService.createFoldersIfNeeded()
            var path = SystemUtils.shared.getXcodeBinaryPath()
            var args = ["--stdio"]
            let home = ProcessInfo.processInfo.homePath

            var environment: [String: String] = ["HOME": home]
            let envVarNamesToFetch = ["PATH", "NODE_EXTRA_CA_CERTS", "NODE_TLS_REJECT_UNAUTHORIZED"]
            let terminalEnvVars = getTerminalEnvironmentVariables(envVarNamesToFetch)

            for varName in envVarNamesToFetch {
                if let value = terminalEnvVars[varName] ?? ProcessInfo.processInfo.environment[varName] {
                    environment[varName] = value
                    Logger.gitHubCopilot.info("Setting env \(varName): \(value)")
                }
            }

            environment["PATH"] = SystemUtils.shared.appendCommonBinPaths(path: environment["PATH"] ?? "")

            let versionNumber = JSONValue(
                stringLiteral: SystemUtils.editorPluginVersion ?? ""
            )
            let xcodeVersion = JSONValue(
                stringLiteral: SystemUtils.xcodeVersion ?? ""
            )
            let watchedFiles = JSONValue(
                booleanLiteral: projectRootURL.path == "/" ? false : true
            )
            let enableSubagent = UserDefaults.shared.value(for: \.enableSubagent)

            #if DEBUG
            // Use local language server if set and available
            if let languageServerPath = Bundle.main.infoDictionary?["LANGUAGE_SERVER_PATH"] as? String {
                let jsPath = URL(fileURLWithPath: NSString(string: languageServerPath).expandingTildeInPath)
                    .appendingPathComponent("dist")
                    .appendingPathComponent("language-server.js")
                let nodePath = Bundle.main.infoDictionary?["NODE_PATH"] as? String ?? "node"
                if FileManager.default.fileExists(atPath: jsPath.path) {
                    path = "/usr/bin/env"
                    if projectRootURL.path == "/" {
                        args = [nodePath, jsPath.path, "--stdio"]
                    } else {
                        args = [nodePath, "--inspect", jsPath.path, "--stdio"]
                    }
                    Logger.debug.info("Using local language server \(path) \(args)")
                }
            }
            // Add debug-specific environment variables
            environment["GH_COPILOT_DEBUG_UI_PORT"] = "8180"
            environment["GH_COPILOT_VERBOSE"] = "true"
            #else
            // Add release-specific environment variables
            if UserDefaults.shared.value(for: \.verboseLoggingEnabled) {
                environment["GH_COPILOT_VERBOSE"] = "true"
            }
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

            let initializeParamsProvider = { @Sendable () -> InitializeParams in
                let capabilities = ClientCapabilities(
                    workspace: .init(
                        applyEdit: false,
                        workspaceEdit: nil,
                        didChangeConfiguration: nil,
                        didChangeWatchedFiles: nil,
                        symbol: nil,
                        executeCommand: nil,
                        /// enable for "watchedFiles capability", set others to default value
                        workspaceFolders: true,
                        configuration: nil,
                        semanticTokens: nil
                    ),
                    textDocument: nil,
                    window: nil,
                    general: nil,
                    experimental: nil
                )

                let authAppId = Bundle.main.infoDictionary?["GITHUB_APP_ID"] as? String
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
                        ],
                        "copilotCapabilities": [
                            /// The editor has support for watching files over LSP
                            "watchedFiles": watchedFiles,
                            "didChangeFeatureFlags": true,
                            "stateDatabase": true,
                            "subAgent": JSONValue(booleanLiteral: enableSubagent),
                        ],
                        "githubAppId": authAppId.map(JSONValue.string) ?? .null,
                    ],
                    capabilities: capabilities,
                    trace: .off,
                    workspaceFolders: [WorkspaceFolder(
                        uri: projectRootURL.absoluteString,
                        name: projectRootURL.lastPathComponent
                    )]
                )
            }
            
            let server = SafeInitializingServer(InitializingServer(server: localServer, initializeParamsProvider: initializeParamsProvider))

            return (server, localServer)
        }()

        self.server = server
        localProcessServer = localServer
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
    
    public func getSessionId() -> String {
        return sessionId
    }
}

func getTerminalEnvironmentVariables(_ variableNames: [String]) -> [String: String] {
    var results = [String: String]()
    guard !variableNames.isEmpty else { return results }

    let userShell: String? = {
       if let shell = ProcessInfo.processInfo.environment["SHELL"] {
           return shell
       }
        
        // Check for zsh executable
        if FileManager.default.fileExists(atPath: "/bin/zsh") {
            Logger.gitHubCopilot.info("SHELL not found, falling back to /bin/zsh")
            return "/bin/zsh"
        }
        // Check for bash executable
        if FileManager.default.fileExists(atPath: "/bin/bash") {
            Logger.gitHubCopilot.info("SHELL not found, falling back to /bin/bash")
            return "/bin/bash"
        }
        
        Logger.gitHubCopilot.info("Cannot determine user's shell, returning empty environment")
        return nil // No shell found
    }()
    
    guard let shell = userShell else {
        return results
    }

    if let env = SystemUtils.shared.getLoginShellEnvironment(shellPath: shell) {
        variableNames.forEach { varName in
            if let value = env[varName] {
                results[varName] = value
            }
        }
    }

    return results
}

@globalActor public enum GitHubCopilotSuggestionActor {
    public actor TheActor {}
    public static let shared = TheActor()
}

actor ToolInitializationActor {
    private var isInitialized = false
    private var unrestoredTools: [ToolStatusUpdate] = []

    func loadUnrestoredToolsIfNeeded() -> [ToolStatusUpdate] {
        guard !isInitialized else { return unrestoredTools }
        isInitialized = true

        // Load tools only once
        if let savedJSON = AppState.shared.get(key: "languageModelToolsStatus"),
           let data = try? JSONEncoder().encode(savedJSON),
           let savedTools = try? JSONDecoder().decode([ToolStatusUpdate].self, from: data) {
            let currentlyAvailableTools = CopilotLanguageModelToolManager.getAvailableLanguageModelTools() ?? []
            let availableToolNames = Set(currentlyAvailableTools.map { $0.name })

            unrestoredTools = savedTools.filter {
                availableToolNames.contains($0.name) && $0.status == .disabled
            }
        }

        return unrestoredTools
    }
}

public final class GitHubCopilotService:
    GitHubCopilotBaseService,
    GitHubCopilotSuggestionServiceType,
    GitHubCopilotConversationServiceType,
    GitHubCopilotAuthServiceType,
    GitHubCopilotTelemetryServiceType
{
    private var ongoingTasks = Set<Task<[CodeSuggestion], Error>>()
    private var serverNotificationHandler: ServerNotificationHandler = ServerNotificationHandlerImpl.shared
    private var serverRequestHandler: ServerRequestHandler = ServerRequestHandlerImpl.shared
    private var cancellables = Set<AnyCancellable>()
    private var statusWatcher: CopilotAuthStatusWatcher?
    private static var services: [GitHubCopilotService] = [] // cache all alive copilot service instances
    private var mcpRuntimeLogFileName: String = ""
    private static let toolInitializationActor = ToolInitializationActor()
    private var lastSentConfiguration: JSONValue?
    private var mcpToolsContinuation: AsyncStream<AnyJSONRPCNotification>.Continuation?

    override init(designatedServer: any GitHubCopilotLSP) {
        super.init(designatedServer: designatedServer)
    }

    override public init(projectRootURL: URL = URL(fileURLWithPath: "/"), workspaceURL: URL = URL(fileURLWithPath: "/")) throws {
        do {
            try super.init(projectRootURL: projectRootURL, workspaceURL: workspaceURL)

            self.handleSendWorkspaceDidChangeNotifications()
            
            let (stream, continuation) = AsyncStream.makeStream(of: AnyJSONRPCNotification.self)
            self.mcpToolsContinuation = continuation
            
            Task { [weak self] in
                for await notification in stream {
                    await self?.handleMCPToolsNotification(notification)
                }
            }

            localProcessServer?.notificationPublisher.sink(receiveValue: { [weak self] notification in
                if notification.method == "copilot/mcpTools" && projectRootURL.path != "/" {
                    self?.mcpToolsContinuation?.yield(notification)
                }
                
                if notification.method == "copilot/mcpRuntimeLogs" && projectRootURL.path != "/" {
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        Task { @MainActor in
                            await self.handleMCPRuntimeLogsNotification(notification)
                        }
                    }
                }

                self?.serverNotificationHandler.handleNotification(notification)
            }).store(in: &cancellables)
            
            Task {
                for await event in server.eventSequence {
                    switch event {
                    case let .request(id, request):
                        self.serverRequestHandler.handleRequest(
                            id: id,
                            request,
                            workspaceURL: workspaceURL,
                            service: self
                        )
                    default:
                        break
                    }
                }
            }

            updateStatusInBackground()

            GitHubCopilotService.services.append(self)

            Task {
                let tools = await registerClientTools(server: self)
                CopilotLanguageModelToolManager.updateToolsStatus(tools)
                await restoreRegisteredToolsStatus()
            }
        } catch {
            Logger.gitHubCopilot.error(error)
            throw error
        }
        
    }

    deinit {
        GitHubCopilotService.services.removeAll { $0 === self }
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
                        textDocument: .init(uri: fileURL.absoluteString, version: 1),
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
                    if maxTry <= 0 {
                        Logger.gitHubCopilot.error(
                            "Max retry for getting suggestions reached: \(GitHubCopilotError.languageServerError(error).localizedDescription)"
                        )
                        break
                    }
                    Logger.gitHubCopilot.info(
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
                let maxTry: Int = 5
                try Task.checkCancellation()
                return try await sendRequest(maxTry: maxTry)
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
    
    // MARK: - NES
    @GitHubCopilotSuggestionActor
    public func getCopilotInlineEdit(
        fileURL: URL,
        content: String,
        cursorPosition: CursorPosition
    ) async throws -> [CodeSuggestion] {
        ongoingTasks.forEach { $0.cancel() }
        ongoingTasks.removeAll()
        await localProcessServer?.cancelOngoingTasks()
        
        do {
            try? await notifyChangeTextDocument(
                fileURL: fileURL,
                content: content,
                version: 1
            )
            
            let completions = try await sendRequest(
                GitHubCopilotRequest.CopilotInlineEdit(
                    params: CopilotInlineEditsParams(
                        textDocument: .init(uri: fileURL.absoluteString, version: 1),
                        position: cursorPosition
                    )
                ))
                .edits
                .compactMap { edit in
                    CodeSuggestion.init(
                        id: edit.command?.arguments.first ?? UUID().uuidString,
                        text: edit.text,
                        position: cursorPosition,
                        range: edit.range
                    )
                }
            return completions
        } catch {
            Logger.gitHubCopilot.error("Failed to get copilot inline edit: \(error.localizedDescription)")
            throw error
        }
    }

    @GitHubCopilotSuggestionActor
    public func createConversation(
        _ message: MessageContent,
        workDoneToken: String,
        workspaceFolder: String,
        workspaceFolders: [WorkspaceFolder]? = nil,
        activeDoc: Doc?,
        skills: [String],
        ignoredSkills: [String]?,
        references: [ConversationAttachedReference],
        model: String?,
        modelProviderName: String?,
        turns: [TurnSchema],
        agentMode: Bool,
        customChatModeId: String?,
        userLanguage: String?
    ) async throws -> ConversationCreateResponse {
        var conversationCreateTurns: [TurnSchema] = []
        // invoke conversation history
        if turns.count > 0 {
            conversationCreateTurns.append(
                contentsOf: turns.map {
                    TurnSchema(
                        request: $0.request,
                        response: $0.response,
                        agentSlug: $0.agentSlug,
                        turnId: $0.turnId
                    )
                }
            )
        }
        conversationCreateTurns.append(TurnSchema(request: message))
        let params = ConversationCreateParams(workDoneToken: workDoneToken,
                                              turns: conversationCreateTurns,
                                              capabilities: ConversationCreateParams.Capabilities(
                                                skills: skills,
                                                allSkills: false),
                                              textDocument: activeDoc,
                                              references: references.map { Reference.from($0) },
                                              source: .panel,
                                              workspaceFolder: workspaceFolder,
                                              workspaceFolders: workspaceFolders,
                                              ignoredSkills: ignoredSkills,
                                              model: model,
                                              modelProviderName: modelProviderName,
                                              chatMode: agentMode ? "Agent" : nil,
                                              customChatModeId: customChatModeId,
                                              needToolCallConfirmation: true,
                                              userLanguage: userLanguage)
        do {
            return try await sendRequest(
                GitHubCopilotRequest.CreateConversation(params: params))
        } catch {
            print("Failed to create conversation. Error: \(error)")
            throw error
        }
    }

    @GitHubCopilotSuggestionActor
    public func createTurn(
        _ message: MessageContent,
       workDoneToken: String,
       conversationId: String,
       turnId: String?,
       activeDoc: Doc?,
       ignoredSkills: [String]?,
       references: [ConversationAttachedReference],
       model: String?,
       modelProviderName: String?,
       workspaceFolder: String,
       workspaceFolders: [WorkspaceFolder]? = nil,
       agentMode: Bool,
       customChatModeId: String?
    ) async throws -> ConversationCreateResponse {
        do {
            let params = TurnCreateParams(workDoneToken: workDoneToken,
                                          conversationId: conversationId,
                                          turnId: turnId,
                                          message: message,
                                          textDocument: activeDoc,
                                          ignoredSkills: ignoredSkills,
                                          references: references.map { Reference.from($0) },
                                          model: model,
                                          modelProviderName: modelProviderName,
                                          workspaceFolder: workspaceFolder,
                                          workspaceFolders: workspaceFolders,
                                          chatMode: agentMode ? "Agent" : nil,
                                          customChatModeId: customChatModeId,
                                          needToolCallConfirmation: true)
            return try await sendRequest(
                GitHubCopilotRequest.CreateTurn(params: params))
        } catch {
            print("Failed to create turn. Error: \(error)")
            throw error
        }
    }
    
    @GitHubCopilotSuggestionActor
    public func deleteTurn(conversationId: String, turnId: String) async throws {
        do {
            let params = TurnDeleteParams(conversationId: conversationId, turnId: turnId, source: .panel)
            _ = try await sendRequest(GitHubCopilotRequest.DeleteTurn(params: params))
        } catch {
            throw error
        }
    }

    @GitHubCopilotSuggestionActor
    public func templates(workspaceFolders: [WorkspaceFolder]? = nil) async throws -> [ChatTemplate] {
        do {
            let params = ConversationTemplatesParams(workspaceFolders: workspaceFolders)
            let response = try await sendRequest(
                GitHubCopilotRequest.GetTemplates(params: params)
            )
            return response
        } catch {
            throw error
        }
    }
    
    @GitHubCopilotSuggestionActor
    public func modes(workspaceFolders: [WorkspaceFolder]? = nil) async throws -> [ConversationMode] {
        do {
            let params = ConversationModesParams(workspaceFolders: workspaceFolders)
            let response = try await sendRequest(
                GitHubCopilotRequest.GetModes(params: params)
            )
            return response
        } catch {
            throw error
        }
    }

    @GitHubCopilotSuggestionActor
    public func models() async throws -> [CopilotModel] {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.CopilotModels()
            )
            return response
        } catch {
            throw error
        }
    }
    
    @GitHubCopilotSuggestionActor
    public func agents() async throws -> [ChatAgent] {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.GetAgents()
            )
            return response
        } catch {
            throw error
        }
    }
    
    @GitHubCopilotSuggestionActor
    public func reviewChanges(params: ReviewChangesParams) async throws -> CodeReviewResult {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.ReviewChanges(params: params)
            )
            return response
        } catch {
            throw error
        }
    }

    @GitHubCopilotSuggestionActor
    public func registerTools(tools: [LanguageModelToolInformation]) async throws -> [LanguageModelTool] {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.RegisterTools(params: RegisterToolsParams(tools: tools))
            )
            return response
        } catch {
            throw error
        }
    }
    
    @GitHubCopilotSuggestionActor
    public func updateToolsStatus(params: UpdateToolsStatusParams) async throws -> [LanguageModelTool] {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.UpdateToolsStatus(params: params)
            )
            return response
        } catch {
            throw error
        }
    }
    
    @GitHubCopilotSuggestionActor
    public func updateMCPToolsStatus(params: UpdateMCPToolsStatusParams) async throws -> [MCPServerToolsCollection] {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.UpdatedMCPToolsStatus(params: params)
            )
            return response
        } catch {
            throw error
        }
    }
    
    @GitHubCopilotSuggestionActor
    public func listMCPRegistryServers(_ params: MCPRegistryListServersParams) async throws -> MCPRegistryServerList {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.MCPRegistryListServers(params: params)
            )
            return response
        } catch {
            throw error
        }
    }
    
    @GitHubCopilotSuggestionActor
    public func getMCPRegistryServer(_ params: MCPRegistryGetServerParams) async throws -> MCPRegistryServerDetail {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.MCPRegistryGetServer(params: params)
            )
            return response
        } catch {
            throw error
        }
    }
    
    @GitHubCopilotSuggestionActor
    public func getMCPRegistryAllowlist() async throws -> GetMCPRegistryAllowlistResult {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.MCPRegistryGetAllowlist()
            )
            return response
        } catch {
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
    public func notifyCopilotInlineEditShown(_ completion: CodeSuggestion) async {
        try? await sendCopilotNotification(.textDocumentDidShowInlineEdit(.from(id: completion.id)))
    }

    @GitHubCopilotSuggestionActor
    public func notifyAccepted(_ completion: CodeSuggestion, acceptedLength: Int? = nil) async {
        _ = try? await sendRequest(
            GitHubCopilotRequest.NotifyAccepted(completionUUID: completion.id, acceptedLength: acceptedLength)
        )
    }
    
    @GitHubCopilotSuggestionActor
    public func notifyCopilotInlineEditAccepted(_ completion: CodeSuggestion) async {
        _ = try? await sendRequest(
            GitHubCopilotRequest.NotifyCopilotInlineEditAccepted(params: [completion.id])
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
            .textDocumentDidOpen(
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
        version: Int,
        contentChanges: [TextDocumentContentChangeEvent]? = nil
    ) async throws {
        let uri = fileURL.absoluteString
        let changes: [TextDocumentContentChangeEvent] = contentChanges ?? [.init(range: nil, rangeLength: nil, text: content)]
        //        Logger.service.debug("Change \(uri), \(content.count)")
        try await server.sendNotification(
            .textDocumentDidChange(
                DidChangeTextDocumentParams(
                    uri: uri,
                    version: version,
                    contentChanges: changes
                )
            )
        )
    }

    @GitHubCopilotSuggestionActor
    public func notifySaveTextDocument(fileURL: URL) async throws {
        let uri = "file://\(fileURL.path)"
        //        Logger.service.debug("Save \(uri)")
        try await server.sendNotification(.textDocumentDidSave(.init(uri: uri)))
    }

    @GitHubCopilotSuggestionActor
    public func notifyCloseTextDocument(fileURL: URL) async throws {
        let uri = "file://\(fileURL.path)"
        //        Logger.service.debug("Close \(uri)")
        try await server.sendNotification(.textDocumentDidClose(.init(uri: uri)))
    }
    
    @GitHubCopilotSuggestionActor
    public func notifyDidChangeWatchedFiles(_ event: DidChangeWatchedFilesEvent) async throws {
//        Logger.service.debug("notifyDidChangeWatchedFiles \(event)")
        try await sendCopilotNotification(.copilotDidChangeWatchedFiles(.init(workspaceUri: event.workspaceUri, changes: event.changes)))
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
    
    @GitHubCopilotSuggestionActor
    public func checkQuota() async throws -> GitHubCopilotQuotaInfo {
        do {
            let response = try await sendRequest(GitHubCopilotRequest.CheckQuota())
            await Status.shared.updateQuotaInfo(response)
            return response
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
            if !CopilotModelManager.hasLLMs() {
                Logger.gitHubCopilot.info("No models found, fetching models...")
                let models = try? await models()
                if let models = models, !models.isEmpty {
                    CopilotModelManager.updateLLMs(models)
                }
            }
            
            if !BYOKModelManager.hasApiKey() {
                Logger.gitHubCopilot.info("No BYOK API keys found, fetching BYOK API keys...")
                let byokApiKeys = try? await listBYOKApiKeys(
                    .init(providerName: nil, modelId: nil)
                )
                if let byokApiKeys = byokApiKeys, !byokApiKeys.apiKeys.isEmpty {
                    BYOKModelManager
                        .updateApiKeys(apiKeys: byokApiKeys.apiKeys)
                }
            }
            
            if !BYOKModelManager.hasBYOKModels() {
                Logger.gitHubCopilot.info("No BYOK models found, fetching BYOK models...")
                let byokModels = try? await listBYOKModels(
                    .init(providerName: nil, enableFetchUrl: nil)
                )
                if let byokModels = byokModels, !byokModels.models.isEmpty {
                    BYOKModelManager
                        .updateBYOKModels(BYOKModels: byokModels.models)
                }
            }
            await unwatchAuthStatus()
        } else if status.status == .notAuthorized {
            await Status.shared
                .updateAuthStatus(
                    .notAuthorized,
                    username: status.user,
                    message: status.status.description
                )
            await watchAuthStatus()
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
    public func signInInitiate() async throws -> (
        status: SignInInitiateStatus,
        verificationUri: String?,
        userCode: String?,
        user: String?
    ) {
        do {
            let result = try await sendRequest(GitHubCopilotRequest.SignInInitiate())
            switch result.status {
            case .promptUserDeviceFlow:
                guard let verificationUri = result.verificationUri,
                      let userCode = result.userCode else {
                    throw GitHubCopilotError.languageServerError(.missingExpectedResult)
                }
                return (status: .promptUserDeviceFlow, verificationUri: verificationUri, userCode: userCode, user: nil)
            case .alreadySignedIn:
                guard let user = result.user else {
                    throw GitHubCopilotError.languageServerError(.missingExpectedResult)
                }
                return (status: .alreadySignedIn, verificationUri: nil, userCode: nil, user: user)
            }
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
        GitHubCopilotService.services.removeAll { $0 === self }
        if let localProcessServer {
            try await localProcessServer.shutdown()
        } else {
            throw GitHubCopilotError.languageServerError(ServerError.serverUnavailable)
        }
    }

    @GitHubCopilotSuggestionActor
    public func exit() async throws {
        GitHubCopilotService.services.removeAll { $0 === self }
        if let localProcessServer {
            try await localProcessServer.exit()
        } else {
            throw GitHubCopilotError.languageServerError(ServerError.serverUnavailable)
        }
    }

    @GitHubCopilotSuggestionActor
    public func sendError(
        transaction: String?,
        stacktrace: String?,
        properties: [String: String]?,
        platform: String?,
        exceptionDetail: [ExceptionDetail]?
    ) async throws {
        let params = TelemetryExceptionParams(
            transaction: transaction,
            stacktrace: stacktrace,
            properties: properties,
            platform: platform ?? "macOS",
            exceptionDetail: exceptionDetail
        )
        do {
            let _ = try await sendRequest(
                GitHubCopilotRequest.TelemetryException(params: params)
            )
        } catch {
            print("Failed to send telemetry exception. Error: \(error)")
            throw error
        }
    }

    private func sendRequest<E: GitHubCopilotRequestType>(_ endpoint: E, timeout: TimeInterval? = nil) async throws -> E.Response {
        do {
            return try await server.sendRequest(endpoint)
        } catch {
            let error = ServerError.convertToServerError(error: error)
            if let info = CLSErrorInfo(for: error) {
                // update the auth status if the error indicates it may have changed, and then rethrow
                if info.affectsAuthStatus && !(endpoint is GitHubCopilotRequest.CheckStatus) {
                    updateStatusInBackground()
                }
            }
            let methodName: String
            switch endpoint.request {
            case .custom(let method, _, _):
                methodName = method
            default:
                methodName = endpoint.request.method.rawValue
            }
            if methodName != "telemetry/exception" { // ignore telemetry request
                Logger.gitHubCopilot.error(
                    "Failed to send request \(methodName). Error: \(GitHubCopilotError.languageServerError(error).localizedDescription)"
                )
            }
            throw error
        }
    }

    public static func signOutAll() async throws {
        var signoutError: Error? = nil
        for service in services {
            do {
                let _ = try await service.signOut()
            } catch let error as ServerError {
                signoutError = GitHubCopilotError.languageServerError(error)
            } catch {
                signoutError = error
            }
        }

        if let signoutError {
            throw signoutError
        } else {
            CopilotModelManager.clearLLMs()
        }
    }
    
    public static func updateAllClsMCP(collections: [UpdateMCPToolsStatusServerCollection]) async {
        var updateError: Error? = nil
        var servers: [MCPServerToolsCollection] = []

        for service in services {
            if service.projectRootURL.path == "/" {
                continue // Skip services with root project URL
            }

            do {
                servers = try await service.updateMCPToolsStatus(
                    params: .init(servers: collections)
                )
            } catch let error as ServerError {
                updateError = GitHubCopilotError.languageServerError(error)
            } catch {
                updateError = error
            }
        }
        
        CopilotMCPToolManager.updateMCPTools(servers)
        Logger.gitHubCopilot.info("Updated All MCPTools: \(servers.count) servers")

        if let updateError {
            Logger.gitHubCopilot.error("Failed to update MCP Tools status: \(updateError)")
        }
    }
    
    public static func updateAllCLSTools(tools: [ToolStatusUpdate]) async -> [LanguageModelTool]  {
        var updateError: Error? = nil
        var updatedTools: [LanguageModelTool] = []

        for service in services {
            if service.projectRootURL.path == "/" {
                continue // Skip services with root project URL
            }

            do {
                updatedTools = try await service.updateToolsStatus(
                    params: .init(tools: tools)
                )
            } catch let error as ServerError {
                updateError = GitHubCopilotError.languageServerError(error)
            } catch {
                updateError = error
            }
        }
        
        CopilotLanguageModelToolManager.updateToolsStatus(updatedTools)
        Logger.gitHubCopilot.info("Updated All Built-In Tools: \(tools.count) tools")

        if let updateError {
            Logger.gitHubCopilot.error("Failed to update Built-In Tools status: \(updateError)")
        }
        
        return updatedTools
    }
    
    /// Refresh client tools by registering an empty list to get the latest tools from the server.
    /// This is a workaround for the issue where server-side tools may not be ready when client tools are initially registered.
    public static func refreshClientTools() async {
        // Use the first available service since CopilotLanguageModelToolManager is shared
        guard let service = services.first(where: { $0.projectRootURL.path != "/" }) else {
            Logger.gitHubCopilot.error("No available service to refresh client tools")
            return
        }

        do {
            // Capture previous snapshot to detect newly added tools only
            let previousNames = Set((CopilotLanguageModelToolManager.getAvailableLanguageModelTools() ?? []).map { $0.name })

            // Register empty list to get the complete updated tool list from server
            let refreshedTools = try await service.registerTools(tools: [])
            CopilotLanguageModelToolManager.updateToolsStatus(refreshedTools)
            Logger.gitHubCopilot.info("Refreshed client tools: \(refreshedTools.count) tools available (previous: \(previousNames.count))")

            // Restore status ONLY for newly added tools whose saved status differs.
            if let savedJSON = AppState.shared.get(key: "languageModelToolsStatus"),
                let data = try? JSONEncoder().encode(savedJSON),
                let savedStatusList = try? JSONDecoder().decode([ToolStatusUpdate].self, from: data),
                !savedStatusList.isEmpty {
                let refreshedByName = Dictionary(uniqueKeysWithValues: (CopilotLanguageModelToolManager.getAvailableLanguageModelTools() ?? []).map { ($0.name, $0) })
                let newlyAddedNames = refreshedTools.map { $0.name }.filter { !previousNames.contains($0) }
                if !newlyAddedNames.isEmpty {
                    let neededUpdates: [ToolStatusUpdate] = newlyAddedNames.compactMap { newName in
                        guard let saved = savedStatusList.first(where: { $0.name == newName }),
                              let current = refreshedByName[newName], current.status != saved.status else { return nil }
                        return saved
                    }
                    if !neededUpdates.isEmpty {
                        do {
                            let finalTools = try await service.updateToolsStatus(params: .init(tools: neededUpdates))
                            CopilotLanguageModelToolManager.updateToolsStatus(finalTools)
                            Logger.gitHubCopilot.info("Restored statuses for newly added tools: \(neededUpdates.map{ $0.name }.joined(separator: ", "))")
                        } catch {
                            Logger.gitHubCopilot.error("Failed to restore newly added tool statuses: \(error)")
                        }
                    }
                }
            }
        } catch {
            Logger.gitHubCopilot.error("Failed to refresh client tools: \(error)")
        }
    }
    
    private func loadUnrestoredLanguageModelTools() -> [ToolStatusUpdate] {
        if let savedJSON = AppState.shared.get(key: "languageModelToolsStatus"),
           let data = try? JSONEncoder().encode(savedJSON),
           let savedTools = try? JSONDecoder().decode([ToolStatusUpdate].self, from: data) {
            return savedTools
        }
        return []
    }
    
    private func restoreRegisteredToolsStatus() async {
        // Get unrestored tools from the shared coordinator
        let toolsToRestore = await GitHubCopilotService.toolInitializationActor.loadUnrestoredToolsIfNeeded()

        guard !toolsToRestore.isEmpty else {
            Logger.gitHubCopilot.info("No previously disabled tools need to be restored")
            return
        }
        
        do {
            let updatedTools = try await updateToolsStatus(params: .init(tools: toolsToRestore))
            CopilotLanguageModelToolManager.updateToolsStatus(updatedTools)
            Logger.gitHubCopilot.info("Restored \(toolsToRestore.count) disabled tools for service at \(projectRootURL.path)")
        } catch {
            Logger.gitHubCopilot.error("Failed to restore tools for service at \(projectRootURL.path): \(error)")
        }
    }
    
    public func handleMCPToolsNotification(_ notification: AnyJSONRPCNotification) async {
        if let payload = GetAllToolsParams.decode(fromParams: notification.params) {
            CopilotMCPToolManager.updateMCPTools(payload.servers)
        }
    }
    
    public func handleMCPRuntimeLogsNotification(_ notification: AnyJSONRPCNotification) async {
        let debugDescription = encodeJSONParams(params: notification.params)
        Logger.mcp.info("[\(self.projectRootURL.path)] copilot/mcpRuntimeLogs: \(debugDescription)")

        if let payload = GitHubCopilotNotification.MCPRuntimeNotification.decode(
            fromParams: notification.params
        ) {
            if mcpRuntimeLogFileName.isEmpty {
                mcpRuntimeLogFileName = mcpLogFileNameFromURL(projectRootURL)
            }
            Logger
                .logMCPRuntime(
                    logFileName: mcpRuntimeLogFileName,
                    level: payload.level.rawValue,
                    message: payload.message,
                    server: payload.server,
                    tool: payload.tool,
                    time: payload.time
                )
        }
    }
    
    private func mcpLogFileNameFromURL(_ projectRootURL: URL) -> String {
        // Create a unique key from workspace URL that's safe for filesystem
        let workspaceName = projectRootURL.lastPathComponent
            .replacingOccurrences(of: ".xcworkspace", with: "")
            .replacingOccurrences(of: ".xcodeproj", with: "")
            .replacingOccurrences(of: ".playground", with: "")
        let workspacePath = projectRootURL.path
        
        // Use a combination of name and hash of path for uniqueness
        let pathHash = String(workspacePath.hash.magnitude, radix: 36).prefix(6)
        return "\(workspaceName)-\(pathHash)"
    }

    public static func getProjectGithubCopilotService(for projectRootURL: URL) -> GitHubCopilotService? {
        if let existingService = services.first(where: { $0.projectRootURL == projectRootURL }) {
            return existingService
        } else {
            return nil
        }
    }

    public func handleSendWorkspaceDidChangeNotifications() {
        Task {
            if projectRootURL.path != "/" {
                try? await self.server.sendNotification(
                    .workspaceDidChangeWorkspaceFolders(
                        .init(event: .init(added: [.init(uri: projectRootURL.absoluteString, name: projectRootURL.lastPathComponent)], removed: []))
                    )
                )
            }
            
            // Send initial configuration after initialize
            await sendConfigurationUpdate()
            
            // Combine both notification streams
            let combinedNotifications = Publishers.Merge3(
                NotificationCenter.default.publisher(for: .gitHubCopilotShouldRefreshEditorInformation).map { _ in "editorInfo" },
                FeatureFlagNotifierImpl.shared.featureFlagsDidChange.map { _ in "featureFlags" },
                DistributedNotificationCenter.default()
                    .publisher(for: .githubCopilotAgentMaxToolCallingLoopDidChange)
                    .map { _ in "agentMaxToolCallingLoop" }
            )
            
            for await _ in combinedNotifications.values {
                await sendConfigurationUpdate()
            }
        }
    }
    
    private func sendConfigurationUpdate() async {
        let includeMCP = projectRootURL.path != "/" &&
            FeatureFlagNotifierImpl.shared.featureFlags.agentMode &&
            FeatureFlagNotifierImpl.shared.featureFlags.mcp
        
        let newConfiguration = editorConfiguration(includeMCP: includeMCP)
        
        // Only send the notification if the configuration has actually changed
        guard self.lastSentConfiguration != newConfiguration else { return }
        
        _ = try? await self.server.sendNotification(
            .workspaceDidChangeConfiguration(
                .init(settings: newConfiguration)
            )
        )
        
        // Cache the sent configuration
        self.lastSentConfiguration = newConfiguration
    }
    
    public func saveBYOKApiKey(_ params: BYOKSaveApiKeyParams) async throws -> BYOKSaveApiKeyResponse {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.BYOKSaveApiKey(params: params)
            )
            return response
        } catch {
            throw error
        }
    }
    
    public func listBYOKApiKeys(_ params: BYOKListApiKeysParams) async throws -> BYOKListApiKeysResponse {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.BYOKListApiKeys(params: params)
            )
            return response
        } catch {
            throw error
        }
    }

    public func deleteBYOKApiKey(_ params: BYOKDeleteApiKeyParams) async throws -> BYOKDeleteApiKeyResponse {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.BYOKDeleteApiKey(params: params)
            )
            return response
        } catch {
            throw error
        }
    }
    
    public func saveBYOKModel(_ params: BYOKSaveModelParams) async throws -> BYOKSaveModelResponse {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.BYOKSaveModel(params: params)
            )
            return response
        } catch {
            throw error
        }
    }
    
    public func listBYOKModels(_ params: BYOKListModelsParams) async throws -> BYOKListModelsResponse {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.BYOKListModels(params: params)
            )
            return response
        } catch {
            throw error
        }
    }
    
    public func deleteBYOKModel(_ params: BYOKDeleteModelParams) async throws -> BYOKDeleteModelResponse {
        do {
            let response = try await sendRequest(
                GitHubCopilotRequest.BYOKDeleteModel(params: params)
            )
            return response
        } catch {
            throw error
        }
    }
}

extension SafeInitializingServer: GitHubCopilotLSP {
    func sendRequest<E: GitHubCopilotRequestType>(_ endpoint: E) async throws -> E.Response {
        try await sendRequest(endpoint.request)
    }
}

extension GitHubCopilotService {
    func sendCopilotNotification(_ notif: CopilotClientNotification) async throws {
        try await localProcessServer?.sendCopilotNotification(notif)
    }
}
