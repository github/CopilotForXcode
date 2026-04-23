import AppKit
import SwiftUI

// MARK: - Model Picker Button (NSViewRepresentable)

struct ModelPickerButton: NSViewRepresentable {
    let selectedModel: LLMModel?
    let copilotModels: [LLMModel]
    let byokModels: [LLMModel]
    let isBYOKFFEnabled: Bool
    let currentCache: ScopeCache
    let fontScale: Double

    func makeNSView(context: Context) -> NSView {
        let container = ModelPickerContainerView(fontScale: fontScale)
        container.translatesAutoresizingMaskIntoConstraints = false

        let button = ClickThroughButton()
        button.title = ""
        button.bezelStyle = .inline
        button.setButtonType(.momentaryPushIn)
        button.isBordered = false
        button.target = context.coordinator
        button.action = #selector(Coordinator.buttonClicked(_:))
        button.translatesAutoresizingMaskIntoConstraints = false
        button.wantsLayer = true

        let titleLabel = NSTextField(labelWithString: "")
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        titleLabel.drawsBackground = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.alignment = .center
        titleLabel.usesSingleLineMode = true
        titleLabel.lineBreakMode = .byTruncatingMiddle

        let chevronView = NSImageView()
        let chevronImage = NSImage(
            systemSymbolName: "chevron.down",
            accessibilityDescription: nil
        )
        let symbolConfig = NSImage.SymbolConfiguration(
            pointSize: 8 * fontScale, weight: .semibold
        )
        chevronView.image = chevronImage?.withSymbolConfiguration(symbolConfig)
        chevronView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = NSStackView(views: [titleLabel, chevronView])
        stackView.orientation = .horizontal
        stackView.spacing = 2 * fontScale
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.alignment = .centerY
        stackView.setHuggingPriority(.required, for: .horizontal)

        button.addSubview(stackView)
        container.addSubview(button)

        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.topAnchor.constraint(equalTo: container.topAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stackView.leadingAnchor.constraint(
                equalTo: button.leadingAnchor, constant: 6 * fontScale
            ),
            stackView.trailingAnchor.constraint(
                equalTo: button.trailingAnchor, constant: -6 * fontScale
            ),
            stackView.topAnchor.constraint(
                equalTo: button.topAnchor, constant: 2 * fontScale
            ),
            stackView.bottomAnchor.constraint(
                equalTo: button.bottomAnchor, constant: -2 * fontScale
            ),

            chevronView.widthAnchor.constraint(equalToConstant: 8 * fontScale),
            chevronView.heightAnchor.constraint(equalToConstant: 8 * fontScale),
        ])

        context.coordinator.button = button
        context.coordinator.titleLabel = titleLabel
        context.coordinator.chevronView = chevronView

