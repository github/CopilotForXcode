import SwiftUI
import Foundation

// MARK: - QuotaSnapshot Model
public struct QuotaSnapshot {
    public var percentRemaining: Float
    public var unlimited: Bool
    public var overagePermitted: Bool
    
    public init(percentRemaining: Float, unlimited: Bool, overagePermitted: Bool) {
        self.percentRemaining = percentRemaining
        self.unlimited = unlimited
        self.overagePermitted = overagePermitted
    }
}

// MARK: - QuotaView Main Class
public class QuotaView: NSView {
    
    // MARK: - Properties
    private let chat: QuotaSnapshot
    private let completions: QuotaSnapshot
    private let premiumInteractions: QuotaSnapshot
    private let resetDate: String
    private let copilotPlan: String
    
    private var isFreeUser: Bool {
        return copilotPlan == "free"
    }
    
    private var isOrgUser: Bool {
        return copilotPlan == "business" || copilotPlan == "enterprise"
    }
    
    private var isFreeQuotaUsedUp: Bool {
        return chat.percentRemaining == 0 && completions.percentRemaining == 0
    }
    
    private var isFreeQuotaRemaining: Bool {
        return chat.percentRemaining > 25 && completions.percentRemaining > 25
    }
    
    // MARK: - Initialization
    public init(
        chat: QuotaSnapshot,
        completions: QuotaSnapshot,
        premiumInteractions: QuotaSnapshot,
        resetDate: String,
        copilotPlan: String
    ) {
        self.chat = chat
        self.completions = completions
        self.premiumInteractions = premiumInteractions
        self.resetDate = resetDate
        self.copilotPlan = copilotPlan
        
        super.init(frame: NSRect(x: 0, y: 0, width: Layout.viewWidth, height: 0))
        
        configureView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Configuration
    private func configureView() {
        autoresizingMask = [.width]
        setupView()
        
        let calculatedHeight = fittingSize.height
        frame = NSRect(x: 0, y: 0, width: Layout.viewWidth, height: calculatedHeight)
    }
    
    private func setupView() {
        let components = createViewComponents()
        addSubviewsToHierarchy(components)
        setupLayoutConstraints(components)
    }
    
    // MARK: - Component Creation
    private func createViewComponents() -> ViewComponents {
        return ViewComponents(
            titleContainer: createTitleContainer(),
            progressViews: createProgressViews(),
            statusMessageLabel: createStatusMessageLabel(),
            resetTextLabel: createResetTextLabel(),
            upsellLabel: createUpsellLabel()
        )
    }
    
    private func addSubviewsToHierarchy(_ components: ViewComponents) {
        addSubview(components.titleContainer)
        components.progressViews.forEach { addSubview($0) }
        if !isFreeUser {
            addSubview(components.statusMessageLabel)
        }
        addSubview(components.resetTextLabel)
        if !(isOrgUser || (isFreeUser && isFreeQuotaRemaining)) {
            addSubview(components.upsellLabel)
        }
    }
}

// MARK: - Title Section
extension QuotaView {
    private func createTitleContainer() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = createTitleLabel()
        let settingsButton = createSettingsButton()
        
        container.addSubview(titleLabel)
        container.addSubview(settingsButton)
        
        setupTitleConstraints(container: container, titleLabel: titleLabel, settingsButton: settingsButton)
        
        return container
    }
    
    private func createTitleLabel() -> NSTextField {
        let label = NSTextField(labelWithString: "Copilot Usage")
        label.font = NSFont.systemFont(ofSize: Style.titleFontSize, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .systemGray
        return label
    }
    
    private func createSettingsButton() -> HoverButton {
        let button = HoverButton()
        
        if let image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "Manage Copilot") {
            image.isTemplate = true
            button.image = image
        }
        
        button.imagePosition = .imageOnly
        button.alphaValue = Style.buttonAlphaValue
        button.toolTip = "Manage Copilot"
        button.setButtonType(.momentaryChange)
        button.isBordered = false
        button.translatesAutoresizingMaskIntoConstraints = false
        button.target = self
        button.action = #selector(openCopilotSettings)
        
        return button
    }
    
