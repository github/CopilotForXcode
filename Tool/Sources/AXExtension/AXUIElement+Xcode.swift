import AppKit
import Foundation

// Extension for xcode specifically
public extension AXUIElement {
    private static let XcodeWorkspaceWindowIdentifier = "Xcode.WorkspaceWindow"
    
    var isSourceEditor: Bool {
        description == "Source Editor"
    }
    
    var isEditorArea: Bool {
        description == "editor area"
    }
    
    var isXcodeWorkspaceWindow: Bool {
        self.description == Self.XcodeWorkspaceWindowIdentifier || self.identifier == Self.XcodeWorkspaceWindowIdentifier
    }
    
    var isXcodeOpenQuickly: Bool {
        ["open_quickly"].contains(self.identifier)
    }
    
    var isXcodeAlert: Bool {
        ["alert"].contains(self.label)
    }
    
    var isXcodeMenuBar: Bool {
        ["menu bar", "menu bar item"].contains(self.description)
    }
}
