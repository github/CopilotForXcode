import Foundation
import Logger
import ServiceManagement

public struct LaunchAgentManager {
    let lastLaunchAgentVersionKey = "LastLaunchAgentVersion"
    let serviceIdentifier: String
    let executablePath: String
    let bundleIdentifier: String

    var launchAgentDirURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents")
    }

    var launchAgentPath: String {
        launchAgentDirURL.appendingPathComponent("\(serviceIdentifier).plist").path
    }

    public init(serviceIdentifier: String, executablePath: String, bundleIdentifier: String) {
        self.serviceIdentifier = serviceIdentifier
        self.executablePath = executablePath
        self.bundleIdentifier = bundleIdentifier
    }

    public func setupLaunchAgentForTheFirstTimeIfNeeded() async throws {
        await removeObsoleteLaunchAgent()
        try await setupLaunchAgent()
    }
    
    public func isBackgroundPermissionGranted() async -> Bool {
        // On macOS 13+, check SMAppService status
        let bridgeLaunchAgent = SMAppService.agent(plistName: "bridgeLaunchAgent.plist")
        let status = bridgeLaunchAgent.status
        return status != .requiresApproval
    }

    public func setupLaunchAgent() async throws {
        Logger.client.info("Registering bridge launch agent")
        let bridgeLaunchAgent = SMAppService.agent(plistName: "bridgeLaunchAgent.plist")
        try bridgeLaunchAgent.register()

        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        UserDefaults.standard.set(buildNumber, forKey: lastLaunchAgentVersionKey)
    }

    public func removeLaunchAgent() async throws {
        Logger.client.info("Unregistering bridge launch agent")
        let bridgeLaunchAgent = SMAppService.agent(plistName: "bridgeLaunchAgent.plist")
        try await bridgeLaunchAgent.unregister()
    }

    public func reloadLaunchAgent() async throws {
        // No-op: macOS 13+ uses SMAppService which doesn't need manual reload
    }

    public func removeObsoleteLaunchAgent() async {
        let path = launchAgentPath
        if FileManager.default.fileExists(atPath: path) {
            Logger.client.info("Unloading and removing old bridge launch agent")
            try? await launchctl("unload", path)
            try? FileManager.default.removeItem(atPath: path)
        }

        // Also remove legacy plist that used "XPCService" instead of "ExtensionService"
        let legacyIdentifier = serviceIdentifier
            .replacingOccurrences(of: "ExtensionService", with: "XPCService")
        let legacyPath = launchAgentDirURL
            .appendingPathComponent("\(legacyIdentifier).plist").path
        if FileManager.default.fileExists(atPath: legacyPath) {
            Logger.client.info("Unloading and removing legacy XPCService launch agent")
            try? await launchctl("unload", legacyPath)
            try? FileManager.default.removeItem(atPath: legacyPath)
        }
    }
}

private func process(_ launchPath: String, _ args: [String]) async throws {
    let task = Process()
    task.launchPath = launchPath
    task.arguments = args
    task.environment = [
        "PATH": "/usr/bin",
    ]
    let outpipe = Pipe()
    task.standardOutput = outpipe

    return try await withUnsafeThrowingContinuation { continuation in
        do {
            task.terminationHandler = { process in
                do {
                    if process.terminationStatus == 0 {
                        continuation.resume(returning: ())
                    } else {
                        if let data = try? outpipe.fileHandleForReading.readToEnd(),
                           let content = String(data: data, encoding: .utf8)
                        {
                            continuation.resume(throwing: E(errorDescription: content))
                        } else {
                            continuation.resume(
                                throwing: E(
                                    errorDescription: "Unknown error."
                                )
                            )
                        }
                    }
                }
            }
            try task.run()
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

private func helper(_ args: String...) async throws {
    // TODO: A more robust way to locate the executable.
    guard let url = Bundle.main.executableURL?
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Applications")
        .appendingPathComponent("Helper")
    else { throw E(errorDescription: "Unable to locate Helper.") }
    return try await process(url.path, args)
}

private func launchctl(_ args: String...) async throws {
    return try await process("/bin/launchctl", args)
}

struct E: Error, LocalizedError {
    var errorDescription: String?
}