    private func setupTitleConstraints(container: NSView, titleLabel: NSTextField, settingsButton: HoverButton) {
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            
            settingsButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            settingsButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
            settingsButton.heightAnchor.constraint(equalToConstant: Layout.settingsButtonHoverSize),
            
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: settingsButton.leadingAnchor, constant: -Layout.settingsButtonSpacing)
        ])
    }
}

// MARK: - Progress Bars Section
extension QuotaView {
    private func createProgressViews() -> [NSView] {
        let completionsView = createProgressBarSection(
            title: "Code Completions",
            snapshot: completions
        )
        
        let chatView = createProgressBarSection(
            title: "Chat Messages",
            snapshot: chat
        )
        
        if isFreeUser {
            return [completionsView, chatView]
        }
        
        let premiumView = createProgressBarSection(
            title: "Premium Requests",
            snapshot: premiumInteractions
        )
        
        return [completionsView, chatView, premiumView]
    }
    
    private func createProgressBarSection(title: String, snapshot: QuotaSnapshot) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = createProgressTitleLabel(title: title)
        let percentageLabel = createPercentageLabel(snapshot: snapshot)
        
        container.addSubview(titleLabel)
        container.addSubview(percentageLabel)
        
        if !snapshot.unlimited {
            addProgressBar(to: container, snapshot: snapshot, titleLabel: titleLabel, percentageLabel: percentageLabel)
        } else {
            setupUnlimitedLayout(container: container, titleLabel: titleLabel, percentageLabel: percentageLabel)
        }
        
        return container
    }
    
    private func createProgressTitleLabel(title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: Style.progressFontSize, weight: .regular)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func createPercentageLabel(snapshot: QuotaSnapshot) -> NSTextField {
        let usedPercentage = (100.0 - snapshot.percentRemaining)
        let numberPart = usedPercentage.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", usedPercentage)
            : String(format: "%.1f", usedPercentage)
        let text = snapshot.unlimited ? "Included" : "\(numberPart)%"
        
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: Style.percentageFontSize, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        
        return label
    }
    
    private func addProgressBar(to container: NSView, snapshot: QuotaSnapshot, titleLabel: NSTextField, percentageLabel: NSTextField) {
        let usedPercentage = 100.0 - snapshot.percentRemaining
        let color = getProgressBarColor(for: usedPercentage)
        
        let progressBackground = createProgressBackground(color: color)
        let progressFill = createProgressFill(color: color, usedPercentage: usedPercentage)
        
        progressBackground.addSubview(progressFill)
        container.addSubview(progressBackground)
        
        setupProgressBarConstraints(
            container: container,
            titleLabel: titleLabel,
            percentageLabel: percentageLabel,
            progressBackground: progressBackground,
            progressFill: progressFill,
            usedPercentage: usedPercentage
        )
    }
    
    private func createProgressBackground(color: NSColor) -> NSView {
        let background = NSView()
        background.wantsLayer = true
        background.layer?.backgroundColor = color.cgColor.copy(alpha: Style.progressBarBackgroundAlpha)
        background.layer?.cornerRadius = Layout.progressBarCornerRadius
        background.translatesAutoresizingMaskIntoConstraints = false
        return background
    }
    
    private func createProgressFill(color: NSColor, usedPercentage: Float) -> NSView {
        let fill = NSView()
        fill.wantsLayer = true
        fill.translatesAutoresizingMaskIntoConstraints = false
        fill.layer?.backgroundColor = color.cgColor
        fill.layer?.cornerRadius = Layout.progressBarCornerRadius
        return fill
    }
    
    private func setupProgressBarConstraints(
        container: NSView,
        titleLabel: NSTextField,
        percentageLabel: NSTextField,
        progressBackground: NSView,
        progressFill: NSView,
        usedPercentage: Float
    ) {
        NSLayoutConstraint.activate([
            // Title and percentage on the same line
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: percentageLabel.leadingAnchor, constant: -Layout.percentageLabelSpacing),
            
            percentageLabel.topAnchor.constraint(equalTo: container.topAnchor),
            percentageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            percentageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.percentageLabelMinWidth),
            
            // Progress bar background
            progressBackground.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Layout.progressBarVerticalOffset),
            progressBackground.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            progressBackground.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            progressBackground.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            progressBackground.heightAnchor.constraint(equalToConstant: Layout.progressBarThickness),
            
            // Progress bar fill
            progressFill.topAnchor.constraint(equalTo: progressBackground.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressBackground.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBackground.bottomAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressBackground.widthAnchor, multiplier: CGFloat(usedPercentage / 100.0))
        ])
    }
    
    private func setupUnlimitedLayout(container: NSView, titleLabel: NSTextField, percentageLabel: NSTextField) {
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: percentageLabel.leadingAnchor, constant: -Layout.percentageLabelSpacing),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            
            percentageLabel.topAnchor.constraint(equalTo: container.topAnchor),
            percentageLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            percentageLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.percentageLabelMinWidth),
            percentageLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
    
    private func getProgressBarColor(for usedPercentage: Float) -> NSColor {
        switch usedPercentage {
        case 90...:
            return .systemRed
        case 75..<90:
            return .systemYellow
        default:
            return .systemBlue
        }
    }
}

