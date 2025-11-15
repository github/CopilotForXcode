import Foundation
import Workspace
import GitHubCopilotService
import JSONRPC
import XcodeInspector

/*
 * project-context is different from others
 * 1. The CLS only request this skill once `after initialized` instead of during conversation / turn.
 * 2. After resolved skill, a file watcher needs to be start for syncing file modification to CLS
 */
public class ProjectContextSkill {
    public static let ID = "project-context"
    public static let ProgressID = "collect-project-context"
    
    public static var resolvedWorkspace: Set<String> = Set()
    
    public static func isWorkspaceResolved(_ path: String) -> Bool {
        return ProjectContextSkill.resolvedWorkspace.contains(path)
    }
    
    public init() { }
    
    /*
     * The request from CLS only contain the projectPath (a initialization parameter for CLS)
     * whereas to get files for xcode workspace, the workspacePath is needed.
     */
    public static func resolveSkill(
        request: WatchedFilesRequest,
        workspacePath: String,
        completion: JSONRPCResponseHandler
    ) {
        guard !ProjectContextSkill.isWorkspaceResolved(workspacePath) else {return }
        
        let params = request.params!
        
        guard params.workspaceFolder.uri != "/" else { return }
        
        /// build workspace URL
        let workspaceURL = URL(fileURLWithPath: workspacePath)
        /// refer to `init` in `Workspace`
        let projectURL = WorkspaceXcodeWindowInspector.extractProjectURL(
            workspaceURL: workspaceURL,
            documentURL: nil
        ) ?? workspaceURL
        
        /// ignore invalid resolve request
        guard projectURL.absoluteString == params.workspaceFolder.uri else { return }
        
        let files = WorkspaceFile.getWatchedFiles(
            workspaceURL: workspaceURL,
            projectURL: projectURL,
            excludeGitIgnoredFiles: params.excludeGitignoredFiles,
            excludeIDEIgnoredFiles: params.excludeIDEIgnoredFiles
        )
        
        let jsonResult = try? JSONEncoder().encode(["files": files])
        let jsonValue = (try? JSONDecoder().decode(JSONValue.self, from: jsonResult ?? Data())) ?? JSONValue.null
        
        completion(AnyJSONRPCResponse(id: request.id, result: jsonValue))
        
        ProjectContextSkill.resolvedWorkspace.insert(workspacePath)
    }
}
