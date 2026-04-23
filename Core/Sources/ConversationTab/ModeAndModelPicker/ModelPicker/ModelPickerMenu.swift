import AppKit
import HostAppActivator
import Persist

// MARK: - Search Field View for Menu

private class ModelSearchFieldView: NSView, NSSearchFieldDelegate {
    let searchField = NSSearchField()
    var onSearchTextChanged: ((String) -> Void)?
    weak var parentMenu: NSMenu?

    init(fontScale: Double, width: CGFloat) {
        let height = 30 * fontScale
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height + 8 * fontScale))

        searchField.placeholderString = "Search models..."
        searchField.font = NSFont.systemFont(ofSize: 12 * fontScale)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.focusRingType = .none
        searchField.delegate = self
        addSubview(searchField)

        NSLayoutConstraint.activate([
            searchField.leadingAnchor.constraint(
                equalTo: leadingAnchor, constant: 8 * fontScale
            ),
            searchField.trailingAnchor.constraint(
                equalTo: trailingAnchor, constant: -8 * fontScale
            ),
            searchField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchField.heightAnchor.constraint(equalToConstant: height),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSSearchField else { return }
        onSearchTextChanged?(field.stringValue)
    }

    /// Intercept Return / Enter in the search field to select the highlighted
    /// menu item. NSMenu doesn't do this automatically for custom-view items.
    func control(
        _ control: NSControl,
        textView _: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if let menu = parentMenu,
               let highlightedItem = menu.highlightedItem,
               let menuItemView = highlightedItem.view as? ModelPickerMenuItem
            {
                menuItemView.performSelect()
                return true
            }
        }
        return false
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            DispatchQueue.main.async { [weak self] in
                self?.searchField.becomeFirstResponder()
            }
        }
    }
}

// MARK: - Custom Menu (allows key events to reach search field)

private class ModelPickerNSMenu: NSMenu {
    weak var searchField: NSSearchField?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }

        // Return / Enter: NSMenu won't fire the action for items with custom
        // views, so we find the currently highlighted ModelPickerMenuItem and
        // invoke its selection callback directly.
        let confirmKeyCodes: Set<UInt16> = [
            36, // return
            76, // enter (numpad)
        ]
        if confirmKeyCodes.contains(event.keyCode) {
            if let highlightedItem = highlightedItem,
               let menuItemView = highlightedItem.view as? ModelPickerMenuItem
            {
                menuItemView.performSelect()
                return true
            }
            return super.performKeyEquivalent(with: event)
        }

        // Forward printable character input and delete keys to the search
        // field. Navigation keys (arrows, Escape, Space, Tab) fall through
        // to super so NSMenu handles them normally.
        if let searchField = searchField,
           Self.shouldForwardToSearchField(event)
        {
            if let window = searchField.window {
                window.makeFirstResponder(searchField)
                searchField.currentEditor()?.keyDown(with: event)
                return true
            }
        }
        return super.performKeyEquivalent(with: event)
    }

    /// Returns `true` for key events that should be forwarded to the search
    /// field: printable characters and delete/backspace. Returns `false` for
    /// navigation and control keys so NSMenu can handle them.
    private static func shouldForwardToSearchField(_ event: NSEvent) -> Bool {
        // Always allow delete / forward-delete so the user can edit the query
        let deleteKeyCodes: Set<UInt16> = [
            51, // delete (backspace)
            117, // forward delete
        ]
        if deleteKeyCodes.contains(event.keyCode) {
            return true
        }

        // Reject keys that NSMenu uses for navigation / activation
        let navigationKeyCodes: Set<UInt16> = [
            123, // left arrow
            124, // right arrow
            125, // down arrow
            126, // up arrow
            53,  // escape
            49,  // space
            48,  // tab
        ]
        if navigationKeyCodes.contains(event.keyCode) {
            return false
        }

        // Don't forward Cmd-key shortcuts (Cmd+A, Cmd+C, etc.)
        if event.modifierFlags.contains(.command) {
            return false
        }

        // Forward if the key produces printable characters
        if let chars = event.characters, !chars.isEmpty {
            return true
        }

        return false
    }
}

