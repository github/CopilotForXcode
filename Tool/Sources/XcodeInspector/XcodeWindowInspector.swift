import AppKit
import AsyncPassthroughSubject
import AXExtension
import Combine
import Foundation
import Logger

public class XcodeWindowInspector: ObservableObject {
    public let uiElement: AXUIElement

    init(uiElement: AXUIElement) {
        self.uiElement = uiElement
        uiElement.setMessagingTimeout(2)
    }
}

public final class WorkspaceXcodeWindowInspector: XcodeWindowInspector {
    let app: NSRunningApplication
    @Published public internal(set) var documentURL: URL = .init(fileURLWithPath: "/")
    @Published public internal(set) var workspaceURL: URL = .init(fileURLWithPath: "/")
    @Published public internal(set) var projectRootURL: URL = .init(fileURLWithPath: "/")
    private var focusedElementChangedTask: Task<Void, Error>?

    public func refresh() {
        Task { @XcodeInspectorActor in updateURLs() }
    }

    public init(
        app: NSRunningApplication,
        uiElement: AXUIElement,
        axNotifications: AsyncPassthroughSubject<XcodeAppInstanceInspector.AXNotification>
    ) {
        self.app = app
        super.init(uiElement: uiElement)

        focusedElementChangedTask = Task { [weak self, axNotifications] in
            await self?.updateURLs()

            await withThrowingTaskGroup(of: Void.self) { [weak self] group in
                group.addTask { [weak self] in
                    // prevent that documentURL may not be available yet
                    try await Task.sleep(nanoseconds: 500_000_000)
                    if self?.documentURL == .init(fileURLWithPath: "/") {
                        await self?.updateURLs()
                    }
                }

                group.addTask { [weak self] in
                    for await notification in await axNotifications.notifications() {
                        guard notification.kind == .focusedUIElementChanged
                            || notification.kind == .titleChanged
                        else { continue }
                        guard let self else { return }
                        try Task.checkCancellation()
                        await Task.yield()
                        await self.updateURLs()
                    }
                }
            }
        }
    }

    @XcodeInspectorActor
    func updateURLs() {
        let documentURL = Self.extractDocumentURL(windowElement: uiElement)
        if let documentURL {
            Task { @MainActor in
                self.documentURL = documentURL
            }
        }
        let workspaceURL = Self.extractWorkspaceURL(windowElement: uiElement)
        if let workspaceURL {
            Task { @MainActor in
                self.workspaceURL = workspaceURL
            }
        }
        let projectURL = Self.extractProjectURL(
            workspaceURL: workspaceURL,
            documentURL: documentURL
        )
        if let projectURL {
            Task { @MainActor in
                self.projectRootURL = projectURL
            }
        }
    }

    static func extractDocumentURL(
        windowElement: AXUIElement
    ) -> URL? {
        // fetch file path of the frontmost window of Xcode through Accessibility API.
        let path = windowElement.document
        if let path = path?.removingPercentEncoding {
            let url = URL(
                fileURLWithPath: path
                    .replacingOccurrences(of: "file://", with: "")
            )
            return adjustFileURL(url)
        }
        return nil
    }

    static func extractWorkspaceURL(
        windowElement: AXUIElement
    ) -> URL? {
        for child in windowElement.children {
            if child.description.starts(with: "/"), child.description.count > 1 {
                let path = child.description
                let trimmedNewLine = path.trimmingCharacters(in: .newlines)
                let url = URL(fileURLWithPath: trimmedNewLine)
                return url
            }
        }
        
        // Fallback: If no child has the workspace path in description, 
        // try to derive it from the window's document URL
        if let documentURL = extractDocumentURL(windowElement: windowElement) {
            if let workspaceURL = deriveWorkspaceFromDocumentURL(documentURL) {
                return workspaceURL
            }
        }
        
        return nil
    }
    
    static func deriveWorkspaceFromDocumentURL(_ documentURL: URL) -> URL? {
        // Check if documentURL itself is already a workspace/project/playground
        if documentURL.pathExtension == "xcworkspace" || 
           documentURL.pathExtension == "xcodeproj" || 
           documentURL.pathExtension == "playground" {
            return documentURL
        }
        
        // Try to find .xcodeproj or .xcworkspace in parent directories
        var currentURL = documentURL
        while currentURL.pathComponents.count > 1 {
            currentURL.deleteLastPathComponent()
            
            // Check if current directory is a playground
            if currentURL.pathExtension == "playground" {
                return currentURL
            }
            
            // Check if this directory contains .xcodeproj or .xcworkspace
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: currentURL.path) else {
                continue
            }
            
            // Check for .playground, .xcworkspace, and .xcodeproj in a single pass
            var foundPlaygroundURL: URL?
            var foundWorkspaceURL: URL?
            var foundProjectURL: URL?
            for item in contents {
                if foundPlaygroundURL == nil, item.hasSuffix(".playground") {
                    foundPlaygroundURL = currentURL.appendingPathComponent(item)
                }
                if foundWorkspaceURL == nil, item.hasSuffix(".xcworkspace") {
                    foundWorkspaceURL = currentURL.appendingPathComponent(item)
                }
                if foundProjectURL == nil, item.hasSuffix(".xcodeproj") {
                    foundProjectURL = currentURL.appendingPathComponent(item)
                }
            }
            if let playgroundURL = foundPlaygroundURL {
                return playgroundURL
            }
            if let workspaceURL = foundWorkspaceURL {
                return workspaceURL
            }
            if let projectURL = foundProjectURL {
                return projectURL
            }
            
            // Stop at the user's home directory or root
            if currentURL.path == "/" || currentURL.path == NSHomeDirectory() {
                break
            }
        }
        
        return nil
    }

    public static func extractProjectURL(
        workspaceURL: URL?,
        documentURL: URL?
    ) -> URL? {
        guard var currentURL = workspaceURL ?? documentURL else { return nil }
        var firstDirectoryURL: URL?
        var lastGitDirectoryURL: URL?
        while currentURL.pathComponents.count > 1 {
            defer { currentURL.deleteLastPathComponent() }
            guard FileManager.default.fileIsDirectory(atPath: currentURL.path) else { continue }
            guard currentURL.pathExtension != "xcodeproj" else { continue }
            guard currentURL.pathExtension != "xcworkspace" else { continue }
            guard currentURL.pathExtension != "playground" else { continue }
            if firstDirectoryURL == nil { firstDirectoryURL = currentURL }
            let gitURL = currentURL.appendingPathComponent(".git")
            if FileManager.default.fileIsDirectory(atPath: gitURL.path) {
                lastGitDirectoryURL = currentURL
            } else if let text = try? String(contentsOf: gitURL) {
                if !text.hasPrefix("gitdir: ../"), // it's not a sub module
                   text.range(of: "/.git/worktrees/") != nil // it's a git worktree
                {
                    lastGitDirectoryURL = currentURL
                }
            }
        }

        return lastGitDirectoryURL ?? firstDirectoryURL ?? workspaceURL
    }
    
    static func adjustFileURL(_ url: URL) -> URL {
        if url.pathExtension == "playground",
           FileManager.default.fileIsDirectory(atPath: url.path)
        {
            return url.appendingPathComponent("Contents.swift")
        }
        return url
    }
}
