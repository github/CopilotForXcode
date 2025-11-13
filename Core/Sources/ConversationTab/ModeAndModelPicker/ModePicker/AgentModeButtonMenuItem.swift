import AppKit
import ConversationServiceProvider
import SwiftUI

// MARK: - Agent Menu Item View

class AgentModeButtonMenuItem: NSView {
    // Layout constants
    private let fontScale: Double
    
    private lazy var scaledConstants = ScaledLayoutConstants(fontScale: fontScale)
    
    private struct ScaledLayoutConstants {
        let fontScale: Double
        
        var menuHeight: CGFloat { 22 * fontScale }
        var checkmarkLeftEdge: CGFloat { 9 * fontScale }
        var checkmarkSize: CGFloat { 13 * fontScale }
        var iconSize: CGFloat { 16 * fontScale }
        var iconTextSpacing: CGFloat { 5 * fontScale }
        var checkmarkIconSpacing: CGFloat { 5 * fontScale }
        var hoverEdgeInset: CGFloat { 5 * fontScale }
        var buttonSpacing: CGFloat { -4 * fontScale }
        var deleteButtonRightEdge: CGFloat { 12 * fontScale }
        var buttonSize: CGFloat { 24 * fontScale }
        var buttonIconSize: CGFloat { 10 * fontScale }
        var buttonBackgroundSize: CGFloat { 17 * fontScale }
        var buttonBackgroundEdgeInset: CGFloat { 3 * fontScale }
        var minWidth: CGFloat { 180 * fontScale }
        var maxWidth: CGFloat { 320 * fontScale }
        var fontSize: CGFloat { 13 * fontScale }
        var fontWeight: NSFont.Weight { .regular }
        
        // MARK: - Computed Properties for Repeated Calculations
        
        /// Starting X position for checkmark and icons without selection
        var checkmarkStartX: CGFloat { checkmarkLeftEdge }
        
        /// Starting X position for icons when menu has selection
        var iconStartXWithSelection: CGFloat {
            checkmarkLeftEdge + checkmarkSize + checkmarkIconSpacing
        }
        
        /// Icon X position based on selection state
        func iconX(isSelected: Bool, menuHasSelection: Bool) -> CGFloat {
            isSelected || menuHasSelection ? iconStartXWithSelection : checkmarkLeftEdge
        }
        
        /// Helper to vertically center an element within the menu height
        func centeredY(for elementSize: CGFloat) -> CGFloat {
            (menuHeight - elementSize) / 2
        }
        
        /// Starting X position for label text based on icon presence
        func labelStartX(hasIcon: Bool, iconName: String?, isSelected: Bool, menuHasSelection: Bool) -> CGFloat {
            if hasIcon {
                let iconX: CGFloat
                let iconWidth: CGFloat
                if iconName == AgentModeIcon.plus {
                    iconX = checkmarkLeftEdge
                    iconWidth = checkmarkSize
                } else {
                    iconX = isSelected ? iconStartXWithSelection : (menuHasSelection ? iconStartXWithSelection : checkmarkLeftEdge)
                    iconWidth = iconSize
                }
                return iconX + iconWidth + iconTextSpacing
            } else {
                return menuHasSelection ? iconStartXWithSelection : checkmarkLeftEdge
            }
        }
    }

    private let name: String
    private let iconName: String?
    private let isSelected: Bool
    private let menuHasSelection: Bool
    private let onSelect: () -> Void
    private let onEdit: (() -> Void)?
    private let onDelete: (() -> Void)?

    private var isHovered = false
    private var isEditButtonHovered = false
    private var isDeleteButtonHovered = false
    private var trackingArea: NSTrackingArea?
    
    private var hasEditDeleteButtons: Bool {
        onEdit != nil && onDelete != nil
    }

    private let nameLabel = NSTextField(labelWithString: "")
    private let iconImageView = NSImageView()
    private let checkmarkImageView = NSImageView()
    private let editButton = NSButton()
    private let deleteButton = NSButton()
    private let editButtonBackground = NSView()
    private let deleteButtonBackground = NSView()

