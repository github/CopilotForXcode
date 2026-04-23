import AppKit
import Foundation

public extension NSRunningApplication {
    var isXcode: Bool { bundleIdentifier == "com.apple.dt.Xcode" }
    var isCopilotForXcodeExtensionService: Bool {
        bundleIdentifier == Bundle.main.bundleIdentifier
    }
}

public extension FileManager {
    func fileIsDirectory(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue && exists
    }
}

extension AXUIElement {
    public var realtimeDocumentURL: URL? {
        guard let window = self.focusedWindow,
              window.identifier == "Xcode.WorkspaceWindow"
        else { return nil }
        
        return WorkspaceXcodeWindowInspector.extractDocumentURL(windowElement: window)
    }
    
    var realtimeWorkspaceURL: URL? {
        guard let window = self.focusedWindow,
              window.identifier == "Xcode.WorkspaceWindow"
        else { return nil }
        
        return WorkspaceXcodeWindowInspector.extractWorkspaceURL(windowElement: window)
    }
    
    static func fromRunningApplication(_ runningApplication: NSRunningApplication) -> AXUIElement {
        let app = AXUIElementCreateApplication(runningApplication.processIdentifier)
        app.setMessagingTimeout(2)
        return app
    }
}