        // Setup tracking for hover
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: context.coordinator,
            userInfo: nil
        )
        button.addTrackingArea(trackingArea)
        context.coordinator.trackingArea = trackingArea

        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let titleLabel = context.coordinator.titleLabel,
              let button = context.coordinator.button,
              let chevronView = context.coordinator.chevronView
        else { return }

        let label = selectedModelLabel
        titleLabel.stringValue = label
        titleLabel.font = NSFont.systemFont(ofSize: 13 * fontScale)
        titleLabel.textColor = .labelColor

        let chevronConfig = NSImage.SymbolConfiguration(
            pointSize: 8 * fontScale, weight: .semibold
        )
        chevronView.image = NSImage(
            systemSymbolName: "chevron.down",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(chevronConfig)
        chevronView.contentTintColor = .tertiaryLabelColor

        // Update coordinator data
        context.coordinator.selectedModel = selectedModel
        context.coordinator.copilotModels = copilotModels
        context.coordinator.byokModels = byokModels
        context.coordinator.isBYOKFFEnabled = isBYOKFFEnabled
        context.coordinator.currentCache = currentCache
        context.coordinator.fontScale = fontScale

        // Hover background
        let isHovered = context.coordinator.isHovered
        button.layer?.backgroundColor = isHovered
            ? NSColor.gray.withAlphaComponent(0.1).cgColor
            : NSColor.clear.cgColor
        button.layer?.cornerRadius = 5 * fontScale
        button.layer?.cornerCurve = .continuous

        // Ideal width based on text (allows shrinking when parent is tight)
        let textWidth = labelWidth(label: label)
        context.coordinator.widthConstraint?.constant = textWidth
        if context.coordinator.widthConstraint == nil {
            let wc = nsView.widthAnchor.constraint(lessThanOrEqualToConstant: textWidth)
            wc.priority = .defaultHigh
            wc.isActive = true
            context.coordinator.widthConstraint = wc
        }

        // Report ideal width so SwiftUI can size us properly
        if let container = nsView as? ModelPickerContainerView {
            container.fontScale = fontScale
            container.idealWidth = textWidth
            container.invalidateIntrinsicContentSize()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectedModel: selectedModel,
            copilotModels: copilotModels,
            byokModels: byokModels,
            isBYOKFFEnabled: isBYOKFFEnabled,
            currentCache: currentCache,
            fontScale: fontScale
        )
    }

    private var selectedModelLabel: String {
        let name = selectedModel?.displayName ?? selectedModel?.modelName ?? ""
        if selectedModel?.degradationReason != nil {
            return "\u{26A0} \(name)"
        }
        return name
    }

    private func labelWidth(label: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 13 * fontScale)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let textWidth = ceil((label as NSString).size(withAttributes: attrs).width)
        // text + left padding(6) + right padding(6) + chevron(8) + stack spacing(2) + text field internal margin(6)
        return textWidth + 28 * fontScale
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        var selectedModel: LLMModel?
        var copilotModels: [LLMModel]
        var byokModels: [LLMModel]
        var isBYOKFFEnabled: Bool
        var currentCache: ScopeCache
        var fontScale: Double

        var button: NSButton?
        var titleLabel: NSTextField?
        var chevronView: NSImageView?
        var trackingArea: NSTrackingArea?
        var widthConstraint: NSLayoutConstraint?
        var isHovered = false

        init(
            selectedModel: LLMModel?,
            copilotModels: [LLMModel],
            byokModels: [LLMModel],
            isBYOKFFEnabled: Bool,
            currentCache: ScopeCache,
            fontScale: Double
        ) {
            self.selectedModel = selectedModel
            self.copilotModels = copilotModels
            self.byokModels = byokModels
            self.isBYOKFFEnabled = isBYOKFFEnabled
            self.currentCache = currentCache
            self.fontScale = fontScale
        }

        @objc func buttonClicked(_ sender: NSButton) {
            let menuBuilder = ModelPickerMenu(
                selectedModel: selectedModel,
                copilotModels: copilotModels,
                byokModels: byokModels,
                isBYOKFFEnabled: isBYOKFFEnabled,
                currentCache: currentCache,
                fontScale: fontScale
            )
            menuBuilder.showMenu(relativeTo: sender)
        }

        @objc(mouseEntered:) func mouseEntered(with event: NSEvent) {
            isHovered = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                button?.animator().layer?.backgroundColor = NSColor.gray
                    .withAlphaComponent(0.1).cgColor
            }
            NSCursor.pointingHand.push()
        }

        @objc(mouseExited:) func mouseExited(with event: NSEvent) {
            isHovered = false
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.15
                button?.animator().layer?.backgroundColor = NSColor.clear.cgColor
            }
            NSCursor.pop()
        }
    }
}

// MARK: - Container view that constrains intrinsic height

private class ModelPickerContainerView: NSView {
    var fontScale: Double
    var idealWidth: CGFloat = NSView.noIntrinsicMetric

    init(fontScale: Double) {
        self.fontScale = fontScale
        super.init(frame: .zero)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.defaultHigh, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {
        let height = 20 * fontScale
        return NSSize(width: idealWidth, height: height)
    }
}
