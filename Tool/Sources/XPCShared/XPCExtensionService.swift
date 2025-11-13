import Foundation
import GitHubCopilotService
import ConversationServiceProvider
import Logger
import Status
import LanguageServerProtocol

public enum XPCExtensionServiceError: Swift.Error, LocalizedError {
    case failedToGetServiceEndpoint
    case failedToCreateXPCConnection
    case xpcServiceError(Error)

    public var errorDescription: String? {
        switch self {
        case .failedToGetServiceEndpoint:
            return "Waiting for service to connect to the communication bridge."
        case .failedToCreateXPCConnection:
            return "Failed to create XPC connection."
        case let .xpcServiceError(error):
            return "Connection to extension service error: \(error.localizedDescription)"
        }
    }
    
    public var underlyingError: Error? {
        switch self {
        case let .xpcServiceError(error):
            return error
        default:
            return nil
        }
    }
}

public class XPCExtensionService {
    @XPCServiceActor
    var service: XPCService?
    @XPCServiceActor
    var connection: NSXPCConnection? { service?.connection }
    let logger: Logger
    let bridge: XPCCommunicationBridge

    public nonisolated
    init(logger: Logger) {
        self.logger = logger
        bridge = XPCCommunicationBridge(logger: logger)
    }

    /// Launches the extension service if it's not running, returns true if the service has finished
    /// launching and the communication becomes available.
    @XPCServiceActor
    public func launchIfNeeded() async throws -> Bool {
        try await bridge.launchExtensionServiceIfNeeded() != nil
    }

    public func getXPCServiceVersion() async throws -> (version: String, build: String) {
        try await withXPCServiceConnected {
            service, continuation in
            service.getXPCServiceVersion { version, build in
                continuation.resume((version, build))
            }
        }
    }
    
    public func getXPCCLSVersion() async throws -> String? {
        try await withXPCServiceConnected {
            service, continuation in
            service.getXPCCLSVersion { version in
                continuation.resume(version)
            }
        }
    }

    public func getXPCServiceAccessibilityPermission() async throws -> ObservedAXStatus {
        try await withXPCServiceConnected {
            service, continuation in
            service.getXPCServiceAccessibilityPermission { isGranted in
                continuation.resume(isGranted)
            }
        }
    }
    
    public func getXPCServiceExtensionPermission() async throws -> ExtensionPermissionStatus {
        try await withXPCServiceConnected {
            service, continuation in
            service.getXPCServiceExtensionPermission { isGranted in
                continuation.resume(isGranted)
            }
        }
    }

    public func getSuggestedCode(editorContent: EditorContent) async throws -> UpdatedContent? {
        try await suggestionRequest(
            editorContent,
            { $0.getSuggestedCode }
        )
    }

    public func getNextSuggestedCode(editorContent: EditorContent) async throws -> UpdatedContent? {
        try await suggestionRequest(
            editorContent,
            { $0.getNextSuggestedCode }
        )
    }

    public func getPreviousSuggestedCode(editorContent: EditorContent) async throws
        -> UpdatedContent?
    {
        try await suggestionRequest(
            editorContent,
            { $0.getPreviousSuggestedCode }
        )
    }

    public func getSuggestionAcceptedCode(editorContent: EditorContent) async throws
        -> UpdatedContent?
    {
        try await suggestionRequest(
            editorContent,
            { $0.getSuggestionAcceptedCode }
        )
    }
    
    public func getNESSuggestionAcceptedCode(editorContent: EditorContent) async throws -> UpdatedContent? {
        try await suggestionRequest(
            editorContent,
            { $0.getNESSuggestionAcceptedCode }
        )
    }

    public func getSuggestionRejectedCode(editorContent: EditorContent) async throws
        -> UpdatedContent?
    {
        try await suggestionRequest(
            editorContent,
            { $0.getSuggestionRejectedCode }
        )
    }
    
