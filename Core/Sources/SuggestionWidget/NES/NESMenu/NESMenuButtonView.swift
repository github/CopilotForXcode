import SwiftUI
import Cocoa
import Logger

struct NESMenuButtonView: NSViewRepresentable {
    let menuController: NESMenuController
    var fontSize: CGFloat
    
    var buttonImage: NSImage? {
        NSImage(
            systemSymbolName: "arrow.right.to.line",
            accessibilityDescription: "Next Edit Suggestion Menu"
        )
    }
    
    var buttonFont: NSFont {
        NSFont.systemFont(ofSize: fontSize, weight: .medium)
    }
    
    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.title = ""
        button.bezelStyle = .shadowlessSquare
        button.isBordered = false
        button.imageScaling = .scaleProportionallyDown
        button.contentTintColor = .white
        button.imagePosition = .imageOnly
        button.focusRingType = .none
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked)
        button.font = buttonFont
        
        let baseConfig = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
        let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: NSColor.white)
        button.image = buttonImage?
            .withSymbolConfiguration(baseConfig)?
            .withSymbolConfiguration(colorConfig)
        
        context.coordinator.setupMenu(for: button)

        return button
    }
    
    func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.font = buttonFont
        if let image = buttonImage {
            let base = NSImage.SymbolConfiguration(pointSize: fontSize, weight: .regular)
            let tinted = NSImage.SymbolConfiguration(hierarchicalColor: .white)
            nsView.image = image.withSymbolConfiguration(base)?.withSymbolConfiguration(tinted)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(menuController: menuController)
    }
    
    class Coordinator: NSObject {
        let menuController: NESMenuController
        private weak var button: NSButton?
        
        init(menuController: NESMenuController) {
            self.menuController = menuController
            super.init()
        }
        
        func setupMenu(for button: NSButton) {
            self.button = button
        }
        
        @objc func buttonClicked(_ sender: NSButton) {
            let menu = menuController.createMenu()
            showMenu(menu, for: sender)
        }
        
        private func showMenu(_ menu: NSMenu, for button: NSButton) {
            // Ensure the button is still in a window before showing the menu
            guard let window = button.window else {
                return
            }
            
            // Ensure menu is properly positioned and shown
            let location = NSPoint(x: 0, y: button.bounds.height + 5)
            let originalLevel = window.level
            window.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
            defer { window.level = originalLevel }
            
            menu.popUp(positioning: nil, at: location, in: button)
        }
        
        @objc func menuDidClose(_ menu: NSMenu) { }
        
        @objc func menuWillOpen(_ menu: NSMenu) { }
    }
}
