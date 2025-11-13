import Foundation
import Status
import SuggestionBasic

@objc(XPCServiceProtocol)
public protocol XPCServiceProtocol {
    func getSuggestedCode(editorContent: Data, withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void)
    func getNextSuggestedCode(editorContent: Data, withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void)
    func getPreviousSuggestedCode(editorContent: Data, withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void)
    func getSuggestionAcceptedCode(editorContent: Data, withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void)
    func getNESSuggestionAcceptedCode(editorContent: Data, withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void)
    func getSuggestionRejectedCode(editorContent: Data, withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void)
    func getNESSuggestionRejectedCode(editorContent: Data, withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void)
    func getRealtimeSuggestedCode(editorContent: Data, withReply reply: @escaping (Data?, Error?) -> Void)
    func getPromptToCodeAcceptedCode(editorContent: Data, withReply reply: @escaping (_ updatedContent: Data?, Error?) -> Void)
    func openChat(withReply reply: @escaping (Error?) -> Void)
    func promptToCode(editorContent: Data, withReply reply: @escaping (Data?, Error?) -> Void)
    func customCommand(id: String, editorContent: Data, withReply reply: @escaping (Data?, Error?) -> Void)
    
    func toggleRealtimeSuggestion(withReply reply: @escaping (Error?) -> Void)
    func toggleRealtimeNES(withReply reply: @escaping (Error?) -> Void)
    func prefetchRealtimeSuggestions(editorContent: Data, withReply reply: @escaping () -> Void)

    func getXPCServiceVersion(withReply reply: @escaping (String, String) -> Void)
    func getXPCCLSVersion(withReply reply: @escaping (String?) -> Void)
    func getXPCServiceAccessibilityPermission(withReply reply: @escaping (ObservedAXStatus) -> Void)
    func getXPCServiceExtensionPermission(withReply reply: @escaping (ExtensionPermissionStatus) -> Void)
    func getXcodeInspectorData(withReply reply: @escaping (Data?, Error?) -> Void)

    func getAvailableMCPServerToolsCollections(withReply reply: @escaping (Data?) -> Void)
    func updateMCPServerToolsStatus(
        tools: Data,
        chatAgentMode: Data?,
        customChatModeId: Data?,
        workspaceFolders: Data?
    )
    func listMCPRegistryServers(_ params: Data, withReply reply: @escaping (Data?, Error?) -> Void)
    func getMCPRegistryServer(_ params: Data, withReply reply: @escaping (Data?, Error?) -> Void)
    func getMCPRegistryAllowlist(withReply reply: @escaping (Data?, Error?) -> Void)
    func getAvailableLanguageModelTools(withReply reply: @escaping (Data?) -> Void)
    func refreshClientTools(withReply reply: @escaping (Data?) -> Void)
    func updateToolsStatus(
        tools: Data,
        chatAgentMode: Data?,
        customChatModeId: Data?,
        workspaceFolders: Data?,
        withReply reply: @escaping (Data?) -> Void
    )

    func getCopilotFeatureFlags(withReply reply: @escaping (Data?) -> Void)
    func getCopilotPolicy(withReply reply: @escaping (Data?) -> Void)
    func updateCopilotModels(withReply reply: @escaping (Data?, Error?) -> Void)
    func getModes(workspaceFolders: Data?, withReply reply: @escaping (Data?, Error?) -> Void)

    func signOutAllGitHubCopilotService()
    func getXPCServiceAuthStatus(withReply reply: @escaping (Data?) -> Void)

    func saveBYOKApiKey(_ params: Data, withReply reply: @escaping (Data?) -> Void)
    func listBYOKApiKeys(_ params: Data, withReply reply: @escaping (Data?) -> Void)
    func deleteBYOKApiKey(_ params: Data, withReply reply: @escaping (Data?) -> Void)
    func saveBYOKModel(_ params: Data, withReply reply: @escaping (Data?) -> Void)
    func listBYOKModels(_ params: Data, withReply reply: @escaping (Data?, Error?) -> Void)
    func deleteBYOKModel(_ params: Data, withReply reply: @escaping (Data?) -> Void)

    func postNotification(name: String, withReply reply: @escaping () -> Void)
    func send(endpoint: String, requestBody: Data, reply: @escaping (Data?, Error?) -> Void)
    func quit(reply: @escaping () -> Void)
}

public struct NoResponse: Codable {
    public static let none = NoResponse()
}

public protocol ExtensionServiceRequestType: Codable {
    associatedtype ResponseBody: Codable
    static var endpoint: String { get }
}

public enum ExtensionServiceRequests {
    public struct OpenExtensionManager: ExtensionServiceRequestType {
        public typealias ResponseBody = NoResponse
        public static let endpoint = "OpenExtensionManager"

        public init() {}
    }

    public struct GetExtensionSuggestionServices: ExtensionServiceRequestType {
        public struct ServiceInfo: Codable {
            public var bundleIdentifier: String
            public var name: String
            
            public init(bundleIdentifier: String, name: String) {
                self.bundleIdentifier = bundleIdentifier
                self.name = name
            }
        }

        public typealias ResponseBody = [ServiceInfo]
        public static let endpoint = "GetExtensionSuggestionServices"

        public init() {}
    }
}

public struct XPCRequestHandlerHitError: Error, LocalizedError {
    public var errorDescription: String? {
        "This is not an actual error, it just indicates a request handler was hit, and no more check is needed."
    }

    public init() {}
}

public struct XPCRequestNotHandledError: Error, LocalizedError {
    public var errorDescription: String? {
        "The request was not handled by the XPC server."
    }

    public init() {}
}

extension ExtensionServiceRequestType {
    /// A helper method to handle requests.
    static func _handle<Request: Codable, Response: Codable>(
        endpoint: String,
        requestBody data: Data,
        reply: @escaping (Data?, Error?) -> Void,
        handler: @escaping (Request) async throws -> Response
    ) throws {
        guard endpoint == Self.endpoint else {
            return
        }
        do {
            let requestBody = try JSONDecoder().decode(Request.self, from: data)
            Task {
                do {
                    let responseBody = try await handler(requestBody)
                    let responseBodyData = try JSONEncoder().encode(responseBody)
                    reply(responseBodyData, nil)
                } catch {
                    reply(nil, error)
                }
            }
        } catch {
            reply(nil, error)
        }
        throw XPCRequestHandlerHitError()
    }

    public static func handle(
        endpoint: String,
        requestBody data: Data,
        reply: @escaping (Data?, Error?) -> Void,
        handler: @escaping (Self) async throws -> Self.ResponseBody
    ) throws {
        try _handle(
            endpoint: endpoint,
            requestBody: data,
            reply: reply
        ) { (request: Self) async throws -> Self.ResponseBody in
            try await handler(request)
        }
    }
}
