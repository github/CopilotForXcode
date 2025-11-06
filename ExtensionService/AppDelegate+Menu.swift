import AppKit
import Foundation
import Preferences
import Status
import SuggestionBasic
import XcodeInspector
import Logger
import StatusBarItemView
import GitHubCopilotViewModel

extension AppDelegate {
    fileprivate var statusBarMenuIdentifier: NSUserInterfaceItemIdentifier {
        .init("statusBarMenu")
    }

    fileprivate var xcodeInspectorDebugMenuIdentifier: NSUserInterfaceItemIdentifier {
        .init("xcodeInspectorDebugMenu")
    }

    fileprivate var sourceEditorDebugMenu: NSUserInterfaceItemIdentifier {
        .init("sourceEditorDebugMenu")
    }

    @MainActor
    @objc func buildStatusBarMenu() {
        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(
            withLength: NSStatusItem.squareLength
        )
        statusBarItem.button?.image = NSImage(named: "MenuBarIcon")

        let statusBarMenu = NSMenu(title: "Status Bar Menu")
        statusBarMenu.identifier = statusBarMenuIdentifier
        statusBarItem.menu = statusBarMenu
        
        let checkForUpdate = NSMenuItem(
            title: "Check for Updates",
            action: #selector(checkForUpdate),
            keyEquivalent: ""
        )

        openCopilotForXcodeItem = NSMenuItem(
            title: "Settings",
            action: #selector(openCopilotForXcodeSettings),
            keyEquivalent: ""
        )

        let xcodeInspectorDebug = NSMenuItem(
            title: "Xcode Inspector Debug",
            action: nil,
            keyEquivalent: ""
        )

        let xcodeInspectorDebugMenu = NSMenu(title: "Xcode Inspector Debug")
        xcodeInspectorDebugMenu.identifier = xcodeInspectorDebugMenuIdentifier
        xcodeInspectorDebug.submenu = xcodeInspectorDebugMenu
        xcodeInspectorDebug.isHidden = false

        axStatusItem = NSMenuItem(
            title: "",
            action: #selector(openAXStatusLink),
            keyEquivalent: ""
        )
        axStatusItem.isHidden = true

        extensionStatusItem = NSMenuItem(
            title: "",
            action: #selector(openExtensionStatusLink),
            keyEquivalent: ""
        )
        extensionStatusItem.isHidden = true

        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quit),
            keyEquivalent: ""
        )
        quitItem.target = self

        toggleCompletions = NSMenuItem(
            title: "Enable/Disable Completions",
            action: #selector(toggleCompletionsEnabled),
            keyEquivalent: ""
        )
        
        toggleIgnoreLanguage = NSMenuItem(
            title: "No Active Document",
            action: nil,
            keyEquivalent: ""
        )
        
        toggleNES = NSMenuItem(
            title: "Enable/Disable Next Edit Suggestions (NES)",
            action: #selector(toggleNESEnabled),
            keyEquivalent: ""
        )

        // Auth menu item with custom view
        accountItem = NSMenuItem()
        accountItem.view = AccountItemView(
            target: self,
            action: #selector(signIntoGitHub)
        )

        authStatusItem = NSMenuItem(
            title: "",
            action: nil,
            keyEquivalent: ""
        )
        authStatusItem.isHidden = true
        
        quotaItem = NSMenuItem()
        quotaItem.view = QuotaView(
            chat: .init(
                percentRemaining: 0,
                unlimited: false,
                overagePermitted: false
            ),
            completions: .init(
                percentRemaining: 0,
                unlimited: false,
                overagePermitted: false
            ),
            premiumInteractions: .init(
                percentRemaining: 0,
                unlimited: false,
                overagePermitted: false
            ),
            resetDate: "",
            copilotPlan: ""
        )
        quotaItem.isHidden = true

        let openDocs = NSMenuItem(
            title: "View Documentation",
            action: #selector(openCopilotDocs),
            keyEquivalent: ""
        )

        let openForum = NSMenuItem(
            title: "Feedback Forum",
            action: #selector(openCopilotForum),
            keyEquivalent: ""
        )

        openChat = NSMenuItem(
            title: "Open Chat",
            action: #selector(openGlobalChat),
            keyEquivalent: ""
        )
        
        signOutItem = NSMenuItem(
            title: "Sign Out",
            action: #selector(signOutGitHub),
            keyEquivalent: ""
        )

        statusBarMenu.addItem(accountItem)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(authStatusItem)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(quotaItem)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(axStatusItem)
        statusBarMenu.addItem(extensionStatusItem)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(checkForUpdate)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(openChat)
        statusBarMenu.addItem(toggleCompletions)
        statusBarMenu.addItem(toggleIgnoreLanguage)
        statusBarMenu.addItem(toggleNES)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(openCopilotForXcodeItem)
        statusBarMenu.addItem(openDocs)
        statusBarMenu.addItem(openForum)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(signOutItem)
        statusBarMenu.addItem(.separator())
        statusBarMenu.addItem(xcodeInspectorDebug)
        statusBarMenu.addItem(quitItem)

        statusBarMenu.delegate = self
        xcodeInspectorDebugMenu.delegate = self
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        switch menu.identifier {
        case statusBarMenuIdentifier:
            if let xcodeInspectorDebug = menu.items.first(where: { item in
                item.submenu?.identifier == xcodeInspectorDebugMenuIdentifier
            }) {
                xcodeInspectorDebug.isHidden = !UserDefaults.shared
                    .value(for: \.enableXcodeInspectorDebugMenu)
            }

            if toggleCompletions != nil {
                toggleCompletions.title = "\(UserDefaults.shared.value(for: \.realtimeSuggestionToggle) ? "Disable" : "Enable") Completions"
            }
            
            if toggleIgnoreLanguage != nil {
                if let lang = DisabledLanguageList.shared.activeDocumentLanguage {
                    toggleIgnoreLanguage.title = "\(DisabledLanguageList.shared.isEnabled(lang) ? "Disable" : "Enable") Completions for \(lang.rawValue)"
                    toggleIgnoreLanguage.action = #selector(
                        toggleIgnoreLanguageEnabled
                    )
                } else {
                    toggleIgnoreLanguage.title = "No Active Document"
                    toggleIgnoreLanguage.action = nil
                }
            }
            
            if toggleNES != nil {
                toggleNES.title = "\(UserDefaults.shared.value(for: \.realtimeNESToggle) ? "Disable" : "Enable") Next Edit Suggestions (NES)"
            }

            Task {
                await forceAuthStatusCheck()
                updateStatusBarItem()
            }

        case xcodeInspectorDebugMenuIdentifier:
            let inspector = XcodeInspector.shared
            menu.items.removeAll()
            menu.items
                .append(.text("Active Project: \(inspector.activeProjectRootURL?.path ?? "N/A")"))
            menu.items
                .append(.text("Active Workspace: \(inspector.activeWorkspaceURL?.path ?? "N/A")"))
            menu.items
                .append(.text("Active Document: \(inspector.activeDocumentURL?.path ?? "N/A")"))

            if let focusedWindow = inspector.focusedWindow {
                menu.items.append(.text(
                    "Active Window: \(focusedWindow.uiElement.identifier)"
                ))
            } else {
                menu.items.append(.text("Active Window: N/A"))
            }

            if let focusedElement = inspector.focusedElement {
                menu.items.append(.text(
                    "Focused Element: \(focusedElement.description)"
                ))
            } else {
                menu.items.append(.text("Focused Element: N/A"))
            }

            if let sourceEditor = inspector.focusedEditor {
                let label = sourceEditor.element.description
                menu.items
                    .append(.text("Active Source Editor: \(label.isEmpty ? "Unknown" : label)"))
            } else {
                menu.items.append(.text("Active Source Editor: N/A"))
            }

            menu.items.append(.separator())

            for xcode in inspector.xcodes {
                let item = NSMenuItem(
                    title: "Xcode \(xcode.processIdentifier)",
                    action: nil,
                    keyEquivalent: ""
                )
                menu.addItem(item)
                let xcodeMenu = NSMenu()
                item.submenu = xcodeMenu
                xcodeMenu.items.append(.text("Is Active: \(xcode.isActive)"))
                xcodeMenu.items
                    .append(.text("Active Project: \(xcode.projectRootURL?.path ?? "N/A")"))
                xcodeMenu.items
                    .append(.text("Active Workspace: \(xcode.workspaceURL?.path ?? "N/A")"))
                xcodeMenu.items
                    .append(.text("Active Document: \(xcode.documentURL?.path ?? "N/A")"))

                for (key, workspace) in xcode.realtimeWorkspaces {
                    let workspaceItem = NSMenuItem(
                        title: "Workspace \(key)",
                        action: nil,
                        keyEquivalent: ""
                    )
                    xcodeMenu.items.append(workspaceItem)
                    let workspaceMenu = NSMenu()
                    workspaceItem.submenu = workspaceMenu
                    let tabsItem = NSMenuItem(
                        title: "Tabs",
                        action: nil,
                        keyEquivalent: ""
                    )
                    workspaceMenu.addItem(tabsItem)
                    let tabsMenu = NSMenu()
                    tabsItem.submenu = tabsMenu
                    for tab in workspace.tabs {
                        tabsMenu.addItem(.text(tab))
                    }
                }
            }

            menu.items.append(.separator())

            menu.items.append(NSMenuItem(
                title: "Restart Xcode Inspector",
                action: #selector(restartXcodeInspector),
                keyEquivalent: ""
            ))

        default:
            break
        }
    }
}

