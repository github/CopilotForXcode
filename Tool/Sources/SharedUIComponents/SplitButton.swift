import SwiftUI
import AppKit

// MARK: - SplitButton Menu Item

public struct SplitButtonMenuItem: Identifiable {
    public enum Kind {
        case action(() -> Void)
        case divider
        case header
    }

    public let id: UUID
    public let title: String
    public let kind: Kind

    public init(title: String, action: @escaping () -> Void) {
        self.id = UUID()
        self.title = title
        self.kind = .action(action)
    }

    private init(id: UUID = UUID(), title: String, kind: Kind) {
        self.id = id
        self.title = title
        self.kind = kind
    }

    public static func divider(id: UUID = UUID()) -> SplitButtonMenuItem {
        .init(id: id, title: "", kind: .divider)
    }

    public static func header(_ title: String, id: UUID = UUID()) -> SplitButtonMenuItem {
        .init(id: id, title: title, kind: .header)
    }
}

@available(macOS 13.0, *)
private enum SplitButtonMenuBuilder {
    static func buildMenu(
        items: [SplitButtonMenuItem],
        pullsDownCoverItem: Bool,
        target: NSObject,
        action: Selector,
        menuItemActions: inout [UUID: () -> Void]
    ) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menuItemActions.removeAll()

        if pullsDownCoverItem {
            // First item is the "cover" item for pullsDown
            menu.addItem(NSMenuItem(title: "", action: nil, keyEquivalent: ""))
        }

        for item in items {
            switch item.kind {
            case .divider:
                menu.addItem(.separator())

            case .header:
                if #available(macOS 14.0, *) {
                    menu.addItem(NSMenuItem.sectionHeader(title: item.title))
                } else {
                    let headerItem = NSMenuItem()
                    headerItem.title = item.title
                    headerItem.isEnabled = false
                    menu.addItem(headerItem)
                }

            case .action(let handler):
                let menuItem = NSMenuItem(
                    title: item.title,
                    action: action,
                    keyEquivalent: ""
                )
                menuItem.target = target
                menuItem.representedObject = item.id
                menuItemActions[item.id] = handler
                menu.addItem(menuItem)
            }
        }

        return menu
    }
}

// MARK: - SplitButton using NSComboButton

@available(macOS 13.0, *)
public struct SplitButton: View {
    let title: String
    let primaryAction: () -> Void
    let isDisabled: Bool
    let menuItems: [SplitButtonMenuItem]
    var style: SplitButtonStyle

    @AppStorage(\.fontScale) private var fontScale

    public enum SplitButtonStyle {
        case standard
        case prominent
    }
    
    public init(
        title: String,
        isDisabled: Bool = false,
        primaryAction: @escaping () -> Void,
        menuItems: [SplitButtonMenuItem] = [],
        style: SplitButtonStyle = .standard
    ) {
        self.title = title
        self.isDisabled = isDisabled
        self.primaryAction = primaryAction
        self.menuItems = menuItems
        self.style = style
    }
    
    public var body: some View {
        switch style {
        case .standard:
            SplitButtonRepresentable(
                title: title,
                isDisabled: isDisabled,
                primaryAction: primaryAction,
                menuItems: menuItems
            )
        case .prominent:
            HStack(spacing: 0) {
                Button(action: primaryAction) {
                    Text(title)
                        .scaledFont(.body)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderless)
                
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: fontScale)
                    .padding(.vertical, 4)

                ProminentMenuButton(
                    menuItems: menuItems,
                    isDisabled: isDisabled
                )
                .frame(width: 16)
            }
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.5 : 1)
        }
    }
}

@available(macOS 13.0, *)
private struct ProminentMenuButton: NSViewRepresentable {
    let menuItems: [SplitButtonMenuItem]
    let isDisabled: Bool

    func makeNSView(context: Context) -> NSPopUpButton {
        let button = NSPopUpButton(frame: .zero, pullsDown: true)
        button.bezelStyle = .smallSquare
        button.isBordered = false
        button.imagePosition = .imageOnly

        updateImage(for: button)
        
        button.contentTintColor = .white
        
        return button
    }
    
    func updateNSView(_ nsView: NSPopUpButton, context: Context) {
        nsView.isEnabled = !isDisabled
        nsView.contentTintColor = isDisabled ? NSColor.white.withAlphaComponent(0.5) : .white
        
        updateImage(for: nsView)
        
        context.coordinator.updateMenu(for: nsView, with: menuItems)
    }
    
    private func updateImage(for button: NSPopUpButton) {
        let config = NSImage.SymbolConfiguration(textStyle: .body)
        let image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "More options")?
            .withSymbolConfiguration(config)
        button.image = image
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        private var menuItemActions: [UUID: () -> Void] = [:]

        func updateMenu(for button: NSPopUpButton, with items: [SplitButtonMenuItem]) {
            button.menu = SplitButtonMenuBuilder.buildMenu(
                items: items,
                pullsDownCoverItem: true,
                target: self,
                action: #selector(handleMenuItemAction(_:)),
                menuItemActions: &menuItemActions
            )
        }

        @objc func handleMenuItemAction(_ sender: NSMenuItem) {
            if let itemId = sender.representedObject as? UUID,
               let action = menuItemActions[itemId] {
                action()
            }
        }
    }
}

@available(macOS 13.0, *)
struct SplitButtonRepresentable: NSViewRepresentable {
    let title: String
    let primaryAction: () -> Void
    let isDisabled: Bool
    let menuItems: [SplitButtonMenuItem]
    
    init(
        title: String,
        isDisabled: Bool = false,
        primaryAction: @escaping () -> Void,
        menuItems: [SplitButtonMenuItem] = []
    ) {
        self.title = title
        self.isDisabled = isDisabled
        self.primaryAction = primaryAction
        self.menuItems = menuItems
    }
    
    func makeNSView(context: Context) -> NSComboButton {
        let button = NSComboButton()
        
        button.title = title
        button.target = context.coordinator
        button.action = #selector(Coordinator.handlePrimaryAction)
        button.isEnabled = !isDisabled
        
        
        context.coordinator.button = button
        context.coordinator.updateMenu(with: menuItems)
        
        return button
    }
    
    func updateNSView(_ nsView: NSComboButton, context: Context) {
        nsView.title = title
        nsView.isEnabled = !isDisabled
        context.coordinator.updateMenu(with: menuItems)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(primaryAction: primaryAction)
    }
    
    class Coordinator: NSObject {
        let primaryAction: () -> Void
        weak var button: NSComboButton?
        private var menuItemActions: [UUID: () -> Void] = [:]
        
        init(primaryAction: @escaping () -> Void) {
            self.primaryAction = primaryAction
        }
        
        @objc func handlePrimaryAction() {
            primaryAction()
        }
        
        @objc func handleMenuItemAction(_ sender: NSMenuItem) {
            if let itemId = sender.representedObject as? UUID,
               let action = menuItemActions[itemId] {
                action()
            }
        }
        
        func updateMenu(with items: [SplitButtonMenuItem]) {
            button?.menu = SplitButtonMenuBuilder.buildMenu(
                items: items,
                pullsDownCoverItem: false,
                target: self,
                action: #selector(handleMenuItemAction(_:)),
                menuItemActions: &menuItemActions
            )
        }
    }
}
