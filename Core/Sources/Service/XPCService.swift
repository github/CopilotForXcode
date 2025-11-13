import AppKit
import Foundation
import GitHubCopilotService
import LanguageServerProtocol
import Logger
import Preferences
import Status
import XPCShared
import HostAppActivator
import XcodeInspector
import GitHubCopilotViewModel
import Workspace
import ConversationServiceProvider

public class XPCService: NSObject, XPCServiceProtocol {
    // MARK: - Service

    public func getXPCServiceVersion(withReply reply: @escaping (String, String) -> Void) {
        reply(
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A",
            Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
        )
    }
    
    public func getXPCCLSVersion(withReply reply: @escaping (String?) -> Void) {
        Task { @MainActor in
            do {
                let service = try GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
                let version = try await service.version()
                reply(version)
            } catch {
                Logger.service.error("Failed to get CLS version: \(error.localizedDescription)")
                reply(nil)
            }
        }
    }

    public func getXPCServiceAccessibilityPermission(withReply reply: @escaping (ObservedAXStatus) -> Void) {
        Task {
            reply(await Status.shared.getAXStatus())
        }
    }
    
    public func getXPCServiceExtensionPermission(
        withReply reply: @escaping (ExtensionPermissionStatus) -> Void
    ) {
        Task {
            reply(await Status.shared.getExtensionStatus())
        }
    }

    // MARK: - Suggestion

    @discardableResult
    private func replyWithUpdatedContent(
        editorContent: Data,
        file: StaticString = #file,
        line: UInt = #line,
        isRealtimeSuggestionRelatedCommand: Bool = false,
        withReply reply: @escaping (Data?, Error?) -> Void,
        getUpdatedContent: @escaping @ServiceActor (
            SuggestionCommandHandler,
            EditorContent
        ) async throws -> UpdatedContent?
    ) -> Task<Void, Never> {
        let task = Task {
            do {
                let editor = try JSONDecoder().decode(EditorContent.self, from: editorContent)
                let handler: SuggestionCommandHandler = WindowBaseCommandHandler()
                try Task.checkCancellation()
                guard let updatedContent = try await getUpdatedContent(handler, editor) else {
                    reply(nil, nil)
                    return
                }
                try Task.checkCancellation()
                try reply(JSONEncoder().encode(updatedContent), nil)
            } catch {
                Logger.service.error("\(file):\(line) \(error.localizedDescription)")
                reply(nil, NSError.from(error))
            }
        }

        Task {
            await Service.shared.realtimeSuggestionController.cancelInFlightTasks(excluding: task)
        }
        return task
    }

