import Foundation
import Workspace
import LanguageServerProtocol

public final class BuiltinExtensionWorkspacePlugin: WorkspacePlugin {
    let extensionManager: BuiltinExtensionManager

    public init(workspace: Workspace, extensionManager: BuiltinExtensionManager = .shared) {
        self.extensionManager = extensionManager
        super.init(workspace: workspace)
    }

    override public func didOpenFilespace(_ filespace: Filespace) async {
        await notifyOpenFile(filespace: filespace)
    }

    override public func didSaveFilespace(_ filespace: Filespace) {
        notifySaveFile(filespace: filespace)
    }

    override public func didUpdateFilespace(
        _ filespace: Filespace,
        content: String,
        contentChanges: [TextDocumentContentChangeEvent]? = nil
    ) async {
        await notifyUpdateFile(filespace: filespace, content: content, contentChanges: contentChanges)
    }

    override public func didCloseFilespace(_ fileURL: URL) {
        Task {
            for ext in extensionManager.extensions {
                ext.workspace(
                    .init(workspaceURL: workspaceURL, projectURL: projectRootURL),
                    didCloseDocumentAt: fileURL
                )
            }
        }
    }

    public func notifyOpenFile(filespace: Filespace) async {
        guard filespace.isTextReadable else { return }
        for ext in extensionManager.extensions {
            await ext.workspace(
                .init(workspaceURL: workspaceURL, projectURL: projectRootURL),
                didOpenDocumentAt: filespace.fileURL
            )
        }
    }

    public func notifyUpdateFile(
        filespace: Filespace,
        content: String,
        contentChanges: [TextDocumentContentChangeEvent]? = nil
    ) async {
        guard filespace.isTextReadable else { return }
        for ext in extensionManager.extensions {
            await ext.workspace(
                .init(workspaceURL: workspaceURL, projectURL: projectRootURL),
                didUpdateDocumentAt: filespace.fileURL,
                content: content,
                contentChanges: contentChanges
            )
        }
    }

    public func notifySaveFile(filespace: Filespace) {
        Task {
            guard filespace.isTextReadable else { return }
            for ext in extensionManager.extensions {
                ext.workspace(
                    .init(workspaceURL: workspaceURL, projectURL: projectRootURL),
                    didSaveDocumentAt: filespace.fileURL
                )
            }
        }
    }
}

