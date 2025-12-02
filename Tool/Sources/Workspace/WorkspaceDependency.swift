import Dependencies
import Foundation

public final class WorkspaceInvoker {
    // Manually trigger the update of the filespace
    public var invokeFilespaceUpdate: (URL, String) async -> Void = { _, _ in }
    
    public init() {}
}

struct WorkspaceInvokerKey: DependencyKey {
    static let liveValue = WorkspaceInvoker()
}

public extension DependencyValues {
    var workspaceInvoker: WorkspaceInvoker {
        get { self[WorkspaceInvokerKey.self] }
        set { self[WorkspaceInvokerKey.self] = newValue }
    }
}