    public func getNESSuggestionRejectedCode(editorContent: EditorContent) async throws
    -> UpdatedContent?
    {
        try await suggestionRequest(
            editorContent,
            { $0.getNESSuggestionRejectedCode }
        )
    }

    public func getRealtimeSuggestedCode(editorContent: EditorContent) async throws
        -> UpdatedContent?
    {
        try await suggestionRequest(
            editorContent,
            { $0.getRealtimeSuggestedCode }
        )
    }

    public func getPromptToCodeAcceptedCode(editorContent: EditorContent) async throws
        -> UpdatedContent?
    {
        try await suggestionRequest(
            editorContent,
            { $0.getPromptToCodeAcceptedCode }
        )
    }

    public func toggleRealtimeSuggestion() async throws {
        try await withXPCServiceConnected {
            service, continuation in
            service.toggleRealtimeSuggestion { error in
                if let error {
                    continuation.reject(error)
                    return
                }
                continuation.resume(())
            }
        } as Void
    }
    
    public func toggleRealtimeNES() async throws {
        try await withXPCServiceConnected {
            service, continuation in
            service.toggleRealtimeNES { error in
                if let error {
                    continuation.reject(error)
                    return
                }
                continuation.resume(())
            }
        } as Void
    }

    public func prefetchRealtimeSuggestions(editorContent: EditorContent) async {
        guard let data = try? JSONEncoder().encode(editorContent) else { return }
        try? await withXPCServiceConnected { service, continuation in
            service.prefetchRealtimeSuggestions(editorContent: data) {
                continuation.resume(())
            }
        }
    }

    public func openChat() async throws {
        try await withXPCServiceConnected {
            service, continuation in
            service.openChat { error in
                if let error {
                    continuation.reject(error)
                    return
                }
                continuation.resume(())
            }
        } as Void
    }

    public func promptToCode(editorContent: EditorContent) async throws -> UpdatedContent? {
        try await suggestionRequest(
            editorContent,
            { $0.promptToCode }
        )
    }

    public func customCommand(
        id: String,
        editorContent: EditorContent
    ) async throws -> UpdatedContent? {
        try await suggestionRequest(
            editorContent,
            { service in { service.customCommand(id: id, editorContent: $0, withReply: $1) } }
        )
    }

    public func quitService() async throws {
        try await withXPCServiceConnectedWithoutLaunching {
            service, continuation in
            service.quit {
                continuation.resume(())
            }
        }
    }

    public func postNotification(name: String) async throws {
        try await withXPCServiceConnected {
            service, continuation in
            service.postNotification(name: name) {
                continuation.resume(())
            }
        }
    }

    public func send<M: ExtensionServiceRequestType>(
        requestBody: M
    ) async throws -> M.ResponseBody {
        try await withXPCServiceConnected { service, continuation in
            do {
                let requestBodyData = try JSONEncoder().encode(requestBody)
                service.send(endpoint: M.endpoint, requestBody: requestBodyData) { data, error in
                    if let error {
                        continuation.reject(error)
                    } else {
                        do {
                            guard let data = data else {
                                continuation.reject(NoDataError())
                                return
                            }
                            let responseBody = try JSONDecoder().decode(
                                M.ResponseBody.self,
                                from: data
                            )
                            continuation.resume(responseBody)
                        } catch {
                            continuation.reject(error)
                        }
                    }
                }
            } catch {
                continuation.reject(error)
            }
        }
    }
}

extension XPCExtensionService: XPCServiceDelegate {
    public func connectionDidInterrupt() async {
        Task { @XPCServiceActor in
            service = nil
        }
    }

    public func connectionDidInvalidate() async {
        Task { @XPCServiceActor in
            service = nil
        }
    }
}

extension XPCExtensionService {
    @XPCServiceActor
    private func updateEndpoint(_ endpoint: NSXPCListenerEndpoint) {
        service = XPCService(
            kind: .anonymous(endpoint: endpoint),
            interface: NSXPCInterface(with: XPCServiceProtocol.self),
            logger: logger,
            delegate: self
        )
    }