    init(
        name: String,
        iconName: String?,
        isSelected: Bool,
        menuHasSelection: Bool,
        fontScale: Double = 1.0,
        fixedWidth: CGFloat? = nil,
        onSelect: @escaping () -> Void,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.name = name
        self.iconName = iconName
        self.isSelected = isSelected
        self.menuHasSelection = menuHasSelection
        self.fontScale = fontScale
        self.onSelect = onSelect
        self.onEdit = onEdit
        self.onDelete = onDelete

        // Use fixed width if provided, otherwise calculate dynamically
        let calculatedWidth = fixedWidth ?? Self.calculateMenuItemWidth(
            name: name,
            hasIcon: iconName != nil,
            isSelected: isSelected,
            menuHasSelection: menuHasSelection,
            hasEditDelete: onEdit != nil && onDelete != nil,
            fontScale: fontScale
        )

        let constants = ScaledLayoutConstants(fontScale: fontScale)
        super.init(frame: NSRect(x: 0, y: 0, width: calculatedWidth, height: constants.menuHeight))
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    static func calculateMenuItemWidth(
        name: String,
        hasIcon: Bool,
        isSelected: Bool,
        menuHasSelection: Bool,
        hasEditDelete: Bool,
        fontScale: Double = 1.0
    ) -> CGFloat {
        // Create scaled constants
        let constants = ScaledLayoutConstants(fontScale: fontScale)
        
        // Calculate text width
        let font = NSFont.systemFont(ofSize: constants.fontSize, weight: constants.fontWeight)
        let textAttributes = [NSAttributedString.Key.font: font]
        let textSize = (name as NSString).size(withAttributes: textAttributes)

        // Calculate label X position using computed property
        let iconName = hasIcon ? (name == "Create an agent" ? AgentModeIcon.plus : nil) : nil
        let labelX = constants.labelStartX(hasIcon: hasIcon, iconName: iconName, isSelected: isSelected, menuHasSelection: menuHasSelection)

        // Calculate required width
        var width = labelX + textSize.width + 10 * fontScale // 10pt padding after text

        if hasEditDelete {
            // Add space for edit and delete buttons
            width = max(width, labelX + textSize.width + 20 * fontScale) // Ensure some space before buttons
            width += (constants.buttonSize * 2) + constants.buttonSpacing + constants.deleteButtonRightEdge
        } else {
            width += 10 * fontScale // Extra padding for items without buttons
        }

        // Clamp to min/max width
        return min(max(width, constants.minWidth), constants.maxWidth)
    }

    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = true

        setupCheckmark()
        setupIcon()
        setupNameLabel()
        
        let showEditDeleteButtons = onEdit != nil && onDelete != nil
        if showEditDeleteButtons {
            setupEditDeleteButtons()
        }

        setupTrackingArea()
    }
    
    // MARK: - View Setup Helpers
    