// MARK: - Footer Section
extension QuotaView {
    private func createStatusMessageLabel() -> NSTextField {
        let message = premiumInteractions.overagePermitted ?
            "Additional paid premium requests enabled." :
            "Additional paid premium requests disabled."
        
        let label = NSTextField(labelWithString: isFreeUser ? "" : message)
        label.font = NSFont.systemFont(ofSize: Style.footerFontSize, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabelColor
        label.alignment = .left
        return label
    }
    
    private func createResetTextLabel() -> NSTextField {
        
        // Format reset date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        
        var resetText = "Allowance resets \(resetDate)."
        
        if let date = formatter.date(from: resetDate) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMMM d, yyyy"
            let formattedDate = outputFormatter.string(from: date)
            resetText = "Allowance resets \(formattedDate)."
        }
        
        let label = NSTextField(labelWithString: resetText)
        label.font = NSFont.systemFont(ofSize: Style.footerFontSize, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textColor = .secondaryLabelColor
        label.alignment = .left
        return label
    }
    
    private func createUpsellLabel() -> NSButton {
        if isFreeUser {
            let button = NSButton()
            let upgradeTitle = "Upgrade to Copilot Pro"

            button.translatesAutoresizingMaskIntoConstraints = false
            button.bezelStyle = .push
            if isFreeQuotaUsedUp {
                if #available(macOS 26.0, *) {
                    button.attributedTitle = NSAttributedString(
                        string: upgradeTitle,
                        attributes: [.foregroundColor: NSColor.controlTextColor]
                    )
                    button.bezelColor = .controlBackgroundColor
                } else {
                    button.attributedTitle = NSAttributedString(
                        string: upgradeTitle,
                        attributes: [.foregroundColor: NSColor.white]
                    )
                    button.bezelColor = .controlAccentColor
                }
            } else {
                button.title = upgradeTitle
            }
            button.controlSize = .large
            button.target = self
            button.action = #selector(openCopilotUpgradePlan)

            return button
        } else {
            let button = HoverButton()
            let title = "Manage paid premium requests"
            
            button.setLinkStyle(title: title, fontSize: Style.footerFontSize)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.alphaValue = Style.labelAlphaValue
            button.alignment = .left
            button.target = self
            button.action = #selector(openCopilotManageOverage)
            
            return button
        }
    }
}

// MARK: - Layout Constraints
extension QuotaView {
    private func setupLayoutConstraints(_ components: ViewComponents) {
        let constraints = buildConstraints(components)
        NSLayoutConstraint.activate(constraints)
    }
    