    @XPCServiceActor
    private func withXPCServiceConnected<T>(
        _ fn: @escaping (XPCServiceProtocol, AutoFinishContinuation<T>) -> Void
    ) async throws -> T {
        if let service, let connection = service.connection {
            do {
                return try await XPCShared.withXPCServiceConnected(connection: connection, fn)
            } catch {
                throw XPCExtensionServiceError.xpcServiceError(error)
            }
        } else {
            guard let endpoint = try await bridge.launchExtensionServiceIfNeeded()
            else { throw XPCExtensionServiceError.failedToGetServiceEndpoint }
            updateEndpoint(endpoint)

            if let service, let connection = service.connection {
                do {
                    return try await XPCShared.withXPCServiceConnected(connection: connection, fn)
                } catch {
                    throw XPCExtensionServiceError.xpcServiceError(error)
                }
            } else {
                throw XPCExtensionServiceError.failedToCreateXPCConnection
            }
        }
    }
    
    @XPCServiceActor
    private func withXPCServiceConnectedWithoutLaunching<T>(
        _ fn: @escaping (XPCServiceProtocol, AutoFinishContinuation<T>) -> Void
    ) async throws -> T {
        if let service, let connection = service.connection {
            do {
                return try await XPCShared.withXPCServiceConnected(connection: connection, fn)
            } catch {
                throw XPCExtensionServiceError.xpcServiceError(error)
            }
        }
        throw XPCExtensionServiceError.failedToCreateXPCConnection
    }

    @XPCServiceActor
    private func suggestionRequest(
        _ editorContent: EditorContent,
        _ fn: @escaping (any XPCServiceProtocol) -> (Data, @escaping (Data?, Error?) -> Void)
            -> Void
    ) async throws -> UpdatedContent? {
        let data = try JSONEncoder().encode(editorContent)
        return try await withXPCServiceConnected {
            service, continuation in
            fn(service)(data) { updatedData, error in
                if let error {
                    continuation.reject(error)
                    return
                }
                do {
                    if let updatedData {
                        let updatedContent = try JSONDecoder()
                            .decode(UpdatedContent.self, from: updatedData)
                        continuation.resume(updatedContent)
                    } else {
                        continuation.resume(nil)
                    }
                } catch {
                    continuation.reject(error)
                }
            }
        }
    }

    @XPCServiceActor
    public func getXcodeInspectorData() async throws -> XcodeInspectorData {
        return try await withXPCServiceConnected {
            service, continuation in
            service.getXcodeInspectorData { data, error in
                if let error {
                    continuation.reject(error)
                    return
                }
                
                guard let data else {
                    continuation.reject(NoDataError())
                    return
                }
                
                do {
                    let inspectorData = try JSONDecoder().decode(XcodeInspectorData.self, from: data)
                    continuation.resume(inspectorData)
                } catch {
                    continuation.reject(error)
                }
            }
        }
    }
    
    // MARK: MCP Server Tools

    @XPCServiceActor
    public func getAvailableMCPServerToolsCollections() async throws -> [MCPServerToolsCollection]? {
        return try await withXPCServiceConnected {
            service, continuation in
            service.getAvailableMCPServerToolsCollections { data in
                guard let data else {
                    continuation.resume(nil)
                    return
                }

                do {
                    let tools = try JSONDecoder().decode([MCPServerToolsCollection].self, from: data)
                    continuation.resume(tools)
                } catch {
                    continuation.reject(error)
                }
            }
        }
    }

    @XPCServiceActor
    public func updateMCPServerToolsStatus(
        _ update: [UpdateMCPToolsStatusServerCollection],
        chatAgentMode: ChatMode? = nil,
        customChatModeId: String? = nil,
        workspaceFolders: [WorkspaceFolder]? = nil
    ) async throws {
        return try await withXPCServiceConnected {
            service, continuation in
            do {
                let data = try JSONEncoder().encode(update)
                let foldersData = workspaceFolders.flatMap { try? JSONEncoder().encode($0) }
                let modeData = chatAgentMode.flatMap { try? JSONEncoder().encode($0) }
                let modeIdData = customChatModeId.flatMap { try? JSONEncoder().encode($0) }
                service.updateMCPServerToolsStatus(
                    tools: data,
                    chatAgentMode: modeData,
                    customChatModeId: modeIdData,
                    workspaceFolders: foldersData
                )
                continuation.resume(())
            } catch {
                continuation.reject(error)
            }
        }
    }
    
