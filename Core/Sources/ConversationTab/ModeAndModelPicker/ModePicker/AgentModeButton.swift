import AppKit
import ConversationServiceProvider
import Persist
import SharedUIComponents
import SwiftUI

// MARK: - Custom NSButton that accepts clicks anywhere within its bounds
class ClickThroughButton: NSButton {
    override func hitTest(_ point: NSPoint) -> NSView? {
        // If the point is within our bounds, return self (the button)
        // This ensures clicks on subviews are handled by the button
        if self.bounds.contains(point) {
            return self
        }
        return super.hitTest(point)
    }
}

// MARK: - Agent Mode Button

struct AgentModeButton: NSViewRepresentable {
    @StateObject private var fontScaleManager = FontScaleManager.shared

    private var fontScale: Double {
        fontScaleManager.currentScale
    }

    let title: String
    let isSelected: Bool
    let activeBackground: Color
    let activeTextColor: Color
    let inactiveTextColor: Color
    let chatMode: String
    let builtInAgentModes: [ConversationMode]
    let customAgents: [ConversationMode]
    let selectedAgent: ConversationMode
    let selectedIconName: String?
    let isCustomAgentEnabled: Bool
    let onSelectAgent: (ConversationMode) -> Void
    let onEditAgent: (ConversationMode) -> Void
    let onDeleteAgent: (ConversationMode) -> Void
    let onCreateAgent: () -> Void

    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false

