import Combine
import ConversationServiceProvider
import Foundation
import JSONRPC
import LanguageClient
import LanguageServerProtocol
import Logger
import ProcessEnv
import Status

public enum ServerError: LocalizedError {
    case handlerUnavailable(String)
    case unhandledMethod(String)
    case notificationDispatchFailed(Error)
    case requestDispatchFailed(Error)
    case clientDataUnavailable(Error)
    case serverUnavailable
    case missingExpectedParameter
    case missingExpectedResult
    case unableToDecodeRequest(Error)
    case unableToSendRequest(Error)
    case unableToSendNotification(Error)
    case serverError(code: Int, message: String, data: Codable?)
    case invalidRequest(Error?)
    case timeout
    case unknownError(Error)

    static func responseError(_ error: AnyJSONRPCResponseError) -> ServerError {
        return ServerError.serverError(code: error.code,
                                       message: error.message,
                                       data: error.data)
    }
    
    static func decodingError(_ error: DecodingError) -> ServerError {
        let message: String
        
        switch error {
        case .typeMismatch(let type, let context):
            message = "Type mismatch: Expected \(type). \(context.debugDescription)"
            
        case .valueNotFound(let type, let context):
            message = "Value not found: Expected \(type). \(context.debugDescription)"
            
        case .keyNotFound(let key, let context):
            message = "Key '\(key.stringValue)' not found. \(context.debugDescription)"
            
        case .dataCorrupted(let context):
            message = "Data corrupted: \(context.debugDescription)"
            
        @unknown default:
            message = error.localizedDescription
        }
        
        return ServerError.serverError(code: -32700, message: message, data: nil)
    }

    static func convertToServerError(error: any Error) -> ServerError {
        if let serverError = error as? ServerError {
            return serverError
        } else if let jsonRPCError = error as? AnyJSONRPCResponseError {
            return responseError(jsonRPCError)
        } else if let decodeError = error as? DecodingError {
            return decodingError(decodeError)
        }
        
        return .unknownError(error)
    }
}

public typealias LSPResponse = Decodable & Sendable

/// A clone of the `LocalProcessServer`.
/// We need it because the original one does not allow us to handle custom notifications.
class CopilotLocalProcessServer {
    public var notificationPublisher: PassthroughSubject<AnyJSONRPCNotification, Never> = PassthroughSubject<AnyJSONRPCNotification, Never>()
    
    private var process: Process?
    private var wrappedServer: CustomJSONRPCServerConnection?

    private var cancellables = Set<AnyCancellable>()
    @MainActor var ongoingCompletionRequestIDs: [JSONId] = []
    @MainActor var ongoingConversationRequestIDs = [String: JSONId]()
    
    public convenience init(
        path: String,
        arguments: [String],
        environment: [String: String]? = nil
    ) {
        let params = Process.ExecutionParameters(
            path: path,
            arguments: arguments,
            environment: environment
        )

        self.init(executionParameters: params)
    }

    init(executionParameters parameters: Process.ExecutionParameters) {
        do {
            let channel: DataChannel = try startLocalProcess(parameters: parameters, terminationHandler: processTerminated)
            let noop: @Sendable (Data) async -> Void = { _ in }
            let newChannel = DataChannel.tap(channel: channel.withMessageFraming(), onRead: noop, onWrite: onWriteRequest)

            self.wrappedServer = CustomJSONRPCServerConnection(dataChannel: newChannel, notificationHandler: handleNotification)
        } catch {
            Logger.gitHubCopilot.error("Failed to start local CLS process: \(error)")
        }
    }
    
    deinit {
        self.process?.terminate()
    }