    // MARK: MCP Registry
    
    @XPCServiceActor
    public func listMCPRegistryServers(_ params: MCPRegistryListServersParams) async throws -> MCPRegistryServerList? {
        return try await withXPCServiceConnected {
            service, continuation in
            do {
                let params = try JSONEncoder().encode(params)
                service.listMCPRegistryServers(params) { data, error in
                    if let error {
                        continuation.reject(error)
                        return
                    }

                    guard let data else {
                        continuation.resume(nil)
                        return
                    }

                    do {
                        let response = try JSONDecoder().decode(MCPRegistryServerList.self, from: data)
                        continuation.resume(response)
                    } catch {
                        continuation.reject(error)
                    }
                }
            } catch {
                continuation.reject(error)
            }
        }
    }
    
    @XPCServiceActor
    public func getMCPRegistryServer(_ params: MCPRegistryGetServerParams) async throws -> MCPRegistryServerDetail? {
        return try await withXPCServiceConnected {
            service, continuation in
            do {
                let params = try JSONEncoder().encode(params)
                service.getMCPRegistryServer(params) { data, error in
                    if let error {
                        continuation.reject(error)
                        return
                    }

                    guard let data else {
                        continuation.resume(nil)
                        return
                    }

                    do {
                        let response = try JSONDecoder().decode(MCPRegistryServerDetail.self, from: data)
                        continuation.resume(response)
                    } catch {
                        continuation.reject(error)
                    }
                }
            } catch {
                continuation.reject(error)
            }
        }
    }
    
    @XPCServiceActor
    public func getMCPRegistryAllowlist() async throws -> GetMCPRegistryAllowlistResult? {
        return try await withXPCServiceConnected {
            service, continuation in
            service.getMCPRegistryAllowlist { data, error in
                if let error {
                    continuation.reject(error)
                    return
                }

                guard let data else {
                    continuation.resume(nil)
                    return
                }

                do {
                    let response = try JSONDecoder().decode(GetMCPRegistryAllowlistResult.self, from: data)
                    continuation.resume(response)
                } catch {
                    continuation.reject(error)
                }
            }
        }
    }
    
    @XPCServiceActor
    public func getAvailableLanguageModelTools() async throws -> [LanguageModelTool]? {
        return try await withXPCServiceConnected {
            service, continuation in
            service.getAvailableLanguageModelTools { data in
                guard let data else {
                    continuation.resume(nil)
                    return
                }

                do {
                    let tools = try JSONDecoder().decode([LanguageModelTool].self, from: data)
                    continuation.resume(tools)
                } catch {
                    continuation.reject(error)
                }
            }
        }
    }
    
    @XPCServiceActor
    public func refreshClientTools() async throws -> [LanguageModelTool]? {
        return try await withXPCServiceConnected {
            service, continuation in
            service.refreshClientTools { data in
                guard let data else {
                    continuation.resume(nil)
                    return
                }

                do {
                    let tools = try JSONDecoder().decode([LanguageModelTool].self, from: data)
                    continuation.resume(tools)
                } catch {
                    continuation.reject(error)
                }
            }
        }
    }
    