import XPCShared

private extension AppDelegate {
    @objc func restartXcodeInspector() {
        Task {
            await XcodeInspector.shared.restart(cleanUp: true)
        }
    }

    @objc func toggleCompletionsEnabled() {
        Task {
            let initialSetting = UserDefaults.shared.value(for: \.realtimeSuggestionToggle)
            do {
                let service = getXPCExtensionService()
                try await service.toggleRealtimeSuggestion()
            } catch {
                Logger.service.error("Failed to toggle completions enabled via XPC: \(error)")
                UserDefaults.shared.set(!initialSetting, for: \.realtimeSuggestionToggle)
            }
        }
    }
    
    @objc func toggleNESEnabled() {
        Task {
            let initialSetting = UserDefaults.shared.value(for: \.realtimeNESToggle)
            do {
                let service = getXPCExtensionService()
                try await service.toggleRealtimeNES()
            } catch {
                Logger.service.error("Failed to toggle NES enabled via XPC: \(error)")
                UserDefaults.shared.set(!initialSetting, for: \.realtimeNESToggle)
            }
        }
    }
    
    @objc func toggleIgnoreLanguageEnabled() {
        guard let lang = DisabledLanguageList.shared.activeDocumentLanguage else { return }

        if DisabledLanguageList.shared.isEnabled(lang) {
            DisabledLanguageList.shared.disable(lang)
        } else {
            DisabledLanguageList.shared.enable(lang)
        }
    }

    @objc func openCopilotDocs() {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "COPILOT_DOCS_URL") as? String {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc func openCopilotForum() {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "COPILOT_FORUM_URL") as? String {
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc func openAXStatusLink() {
        Task {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    @objc func openExtensionStatusLink() {
        Task {
            let status = await Status.shared.getExtensionStatus()
            if status == .notGranted {
                if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences?extensionPointIdentifier=com.apple.dt.Xcode.extension.source-editor") {
                    NSWorkspace.shared.open(url)
                }
            } else {
                NSWorkspace.restartXcode()
            }
        }
    }
    
    @objc func openUpSellLink() {
        Task {
            if let url = URL(string: "https://aka.ms/github-copilot-settings") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}

private extension NSMenuItem {
    static func text(_ text: String) -> NSMenuItem {
        let item = NSMenuItem(
            title: text,
            action: nil,
            keyEquivalent: ""
        )
        item.isEnabled = false
        return item
    }
}
