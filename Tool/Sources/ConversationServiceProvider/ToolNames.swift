
public enum ToolName: String, Codable {
    case runInTerminal = "run_in_terminal"
    case getTerminalOutput = "get_terminal_output"
    case getErrors = "get_errors"
    case insertEditIntoFile = "insert_edit_into_file"
    case createFile = "create_file"
    case fetchWebPage = "fetch_webpage"
}

public enum ServerToolName: String, Codable {
    case readFile = "read_file"
    case findFiles = "file_search"
    case findTextInFiles = "grep_search"
    case listDir = "list_dir"
    case replaceString = "replace_string_in_file"
    case codebase = "semantic_search"
}

public enum CopilotToolName: String, Codable {
    case readFile = "copilot.read_file"
}
