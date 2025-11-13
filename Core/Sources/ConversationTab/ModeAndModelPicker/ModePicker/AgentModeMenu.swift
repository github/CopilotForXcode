import AppKit
import ConversationServiceProvider

// MARK: - Agent Mode Menu Builder

struct AgentModeMenu {
    let builtInAgentModes: [ConversationMode]
    let customAgents: [ConversationMode]
    let selectedAgent: ConversationMode
    let fontScale: Double
    let onSelectAgent: (ConversationMode) -> Void
    let onEditAgent: (ConversationMode) -> Void
    let onDeleteAgent: (ConversationMode) -> Void
    let onCreateAgent: () -> Void
    
    func createMenu() -> NSMenu {
        let menu = NSMenu()
        
        let menuHasSelection = true // Always show checkmarks for clarity
        
        // Calculate the maximum width needed across all items
        let maxWidth = calculateMaxMenuItemWidth(menuHasSelection: menuHasSelection)
        
        // Add built-in agent modes
        addBuiltInModes(to: menu, menuHasSelection: menuHasSelection, width: maxWidth)
        
        // Add custom agents if any
        if !customAgents.isEmpty {
            menu.addItem(.separator())
            addCustomAgents(to: menu, menuHasSelection: menuHasSelection, width: maxWidth)
        }
        
        // Add create option
        menu.addItem(.separator())
        addCreateOption(to: menu, menuHasSelection: menuHasSelection, width: maxWidth)
        
        return menu
    }
    
    private func calculateMaxMenuItemWidth(menuHasSelection: Bool) -> CGFloat {
        var maxWidth: CGFloat = 0
        
        // Check built-in modes
        for mode in builtInAgentModes {
            let width = AgentModeButtonMenuItem.calculateMenuItemWidth(
                name: mode.name,
                hasIcon: true,
                isSelected: selectedAgent.id == mode.id,
                menuHasSelection: menuHasSelection,
                hasEditDelete: false,
                fontScale: fontScale
            )
            maxWidth = max(maxWidth, width)
        }
        
        // Check custom agents
        for agent in customAgents {
            let width = AgentModeButtonMenuItem.calculateMenuItemWidth(
                name: agent.name,
                hasIcon: false,
                isSelected: selectedAgent.id == agent.id,
                menuHasSelection: menuHasSelection,
                hasEditDelete: true,
                fontScale: fontScale
            )
            maxWidth = max(maxWidth, width)
        }
        
        // Check create option
        let createWidth = AgentModeButtonMenuItem.calculateMenuItemWidth(
            name: "Create an agent",
            hasIcon: true,
            isSelected: false,
            menuHasSelection: menuHasSelection,
            hasEditDelete: false,
            fontScale: fontScale
        )
        maxWidth = max(maxWidth, createWidth)
        
        return maxWidth
    }
    
    private func addBuiltInModes(to menu: NSMenu, menuHasSelection: Bool, width: CGFloat) {
        for mode in builtInAgentModes {
            let agentItem = NSMenuItem()
            // Determine icon: use checklist for Plan, Agent icon for others
            let iconName = AgentModeIcon.icon(for: mode.name)
            let agentView = AgentModeButtonMenuItem(
                name: mode.name,
                iconName: iconName,
                isSelected: selectedAgent.id == mode.id,
                menuHasSelection: menuHasSelection,
                fontScale: fontScale,
                fixedWidth: width,
                onSelect: { [onSelectAgent] in
                    onSelectAgent(mode)
                    menu.cancelTracking()
                }
            )
            agentView.toolTip = mode.description
            agentItem.view = agentView
            menu.addItem(agentItem)
        }
    }
    
    private func addCustomAgents(to menu: NSMenu, menuHasSelection: Bool, width: CGFloat) {
        for agent in customAgents {
            let agentItem = NSMenuItem()
            agentItem.representedObject = agent

            // Create custom view for the menu item
            let customView = AgentModeButtonMenuItem(
                name: agent.name,
                iconName: nil,
                isSelected: selectedAgent.id == agent.id,
                menuHasSelection: menuHasSelection,
                fontScale: fontScale,
                fixedWidth: width,
                onSelect: { [onSelectAgent] in
                    onSelectAgent(agent)
                    menu.cancelTracking()
                },
                onEdit: { [onEditAgent] in
                    onEditAgent(agent)
                    menu.cancelTracking()
                },
                onDelete: { [onDeleteAgent] in
                    onDeleteAgent(agent)
                    menu.cancelTracking()
                }
            )

            customView.toolTip = agent.description
            agentItem.view = customView
            menu.addItem(agentItem)
        }
    }
    
    private func addCreateOption(to menu: NSMenu, menuHasSelection: Bool, width: CGFloat) {
        let createItem = NSMenuItem()
        let createView = AgentModeButtonMenuItem(
            name: "Create an agent",
            iconName: AgentModeIcon.plus,
            isSelected: false,
            menuHasSelection: menuHasSelection,
            fontScale: fontScale,
            fixedWidth: width,
            onSelect: { [onCreateAgent] in
                onCreateAgent()
                menu.cancelTracking()
            }
        )
        createItem.view = createView
        menu.addItem(createItem)
    }
    
    func showMenu(relativeTo button: NSButton) {
        let menu = createMenu()
        
        // Show menu aligned to the button's edge, positioned below the button
        let buttonFrame = button.frame
        let menuOrigin = NSPoint(x: buttonFrame.minX, y: buttonFrame.maxY)
        menu.popUp(positioning: menu.items.first, at: menuOrigin, in: button.superview)
    }
}