// MARK: - Model Picker Menu Builder

struct ModelPickerMenu {
    let selectedModel: LLMModel?
    let copilotModels: [LLMModel]
    let byokModels: [LLMModel]
    let isBYOKFFEnabled: Bool
    let currentCache: ScopeCache
    let fontScale: Double

    private let detailPanel = ModelPickerDetailPanel.shared

    func showMenu(relativeTo button: NSButton) {
        let menu = createMenu(allCopilotModels: copilotModels, allBYOKModels: byokModels)
        let buttonFrame = button.frame
        let menuOrigin = NSPoint(x: buttonFrame.minX, y: buttonFrame.maxY)
        menu.popUp(positioning: nil, at: menuOrigin, in: button.superview)
        detailPanel.orderOut(nil)
    }

    private func createMenu(
        allCopilotModels: [LLMModel],
        allBYOKModels: [LLMModel]
    ) -> NSMenu {
        let menu = ModelPickerNSMenu()
        menu.autoenablesItems = false

        let maxWidth = calculateMaxWidth(
            copilotModels: allCopilotModels,
            byokModels: allBYOKModels
        )

        // Search bar at top (sized to match content)
        let searchItem = NSMenuItem()
        let searchView = ModelSearchFieldView(fontScale: fontScale, width: maxWidth)
        searchView.parentMenu = menu
        searchItem.view = searchView
        menu.addItem(searchItem)
        menu.searchField = searchView.searchField

        // Separator after search
        menu.addItem(.separator())

        // Build initial menu items
        rebuildMenuItems(
            menu: menu,
            copilotModels: allCopilotModels,
            byokModels: allBYOKModels,
            maxWidth: maxWidth,
            searchText: ""
        )

        // Handle search
        searchView.onSearchTextChanged = { [weak menu] searchText in
            guard let menu = menu else { return }
            self.rebuildMenuItems(
                menu: menu,
                copilotModels: allCopilotModels,
                byokModels: allBYOKModels,
                maxWidth: maxWidth,
                searchText: searchText
            )
        }

        return menu
    }

    private func rebuildMenuItems(
        menu: NSMenu,
        copilotModels: [LLMModel],
        byokModels: [LLMModel],
        maxWidth: CGFloat,
        searchText: String
    ) {
        // Remove all items except the search bar and separator (first 2 items)
        while menu.items.count > 2 {
            menu.removeItem(at: menu.items.count - 1)
        }

        let query = searchText.lowercased().trimmingCharacters(in: .whitespaces)

        let filteredCopilotModels: [LLMModel]
        let filteredBYOKModels: [LLMModel]
        if query.isEmpty {
            filteredCopilotModels = copilotModels
            filteredBYOKModels = byokModels
        } else {
            filteredCopilotModels = copilotModels.filter {
                ($0.displayName ?? $0.modelName).lowercased().contains(query)
                    || $0.modelFamily.lowercased().contains(query)
            }
            filteredBYOKModels = byokModels.filter {
                ($0.displayName ?? $0.modelName).lowercased().contains(query)
                    || $0.modelFamily.lowercased().contains(query)
                    || ($0.providerName ?? "").lowercased().contains(query)
            }
        }

        let premiumModels = filteredCopilotModels.filter { $0.isPremiumModel }
        let standardModels = filteredCopilotModels.filter {
            $0.isStandardModel && !$0.isAutoModel
        }
        let autoModel = filteredCopilotModels.first(where: { $0.isAutoModel })

        // Auto model
        if let autoModel = autoModel {
            addModelItem(
                to: menu, model: autoModel, maxWidth: maxWidth
            )
        }

        // Standard models section
        addSection(
            to: menu, title: "Standard Models", models: standardModels,
            maxWidth: maxWidth
        )

        // Premium models section
        addSection(
            to: menu, title: "Premium Models", models: premiumModels,
            maxWidth: maxWidth
        )

        // BYOK models section
        if isBYOKFFEnabled {
            addSection(
                to: menu, title: "Other Models", models: filteredBYOKModels,
                maxWidth: maxWidth
            )

            if query.isEmpty {
                menu.addItem(.separator())
                let manageItem = NSMenuItem(
                    title: "Manage Models...",
                    action: #selector(ModelPickerMenuActions.manageModels),
                    keyEquivalent: ""
                )
                manageItem.target = ModelPickerMenuActions.shared
                menu.addItem(manageItem)
            }
        }

        if standardModels.isEmpty, premiumModels.isEmpty, autoModel == nil,
            filteredBYOKModels.isEmpty
        {
            if query.isEmpty {
                let addItem = NSMenuItem(
                    title: "Add Premium Models",
                    action: #selector(ModelPickerMenuActions.addPremiumModels),
                    keyEquivalent: ""
                )
                addItem.target = ModelPickerMenuActions.shared
                menu.addItem(addItem)
            } else {
                let noResults = NSMenuItem(title: "No models found", action: nil, keyEquivalent: "")
                noResults.isEnabled = false
                menu.addItem(noResults)
            }
        }
    }