    @XPCServiceActor
    public func updateToolsStatus(
        _ update: [ToolStatusUpdate],
        chatAgentMode: ChatMode? = nil,
        customChatModeId: String? = nil,
        workspaceFolders: [WorkspaceFolder]? = nil
    ) async throws -> [LanguageModelTool]? {
        return try await withXPCServiceConnected {
            service, continuation in
            do {
                let data = try JSONEncoder().encode(update)
                let foldersData = workspaceFolders.flatMap { try? JSONEncoder().encode($0) }
                let modeData = chatAgentMode.flatMap { try? JSONEncoder().encode($0) }
                let modeIdData = customChatModeId.flatMap { try? JSONEncoder().encode($0) }
                service.updateToolsStatus(
                    tools: data,
                    chatAgentMode: modeData,
                    customChatModeId: modeIdData,
                    workspaceFolders: foldersData
                ) { data in
                    guard let data else {
                        continuation.resume(nil)
                        return
                    }

                    do {
                        let response = try JSONDecoder().decode([LanguageModelTool].self, from: data)
                        continuation.resume(response)
                    } catch {
                        continuation.reject(error)
                    }
                }
            } catch {
                continuation.reject(error)
            }
        }
    }
    
    @XPCServiceActor
    public func getCopilotFeatureFlags() async throws -> FeatureFlags? {
        return try await withXPCServiceConnected {
            service, continuation in
            service.getCopilotFeatureFlags { data in
                guard let data else {
                    continuation.resume(nil)
                    return
                }

                do {
                    let featureFlags = try JSONDecoder().decode(FeatureFlags.self, from: data)
                    continuation.resume(featureFlags)
                } catch {
                    continuation.reject(error)
                }
            }
        }
    }
    
    @XPCServiceActor
    public func getCopilotPolicy() async throws -> CopilotPolicy? {
        return try await withXPCServiceConnected {
            service, continuation in
            service.getCopilotPolicy { data in
                guard let data else {
                    continuation.resume(nil)
                    return
                }

                do {
                    let copilotPolicy = try JSONDecoder().decode(CopilotPolicy.self, from: data)
                    continuation.resume(copilotPolicy)
                } catch {
                    continuation.reject(error)
                }
            }
        }
    }
    
    @XPCServiceActor
    public func getModes(workspaceFolders: [WorkspaceFolder]? = nil) async throws -> [ConversationMode]? {
        return try await withXPCServiceConnected {
            service, continuation in
            let workspaceFoldersData = workspaceFolders.flatMap { try? JSONEncoder().encode($0) }
            service.getModes(workspaceFolders: workspaceFoldersData) { data, error in
                if let error {
                    continuation.reject(error)
                    return
                }

                guard let data else {
                    continuation.resume(nil)
                    return
                }

                do {
                    let modes = try JSONDecoder().decode([ConversationMode].self, from: data)
                    continuation.resume(modes)
                } catch {
                    continuation.reject(error)
                }
            }
        }
    }
    
    @XPCServiceActor
    public func signOutAllGitHubCopilotService() async throws {
        return try await withXPCServiceConnected {
            service, _ in service.signOutAllGitHubCopilotService()
        }
    }
    
    @XPCServiceActor
    public func getXPCServiceAuthStatus() async throws -> AuthStatus? {
        return try await withXPCServiceConnected {
            service, continuation in
            service.getXPCServiceAuthStatus { data in
                guard let data else {
                    continuation.resume(nil)
                    return
                }

                do {
                    let authStatus = try JSONDecoder().decode(AuthStatus.self, from: data)
                    continuation.resume(authStatus)
                } catch {
                    continuation.reject(error)
                }
            }
        }
    }
    
    @XPCServiceActor
    public func updateCopilotModels() async throws -> [CopilotModel]? {
        return try await withXPCServiceConnected {
            service, continuation in
            service.updateCopilotModels { data, error in
                if let error {
                    continuation.reject(error)
                    return
                }
                
                guard let data else {
                    continuation.resume(nil)
                    return
                }

                do {
                    let models = try JSONDecoder().decode([CopilotModel].self, from: data)
                    continuation.resume(models)
                } catch {
                    continuation.reject(error)
                }
            }
        }
    }
    