    private func startLocalProcess(parameters: Process.ExecutionParameters,
                                      terminationHandler: @escaping @Sendable () -> Void) throws -> DataChannel {
        let (channel, process) = try DataChannel.localProcessChannel(parameters: parameters, terminationHandler: terminationHandler)

        // Create a serial queue to synchronize writes
        let writeQueue = DispatchQueue(label: "DataChannel.writeQueue")
        let stdinPipe: Pipe = process.standardInput as! Pipe
        self.process = process
        let handler: DataChannel.WriteHandler = { data in
            try writeQueue.sync {
                // write is not thread-safe, so we need to use queue to ensure it thread-safe
                try stdinPipe.fileHandleForWriting.write(contentsOf: data)
            }
        }

        let wrappedChannel = DataChannel(
            writeHandler: handler,
            dataSequence: channel.dataSequence
        )

        return wrappedChannel
    }
    
    @Sendable
    private func onWriteRequest(data: Data) {
        guard let request = try? JSONDecoder().decode(JSONRPCRequest<JSONValue>.self, from: data) else {
            return
        }

        if request.method == "getCompletionsCycling" || request.method == "textDocument/copilotInlineEdit" {
            Task { @MainActor [weak self] in
                self?.ongoingCompletionRequestIDs.append(request.id)
            }
        } else if request.method == "conversation/create" {
            Task { @MainActor [weak self] in
                if let paramsData = try? JSONEncoder().encode(request.params) {
                    do {
                        let params = try JSONDecoder().decode(ConversationCreateParams.self, from: paramsData)
                        self?.ongoingConversationRequestIDs[params.workDoneToken] = request.id
                    } catch {
                        // Handle decoding error
                        Logger.gitHubCopilot.error("Error decoding ConversationCreateParams: \(error)")
                    }
                }
            }
        } else if request.method == "conversation/turn" {
            Task { @MainActor [weak self] in
                if let paramsData = try? JSONEncoder().encode(request.params) {
                    do {
                        let params = try JSONDecoder().decode(TurnCreateParams.self, from: paramsData)
                        self?.ongoingConversationRequestIDs[params.workDoneToken] = request.id
                    } catch {
                        // Handle decoding error
                        Logger.gitHubCopilot.error("Error decoding TurnCreateParams: \(error)")
                    }
                }
            }
        }
    }

    @Sendable
    private func processTerminated() {
        // releasing the server here will short-circuit any pending requests,
        // which might otherwise take a while to time out, if ever.
        wrappedServer = nil
    }

    private func handleNotification(
        _ anyNotification: AnyJSONRPCNotification,
        data: Data
    ) -> Bool {
        let methodName = anyNotification.method
        let debugDescription = encodeJSONParams(params: anyNotification.params)
        if let method = ServerNotification.Method(rawValue: methodName) {
            switch method {
            case .windowLogMessage:
                Logger.gitHubCopilot.info("\(anyNotification.method): \(debugDescription)")
                return true
            case .protocolProgress:
                notificationPublisher.send(anyNotification)
                return true
            default:
                return false
            }
        } else {
            switch methodName {
            case "LogMessage":
                Logger.gitHubCopilot.info("\(anyNotification.method): \(debugDescription)")
                return true
            case "didChangeStatus":
                Logger.gitHubCopilot.info("\(anyNotification.method): \(debugDescription)")
                if let payload = GitHubCopilotNotification.StatusNotification.decode(fromParams: anyNotification.params) {
                    Task {
                        await Status.shared
                            .updateCLSStatus(
                                payload.kind.clsStatus,
                                busy: payload.busy,
                                message: payload.message ?? ""
                            )
                    }
                }
                return true
            case "copilot/didChangeFeatureFlags":
                notificationPublisher.send(anyNotification)
                return true
            case "copilot/mcpTools":
                notificationPublisher.send(anyNotification)
                return true
            case "copilot/mcpRuntimeLogs":
                notificationPublisher.send(anyNotification)
                return true
            case "policy/didChange":
                notificationPublisher.send(anyNotification)
                return true
            case "conversation/preconditionsNotification", "statusNotification":
                // Ignore
                return true
            default:
                return false
            }
        }
    }
}

