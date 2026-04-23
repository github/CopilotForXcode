import Cocoa
import ComposableArchitecture
import SwiftUI
import HostAppActivator

class NESMenuController: ObservableObject {
    private static let defaultParagraphTabStopLocation: CGFloat = 180.0
    private static let titleColor: NSColor = NSColor(Color.secondary)
    private static let shortcutIconColor: NSColor = NSColor.tertiaryLabelColor
    static let baseFontSize: CGFloat = 13
    
    private var menu: NSMenu?
    var fontSize: CGFloat {
        didSet { menu = nil }
    }
    var fontSizeScale: Double {
        didSet { menu = nil }
    }
    var store: StoreOf<NESSuggestionPanelFeature>
    
    private var imageSize: NSSize {
        NSSize(width: self.fontSize, height: self.fontSize)
    }
    private var paragraphStyle: NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.tabStops = [
            NSTextTab(
                textAlignment: .right,
                location: Self.defaultParagraphTabStopLocation * fontSizeScale
            )
        ]
        return style
    }
    
    init(fontSize: CGFloat, fontSizeScale: Double, store: StoreOf<NESSuggestionPanelFeature>) {
        self.fontSize = fontSize
        self.fontSizeScale = fontSizeScale
        self.store = store
    }
    
    func createMenu() -> NSMenu {
        let menu = NESCustomMenu(title: "")
        menu.menuController = self
        
        menu.font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        
        let titleItem = createTitleItem()
        let settingsItem = createSettingItem()
        let goToAcceptItem = createGoToAcceptItem()
        let rejectItem = createRejectItem()
        let moreInfoItem = createGetMoreInfoItem()
        
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(goToAcceptItem)
        menu.addItem(rejectItem)
//        menu.addItem(NSMenuItem.separator())
//        menu.addItem(moreInfoItem)
        
        self.menu = menu
        return menu
    }
    
    private func createImage(_ name: String, description accessibilityDescription: String) -> NSImage? {
        guard let image = NSImage(
            systemSymbolName: name, accessibilityDescription: accessibilityDescription
        ) else { return nil }
        
        image.size = self.imageSize
        return image
    }
    
    private func createParagraphAttributedTitle(_ text: String, helpText: String) -> NSAttributedString {
        let attributedTitle = NSMutableAttributedString(string: text)
        attributedTitle.append(NSAttributedString(
            string: "\t\(helpText)",
            attributes: [
                .foregroundColor: Self.shortcutIconColor,
                .font: NSFont.systemFont(ofSize: fontSize - 1, weight: .regular),
                .paragraphStyle: paragraphStyle
            ]
        ))
        
        attributedTitle.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: attributedTitle.length)
        )
        
        return attributedTitle
        
    }
    
    private func createParagraphAttributedTitle(_ text: String, systemSymbolName: String) -> NSAttributedString {
        let attributedTitle = NSMutableAttributedString(string: text)
        attributedTitle.append(NSAttributedString(string: "\t"))

        if let image = createImage(systemSymbolName, description: "\(systemSymbolName) key") {
            let attachment = NSTextAttachment()
            attachment.image = image
            
            let attachmentString = NSMutableAttributedString(attachment: attachment)
            attachmentString.addAttributes([
                .foregroundColor: Self.shortcutIconColor,
                .font: NSFont.systemFont(ofSize: fontSize - 1, weight: .regular),
                .paragraphStyle: paragraphStyle
            ], range: NSRange(location: 0, length: attachmentString.length))
            
            attributedTitle.append(attachmentString)
        }
        
        attributedTitle.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: attributedTitle.length)
        )
        
        return attributedTitle
        
    }
    
    @objc func handleSettingsAction() {
        try? launchHostAppAdvancedSettings()
    }
    
    @objc func handleGoToAcceptAction() {
        let state = store.withState { $0 }
        state.nesContent?.acceptNESSuggestion()
    }
    
    @objc func handleRejectAction() {
        let state = store.withState { $0 }
        state.nesContent?.rejectNESSuggestion()
    }
    
    @objc func handleGetMoreInfoAction() { }
    
    private func createTitleItem() -> NSMenuItem {
        let titleItem = NSMenuItem()
        
        titleItem.isEnabled = false
        
        let attributedTitle = NSMutableAttributedString(string: "Copilot Next Edit Suggestion")
        attributedTitle.addAttributes([
            .foregroundColor: Self.titleColor,
            .font: NSFont.systemFont(ofSize: fontSize - 1, weight: .medium)
        ], range: NSRange(location: 0, length: attributedTitle.length))
        
        titleItem.attributedTitle = attributedTitle
        return titleItem
    }
    
    private func createSettingItem() -> NSMenuItem {
        let settingsItem = NSMenuItem(
            title: "Settings",
            action: #selector(handleSettingsAction),
            keyEquivalent: ""
        )
        settingsItem.target = self
        
        if let gearImage = NSImage(
            systemSymbolName: "gearshape",
            accessibilityDescription: "Settings"
        ) {
            gearImage.size = self.imageSize
            settingsItem.image = gearImage
        }
        
        return settingsItem
    }
    
    private func createGoToAcceptItem() -> NSMenuItem {
        let goToAcceptItem = NSMenuItem(
            title: "Go To / Accept",
            action: #selector(handleGoToAcceptAction),
            keyEquivalent: ""
        )
        goToAcceptItem.target = self
        
        let imageSymbolName = "arrow.right.to.line"
        
        if let arrowImage = createImage(imageSymbolName, description: "Go To or Accept") {
            goToAcceptItem.image = arrowImage
        }
        
        let attributedTitle = createParagraphAttributedTitle("Go To / Accept", systemSymbolName: imageSymbolName)
        goToAcceptItem.attributedTitle = attributedTitle
        
        return goToAcceptItem
    }
    
    private func createRejectItem() -> NSMenuItem {
        let rejectItem = NSMenuItem(
            title: "Reject",
            action: #selector(handleRejectAction),
            keyEquivalent: ""
        )
        rejectItem.target = self
        
        if let xImage = createImage("xmark", description: "Reject") {
            rejectItem.image = xImage
        }
        
        let attributedTitle = createParagraphAttributedTitle("Reject", helpText: "Esc")
        rejectItem.attributedTitle = attributedTitle
        
        return rejectItem
    }
    
    private func createGetMoreInfoItem() -> NSMenuItem {
        let moreInfoItem = NSMenuItem(
            title: "Get More Info",
            action: #selector(handleGetMoreInfoAction),
            keyEquivalent: ""
        )
        moreInfoItem.target = self
        
        let attributedTitle = NSMutableAttributedString(string: "Get More Info")
        attributedTitle.addAttributes([
            .foregroundColor: NSColor.linkColor,
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium)
        ], range: NSRange(location: 0, length: attributedTitle.length))
        
        moreInfoItem.attributedTitle = attributedTitle
        
        return moreInfoItem
    }
}
