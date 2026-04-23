import AppKit

// MARK: - Model Menu Item View

class ModelPickerMenuItem: NSView {
    private let fontScale: Double
    private let model: LLMModel
    private let isSelected: Bool
    private let multiplierText: String
    private let onSelect: () -> Void
    private let onHover: ((LLMModel, NSRect) -> Void)?
    private let onHoverExit: (() -> Void)?

    private var wasHighlighted = false

    private let nameLabel = NSTextField(labelWithString: "")
    private let multiplierLabel = NSTextField(labelWithString: "")
    private let checkmarkImageView = NSImageView()
    private let warningImageView = NSImageView()

    private struct LayoutConstants {
        let fontScale: Double

        var menuHeight: CGFloat { 22 * fontScale }
        var checkmarkSize: CGFloat { 13 * fontScale }
        var hoverEdgeInset: CGFloat { 5 * fontScale }
        var fontSize: CGFloat { 13 * fontScale }
        var leadingPadding: CGFloat { 9 * fontScale }
        var trailingPadding: CGFloat { 9 * fontScale }
        var checkmarkToText: CGFloat { 5 * fontScale }
        var nameToMultiplier: CGFloat { 8 * fontScale }
    }

    private lazy var constants = LayoutConstants(fontScale: fontScale)

    init(
        model: LLMModel,
        isSelected: Bool,
        multiplierText: String,
        fontScale: Double,
        fixedWidth: CGFloat,
        onSelect: @escaping () -> Void,
        onHover: ((LLMModel, NSRect) -> Void)? = nil,
        onHoverExit: (() -> Void)? = nil
    ) {
        self.model = model
        self.isSelected = isSelected
        self.multiplierText = multiplierText
        self.fontScale = fontScale
        self.onSelect = onSelect
        self.onHover = onHover
        self.onHoverExit = onHoverExit

        let constants = LayoutConstants(fontScale: fontScale)
        super.init(
            frame: NSRect(x: 0, y: 0, width: fixedWidth, height: constants.menuHeight)
        )
        setupView()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Highlight state (driven by NSMenu)

    private var isHighlighted: Bool {
        enclosingMenuItem?.isHighlighted ?? false
    }

    private func setupView() {
        wantsLayer = true
        layer?.masksToBounds = true

        setupCheckmark()
        setupWarningIcon()
        setupLabels()
    }

    private func setupCheckmark() {
        let config = NSImage.SymbolConfiguration(
            pointSize: constants.checkmarkSize,
            weight: .medium
        )
        checkmarkImageView.image = NSImage(
            systemSymbolName: "checkmark",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config)
        checkmarkImageView.contentTintColor = .labelColor
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.isHidden = !isSelected || model.degradationReason != nil
        addSubview(checkmarkImageView)

        NSLayoutConstraint.activate([
            checkmarkImageView.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: constants.leadingPadding
            ),
            checkmarkImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmarkImageView.widthAnchor.constraint(
                equalToConstant: constants.checkmarkSize
            ),
            checkmarkImageView.heightAnchor.constraint(
                equalToConstant: constants.checkmarkSize
            ),
        ])
    }

