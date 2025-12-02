import Foundation
import Workspace
import Dependencies

struct WorkspaceInvocationCoordinator {
    @Dependency(\.workspaceInvoker) private var workspaceInvoker
    
    func invokeFilespaceUpdate(fileURL: URL, content: String) async {
        await workspaceInvoker.invokeFilespaceUpdate(fileURL, content)
    }
}
