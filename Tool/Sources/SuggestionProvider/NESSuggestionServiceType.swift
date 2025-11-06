import CopilotForXcodeKit

public protocol NESSuggestionServiceType {
    func getNESSuggestions(
        _ request: CopilotForXcodeKit.SuggestionRequest,
        workspace: CopilotForXcodeKit.WorkspaceInfo
    ) async throws -> [CopilotForXcodeKit.CodeSuggestion]
}