    private func buildConstraints(_ components: ViewComponents) -> [NSLayoutConstraint] {
        var constraints: [NSLayoutConstraint] = []
        
        // Title constraints
        constraints.append(contentsOf: buildTitleConstraints(components.titleContainer))
        
        // Progress view constraints
        constraints.append(contentsOf: buildProgressViewConstraints(components))
        
        // Footer constraints
        constraints.append(contentsOf: buildFooterConstraints(components))
        
        return constraints
    }
    
    private func buildTitleConstraints(_ titleContainer: NSView) -> [NSLayoutConstraint] {
        return [
            titleContainer.topAnchor.constraint(equalTo: topAnchor, constant: 0),
            titleContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
            titleContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
            titleContainer.heightAnchor.constraint(equalToConstant: Layout.titleHeight)
        ]
    }
    
    private func buildProgressViewConstraints(_ components: ViewComponents) -> [NSLayoutConstraint] {
        let completionsView = components.progressViews[0]
        let chatView = components.progressViews[1]
        
        var constraints: [NSLayoutConstraint] = []
        
        if !isFreeUser {
            let premiumView = components.progressViews[2]
            constraints.append(contentsOf: buildPremiumProgressConstraints(premiumView, titleContainer: components.titleContainer))
            constraints.append(contentsOf: buildCompletionsProgressConstraints(completionsView, topView: premiumView, isPremiumUnlimited: premiumInteractions.unlimited))
        } else {
            constraints.append(contentsOf: buildCompletionsProgressConstraints(completionsView, topView: components.titleContainer, isPremiumUnlimited: false))
        }
        
        constraints.append(contentsOf: buildChatProgressConstraints(chatView, topView: completionsView))
        
        return constraints
    }
    
    private func buildPremiumProgressConstraints(_ premiumView: NSView, titleContainer: NSView) -> [NSLayoutConstraint] {
        return [
            premiumView.topAnchor.constraint(equalTo: titleContainer.bottomAnchor, constant: Layout.verticalSpacing),
            premiumView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
            premiumView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
            premiumView.heightAnchor.constraint(
                equalToConstant: premiumInteractions.unlimited ? Layout.unlimitedProgressBarHeight : Layout.progressBarHeight
            )
        ]
    }
    
    private func buildCompletionsProgressConstraints(_ completionsView: NSView, topView: NSView, isPremiumUnlimited: Bool) -> [NSLayoutConstraint] {
        let topSpacing = isPremiumUnlimited ? Layout.unlimitedVerticalSpacing : Layout.verticalSpacing
        
        return [
            completionsView.topAnchor.constraint(equalTo: topView.bottomAnchor, constant: topSpacing),
            completionsView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
            completionsView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
            completionsView.heightAnchor.constraint(
                equalToConstant: completions.unlimited ? Layout.unlimitedProgressBarHeight : Layout.progressBarHeight
            )
        ]
    }
    
    private func buildChatProgressConstraints(_ chatView: NSView, topView: NSView) -> [NSLayoutConstraint] {
        let topSpacing = completions.unlimited ? Layout.unlimitedVerticalSpacing : Layout.verticalSpacing
        
        return [
            chatView.topAnchor.constraint(equalTo: topView.bottomAnchor, constant: topSpacing),
            chatView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
            chatView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
            chatView.heightAnchor.constraint(
                equalToConstant: chat.unlimited ? Layout.unlimitedProgressBarHeight : Layout.progressBarHeight
            )
        ]
    }
    
