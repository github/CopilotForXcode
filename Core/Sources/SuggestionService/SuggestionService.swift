import BuiltinExtension
import struct CopilotForXcodeKit.WorkspaceInfo
import Foundation
import GitHubCopilotService
import Preferences
import SuggestionBasic
import SuggestionProvider
import UserDefaultsObserver
import Workspace

public protocol SuggestionServiceType: SuggestionServiceProvider {}

public actor SuggestionService: SuggestionServiceType {
    public var configuration: SuggestionProvider.SuggestionServiceConfiguration {
        get async { await suggestionProvider.configuration }
    }

    let middlewares: [SuggestionServiceMiddleware]

    let suggestionProvider: SuggestionServiceProvider

    public init(
        provider: any SuggestionServiceProvider,
        middlewares: [SuggestionServiceMiddleware] = SuggestionServiceMiddlewareContainer
            .middlewares
    ) {
        suggestionProvider = provider
        self.middlewares = middlewares
    }

    public static func service(
        for serviceType: SuggestionFeatureProvider = UserDefaults.shared
            .value(for: \.suggestionFeatureProvider)
    ) -> SuggestionService {
        switch serviceType {
        case .builtIn(.gitHubCopilot), .extension:
            let provider = BuiltinExtensionSuggestionServiceProvider(
                extension: GitHubCopilotExtension.self
            )
            return SuggestionService(provider: provider)
        }
    }
}

public extension SuggestionService {
    func getSuggestions(
        _ request: SuggestionRequest,
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async throws -> [SuggestionBasic.CodeSuggestion] {
        var getSuggestion = suggestionProvider.getSuggestions(_:workspaceInfo:)
        let configuration = await configuration

        for middleware in middlewares.reversed() {
            getSuggestion = { [getSuggestion] request, workspaceInfo in
                try await middleware.getSuggestion(
                    request,
                    configuration: configuration,
                    next: { [getSuggestion] request in
                        try await getSuggestion(request, workspaceInfo)
                    }
                )
            }
        }

        return try await getSuggestion(request, workspaceInfo)
    }
    
    func getNESSuggestions(
        _ request: SuggestionRequest,
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo,
    ) async throws -> [SuggestionBasic.CodeSuggestion] {
        var getNESSuggestion = suggestionProvider.getNESSuggestions(_:workspaceInfo:)
        let configuration = await configuration
        
        for middleware in middlewares.reversed() {
            getNESSuggestion = { [getNESSuggestion] request, workspaceInfo in
                try await middleware.getNESSuggestion(
                    request,
                    configuration: configuration,
                    next: { [getNESSuggestion] request in
                        try await getNESSuggestion(request, workspaceInfo)
                    }
                )
            }
        }
        
        return try await getNESSuggestion(request, workspaceInfo)
    }

    func notifyAccepted(
        _ suggestion: SuggestionBasic.CodeSuggestion,
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async {
        await suggestionProvider.notifyAccepted(suggestion, workspaceInfo: workspaceInfo)
    }

    func notifyRejected(
        _ suggestions: [SuggestionBasic.CodeSuggestion],
        workspaceInfo: CopilotForXcodeKit.WorkspaceInfo
    ) async {
        await suggestionProvider.notifyRejected(suggestions, workspaceInfo: workspaceInfo)
    }
    
    func cancelRequest(workspaceInfo: CopilotForXcodeKit.WorkspaceInfo) async {
        await suggestionProvider.cancelRequest(workspaceInfo: workspaceInfo)
    }
}

