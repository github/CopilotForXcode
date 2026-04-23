import AppKit
import Client
import Foundation
import SwiftUI
import Toast
import XcodeInspector
import SystemUtils
import SharedUIComponents
import Workspace
import LanguageServerProtocol

// MARK: - Workspace URL Helpers

private func getCurrentWorkspaceURL() async -> URL? {
    guard let service = try? getService(),
          let inspectorData = try? await service.getXcodeInspectorData() else {
        return nil
    }

    if let url = inspectorData.realtimeActiveWorkspaceURL,
       let workspaceURL = URL(string: url),
       workspaceURL.path != "/" {
        return workspaceURL
    } else if let url = inspectorData.latestNonRootWorkspaceURL {
        return URL(string: url)
    }

    return nil
}

func getCurrentProjectURL() async -> URL? {
    guard let workspaceURL = await getCurrentWorkspaceURL(),
          let projectURL = WorkspaceXcodeWindowInspector.extractProjectURL(
              workspaceURL: workspaceURL,
              documentURL: nil
          ) else {
        return nil
    }

    return projectURL
}

// MARK: - Workspace Folders

func getWorkspaceFolders() async -> [WorkspaceFolder]? {
    guard let workspaceURL = await getCurrentWorkspaceURL(),
          let workspaceInfo = WorkspaceFile.getWorkspaceInfo(workspaceURL: workspaceURL) else {
        return nil
    }

    let projects = WorkspaceFile.getProjects(workspace: workspaceInfo)
    return projects.map { project in
        WorkspaceFolder(uri: project.uri, name: project.name)
    }
}

// MARK: - File System Helpers

func ensureDirectoryExists(at url: URL) throws {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: url.path) {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }
}