    public func getSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.presentSuggestions(editor: editor)
        }
    }

    public func getNextSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.presentNextSuggestion(editor: editor)
        }
    }

    public func getPreviousSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.presentPreviousSuggestion(editor: editor)
        }
    }

    public func getSuggestionRejectedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.rejectSuggestion(editor: editor)
        }
    }
    
    public func getNESSuggestionRejectedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.rejectNESSuggestion(editor: editor)
        }
    }

    public func getSuggestionAcceptedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.acceptSuggestion(editor: editor)
        }
    }
    
    public func getNESSuggestionAcceptedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.acceptNESSuggestion(editor: editor)
        }
    }

    public func getPromptToCodeAcceptedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.acceptPromptToCode(editor: editor)
        }
    }

    public func getRealtimeSuggestedCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(
            editorContent: editorContent,
            isRealtimeSuggestionRelatedCommand: true,
            withReply: reply
        ) { handler, editor in
            try await handler.presentRealtimeSuggestions(editor: editor)
        }
    }

    public func prefetchRealtimeSuggestions(
        editorContent: Data,
        withReply reply: @escaping () -> Void
    ) {
        // We don't need to wait for this.
        reply()

        replyWithUpdatedContent(
            editorContent: editorContent,
            isRealtimeSuggestionRelatedCommand: true,
            withReply: { _, _ in }
        ) { handler, editor in
            try await handler.generateRealtimeSuggestions(editor: editor)
        }
    }

    public func openChat(
        withReply reply: @escaping (Error?) -> Void
    ) {
        Task {
            do {
                // Check if app is already running
                if let _ = getRunningHostApp() {
                    // App is already running, use the chat service
                    let handler = PseudoCommandHandler()
                    handler.openChat(forceDetach: true)
                } else {
                    try launchHostAppDefault()
                }
                reply(nil)
            } catch {
                reply(error)
            }
        }
    }

    public func promptToCode(
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.promptToCode(editor: editor)
        }
    }

    public func customCommand(
        id: String,
        editorContent: Data,
        withReply reply: @escaping (Data?, Error?) -> Void
    ) {
        replyWithUpdatedContent(editorContent: editorContent, withReply: reply) { handler, editor in
            try await handler.customCommand(id: id, editor: editor)
        }
    }

    // MARK: - Settings

    public func toggleRealtimeSuggestion(withReply reply: @escaping (Error?) -> Void) {
        guard AXIsProcessTrusted() else {
            reply(NoAccessToAccessibilityAPIError())
            return
        }
        Task { @ServiceActor in
            await Service.shared.realtimeSuggestionController.cancelInFlightTasks()
            let on = !UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
            UserDefaults.shared.set(on, for: \.realtimeSuggestionToggle)
            Task { @MainActor in
                Service.shared.guiController.store
                    .send(.suggestionWidget(.toastPanel(.toast(.toast(
                        "Real-time suggestion is turned \(on ? "on" : "off")",
                        .info,
                        nil
                    )))))
            }
            reply(nil)
        }
    }
    
    public func toggleRealtimeNES(withReply reply: @escaping (Error?) -> Void) {
        guard AXIsProcessTrusted() else {
            reply(NoAccessToAccessibilityAPIError())
            return
        }
        Task { @ServiceActor in
            await Service.shared.realtimeSuggestionController.cancelInFlightTasks()
            let on = !UserDefaults.shared.value(for: \.realtimeNESToggle)
            UserDefaults.shared.set(on, for: \.realtimeNESToggle)
            Task { @MainActor in
                Service.shared.guiController.store
                    .send(.suggestionWidget(.toastPanel(.toast(.toast(
                        "Next Edit Suggestions (NES) is turned \(on ? "on" : "off")",
                        .info,
                        nil
                    )))))
                Service.shared.guiController.store
                    .send(.suggestionWidget(.panel(.onRealtimeNESToggleChanged(on))))
            }
            reply(nil)
        }
    }

    public func postNotification(name: String, withReply reply: @escaping () -> Void) {
        reply()
        NotificationCenter.default.post(name: .init(name), object: nil)
    }

    public func quit(reply: @escaping () -> Void) {
        Task {
            await Service.shared.prepareForExit()
            reply()
        }
    }

    // MARK: - Requests

    public func send(
        endpoint: String,
        requestBody: Data,
        reply: @escaping (Data?, Error?) -> Void
    ) {
        Service.shared.handleXPCServiceRequests(
            endpoint: endpoint,
            requestBody: requestBody,
            reply: reply
        )
    }

    // MARK: - XcodeInspector

    public func getXcodeInspectorData(withReply reply: @escaping (Data?, Error?) -> Void) {
        do {
            // Capture current XcodeInspector data
            let inspectorData = XcodeInspectorData(
                activeWorkspaceURL: XcodeInspector.shared.activeWorkspaceURL?.absoluteString,
                activeProjectRootURL: XcodeInspector.shared.activeProjectRootURL?.absoluteString,
                realtimeActiveWorkspaceURL: XcodeInspector.shared.realtimeActiveWorkspaceURL?.absoluteString,
                realtimeActiveProjectURL: XcodeInspector.shared.realtimeActiveProjectURL?.absoluteString,
                latestNonRootWorkspaceURL: XcodeInspector.shared.latestNonRootWorkspaceURL?.absoluteString
            )
            
            // Encode and send the data
            let data = try JSONEncoder().encode(inspectorData)
            reply(data, nil)
        } catch {
            Logger.service.error("Failed to encode XcodeInspector data: \(error.localizedDescription)")
            reply(nil, error)
        }
    }
    
    // MARK: - MCP Server Tools
    public func getAvailableMCPServerToolsCollections(withReply reply: @escaping (Data?) -> Void) {
        let availableMCPServerTools = CopilotMCPToolManager.getAvailableMCPServerToolsCollections()
        if let availableMCPServerTools = availableMCPServerTools {
            // Encode and send the data
            let data = try? JSONEncoder().encode(availableMCPServerTools)
            reply(data)
        } else {
            reply(nil)
        }
    }

    public func updateMCPServerToolsStatus(
        tools: Data,
        chatAgentMode: Data?,
        customChatModeId: Data?,
        workspaceFolders: Data?
    ) {
        // Decode the data
        let decoder = JSONDecoder()
        var collections: [UpdateMCPToolsStatusServerCollection] = []
        var folders: [WorkspaceFolder]? = nil
        var mode: ChatMode? = nil
        var modeId: String? = nil
        do {
            collections = try decoder.decode([UpdateMCPToolsStatusServerCollection].self, from: tools)
            if let workspaceFolders = workspaceFolders {
                folders = try? decoder.decode([WorkspaceFolder].self, from: workspaceFolders)
            }
            if let chatAgentMode = chatAgentMode {
                mode = try? decoder.decode(ChatMode.self, from: chatAgentMode)
            }
            if let customChatModeId = customChatModeId {
                modeId = try? decoder.decode(String.self, from: customChatModeId)
            }
            if collections.isEmpty {
                return
            }
        } catch {
            Logger.service.error("Failed to decode MCP server collections or workspace folders: \(error)")
            return
        }

        Task { @MainActor in
            // Only use auth service when ALL three parameters are provided.
            if mode != nil, modeId != nil, folders != nil {
                do {
                    if let uri = folders!.first?.uri, let projectRootURL = URL(string: uri) {
                        if let service = GitHubCopilotService.getProjectGithubCopilotService(
                            for: projectRootURL
                        ) {
                            let params = UpdateMCPToolsStatusParams(
                                chatModeKind: mode,
                                customChatModeId: modeId,
                                workspaceFolders: folders,
                                servers: collections
                            )
                            try await service.updateMCPToolsStatus(params: params)
                        }
                    }
                } catch {
                    Logger.service.error("Failed to update MCP tool status via auth service: \(error)")
                }
            } else {
                // Fallback to legacy/global update when context not fully provided.
                await GitHubCopilotService.updateAllClsMCP(collections: collections)
            }
        }
    }
    
    // MARK: - MCP Registry
    
    public func listMCPRegistryServers(_ params: Data, withReply reply: @escaping (Data?, Error?) -> Void) {
        let decoder = JSONDecoder()
        var listMCPRegistryServersParams: MCPRegistryListServersParams?
        do {
            listMCPRegistryServersParams = try decoder.decode(MCPRegistryListServersParams.self, from: params)
        } catch {
            Logger.service.error("Failed to decode MCP Registry list servers parameters: \(error)")
            return
        }
        
        Task { @MainActor in
            do {
                let service = try GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
                let response = try await service.listMCPRegistryServers(listMCPRegistryServersParams!)
                let data = try? JSONEncoder().encode(response)
                reply(data, nil)
            } catch {
                Logger.service.error("Failed to list MCP Registry servers: \(error)")
                reply(nil, NSError.from(error))
            }
        }
    }
    
    public func getMCPRegistryServer(_ params: Data, withReply reply: @escaping (Data?, Error?) -> Void) {
        let decoder = JSONDecoder()
        var getMCPRegistryServerParams: MCPRegistryGetServerParams?
        do {
            getMCPRegistryServerParams = try decoder.decode(MCPRegistryGetServerParams.self, from: params)
        } catch {
            Logger.service.error("Failed to decode MCP Registry get server parameters: \(error)")
            return
        }
        
        Task { @MainActor in
            do {
                let service = try GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
                let response = try await service.getMCPRegistryServer(getMCPRegistryServerParams!)
                let data = try? JSONEncoder().encode(response)
                reply(data, nil)
            } catch {
                Logger.service.error("Failed to get MCP Registry servers: \(error)")
                reply(nil, NSError.from(error))
            }
        }
    }
    
    public func getMCPRegistryAllowlist(withReply reply: @escaping (Data?, Error?) -> Void) {
        Task { @MainActor in
            do {
                let service = try GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
                let response = try await service.getMCPRegistryAllowlist()
                let data = try? JSONEncoder().encode(response)
                reply(data, nil)
            } catch {
                Logger.service.error("Failed to get MCP Registry allowlist: \(error)")
                reply(nil, NSError.from(error))
            }
        }
    }

    // MARK: - Language Model Tools
    public func getAvailableLanguageModelTools(withReply reply: @escaping (Data?) -> Void) {
        let availableLanguageModelTools = CopilotLanguageModelToolManager.getAvailableLanguageModelTools()
        if let availableLanguageModelTools = availableLanguageModelTools {
            // Encode and send the data
            let data = try? JSONEncoder().encode(availableLanguageModelTools)
            reply(data)
        } else {
            reply(nil)
        }
    }
    
    public func refreshClientTools(withReply reply: @escaping (Data?) -> Void) {
        Task { @MainActor in
            await GitHubCopilotService.refreshClientTools()
            let availableLanguageModelTools = CopilotLanguageModelToolManager.getAvailableLanguageModelTools()
            if let availableLanguageModelTools = availableLanguageModelTools {
                let data = try? JSONEncoder().encode(availableLanguageModelTools)
                reply(data)
            } else {
                reply(nil)
            }
        }
    }
    
    public func updateToolsStatus(
        tools: Data,
        chatAgentMode: Data?,
        customChatModeId: Data?,
        workspaceFolders: Data?,
        withReply reply: @escaping (Data?) -> Void
    ) {
        // Decode the data
        let decoder = JSONDecoder()
        var toolStatusUpdates: [ToolStatusUpdate] = []
        var folders: [WorkspaceFolder]? = nil
        var mode: ChatMode? = nil
        var modeId: String? = nil
        do {
            toolStatusUpdates = try decoder.decode([ToolStatusUpdate].self, from: tools)
            if let workspaceFolders = workspaceFolders {
                folders = try? decoder.decode([WorkspaceFolder].self, from: workspaceFolders)
            }
            if let chatAgentMode = chatAgentMode {
                mode = try? decoder.decode(ChatMode.self, from: chatAgentMode)
            }
            if let customChatModeId = customChatModeId {
                modeId = try? decoder.decode(String.self, from: customChatModeId)
            }
            if toolStatusUpdates.isEmpty {
                let emptyData = try JSONEncoder().encode([LanguageModelTool]())
                reply(emptyData)
                return
            }
        } catch {
            Logger.service.error("Failed to decode built-in tools or workspace folders: \(error)")
            reply(nil)
            return
        }

        Task { @MainActor in
            var updatedTools: [LanguageModelTool] = []
            if mode != nil, modeId != nil, folders != nil {
                // Use auth service path when all three context parameters are present.
                do {
                    if let uri = folders!.first?.uri, let projectRootURL = URL(string: uri) {
                        if let service = GitHubCopilotService.getProjectGithubCopilotService(
                            for: projectRootURL
                        ) {
                            updatedTools = try await service.updateToolsStatus(
                                params: .init(
                                    chatmodeKind: mode,
                                    customChatModeId: modeId,
                                    workspaceFolders: folders,
                                    tools: toolStatusUpdates
                                )
                            )
                        }
                    }
                } catch {
                    Logger.service.error("Failed contextual tools update: \(error)")
                    updatedTools = await GitHubCopilotService.updateAllCLSTools(tools: toolStatusUpdates)
                }
            } else {
                // Fallback without contextual parameters.
                updatedTools = await GitHubCopilotService.updateAllCLSTools(tools: toolStatusUpdates)
            }
            // Encode and return the updated tools
            do {
                let data = try JSONEncoder().encode(updatedTools)
                reply(data)
            } catch {
                Logger.service.error("Failed to encode updated tools: \(error)")
                reply(nil)
            }
        }
    }
    
    // MARK: - FeatureFlags
    public func getCopilotFeatureFlags(
        withReply reply: @escaping (Data?) -> Void
    ) {
        let featureFlags = FeatureFlagNotifierImpl.shared.featureFlags
        let data = try? JSONEncoder().encode(featureFlags)
        reply(data)
    }
    
    public func getCopilotPolicy(
        withReply reply: @escaping (Data?) -> Void
    ) {
        let copilotPolicy = CopilotPolicyNotifierImpl.shared.copilotPolicy
        let data = try? JSONEncoder().encode(copilotPolicy)
        reply(data)
    }
    
    public func getModes(workspaceFolders: Data?, withReply reply: @escaping (Data?, Error?) -> Void) {
        Task { @MainActor in
            do {
                let service = try GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
                var folders: [WorkspaceFolder]? = nil
                if let workspaceFolders = workspaceFolders {
                    folders = try JSONDecoder().decode([WorkspaceFolder].self, from: workspaceFolders)
                }
                
                let modes = try await service.modes(workspaceFolders: folders)
                let data = try JSONEncoder().encode(modes)
                reply(data, nil)
            } catch {
                Logger.service.error("Failed to get modes: \(error.localizedDescription)")
                reply(nil, NSError.from(error))
            }
        }
    }
    
    // MARK: - Auth
    public func signOutAllGitHubCopilotService() {
        Task { @MainActor in
            do {
                try await GitHubCopilotService.signOutAll()
            } catch {
                Logger.service.error("Failed to sign out all: \(error)")
            }
        }
    }
    
    public func getXPCServiceAuthStatus(withReply reply: @escaping (Data?) -> Void) {
        Task { @MainActor in
            let service = try GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
            _ = try await service.checkStatus()
            let authStatus = await Status.shared.getAuthStatus()
            let data = try? JSONEncoder().encode(authStatus)
            reply(data)
        }
    }
    
    public func updateCopilotModels(withReply reply: @escaping (Data?, Error?) -> Void) {
        Task { @MainActor in
            do {
                let service = try GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
                let models = try await service.models()
                CopilotModelManager.updateLLMs(models)
                let data = try JSONEncoder().encode(models)
                reply(data, nil)
            } catch {
                Logger.service.error("Failed to get models: \(error.localizedDescription)")
                reply(nil, NSError.from(error))
            }
        }
    }
    
    // MARK: - BYOK
    public func saveBYOKApiKey(_ params: Data, withReply reply: @escaping (Data?) -> Void) {
        let decoder = JSONDecoder()
        var saveApiKeyParams: BYOKSaveApiKeyParams? = nil
        do {
            saveApiKeyParams = try decoder.decode(BYOKSaveApiKeyParams.self, from: params)
            if saveApiKeyParams == nil {
                return
            }
        } catch {
            Logger.service.error("Failed to save BYOK API Key: \(error)")
            return
        }
        
        Task { @MainActor in
            let service = try GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
            let response = try await service.saveBYOKApiKey(saveApiKeyParams!)
            let data = try? JSONEncoder().encode(response)
            reply(data)
        }
    }
    
    public func listBYOKApiKeys(_ params: Data, withReply reply: @escaping (Data?) -> Void) {
        let decoder = JSONDecoder()
        var listApiKeysParams: BYOKListApiKeysParams? = nil
        do {
            listApiKeysParams = try decoder.decode(BYOKListApiKeysParams.self, from: params)
            if listApiKeysParams == nil {
                return
            }
        } catch {
            Logger.service.error("Failed to list BYOK API keys: \(error)")
            return
        }
        
        Task { @MainActor in
            let service = try GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
            let response = try await service.listBYOKApiKeys(listApiKeysParams!)
            if !response.apiKeys.isEmpty {
                BYOKModelManager.updateApiKeys(apiKeys: response.apiKeys)
            }
            let data = try? JSONEncoder().encode(response)
            reply(data)
        }
    }
    
    public func deleteBYOKApiKey(_ params: Data, withReply reply: @escaping (Data?) -> Void) {
        let decoder = JSONDecoder()
        var deleteApiKeyParams: BYOKDeleteApiKeyParams? = nil
        do {
            deleteApiKeyParams = try decoder.decode(BYOKDeleteApiKeyParams.self, from: params)
            if deleteApiKeyParams == nil {
                return
            }
        } catch {
            Logger.service.error("Failed to delete BYOK API Key: \(error)")
            return
        }
        
        Task { @MainActor in
            let service = try GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
            let response = try await service.deleteBYOKApiKey(deleteApiKeyParams!)
            let data = try? JSONEncoder().encode(response)
            reply(data)
        }
    }
    
    public func saveBYOKModel(_ params: Data, withReply reply: @escaping (Data?) -> Void) {
        let decoder = JSONDecoder()
        var saveModelParams: BYOKSaveModelParams? = nil
        do {
            saveModelParams = try decoder.decode(BYOKSaveModelParams.self, from: params)
            if saveModelParams == nil {
                return
            }
        } catch {
            Logger.service.error("Failed to save BYOK model: \(error)")
            return
        }
        
        Task { @MainActor in
            let service = try GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
            let response = try await service.saveBYOKModel(saveModelParams!)
            let data = try? JSONEncoder().encode(response)
            reply(data)
        }
    }
    
    public func listBYOKModels(_ params: Data, withReply reply: @escaping (Data?, Error?) -> Void) {
        let decoder = JSONDecoder()
        var listModelsParams: BYOKListModelsParams? = nil
        do {
            listModelsParams = try decoder.decode(BYOKListModelsParams.self, from: params)
            if listModelsParams == nil {
                return
            }
        } catch {
            Logger.service.error("Failed to list BYOK models: \(error)")
            return
        }
        
        Task { @MainActor in
            do {
                let service = try GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
                let response = try await service.listBYOKModels(listModelsParams!)
                if !response.models.isEmpty && listModelsParams?.enableFetchUrl == true {
                    for model in response.models {
                        _ = try await service.saveBYOKModel(model)
                    }
                }
                let fullModelResponse = try await service.listBYOKModels(BYOKListModelsParams())
                BYOKModelManager.updateBYOKModels(BYOKModels: fullModelResponse.models)
                let data = try? JSONEncoder().encode(response)
                reply(data, nil)
            } catch {
                Logger.service.error("Failed to list BYOK models: \(error)")
                reply(nil, NSError.from(error))
            }
        }
    }
    
    public func deleteBYOKModel(_ params: Data, withReply reply: @escaping (Data?) -> Void) {
        let decoder = JSONDecoder()
        var deleteModelParams: BYOKDeleteModelParams? = nil
        do {
            deleteModelParams = try decoder.decode(BYOKDeleteModelParams.self, from: params)
            if deleteModelParams == nil {
                return
            }
        } catch {
            Logger.service.error("Failed to delete BYOK model: \(error)")
            return
        }
        
        Task { @MainActor in
            let service = try GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
            let response = try await service.deleteBYOKModel(deleteModelParams!)
            let data = try? JSONEncoder().encode(response)
            reply(data)
        }
    }
}

struct NoAccessToAccessibilityAPIError: Error, LocalizedError {
    var errorDescription: String? {
        "Accessibility API permission is not granted. Please enable in System Settings.app."
    }

    init() {}
}
