import AppKit

// MARK: - Floating Detail Panel (shown on menu item hover)

class ModelPickerDetailPanel: NSPanel {
    static let shared = ModelPickerDetailPanel()

    private let contentLabel = NSTextField(wrappingLabelWithString: "")
    private let nameLabel = NSTextField(labelWithString: "")
    private let separatorView = NSBox()
    private let containerView = NSView()
    private var hideTimer: Timer?

    private var containerConstraints: [NSLayoutConstraint] = []
    private var currentFontScale: CGFloat = 1.0

    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        self.isFloatingPanel = true
        self.level = .popUpMenu + 1
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hidesOnDeactivate = false
        self.hasShadow = true
        self.isMovable = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        setupContent()
    }

    private func setupContent() {
        let visual = NSVisualEffectView()
        visual.material = .popover
        visual.state = .active
        visual.wantsLayer = true
        visual.layer?.cornerRadius = 8
        visual.layer?.masksToBounds = true
        visual.translatesAutoresizingMaskIntoConstraints = false

        containerView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.textColor = .labelColor
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.backgroundColor = .clear
        nameLabel.drawsBackground = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.lineBreakMode = .byTruncatingTail

        separatorView.boxType = .separator
        separatorView.translatesAutoresizingMaskIntoConstraints = false

        contentLabel.isEditable = false
        contentLabel.isBordered = false
        contentLabel.backgroundColor = .clear
        contentLabel.drawsBackground = false
        contentLabel.textColor = .secondaryLabelColor
        contentLabel.usesSingleLineMode = false
        contentLabel.maximumNumberOfLines = 0
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(nameLabel)
        containerView.addSubview(separatorView)
        containerView.addSubview(contentLabel)

        visual.addSubview(containerView)
        self.contentView = visual

        // Static constraints that don't depend on font scale
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            separatorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            separatorView.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor
            ),

            contentLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            contentLabel.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor
            ),
            contentLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        applyScaledConstraints(to: visual, fontScale: 1.0)
    }

    private func applyScaledConstraints(
        to visual: NSView,
        fontScale: CGFloat
    ) {
        NSLayoutConstraint.deactivate(containerConstraints)

        let padding: CGFloat = 10 * fontScale
        let horizontalPadding: CGFloat = 12 * fontScale
        let spacing: CGFloat = 6 * fontScale

        containerConstraints = [
            containerView.topAnchor.constraint(
                equalTo: visual.topAnchor, constant: padding
            ),
            containerView.leadingAnchor.constraint(
                equalTo: visual.leadingAnchor, constant: horizontalPadding
            ),
            containerView.trailingAnchor.constraint(
                equalTo: visual.trailingAnchor, constant: -horizontalPadding
            ),
            containerView.bottomAnchor.constraint(
                equalTo: visual.bottomAnchor, constant: -padding
            ),
            separatorView.topAnchor.constraint(
                equalTo: nameLabel.bottomAnchor, constant: spacing
            ),
            contentLabel.topAnchor.constraint(
                equalTo: separatorView.bottomAnchor, constant: spacing
            ),
        ]

        NSLayoutConstraint.activate(containerConstraints)

        nameLabel.font = NSFont.systemFont(
            ofSize: 13 * fontScale, weight: .semibold
        )
        contentLabel.font = NSFont.systemFont(ofSize: 12 * fontScale)
        contentLabel.preferredMaxLayoutWidth = 236 * fontScale

        visual.layer?.cornerRadius = 8 * fontScale

        currentFontScale = fontScale
    }

    func show(
        for model: LLMModel,
        nearRect: NSRect,
        preferRight: Bool = true,
        fontScale: CGFloat = 1.0
    ) {
        hideTimer?.invalidate()
        hideTimer = nil

        if let visual = self.contentView {
            applyScaledConstraints(to: visual, fontScale: fontScale)
        }

        let displayName = model.displayName ?? model.modelName
        nameLabel.stringValue = displayName

        var details: [String] = []

        // Provider
        if let provider = model.providerName, !provider.isEmpty {
            details.append("Provider: \(provider)")
        }

        // Billing
        if let billing = model.billing {
            if billing.multiplier == 0 {
                details.append("Cost: Included")
            } else {
                let formatted = billing.multiplier
                    .truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", billing.multiplier)
                    : String(format: "%.2f", billing.multiplier)
                details.append("Cost: \(formatted)x premium")
            }
        }

        // Vision support
        if model.supportVision {
            details.append("Supports: Vision")
        }

        // Degradation
        if let reason = model.degradationReason {
            details.append("\n\u{26A0} \(reason)")
        }

        // Auto model description
        if model.isAutoModel {
            details = [
                "Automatically selects the best model for your request based on capacity and performance.",
                "\nCost may vary based on the selected model.",
            ]
        }

        contentLabel.stringValue = details.joined(separator: "\n")

        // Size to fit content
        let fittingSize = containerView.fittingSize
        let panelWidth: CGFloat = 260 * fontScale
        let panelHeight = fittingSize.height + 20 * fontScale

        let gap: CGFloat = 4 * fontScale
        var origin: NSPoint
        if preferRight {
            origin = NSPoint(
                x: nearRect.maxX + gap, y: nearRect.midY - panelHeight / 2
            )
        } else {
            origin = NSPoint(
                x: nearRect.minX - panelWidth - gap,
                y: nearRect.midY - panelHeight / 2
            )
        }

        // Find the screen that contains the menu item
        let menuScreen = NSScreen.screens.first(where: {
            $0.frame.contains(nearRect.origin)
        }) ?? NSScreen.main

        // Ensure the panel stays fully visible on that screen
        if let screen = menuScreen {
            let screenFrame = screen.visibleFrame
            if origin.x + panelWidth > screenFrame.maxX {
                origin.x = nearRect.minX - panelWidth - gap
            }
            if origin.x < screenFrame.minX {
                origin.x = nearRect.maxX + gap
            }
            // Clamp horizontally as last resort
            origin.x = max(origin.x, screenFrame.minX)
            origin.x = min(origin.x, screenFrame.maxX - panelWidth)
            // Clamp vertically
            origin.y = max(origin.y, screenFrame.minY)
            origin.y = min(origin.y, screenFrame.maxY - panelHeight)
        }

        setContentSize(NSSize(width: panelWidth, height: panelHeight))
        setFrameOrigin(origin)
        orderFront(nil)
    }

    func scheduleHide() {
        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.orderOut(nil)
        }
    }

    func cancelHide() {
        hideTimer?.invalidate()
        hideTimer = nil
    }

    override func close() {
        hideTimer?.invalidate()
        hideTimer = nil
        super.close()
    }
}
