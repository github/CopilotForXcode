import ConversationServiceProvider
import CopilotForXcodeKit
import Foundation
import Logger
import XcodeInspector
import Workspace

public final class BuiltinExtensionConversationServiceProvider<
    T: BuiltinExtension
>: ConversationServiceProvider {
    public func notifyChangeTextDocument(fileURL: URL, content: String, version: Int, workspaceURL: URL?) async throws {
        guard let conversationService else {
            Logger.service.error("Builtin chat service not found.")
            return
        }

        guard let workspaceInfo = await activeWorkspace(workspaceURL) else {
            Logger.service.error("Could not get active workspace info")
            return
        }
        
        try? await conversationService.notifyChangeTextDocument(fileURL: fileURL, content: content, version: version, workspace: workspaceInfo)
    }
    
    
    private let extensionManager: BuiltinExtensionManager

    public init(
        extension: T.Type,
        extensionManager: BuiltinExtensionManager = .shared
    ) {
        self.extensionManager = extensionManager
    }

    var conversationService: ConversationServiceType? {
        extensionManager.extensions.first { $0 is T }?.conversationService
    }
    
    private func activeWorkspace(_ workspaceURL: URL? = nil) async -> WorkspaceInfo? {
        if let workspaceURL = workspaceURL {
            if let workspaceBinding = WorkspaceFile.getWorkspaceInfo(workspaceURL: workspaceURL) {
                return workspaceBinding
            }
        }

        guard let workspaceURL = await XcodeInspector.shared.safe.realtimeActiveWorkspaceURL,
              let projectURL = await XcodeInspector.shared.safe.realtimeActiveProjectURL
        else { return nil }
        
        return WorkspaceInfo(workspaceURL: workspaceURL, projectURL: projectURL)
    }
    
    struct BuiltinExtensionChatServiceNotFoundError: Error, LocalizedError {
        var errorDescription: String? {
            "Builtin chat service not found."
        }
    }

    public func createConversation(
        _ request: ConversationRequest, workspaceURL: URL?
    ) async throws -> ConversationCreateResponse? {
        guard let conversationService else {
            Logger.service.error("Builtin chat service not found.")
            return nil
        }
        guard let workspaceInfo = await activeWorkspace(workspaceURL) else {
            Logger.service.error("Could not get active workspace info")
            return nil
        }
        
        return try await conversationService.createConversation(request, workspace: workspaceInfo)
    }

    public func createTurn(
        with conversationId: String, request: ConversationRequest, workspaceURL: URL?
    ) async throws -> ConversationCreateResponse? {
        guard let conversationService else {
            Logger.service.error("Builtin chat service not found.")
            return nil
        }
        guard let workspaceInfo = await activeWorkspace(workspaceURL) else {
            Logger.service.error("Could not get active workspace info")
            return nil
        }
        
        return try await conversationService
            .createTurn(
                with: conversationId,
                request: request,
                workspace: workspaceInfo
            )
    }
    
    public func deleteTurn(with conversationId: String, turnId: String, workspaceURL: URL?) async throws {
        guard let conversationService else {
            Logger.service.error("Builtin chat service not found.")
            return
        }
        guard let workspaceInfo = await activeWorkspace(workspaceURL) else {
            Logger.service.error("Could not get active workspace info")
            return
        }
        
        try await conversationService.deleteTurn(with: conversationId, turnId: turnId, workspace: workspaceInfo)
    }

    public func stopReceivingMessage(_ workDoneToken: String, workspaceURL: URL?) async throws {
        guard let conversationService else {
            Logger.service.error("Builtin chat service not found.")
            return
        }
        guard let workspaceInfo = await activeWorkspace(workspaceURL) else {
            Logger.service.error("Could not get active workspace info")
            return
        }
        
        try await conversationService.cancelProgress(workDoneToken, workspace: workspaceInfo)
    }
    
    public func rateConversation(turnId: String, rating: ConversationRating, workspaceURL: URL?) async throws {
        guard let conversationService else {
            Logger.service.error("Builtin chat service not found.")
            return
        }
        guard let workspaceInfo = await activeWorkspace(workspaceURL) else {
            Logger.service.error("Could not get active workspace info")
            return
        }
        try? await conversationService.rateConversation(turnId: turnId, rating: rating, workspace: workspaceInfo)
    }
    
    public func copyCode(_ request: CopyCodeRequest, workspaceURL: URL?) async throws {
        guard let conversationService else {
            Logger.service.error("Builtin chat service not found.")
            return
        }
        guard let workspaceInfo = await activeWorkspace(workspaceURL) else {
            Logger.service.error("Could not get active workspace info")
            return
        }
        try? await conversationService.copyCode(request: request, workspace: workspaceInfo)
    }

    public func templates() async throws -> [ChatTemplate]? {
        guard let conversationService else {
            Logger.service.error("Builtin chat service not found.")
            return nil
        }
        guard let workspaceInfo = await activeWorkspace() else {
            Logger.service.error("Could not get active workspace info")
            return nil
        }

        return (try? await conversationService.templates(workspace: workspaceInfo))
    }
    
    public func modes() async throws -> [ConversationMode]? {
        guard let conversationService else {
            Logger.service.error("Builtin chat service not found.")
            return nil
        }
        guard let workspaceInfo = await activeWorkspace() else {
            Logger.service.error("Could not get active workspace info")
            return nil
        }

        return (try? await conversationService.modes(workspace: workspaceInfo))
    }

    public func models() async throws -> [CopilotModel]? {
        guard let conversationService else {
            Logger.service.error("Builtin chat service not found.")
            return nil
        }
        guard let workspaceInfo = await activeWorkspace() else {
            Logger.service.error("Could not get active workspace info")
            return nil
        }

        return (try? await conversationService.models(workspace: workspaceInfo))
    }
    
    public func notifyDidChangeWatchedFiles(_ event: DidChangeWatchedFilesEvent, workspace: WorkspaceInfo) async throws {
        guard let conversationService else {
            Logger.service.error("Builtin chat service not found.")
            return
        }
        
        try? await conversationService.notifyDidChangeWatchedFiles(event, workspace: workspace)
    }
        
    public func agents() async throws -> [ChatAgent]? {
        guard let conversationService else {
            Logger.service.error("Builtin chat service not found.")
            return nil
        }
        guard let workspaceInfo = await activeWorkspace() else {
            Logger.service.error("Could not get active workspace info")
            return nil
        }
        
        return (try? await conversationService.agents(workspace: workspaceInfo))
    }
    
    public func reviewChanges(_ changes: [ReviewChangesParams.Change]) async throws -> CodeReviewResult? {
        guard let conversationService else {
            Logger.service.error("Builtin chat service not found.")
            return nil
        }
        guard let workspaceInfo = await activeWorkspace() else {
            Logger.service.error("Could not get active workspace info")
            return nil
        }
        
        return (try? await conversationService.reviewChanges(workspace: workspaceInfo, changes: changes))
    }
}