        let button = ClickThroughButton()
        button.title = ""
        button.bezelStyle = .inline
        button.setButtonType(.momentaryPushIn)
        button.isBordered = false
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked(_:))
        button.translatesAutoresizingMaskIntoConstraints = false

        // Create icon for agent mode
        let iconImageView = NSImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.imageScaling = .scaleProportionallyDown

        // Create chevron icon
        let chevronView = NSImageView()
        let chevronImage = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)
        let symbolConfig = NSImage.SymbolConfiguration(pointSize: 9 * fontScale, weight: .bold)
        chevronView.image = chevronImage?.withSymbolConfiguration(symbolConfig)
        chevronView.translatesAutoresizingMaskIntoConstraints = false
        chevronView.isHidden = !isCustomAgentEnabled

        // Create title label
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = NSFont.systemFont(ofSize: 12 * fontScale)
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        titleLabel.drawsBackground = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.alignment = .center
        titleLabel.usesSingleLineMode = true
        titleLabel.lineBreakMode = .byClipping

        // Create horizontal stack with icon, title, and chevron
        let stackView = NSStackView(views: [iconImageView, titleLabel, chevronView])
        stackView.orientation = .horizontal
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = .centerY
        stackView.setHuggingPriority(.required, for: .horizontal)
        stackView.setContentCompressionResistancePriority(.required, for: .horizontal)

        // Set custom spacing between title and chevron
        stackView.setCustomSpacing(3 * fontScale, after: titleLabel)

        button.addSubview(stackView)
        containerView.addSubview(button)

        let stackLeadingConstraint = stackView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 6 * fontScale)
        let stackTrailingConstraint = stackView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -6 * fontScale)
        let stackTopConstraint = stackView.topAnchor.constraint(equalTo: button.topAnchor, constant: 2 * fontScale)
        let stackBottomConstraint = stackView.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -2 * fontScale)
        let iconWidthConstraint = iconImageView.widthAnchor.constraint(equalToConstant: 16 * fontScale)
        let iconHeightConstraint = iconImageView.heightAnchor.constraint(equalToConstant: 16 * fontScale)
        let chevronWidthConstraint = chevronView.widthAnchor.constraint(equalToConstant: 9 * fontScale)
        let chevronHeightConstraint = chevronView.heightAnchor.constraint(equalToConstant: 9 * fontScale)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            button.topAnchor.constraint(equalTo: containerView.topAnchor),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            stackLeadingConstraint,
            stackTrailingConstraint,
            stackTopConstraint,
            stackBottomConstraint,

            iconWidthConstraint,
            iconHeightConstraint,

            chevronWidthConstraint,
            chevronHeightConstraint,
        ])

        context.coordinator.button = button
        context.coordinator.titleLabel = titleLabel
        context.coordinator.iconImageView = iconImageView
        context.coordinator.chevronView = chevronView
        context.coordinator.stackView = stackView
        context.coordinator.stackLeadingConstraint = stackLeadingConstraint
        context.coordinator.stackTrailingConstraint = stackTrailingConstraint
        context.coordinator.stackTopConstraint = stackTopConstraint
        context.coordinator.stackBottomConstraint = stackBottomConstraint
        context.coordinator.iconWidthConstraint = iconWidthConstraint
        context.coordinator.iconHeightConstraint = iconHeightConstraint
        context.coordinator.chevronWidthConstraint = chevronWidthConstraint
        context.coordinator.chevronHeightConstraint = chevronHeightConstraint

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let button = context.coordinator.button,
              let titleLabel = context.coordinator.titleLabel,
              let iconImageView = context.coordinator.iconImageView,
              let chevronView = context.coordinator.chevronView,
              let stackView = context.coordinator.stackView else { return }

        titleLabel.stringValue = title
        titleLabel.font = NSFont.systemFont(ofSize: 12 * fontScale)
        context.coordinator.chatMode = chatMode
        context.coordinator.builtInAgentModes = builtInAgentModes
        context.coordinator.customAgents = customAgents
        context.coordinator.selectedAgent = selectedAgent
        context.coordinator.isSelected = isSelected
        context.coordinator.isCustomAgentEnabled = isCustomAgentEnabled
        context.coordinator.fontScale = fontScale

        // Update constraints for scaling
        context.coordinator.stackLeadingConstraint?.constant = 6 * fontScale
        context.coordinator.stackTrailingConstraint?.constant = -6 * fontScale
        context.coordinator.stackTopConstraint?.constant = 2 * fontScale
        context.coordinator.stackBottomConstraint?.constant = -2 * fontScale
        context.coordinator.iconWidthConstraint?.constant = 16 * fontScale
        context.coordinator.iconHeightConstraint?.constant = 16 * fontScale
        context.coordinator.chevronWidthConstraint?.constant = 9 * fontScale
        context.coordinator.chevronHeightConstraint?.constant = 9 * fontScale
        stackView.spacing = 0

        // Update custom spacing between title and chevron
        stackView.setCustomSpacing(3 * fontScale, after: titleLabel)

        // Update chevron visibility based on feature flag and policy
        chevronView.isHidden = !isCustomAgentEnabled

        // Update icon based on selected agent mode
        if let iconName = selectedIconName {
            iconImageView.isHidden = false
            iconImageView.image = createIconImage(named: iconName, pointSize: 16 * fontScale)
        } else {
            // No icon for custom agents
            iconImageView.isHidden = true
            iconImageView.image = nil
        }

        // Update chevron icon with scaled size
        chevronView.image = createSFSymbolImage(named: "chevron.down", pointSize: 9 * fontScale, weight: .bold)

        // Update button appearance based on selection
        if isSelected {
            button.layer?.backgroundColor = NSColor(activeBackground).cgColor
            titleLabel.textColor = NSColor(activeTextColor)
            iconImageView.contentTintColor = NSColor(activeTextColor)
            chevronView.contentTintColor = NSColor(activeTextColor)

            // Remove existing shadows before adding new ones
            button.layer?.shadowOpacity = 0

            // Add shadows
            button.shadow = {
                let shadow = NSShadow()
                shadow.shadowColor = NSColor.black.withAlphaComponent(0.05)
                shadow.shadowOffset = NSSize(width: 0, height: -1)
                shadow.shadowBlurRadius = 0.375
                return shadow
            }()

            // For the second shadow, we can add a sublayer or just use one.
            // For simplicity, we will just use one for now. A second shadow can be added with a sublayer if needed.

            // Add overlay
            button.layer?.borderColor = NSColor.black.withAlphaComponent(0.02).cgColor
            button.layer?.borderWidth = 0.5

        } else {
            button.layer?.backgroundColor = NSColor.clear.cgColor
            titleLabel.textColor = NSColor(inactiveTextColor)
            iconImageView.contentTintColor = NSColor(inactiveTextColor)
            chevronView.contentTintColor = NSColor(inactiveTextColor)
            button.shadow = nil
            button.layer?.borderColor = NSColor.clear.cgColor
            button.layer?.borderWidth = 0
        }
        button.wantsLayer = true
        button.layer?.cornerRadius = 10 * fontScale
        button.layer?.cornerCurve = .continuous
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            chatMode: chatMode,
            builtInAgentModes: builtInAgentModes,
            customAgents: customAgents,
            selectedAgent: selectedAgent,
            isSelected: isSelected,
            isCustomAgentEnabled: isCustomAgentEnabled,
            fontScale: fontScale,
            onSelectAgent: onSelectAgent,
            onEditAgent: onEditAgent,
            onDeleteAgent: onDeleteAgent,
            onCreateAgent: onCreateAgent
        )
    }

    // MARK: - Helper Methods for Image Creation

    /// Creates an icon image - either a custom asset or SF Symbol
    private func createIconImage(named iconName: String, pointSize: CGFloat) -> NSImage? {
        if iconName == AgentModeIcon.agent {
            return createResizedCustomImage(named: iconName, targetSize: pointSize)
        } else {
            return createSFSymbolImage(named: iconName, pointSize: pointSize, weight: .bold)
        }
    }

    /// Creates a resized custom image (non-SF Symbol) with template rendering
    private func createResizedCustomImage(named imageName: String, targetSize: CGFloat) -> NSImage? {
        guard let image = NSImage(named: imageName) else { return nil }

        let size = NSSize(width: targetSize, height: targetSize)
        let resizedImage = NSImage(size: size)
        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1.0
        )
        resizedImage.unlockFocus()
        resizedImage.isTemplate = true
        return resizedImage
    }

    /// Creates an SF Symbol image with the specified configuration
    private func createSFSymbolImage(named symbolName: String, pointSize: CGFloat, weight: NSFont.Weight) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
    }

    class Coordinator: NSObject {
        var chatMode: String
        var builtInAgentModes: [ConversationMode]
        var customAgents: [ConversationMode]
        var selectedAgent: ConversationMode
        var isSelected: Bool
        var isCustomAgentEnabled: Bool
        var fontScale: Double
        var button: NSButton?
        var titleLabel: NSTextField?
        var iconImageView: NSImageView?
        var chevronView: NSImageView?
        var stackView: NSStackView?
        var stackLeadingConstraint: NSLayoutConstraint?
        var stackTrailingConstraint: NSLayoutConstraint?
        var stackTopConstraint: NSLayoutConstraint?
        var stackBottomConstraint: NSLayoutConstraint?
        var iconWidthConstraint: NSLayoutConstraint?
        var iconHeightConstraint: NSLayoutConstraint?
        var chevronWidthConstraint: NSLayoutConstraint?
        var chevronHeightConstraint: NSLayoutConstraint?
        let onSelectAgent: (ConversationMode) -> Void
        let onEditAgent: (ConversationMode) -> Void
        let onDeleteAgent: (ConversationMode) -> Void
        let onCreateAgent: () -> Void

        init(
            chatMode: String,
            builtInAgentModes: [ConversationMode],
            customAgents: [ConversationMode],
            selectedAgent: ConversationMode,
            isSelected: Bool,
            isCustomAgentEnabled: Bool,
            fontScale: Double,
            onSelectAgent: @escaping (ConversationMode) -> Void,
            onEditAgent: @escaping (ConversationMode) -> Void,
            onDeleteAgent: @escaping (ConversationMode) -> Void,
            onCreateAgent: @escaping () -> Void
        ) {
            self.chatMode = chatMode
            self.builtInAgentModes = builtInAgentModes
            self.customAgents = customAgents
            self.selectedAgent = selectedAgent
            self.isSelected = isSelected
            self.isCustomAgentEnabled = isCustomAgentEnabled
            self.fontScale = fontScale
            self.onSelectAgent = onSelectAgent
            self.onEditAgent = onEditAgent
            self.onDeleteAgent = onDeleteAgent
            self.onCreateAgent = onCreateAgent
        }

        @objc func buttonClicked(_ sender: NSButton) {
            // If in Ask mode, switch to agent mode
            if chatMode == ChatMode.Ask.rawValue {
                // Restore the previously selected agent from AppState
                let savedSubMode = AppState.shared.getSelectedAgentSubMode()

                // Try to find the saved agent
                let agent = builtInAgentModes.first(where: { $0.id == savedSubMode })
                    ?? customAgents.first(where: { $0.id == savedSubMode })
                    ?? builtInAgentModes.first
                
                if let agent = agent {
                    onSelectAgent(agent)
                }
            } else {
                // If in Agent mode and custom agent is enabled, show the menu
                // If custom agent is disabled, do nothing
                if isCustomAgentEnabled {
                    showMenu(sender)
                }
            }
        }

        @objc func showMenu(_ sender: NSButton) {
            let menuBuilder = AgentModeMenu(
                builtInAgentModes: builtInAgentModes,
                customAgents: customAgents,
                selectedAgent: selectedAgent,
                fontScale: fontScale,
                onSelectAgent: onSelectAgent,
                onEditAgent: onEditAgent,
                onDeleteAgent: onDeleteAgent,
                onCreateAgent: onCreateAgent
            )
            menuBuilder.showMenu(relativeTo: sender)
        }
    }
}