    private func addSection(
        to menu: NSMenu,
        title: String,
        models: [LLMModel],
        maxWidth: CGFloat
    ) {
        guard !models.isEmpty else { return }

        // Section header
        menu.addItem(.separator())
        let headerItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        let headerFont = NSFont.systemFont(ofSize: 11 * fontScale, weight: .semibold)
        headerItem.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: headerFont,
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        menu.addItem(headerItem)

        for model in models {
            addModelItem(to: menu, model: model, maxWidth: maxWidth)
        }
    }

    private func addModelItem(
        to menu: NSMenu,
        model: LLMModel,
        maxWidth: CGFloat
    ) {
        let item = NSMenuItem()
        let multiplierText = currentCache
            .modelMultiplierCache[model.id.appending(model.providerName ?? "")]
            ?? ModelMenuItemFormatter.getMultiplierText(for: model)

        let menuItemView = ModelPickerMenuItem(
            model: model,
            isSelected: selectedModel == model,
            multiplierText: multiplierText,
            fontScale: fontScale,
            fixedWidth: maxWidth,
            onSelect: {
                AppState.shared.setSelectedModel(model)
                menu.cancelTracking()
                self.detailPanel.orderOut(nil)
            },
            onHover: { hoveredModel, itemRect in
                self.detailPanel.show(
                    for: hoveredModel,
                    nearRect: itemRect,
                    fontScale: self.fontScale
                )
            },
            onHoverExit: {
                self.detailPanel.scheduleHide()
            }
        )
        item.view = menuItemView
        menu.addItem(item)
    }

    private func calculateMaxWidth(
        copilotModels: [LLMModel],
        byokModels: [LLMModel]
    ) -> CGFloat {
        var maxWidth: CGFloat = 0
        let allModels = isBYOKFFEnabled ? copilotModels + byokModels : copilotModels

        for model in allModels {
            let multiplierText = currentCache
                .modelMultiplierCache[model.id.appending(model.providerName ?? "")]
                ?? ModelMenuItemFormatter.getMultiplierText(for: model)
            let width = ModelPickerMenuItem.calculateItemWidth(
                model: model,
                multiplierText: multiplierText,
                fontScale: fontScale
            )
            maxWidth = max(maxWidth, width)
        }

        return maxWidth
    }
}

// MARK: - Menu Action Target

private class ModelPickerMenuActions: NSObject {
    static let shared = ModelPickerMenuActions()

    @objc func manageModels() {
        try? launchHostAppBYOKSettings()
    }

    @objc func addPremiumModels() {
        if let url = URL(string: "https://aka.ms/github-copilot-upgrade-plan") {
            NSWorkspace.shared.open(url)
        }
    }
}