    private func setupWarningIcon() {
        guard model.degradationReason != nil else { return }

        let config = NSImage.SymbolConfiguration(
            pointSize: constants.checkmarkSize,
            weight: .medium
        )
        warningImageView.image = NSImage(
            systemSymbolName: "exclamationmark.triangle",
            accessibilityDescription: "Degraded"
        )?.withSymbolConfiguration(config)
        warningImageView.contentTintColor = .labelColor
        warningImageView.translatesAutoresizingMaskIntoConstraints = false
        warningImageView.isHidden = false
        addSubview(warningImageView)

        NSLayoutConstraint.activate([
            warningImageView.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: constants.leadingPadding
            ),
            warningImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            warningImageView.widthAnchor.constraint(
                equalToConstant: constants.checkmarkSize
            ),
            warningImageView.heightAnchor.constraint(
                equalToConstant: constants.checkmarkSize
            ),
        ])
    }

    private func setupLabels() {
        let displayName = model.displayName ?? model.modelName

        // Name label — left-aligned, truncates tail, fills remaining space
        nameLabel.stringValue = displayName
        nameLabel.font = NSFont.systemFont(ofSize: constants.fontSize, weight: .regular)
        nameLabel.textColor = .labelColor
        nameLabel.isEditable = false
        nameLabel.isBordered = false
        nameLabel.backgroundColor = .clear
        nameLabel.drawsBackground = false
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(nameLabel)

        // Multiplier label — right-aligned, never truncates
        multiplierLabel.stringValue = multiplierText
        multiplierLabel.font = NSFont.systemFont(
            ofSize: constants.fontSize, weight: .regular
        )
        multiplierLabel.textColor = .secondaryLabelColor
        multiplierLabel.isEditable = false
        multiplierLabel.isBordered = false
        multiplierLabel.backgroundColor = .clear
        multiplierLabel.drawsBackground = false
        multiplierLabel.alignment = .right
        multiplierLabel.translatesAutoresizingMaskIntoConstraints = false
        multiplierLabel.setContentHuggingPriority(.required, for: .horizontal)
        multiplierLabel.setContentCompressionResistancePriority(
            .required, for: .horizontal
        )
        multiplierLabel.isHidden = multiplierText.isEmpty
        addSubview(multiplierLabel)

        let textLeading = checkmarkImageView.trailingAnchor

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(
                equalTo: textLeading, constant: constants.checkmarkToText
            ),
            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            multiplierLabel.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -constants.trailingPadding
            ),
            multiplierLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            nameLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: multiplierLabel.leadingAnchor,
                constant: -constants.nameToMultiplier
            ),
        ])
    }

    // MARK: - Mouse handling

    override func mouseUp(with _: NSEvent) {
        onSelect()
    }

    // MARK: - Keyboard selection

    /// Called by the menu's `performKeyEquivalent` when Return/Enter is pressed
    /// while this item is highlighted. Custom-view menu items don't receive
    /// the default NSMenu action, so the menu triggers selection explicitly.
    func performSelect() {
        onSelect()
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let confirmKeyCodes: Set<UInt16> = [
            36, // return
            76, // enter (numpad)
        ]
        if confirmKeyCodes.contains(event.keyCode) {
            onSelect()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Drawing (highlight driven by NSMenu)

    private func updateColors() {
        let highlighted = isHighlighted
        if highlighted {
            nameLabel.textColor = .white
            multiplierLabel.textColor = .white.withAlphaComponent(0.8)
            checkmarkImageView.contentTintColor = .white
            warningImageView.contentTintColor = .white
        } else {
            nameLabel.textColor = .labelColor
            multiplierLabel.textColor = .secondaryLabelColor
            checkmarkImageView.contentTintColor = .labelColor
            warningImageView.contentTintColor = .labelColor
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let highlighted = isHighlighted

        // Trigger detail panel on highlight change
        if highlighted != wasHighlighted {
            wasHighlighted = highlighted
            if highlighted {
                if let onHover = onHover {
                    let screenRect =
                        window?.convertToScreen(convert(bounds, to: nil)) ?? .zero
                    onHover(model, screenRect)
                }
            } else {
                onHoverExit?()
            }
        }

        updateColors()

        if highlighted {
            ModelMenuItemFormatter.drawMenuItemHighlight(
                in: frame,
                fontScale: fontScale,
                hoverEdgeInset: constants.hoverEdgeInset
            )
        }
    }

    // MARK: - Width Calculation

    static func calculateItemWidth(
        model: LLMModel,
        multiplierText: String,
        fontScale: Double
    ) -> CGFloat {
        let constants = LayoutConstants(fontScale: fontScale)
        let font = NSFont.systemFont(ofSize: constants.fontSize, weight: .regular)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let displayName = model.displayName ?? model.modelName
        let nameWidth = (displayName as NSString).size(withAttributes: attrs).width

        var width = constants.leadingPadding + constants.checkmarkSize
            + constants.checkmarkToText + ceil(nameWidth) + constants.trailingPadding

        if !multiplierText.isEmpty {
            let multWidth = ceil(
                (multiplierText as NSString).size(withAttributes: attrs).width
            )
            width += constants.nameToMultiplier + multWidth
        }

        return width
    }
}
