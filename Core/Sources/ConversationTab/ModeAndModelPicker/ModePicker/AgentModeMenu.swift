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
        
        // Add built-in agent modes
        addBuiltInModes(to: menu, menuHasSelection: menuHasSelection)
        
        // Add custom agents if any
        if !customAgents.isEmpty {
            menu.addItem(.separator())
            addCustomAgents(to: menu, menuHasSelection: menuHasSelection)
        }
        
        // Add create option
        menu.addItem(.separator())
        addCreateOption(to: menu, menuHasSelection: menuHasSelection)
        
        return menu
    }
    
    private func addBuiltInModes(to menu: NSMenu, menuHasSelection: Bool) {
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
    
    private func addCustomAgents(to menu: NSMenu, menuHasSelection: Bool) {
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
    
    private func addCreateOption(to menu: NSMenu, menuHasSelection: Bool) {
        let createItem = NSMenuItem()
        let createView = AgentModeButtonMenuItem(
            name: "Create an agent",
            iconName: AgentModeIcon.plus,
            isSelected: false,
            menuHasSelection: menuHasSelection,
            fontScale: fontScale,
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