    private func setupCheckmark() {
        let checkmarkConfig = NSImage.SymbolConfiguration(pointSize: scaledConstants.checkmarkSize, weight: .medium)
        if let image = NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)?
            .withSymbolConfiguration(checkmarkConfig) {
            checkmarkImageView.image = image
        }
        checkmarkImageView.contentTintColor = .labelColor
        let checkmarkY = scaledConstants.centeredY(for: scaledConstants.checkmarkSize)
        checkmarkImageView.frame = NSRect(
            x: scaledConstants.checkmarkStartX,
            y: checkmarkY,
            width: scaledConstants.checkmarkSize,
            height: scaledConstants.checkmarkSize
        )
        checkmarkImageView.isHidden = !isSelected
        addSubview(checkmarkImageView)
    }
    
    private func setupIcon() {
        guard let iconName = iconName else { return }
        
        if iconName == AgentModeIcon.agent {
            setupCustomAgentIcon()
        } else if iconName == AgentModeIcon.plus {
            setupPlusIcon()
        } else {
            setupSFSymbolIcon(iconName)
        }
        
        iconImageView.contentTintColor = .labelColor
        iconImageView.isHidden = false
        
        // Calculate and set icon position
        let (iconX, iconSize, iconY) = calculateIconPosition(for: iconName)
        iconImageView.frame = NSRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
        addSubview(iconImageView)
    }
    
    private func setupCustomAgentIcon() {
        guard let image = NSImage(named: AgentModeIcon.agent) else { return }
        
        let targetSize = NSSize(width: scaledConstants.iconSize, height: scaledConstants.iconSize)
        let resizedImage = NSImage(size: targetSize)
        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1.0
        )
        resizedImage.unlockFocus()
        resizedImage.isTemplate = true
        iconImageView.image = resizedImage
    }
    
    private func setupPlusIcon() {
        let plusConfig = NSImage.SymbolConfiguration(pointSize: scaledConstants.checkmarkSize, weight: .medium)
        if let image = NSImage(systemSymbolName: AgentModeIcon.plus, accessibilityDescription: nil) {
            iconImageView.image = image.withSymbolConfiguration(plusConfig)
        }
    }
    
    private func setupSFSymbolIcon(_ iconName: String) {
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: scaledConstants.iconSize, weight: .medium)
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil) {
            iconImageView.image = image.withSymbolConfiguration(symbolConfig)
        }
    }
    
    private func calculateIconPosition(for iconName: String) -> (x: CGFloat, size: CGFloat, y: CGFloat) {
        if iconName == AgentModeIcon.plus {
            let size = scaledConstants.checkmarkSize
            return (
                scaledConstants.checkmarkStartX,
                size,
                scaledConstants.centeredY(for: size)
            )
        } else {
            let size = scaledConstants.iconSize
            return (
                scaledConstants.iconX(isSelected: isSelected, menuHasSelection: menuHasSelection),
                size,
                scaledConstants.centeredY(for: size)
            )
        }
    }
    
    private func setupNameLabel() {
        let labelX = scaledConstants.labelStartX(
            hasIcon: iconName != nil,
            iconName: iconName,
            isSelected: isSelected,
            menuHasSelection: menuHasSelection
        )
        
        nameLabel.stringValue = name
        nameLabel.font = NSFont.systemFont(ofSize: scaledConstants.fontSize, weight: scaledConstants.fontWeight)
        nameLabel.textColor = .labelColor
        nameLabel.frame = NSRect(x: labelX, y: 3 * fontScale, width: 160 * fontScale, height: 16 * fontScale)
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.backgroundColor = .clear
        nameLabel.drawsBackground = false
        addSubview(nameLabel)
    }
    
    private func setupEditDeleteButtons() {
        let viewWidth = frame.width
        let buttonIconConfig = NSImage.SymbolConfiguration(pointSize: scaledConstants.buttonIconSize, weight: .medium)
        
        // Calculate button positions from the right edge
        let deleteButtonX = viewWidth - scaledConstants.deleteButtonRightEdge - scaledConstants.buttonSize
        let editButtonX = deleteButtonX - scaledConstants.buttonSpacing - scaledConstants.buttonSize
        let backgroundY = (frame.height - scaledConstants.buttonBackgroundSize) / 2
        
        // Setup edit button and background
        setupEditButton(at: editButtonX, backgroundY: backgroundY, config: buttonIconConfig)
        
        // Setup delete button and background
        setupDeleteButton(at: deleteButtonX, backgroundY: backgroundY, config: buttonIconConfig)
    }
    
    private func setupButtonWithBackground(
        button: NSButton,
        background: NSView,
        at x: CGFloat,
        backgroundY: CGFloat,
        iconName: String,
        accessibilityDescription: String,
        action: Selector,
        config: NSImage.SymbolConfiguration
    ) {
        // Setup background
        let backgroundX = x + scaledConstants.buttonBackgroundEdgeInset
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.15).cgColor
        background.layer?.cornerRadius = scaledConstants.buttonBackgroundSize / 2
        background.frame = NSRect(
            x: backgroundX,
            y: backgroundY,
            width: scaledConstants.buttonBackgroundSize,
            height: scaledConstants.buttonBackgroundSize
        )
        background.isHidden = true
        addSubview(background)
        
        // Setup button
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: accessibilityDescription)?.withSymbolConfiguration(config)
        button.bezelStyle = .roundRect
        button.isBordered = false
        button.frame = NSRect(
            x: x,
            y: scaledConstants.centeredY(for: scaledConstants.buttonSize),
            width: scaledConstants.buttonSize,
            height: scaledConstants.buttonSize
        )
        button.target = self
        button.action = action
        button.isHidden = true
        button.alphaValue = 1.0
        addSubview(button)
    }
    
    private func setupEditButton(at x: CGFloat, backgroundY: CGFloat, config: NSImage.SymbolConfiguration) {
        setupButtonWithBackground(
            button: editButton,
            background: editButtonBackground,
            at: x,
            backgroundY: backgroundY,
            iconName: "pencil",
            accessibilityDescription: "Edit",
            action: #selector(editTapped),
            config: config
        )
    }
    
    private func setupDeleteButton(at x: CGFloat, backgroundY: CGFloat, config: NSImage.SymbolConfiguration) {
        setupButtonWithBackground(
            button: deleteButton,
            background: deleteButtonBackground,
            at: x,
            backgroundY: backgroundY,
            iconName: "trash",
            accessibilityDescription: "Delete",
            action: #selector(deleteTapped),
            config: config
        )
    }

    private func setupTrackingArea() {
        // Use .zero rect with .inVisibleRect to automatically track the visible bounds
        // This avoids accessing bounds during layout cycles
        trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateButtonVisibility()
        updateColors()
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        isEditButtonHovered = false
        isDeleteButtonHovered = false
        updateButtonVisibility()
        editButtonBackground.isHidden = true
        deleteButtonBackground.isHidden = true
        updateColors()
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        if hasEditDeleteButtons {
            if editButton.frame.contains(location) || deleteButton.frame.contains(location) {
                return
            }
        }

        onSelect()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        setupTrackingArea()
    }

    private func updateButtonVisibility() {
        if hasEditDeleteButtons {
            editButton.isHidden = !isHovered
            deleteButton.isHidden = !isHovered
        }
    }

    private func updateColors() {
        if isHovered {
            nameLabel.textColor = .white
            iconImageView.contentTintColor = .white
            checkmarkImageView.contentTintColor = .white
            if hasEditDeleteButtons {
                editButton.contentTintColor = .white
                deleteButton.contentTintColor = .white
            }
        } else {
            nameLabel.textColor = .labelColor
            iconImageView.contentTintColor = .labelColor
            checkmarkImageView.contentTintColor = .labelColor
            if hasEditDeleteButtons {
                editButton.contentTintColor = nil
                deleteButton.contentTintColor = nil
            }
        }
    }

    @objc private func editTapped() {
        onEdit?()
    }

    @objc private func deleteTapped() {
        onDelete?()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if isHovered {
            NSGraphicsContext.saveGraphicsState()

            let hoverColor = NSColor(.accentColor)
            hoverColor.setFill()

            let cornerRadius: CGFloat
            if #available(macOS 26.0, *) {
                cornerRadius = 8.0 * fontScale
            } else {
                cornerRadius = 4.0 * fontScale
            }

            // Use frame dimensions instead of bounds to avoid layout recursion
            let viewWidth = frame.width
            let viewHeight = frame.height
            let hoverWidth = viewWidth - (scaledConstants.hoverEdgeInset * 2)
            let insetRect = NSRect(x: scaledConstants.hoverEdgeInset, y: 0, width: hoverWidth, height: viewHeight)
            let path = NSBezierPath(roundedRect: insetRect, xRadius: cornerRadius, yRadius: cornerRadius)
            path.fill()

            NSGraphicsContext.restoreGraphicsState()
        }
    }

    override func mouseMoved(with event: NSEvent) {
        guard hasEditDeleteButtons else { return }

        let location = convert(event.locationInWindow, from: nil)

        if editButton.frame.contains(location) && !editButton.isHidden {
            updateButtonHoverState(editHovered: true, deleteHovered: false, trashFilled: false)
        } else if deleteButton.frame.contains(location) && !deleteButton.isHidden {
            updateButtonHoverState(editHovered: false, deleteHovered: true, trashFilled: true)
        } else {
            updateButtonHoverState(editHovered: false, deleteHovered: false, trashFilled: false)
        }

        if isHovered {
            editButton.contentTintColor = .white
            deleteButton.contentTintColor = .white
        }
    }
    
    private func updateButtonHoverState(editHovered: Bool, deleteHovered: Bool, trashFilled: Bool) {
        isEditButtonHovered = editHovered
        isDeleteButtonHovered = deleteHovered
        editButtonBackground.isHidden = !editHovered
        deleteButtonBackground.isHidden = !deleteHovered
        
        let buttonIconConfig = NSImage.SymbolConfiguration(pointSize: scaledConstants.buttonIconSize, weight: .medium)
        let trashIcon = trashFilled ? "trash.fill" : "trash"
        deleteButton.image = NSImage(systemSymbolName: trashIcon, accessibilityDescription: "Delete")?.withSymbolConfiguration(buttonIconConfig)
    }
}
