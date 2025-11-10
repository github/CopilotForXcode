import Foundation
import AppKit
import Logger

public let HostAppURL = locateHostBundleURL(url: Bundle.main.bundleURL)

public extension Notification.Name {
    static let openSettingsWindowRequest = Notification
        .Name("com.github.CopilotForXcode.OpenSettingsWindowRequest")
    static let openToolsSettingsWindowRequest = Notification
        .Name("com.github.CopilotForXcode.OpenToolsSettingsWindowRequest")
    static let openBYOKSettingsWindowRequest = Notification
        .Name("com.github.CopilotForXcode.OpenBYOKSettingsWindowRequest")
    static let openAdvancedSettingsWindowRequest = Notification
        .Name("com.github.CopilotForXcode.OpenAdvancedSettingsWindowRequest")
    static let selectedAgentSubModeDidChange = Notification
        .Name("com.github.CopilotForXcode.SelectedAgentSubModeDidChange")
}

public enum GitHubCopilotForXcodeSettingsLaunchError: Error, LocalizedError {
    case appNotFound
    case openFailed(errorDescription: String)

    public var errorDescription: String? {
        switch self {
        case .appNotFound:
            return "\(hostAppName()) settings application not found"
        case let .openFailed(errorDescription):
            return "Failed to launch \(hostAppName()) settings (\(errorDescription))"
        }
    }
}

public func getRunningHostApp() -> NSRunningApplication? {
    return NSWorkspace.shared.runningApplications.first(where: {
        $0.bundleIdentifier == (Bundle.main.object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String)
    })
}

public func launchHostAppSettings() throws {
    // Try the AppleScript approach first, but only if app is already running
    if let hostApp = getRunningHostApp() {
        let activated = hostApp.activate(options: [.activateIgnoringOtherApps])
        Logger.ui.info("\(hostAppName()) activated: \(activated)")

        let scriptSuccess = tryLaunchWithAppleScript()
        
        // If AppleScript fails, fall back to notification center
        if !scriptSuccess {
            DistributedNotificationCenter.default().postNotificationName(
                .openSettingsWindowRequest,
                object: nil
            )
            Logger.ui.info("\(hostAppName()) settings notification sent after activation")
            return
        }
    } else {
        // If app is not running, launch it with the settings flag
        try launchHostAppWithArgs(args: ["--settings"])
    }
}

public func launchHostAppToolsSettings(currentAgentSubMode: String) throws {
    // Try the AppleScript approach first, but only if app is already running
    if let hostApp = getRunningHostApp() {
        let activated = hostApp.activate(options: [.activateIgnoringOtherApps])
        Logger.ui.info("\(hostAppName()) activated: \(activated)")

        _ = tryLaunchWithAppleScript()
        
        DistributedNotificationCenter.default().postNotificationName(
            .openToolsSettingsWindowRequest,
            object: nil
        )
        
        // Notify settings app of current agent submode
        DistributedNotificationCenter.default().postNotificationName(
            .selectedAgentSubModeDidChange,
            object: nil,
            userInfo: ["agentSubMode": currentAgentSubMode],
            options: .deliverImmediately
        )
        
        Logger.ui.info("\(hostAppName()) MCP settings notification sent after activation")
        return
    } else {
        // If app is not running, launch it with the settings flag
        try launchHostAppWithArgs(args: ["--tools"])
    }
}

public func launchHostAppBYOKSettings() throws {
    // Try the AppleScript approach first, but only if app is already running
    if let hostApp = getRunningHostApp() {
        let activated = hostApp.activate(options: [.activateIgnoringOtherApps])
        Logger.ui.info("\(hostAppName()) activated: \(activated)")

        _ = tryLaunchWithAppleScript()
        
        DistributedNotificationCenter.default().postNotificationName(
            .openBYOKSettingsWindowRequest,
            object: nil
        )
        Logger.ui.info("\(hostAppName()) BYOK settings notification sent after activation")
        return
    } else {
        // If app is not running, launch it with the settings flag
        try launchHostAppWithArgs(args: ["--byok"])
    }
}

public func launchHostAppAdvancedSettings() throws {
    // Try the AppleScript approach first, but only if app is already running
    if let hostApp = getRunningHostApp() {
        let activated = hostApp.activate(options: [.activateIgnoringOtherApps])
        Logger.ui.info("\(hostAppName()) activated: \(activated)")
        
        _ = tryLaunchWithAppleScript()
        
        DistributedNotificationCenter.default().postNotificationName(
            .openAdvancedSettingsWindowRequest,
            object: nil
        )
        Logger.ui.info("\(hostAppName()) Advanced settings notification sent after activation")
        return
    } else {
        // If app is not running, launch it with the settings flag
        try launchHostAppWithArgs(args: ["--advanced"])
    }
}

private func tryLaunchWithAppleScript() -> Bool {
    // Try to launch settings using AppleScript
    let script = """
    tell application "\(hostAppName())"
        activate
        tell application "System Events"
            keystroke "," using command down
        end tell
    end tell
    """
    
    var error: NSDictionary?
    if let scriptObject = NSAppleScript(source: script) {
        scriptObject.executeAndReturnError(&error)
        
        // Log the result
        if let error = error {
            Logger.ui.info("\(hostAppName()) settings script error: \(error)")
            return false
        }
        
        Logger.ui.info("\(hostAppName()) settings opened successfully via AppleScript")
        return true
    }
    
    return false
}

public func launchHostAppDefault() throws {
    try launchHostAppWithArgs(args: nil)
}

func launchHostAppWithArgs(args: [String]?) throws {
    guard let appURL = HostAppURL else {
        throw GitHubCopilotForXcodeSettingsLaunchError.appNotFound
    }
    
    Task {
        let configuration = NSWorkspace.OpenConfiguration()
        if let args {
            configuration.arguments = args
        }
        configuration.activates = true
        
        try await NSWorkspace.shared
            .openApplication(at: appURL, configuration: configuration)
    }
}

func locateHostBundleURL(url: URL) -> URL? {
    var nextURL = url
    while nextURL.path != "/" {
        nextURL = nextURL.deletingLastPathComponent()
        if nextURL.lastPathComponent.hasSuffix(".app") {
            return nextURL
        }
    }
    let devAppURL = url
        .deletingLastPathComponent()
        .appendingPathComponent("GitHub Copilot for Xcode Dev.app")
    return devAppURL
}

func hostAppName() -> String {
    return Bundle.main.object(forInfoDictionaryKey: "HOST_APP_NAME") as? String
        ?? "GitHub Copilot for Xcode"
}

public let SELECTED_AGENT_SUBMODE_KEY = "selectedAgentSubMode"
