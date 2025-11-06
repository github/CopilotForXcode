import Combine
import ConversationServiceProvider
import Foundation
import JSONRPC
import LanguageClient
import LanguageServerProtocol
import Logger

public typealias ResponseHandler = ServerRequest.Handler<JSONValue>
public typealias LegacyResponseHandler = (AnyJSONRPCResponse) -> Void

protocol ServerRequestHandler {
    func handleRequest(id: JSONId, _ request: ServerRequest, workspaceURL: URL, service: GitHubCopilotService?)
}

class ServerRequestHandlerImpl: ServerRequestHandler {
    public static let shared = ServerRequestHandlerImpl()
    private let conversationContextHandler: ConversationContextHandler = ConversationContextHandlerImpl.shared
    private let watchedFilesHandler: WatchedFilesHandler = WatchedFilesHandlerImpl.shared
    private let showMessageRequestHandler: ShowMessageRequestHandler = ShowMessageRequestHandlerImpl.shared
    private let dynamicOAuthRequestHandler: DynamicOAuthRequestHandler = DynamicOAuthRequestHandlerImpl.shared

    func handleRequest(id: JSONId, _ request: ServerRequest, workspaceURL: URL, service: GitHubCopilotService?) {
        switch request {
        case let .windowShowMessageRequest(params, callback):
            if workspaceURL.path != "/" {
                do {
                    let paramsData = try JSONEncoder().encode(params)
                    let showMessageRequestParams = try JSONDecoder().decode(ShowMessageRequestParams.self, from: paramsData)

                    showMessageRequestHandler.handleShowMessageRequest(
                        ShowMessageRequest(
                            id: id,
                            method: "window/showMessageRequest",
                            params: showMessageRequestParams
                        ),
                        callback: callback
                    )
                } catch {
                    Task {
                        await callback(.success(nil))
                    }
                }
            }

        case let .custom(method, params, callback):
            let legacyResponseHandler = toLegacyResponseHandler(callback)
            do {
                switch method {
                case "conversation/context":
                    let paramsData = try JSONEncoder().encode(params)
                    let contextParams = try JSONDecoder().decode(ConversationContextParams.self, from: paramsData)
                    conversationContextHandler.handleConversationContext(
                        ConversationContextRequest(id: id, method: method, params: contextParams),
                        completion: legacyResponseHandler
                    )

                case "copilot/watchedFiles":
                    let paramsData = try JSONEncoder().encode(params)
                    let watchedFilesParams = try JSONDecoder().decode(WatchedFilesParams.self, from: paramsData)
                    watchedFilesHandler.handleWatchedFiles(
                        WatchedFilesRequest(id: id, method: method, params: watchedFilesParams),
                        workspaceURL: workspaceURL,
                        completion: legacyResponseHandler,
                        service: service
                    )

                case "conversation/invokeClientTool":
                    let paramsData = try JSONEncoder().encode(params)
                    let invokeParams = try JSONDecoder().decode(InvokeClientToolParams.self, from: paramsData)
                    ClientToolHandlerImpl.shared.invokeClientTool(
                        InvokeClientToolRequest(id: id, method: method, params: invokeParams),
                        completion: legacyResponseHandler
                    )

                case "conversation/invokeClientToolConfirmation":
                    let paramsData = try JSONEncoder().encode(params)
                    let invokeParams = try JSONDecoder().decode(InvokeClientToolParams.self, from: paramsData)
                    ClientToolHandlerImpl.shared.invokeClientToolConfirmation(
                        InvokeClientToolConfirmationRequest(id: id, method: method, params: invokeParams),
                        completion: legacyResponseHandler
                    )

                case "copilot/dynamicOAuth":
                    let paramsData = try JSONEncoder().encode(params)
                    let dynamicOAuthParams = try JSONDecoder().decode(DynamicOAuthParams.self, from: paramsData)
                    DynamicOAuthRequestHandlerImpl.shared.handleDynamicOAuthRequest(
                        DynamicOAuthRequest(id: id, method: method, params: dynamicOAuthParams),
                        completion: legacyResponseHandler
                    )

                default:
                    break
                }
            } catch {
                handleError(id: id, method: method, error: error, callback: legacyResponseHandler)
            }

        default:
            break
        }
    }

    private func handleError(id: JSONId, method: String, error: Error, callback: @escaping (AnyJSONRPCResponse) -> Void) {
        callback(
            AnyJSONRPCResponse(
                id: id,
                result: JSONValue.array([
                    JSONValue.null,
                    JSONValue.hash([
                        "code": .number(-32602 /* Invalid params */ ),
                        "message": .string("Error handling \(method): \(error.localizedDescription)")]),
                ])
            )
        )
        Logger.gitHubCopilot.error(error)
    }

    /// Converts a new Handler to work with old code that expects LegacyResponseHandler
    private func toLegacyResponseHandler(
        _ newHandler: @escaping ResponseHandler
    ) -> LegacyResponseHandler {
        return { response in
            Task {
                if let error = response.error {
                    await newHandler(.failure(error))
                } else if let result = response.result {
                    await newHandler(.success(result))
                }
            }
        }
    }
}