extension CopilotLocalProcessServer: ServerConnection {
    var eventSequence: EventSequence {
        guard let server = wrappedServer else {
            let result = EventSequence.makeStream()
            result.continuation.finish()
            return result.stream
        }
        
        return server.eventSequence
    }

    public func sendNotification(_ notif: ClientNotification) async throws {
        guard let server = wrappedServer, let process = process, process.isRunning else {
            throw ServerError.serverUnavailable
        }
        
        do {
            try await server.sendNotification(notif)
        } catch {
            throw ServerError.unableToSendNotification(error)
        }
    }
    
    /// send copilot specific notification
    public func sendCopilotNotification(_ notif: CopilotClientNotification) async throws -> Void {
        guard let server = wrappedServer, let process = process, process.isRunning else {
            throw ServerError.serverUnavailable
        }
        
        let method = notif.method.rawValue
        
        do {
            switch notif {
            case .copilotDidChangeWatchedFiles(let params):
                try await server.sendNotification(params, method: method)
            case .clientProtocolProgress(let params):
                try await server.sendNotification(params, method: method)
            case .textDocumentDidShowInlineEdit(let params):
                try await server.sendNotification(params, method: method)
            }
        } catch {
            throw ServerError.unableToSendNotification(error)
        }
    }

    /// Cancel ongoing completion requests.
    public func cancelOngoingTasks() async {
        let task = Task { @MainActor in
            for id in ongoingCompletionRequestIDs {
                await cancelTask(id)
            }
            self.ongoingCompletionRequestIDs = []
        }
        await task.value
    }
    
    public func cancelOngoingTask(_ workDoneToken: String) async {
        let task = Task { @MainActor in
            guard let id = ongoingConversationRequestIDs[workDoneToken] else { return }
            await cancelTask(id)
        }
        await task.value
    }
    
    public func cancelTask(_ id: JSONId) async {
        guard let server = wrappedServer, let process = process, process.isRunning else {
            return
        }
        
        switch id {
        case let .numericId(id):
            try? await server.sendNotification(.protocolCancelRequest(.init(id: id)))
        case let .stringId(id):
            try? await server.sendNotification(.protocolCancelRequest(.init(id: id)))
        }
    }
    
    public func sendRequest<Response: LSPResponse>(
        _ request: ClientRequest
    ) async throws -> Response {
        guard let server = wrappedServer, let process = process, process.isRunning else {
            throw ServerError.serverUnavailable
        }
        
        do {
            return try await server.sendRequest(request)
        } catch {
            throw ServerError.convertToServerError(error: error)
        }
    }
}

func encodeJSONParams(params: JSONValue?) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted
    if let jsonData = try? encoder.encode(params),
       let text = String(data: jsonData, encoding: .utf8)
    {
        return text
    }
    return "N/A"
}

// MARK: - Copilot custom notification

public struct CopilotDidChangeWatchedFilesParams: Codable, Hashable {
    /// The CLS need an additional parameter `workspaceUri` for "workspace/didChangeWatchedFiles" event
    public var workspaceUri: String
    public var changes: [FileEvent]

    public init(workspaceUri: String, changes: [FileEvent]) {
        self.workspaceUri = workspaceUri
        self.changes = changes
    }
}

public enum CopilotClientNotification {
    public enum Method: String {
        case workspaceDidChangeWatchedFiles = "workspace/didChangeWatchedFiles"
        case protocolProgress = "$/progress"
        case textDocumentDidShowInlineEdit = "textDocument/didShowInlineEdit"
    }
    
    case copilotDidChangeWatchedFiles(CopilotDidChangeWatchedFilesParams)
    case clientProtocolProgress(ProgressParams)
    case textDocumentDidShowInlineEdit(TextDocumentDidShowInlineEditParams)
    
    public var method: Method {
        switch self {
        case .copilotDidChangeWatchedFiles:
            return .workspaceDidChangeWatchedFiles
        case .clientProtocolProgress:
            return .protocolProgress
        case .textDocumentDidShowInlineEdit:
            return .textDocumentDidShowInlineEdit
        }
    }
}