    private func buildFooterConstraints(_ components: ViewComponents) -> [NSLayoutConstraint] {
        let chatView = components.progressViews[1]
        let topSpacing = chat.unlimited ? Layout.unlimitedVerticalSpacing : Layout.verticalSpacing
        
        var constraints = [NSLayoutConstraint]()
        
        if !isFreeUser {
            // Add status message label constraints
            constraints.append(contentsOf: [
                components.statusMessageLabel.topAnchor.constraint(equalTo: chatView.bottomAnchor, constant: topSpacing),
                components.statusMessageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
                components.statusMessageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
                components.statusMessageLabel.heightAnchor.constraint(equalToConstant: Layout.footerTextHeight)
            ])
            
            // Add reset text label constraints with status message label as the top anchor
            constraints.append(contentsOf: [
                components.resetTextLabel.topAnchor.constraint(equalTo: components.statusMessageLabel.bottomAnchor),
                components.resetTextLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
                components.resetTextLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
                components.resetTextLabel.heightAnchor.constraint(equalToConstant: Layout.footerTextHeight)
            ])
        } else {
            // For free users, only show reset text label
            constraints.append(contentsOf: [
                components.resetTextLabel.topAnchor.constraint(equalTo: chatView.bottomAnchor, constant: topSpacing),
                components.resetTextLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
                components.resetTextLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
                components.resetTextLabel.heightAnchor.constraint(equalToConstant: Layout.footerTextHeight)
            ])
        }
        
        if isOrgUser || (isFreeUser && isFreeQuotaRemaining) {
            // Do not show link label for business or enterprise users
            constraints.append(components.resetTextLabel.bottomAnchor.constraint(equalTo: bottomAnchor))
            return constraints
        }
        
        // Add link label constraints
        constraints.append(contentsOf: [
            components.upsellLabel.topAnchor.constraint(equalTo: components.resetTextLabel.bottomAnchor),
            components.upsellLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalMargin),
            components.upsellLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalMargin),
            components.upsellLabel.heightAnchor.constraint(equalToConstant: isFreeUser ? Layout.upgradeButtonHeight : Layout.linkLabelHeight),
            
            components.upsellLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        return constraints
    }
}

// MARK: - Actions
extension QuotaView {
    @objc private func openCopilotSettings() {
        Task {
            if let url = URL(string: "https://aka.ms/github-copilot-settings") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc private func openCopilotManageOverage() {
        Task {
            if let url = URL(string: "https://aka.ms/github-copilot-manage-overage") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc private func openCopilotUpgradePlan() {
        Task {
            if let url = URL(string: "https://aka.ms/github-copilot-upgrade-plan") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

// MARK: - Helper Types
private struct ViewComponents {
    let titleContainer: NSView
    let progressViews: [NSView]
    let statusMessageLabel: NSTextField
    let resetTextLabel: NSTextField
    let upsellLabel: NSButton
}

// MARK: - Layout Constants
private struct Layout {
    static let viewWidth: CGFloat = 256
    static let horizontalMargin: CGFloat = 14
    static let verticalSpacing: CGFloat = 8
    static let unlimitedVerticalSpacing: CGFloat = 6
    static let smallVerticalSpacing: CGFloat = 4
    
    static let titleHeight: CGFloat = 20
    static let progressBarHeight: CGFloat = 22
    static let unlimitedProgressBarHeight: CGFloat = 16
    static let footerTextHeight: CGFloat = 16
    static let linkLabelHeight: CGFloat = 16
    static let upgradeButtonHeight: CGFloat = 40
    
    static let settingsButtonSize: CGFloat = 20
    static let settingsButtonHoverSize: CGFloat = 14
    static let settingsButtonSpacing: CGFloat = 8
    
    static let progressBarThickness: CGFloat = 3
    static let progressBarCornerRadius: CGFloat = 1.5
    static let progressBarVerticalOffset: CGFloat = -10
    static let percentageLabelMinWidth: CGFloat = 35
    static let percentageLabelSpacing: CGFloat = 8
}

// MARK: - Style Constants
private struct Style {
    static let labelAlphaValue: CGFloat = 0.85
    static let progressBarBackgroundAlpha: CGFloat = 0.3
    static let buttonAlphaValue: CGFloat = 0.85
    
    static let titleFontSize: CGFloat = 11
    static let progressFontSize: CGFloat = 13
    static let percentageFontSize: CGFloat = 11
    static let footerFontSize: CGFloat = 11
}
