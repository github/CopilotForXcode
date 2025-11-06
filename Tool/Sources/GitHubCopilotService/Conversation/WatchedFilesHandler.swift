import JSONRPC
import Combine
import Workspace
import XcodeInspector
import Foundation
import ConversationServiceProvider
import LanguageServerProtocol

public protocol WatchedFilesHandler {
    func handleWatchedFiles(_ request: WatchedFilesRequest, workspaceURL: URL, completion: @escaping (AnyJSONRPCResponse) -> Void, service: GitHubCopilotService?)
}

public final class WatchedFilesHandlerImpl: WatchedFilesHandler {
    public static let shared = WatchedFilesHandlerImpl()

    public func handleWatchedFiles(_ request: WatchedFilesRequest, workspaceURL: URL, completion: @escaping (AnyJSONRPCResponse) -> Void, service: GitHubCopilotService?) {
        guard let params = request.params, params.workspaceFolder.uri != "/" else { return }

        let projectURL = WorkspaceXcodeWindowInspector.extractProjectURL(workspaceURL: workspaceURL, documentURL: nil) ?? workspaceURL
        
        let files = WorkspaceFile.getWatchedFiles(
            workspaceURL: workspaceURL,
            projectURL: projectURL,
            excludeGitIgnoredFiles: params.excludeGitignoredFiles,
            excludeIDEIgnoredFiles: params.excludeIDEIgnoredFiles
        )
        WorkspaceFileIndex.shared.setFiles(files, for: workspaceURL)

        let fileUris = files.prefix(10000).map { $0.url.absoluteString } // Set max number of indexing file to 10000
        
        let batchSize = BatchingFileChangeWatcher.maxEventPublishSize
        
        Task {
            var sentCount = 0
            if params.partialResultToken != nil && fileUris.count > batchSize {
                for startIndex in stride(from: 0, to: fileUris.count, by: batchSize) {
                    let endIndex = min(startIndex + batchSize, fileUris.count)
                    let partialResult = Array(fileUris[startIndex..<endIndex])
                    let jsonResult: JSONValue = .array(partialResult.map { .hash(["uri": .string($0)]) })
                    let jsonValue: JSONValue = .hash(["files": jsonResult])

                    if let progressParams = CopilotProgressParams.toProtocolProgressParams(
                            token: params.partialResultToken!, value: jsonValue) {
                        try? await service?.sendCopilotNotification(.clientProtocolProgress(progressParams))
                    }

                    sentCount = endIndex
                    try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
                }
            }
            
            if sentCount < fileUris.count {
                let remainingFiles = Array(fileUris[sentCount..<fileUris.count])
                let jsonResult: JSONValue = .array(remainingFiles.map { .hash(["uri": .string($0)]) })
                let jsonValue: JSONValue = .hash(["files": jsonResult])

                completion(AnyJSONRPCResponse(id: request.id, result: jsonValue))
            } else {
                let jsonResult: JSONValue = .array([])
                let jsonValue: JSONValue = .hash(["files": jsonResult])

                completion(AnyJSONRPCResponse(id: request.id, result: jsonValue))
            }
        }

        
        startFileChangeWatcher(workspaceURL: workspaceURL, projectURL: projectURL, service: service)
    }

    func startFileChangeWatcher(workspaceURL: URL, projectURL: URL, service: GitHubCopilotService?) {
        Task {
            WorkspaceDirectoryIndex.shared.initIndexFor(workspaceURL, projectURL: projectURL)
            
            await FileChangeWatcherServicePool.shared.watch(
                for: workspaceURL,
                publisher: { fileEvents in
                    self.onFileEvents(
                        fileEvents: fileEvents,
                        workspaceURL: workspaceURL,
                        projectURL: projectURL,
                        service: service)
                },
                directoryChangePublisher: { directoryEvents in
                    self.onDirectoryEvent(
                        directoryEvents: directoryEvents,
                        workspaceURL: workspaceURL,
                        projectURL: projectURL)
                }
            )
        }
    }
    
    private func onFileEvents(fileEvents: [FileEvent], workspaceURL: URL, projectURL: URL, service: GitHubCopilotService?) {
        // Update the local file index with file events
        fileEvents.forEach { event in
            let fileURL = URL(string: event.uri)!
            let relativePath = fileURL.path.replacingOccurrences(of: projectURL.path, with: "")
            let fileName = fileURL.lastPathComponent
            let file = ConversationFileReference(url: fileURL, relativePath: relativePath, fileName: fileName)
            if event.type == .deleted {
                WorkspaceFileIndex.shared.removeFile(file, from: workspaceURL)
            } else {
                WorkspaceFileIndex.shared.addFile(file, to: workspaceURL)
            }
        }
        
        Task {
            try? await service?.notifyDidChangeWatchedFiles(
                .init(workspaceUri: projectURL.path, changes: fileEvents))
        }
    }
    
    private func onDirectoryEvent(directoryEvents: [FileEvent], workspaceURL: URL, projectURL: URL) {
        directoryEvents.forEach { event in
            guard let directoryURL = URL(string: event.uri) else {
                return
            }
            let directory = ConversationDirectoryReference(url: directoryURL, projectURL: projectURL)
            if event.type == .deleted {
                WorkspaceDirectoryIndex.shared.removeDirectory(directory, from: workspaceURL)
            } else {
                WorkspaceDirectoryIndex.shared.addDirectory(directory, to: workspaceURL)
            }
        }
    }
}

public struct CopilotProgressParams: Codable {
    let token: ProgressToken
    let value: JSONValue

    init(token: ProgressToken, value: JSONValue) {
        self.token = token
        self.value = value
    }

    public static func toProtocolProgressParams(token: ProgressToken, value: JSONValue) -> ProgressParams? {
        let copilotProgress = CopilotProgressParams(token: token, value: value)

        if let jsonData = try? JSONEncoder().encode(copilotProgress),
           let progressParams = try? JSONDecoder().decode(ProgressParams.self, from: jsonData) {
            return progressParams
        }
        return nil
    }
}