    // MARK: BYOK
    @XPCServiceActor
    public func saveBYOKApiKey(_ params: BYOKSaveApiKeyParams) async throws -> BYOKSaveApiKeyResponse? {
        return try await withXPCServiceConnected {
            service, continuation in
            do {
                let params = try JSONEncoder().encode(params)
                service.saveBYOKApiKey(params) { data in
                    guard let data else {
                        continuation.resume(nil)
                        return
                    }

                    do {
                        let response = try JSONDecoder().decode(BYOKSaveApiKeyResponse.self, from: data)
                        continuation.resume(response)
                    } catch {
                        continuation.reject(error)
                    }
                }
            } catch {
                continuation.reject(error)
            }
        }
    }
    
    @XPCServiceActor
    public func listBYOKApiKey(_ params: BYOKListApiKeysParams) async throws -> BYOKListApiKeysResponse? {
        return try await withXPCServiceConnected {
            service, continuation in
            do {
                let params = try JSONEncoder().encode(params)
                service.listBYOKApiKeys(params) { data in
                    guard let data else {
                        continuation.resume(nil)
                        return
                    }

                    do {
                        let response = try JSONDecoder().decode(BYOKListApiKeysResponse.self, from: data)
                        continuation.resume(response)
                    } catch {
                        continuation.reject(error)
                    }
                }
            } catch {
                continuation.reject(error)
            }
        }
    }
    
    @XPCServiceActor
    public func deleteBYOKApiKey(_ params: BYOKDeleteApiKeyParams) async throws -> BYOKDeleteApiKeyResponse? {
        return try await withXPCServiceConnected {
            service, continuation in
            do {
                let params = try JSONEncoder().encode(params)
                service.deleteBYOKApiKey(params) { data in
                    guard let data else {
                        continuation.resume(nil)
                        return
                    }

                    do {
                        let response = try JSONDecoder().decode(BYOKDeleteApiKeyResponse.self, from: data)
                        continuation.resume(response)
                    } catch {
                        continuation.reject(error)
                    }
                }
            } catch {
                continuation.reject(error)
            }
        }
    }
    
    @XPCServiceActor
    public func saveBYOKModel(_ params: BYOKSaveModelParams) async throws -> BYOKSaveModelResponse? {
        return try await withXPCServiceConnected {
            service, continuation in
            do {
                let params = try JSONEncoder().encode(params)
                service.saveBYOKModel(params) { data in
                    guard let data else {
                        continuation.resume(nil)
                        return
                    }

                    do {
                        let response = try JSONDecoder().decode(BYOKSaveModelResponse.self, from: data)
                        continuation.resume(response)
                    } catch {
                        continuation.reject(error)
                    }
                }
            } catch {
                continuation.reject(error)
            }
        }
    }
    
    @XPCServiceActor
    public func listBYOKModels(_ params: BYOKListModelsParams) async throws -> BYOKListModelsResponse? {
        return try await withXPCServiceConnected {
            service, continuation in
            do {
                let params = try JSONEncoder().encode(params)
                service.listBYOKModels(params) { data, error in
                    if let error {
                        continuation.reject(error)
                        return
                    }

                    guard let data else {
                        continuation.resume(nil)
                        return
                    }

                    do {
                        let response = try JSONDecoder().decode(BYOKListModelsResponse.self, from: data)
                        continuation.resume(response)
                    } catch {
                        continuation.reject(error)
                    }
                }
            } catch {
                continuation.reject(error)
            }
        }
    }
    
    @XPCServiceActor
    public func deleteBYOKModel(_ params: BYOKDeleteModelParams) async throws -> BYOKDeleteModelResponse? {
        return try await withXPCServiceConnected {
            service, continuation in
            do {
                let params = try JSONEncoder().encode(params)
                service.deleteBYOKModel(params) { data in
                    guard let data else {
                        continuation.resume(nil)
                        return
                    }

                    do {
                        let response = try JSONDecoder().decode(BYOKDeleteModelResponse.self, from: data)
                        continuation.resume(response)
                    } catch {
                        continuation.reject(error)
                    }
                }
            } catch {
                continuation.reject(error)
            }
        }
    }
}
