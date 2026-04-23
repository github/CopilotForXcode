import Foundation

public enum PromptType: String, CaseIterable, Equatable {
    case instructions = "instructions"
    case prompt = "prompt"
    case agent = "agent"
    
    /// The directory name under .github where files of this type are stored
    public var directoryName: String {
        switch self {
        case .instructions:
            return "instructions"
        case .prompt:
            return "prompts"
        case .agent:
            return "agents"
        }
    }
    
    /// The file extension for this prompt type
    public var fileExtension: String {
        switch self {
        case .instructions:
            return ".instructions.md"
        case .prompt:
            return ".prompt.md"
        case .agent:
            return ".agent.md"
        }
    }
    
    /// Human-readable name for display purposes
    public var displayName: String {
        switch self {
        case .instructions:
            return "Instruction File"
        case .prompt:
            return "Prompt File"
        case .agent:
            return "Agent File"
        }
    }
    
    /// Human-readable name for settings
    public var settingTitle: String {
        switch self {
        case .instructions:
            return "Custom Instructions"
        case .prompt:
            return "Prompt Files"
        case .agent:
            return "Agent Files"
        }
    }
    
    /// Description for the prompt type
    public var description: String {
        switch self {
        case .instructions:
            return "Configure `.github/instructions/*.instructions.md` files scoped to specific file patterns or tasks."
        case .prompt:
            return "Configure `.github/prompts/*.prompt.md` files for reusable prompts. Trigger with '/' commands in the Chat view."
        case .agent:
            return "Configure `.github/agents/*.agent.md` files for autonomous agent tasks. Agents can perform multi-step operations."
        }
    }
    
    /// Default template content for new files
    public var defaultTemplate: String {
        switch self {
        case .instructions:
            return """
            ---
            applyTo: '**'
            ---
            Provide project context and coding guidelines that AI should follow when generating code, or answering questions.

            """
        case .prompt:
            return """
            ---
            description: Prompt Description
            ---
            Define the task to achieve, including specific requirements, constraints, and success criteria.

            """
        case .agent:
            return """
            ---
            description: 'Describe what this custom agent does and when to use it.'
            tools: []
            ---
            Define what this custom agent accomplishes for the user, when to use it, and the edges it won't cross. Specify its ideal inputs/outputs, the tools it may call, and how it reports progress or asks for help.

            """
        }
    }
    
    /// Get the help link for this prompt type. Requires the editor plugin version string.
    public func helpLink(editorPluginVersion: String) -> String {
        let version = editorPluginVersion == "0.0.0" ? "main" : editorPluginVersion
        
        switch self {
        case .instructions:
            return "https://github.com/github/CopilotForXcode/blob/\(version)/Docs/CustomInstructions.md"
        case .prompt:
            return "https://github.com/github/CopilotForXcode/blob/\(version)/Docs/PromptFiles.md"
        case .agent:
            return "https://github.com/github/CopilotForXcode/blob/\(version)/Docs/AgentFiles.md"
        }
    }
    
    /// Get the full file path for a given name and project URL
    public func getFilePath(fileName: String, projectURL: URL) -> URL {
        let directory = getDirectoryPath(projectURL: projectURL)
        return directory.appendingPathComponent("\(fileName)\(fileExtension)")
    }
    
    /// Get the directory path for this prompt type
    public func getDirectoryPath(projectURL: URL) -> URL {
        return projectURL.appendingPathComponent(".github/\(directoryName)")
    }
}
