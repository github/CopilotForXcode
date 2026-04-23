import ComposableArchitecture
import SwiftUI
import SharedUIComponents

struct GeneralSettingsView: View {
    @AppStorage(\.extensionPermissionShown) var extensionPermissionShown: Bool
    @AppStorage(\.quitXPCServiceOnXcodeAndAppQuit) var quitXPCServiceOnXcodeAndAppQuit: Bool
    @State private var shouldPresentExtensionPermissionAlert = false
    @State private var shouldShowRestartXcodeAlert = false

    let store: StoreOf<General>

    var accessibilityPermissionSubtitle: String {
        switch store.isAccessibilityPermissionGranted {
        case .granted:
            return "Granted"
        case .notGranted:
            return "Enable accessibility in system preferences"
        case .unknown:
            return ""
        }
    }

    var extensionPermissionSubtitle: any View {
        switch store.isExtensionPermissionGranted {
        case .notGranted:
            return HStack(spacing: 0) {
                Text("Enable ")
                Text(
                    "Extensions \(Image(systemName: "puzzlepiece.extension.fill")) → Xcode Source Editor \(Image(systemName: "info.circle")) → GitHub Copilot for Xcode"
                )
                .bold()
                .foregroundStyle(.primary)
                Text(" for faster and full-featured code completion.")
            }
        case .disabled:
            return Text("Quit and restart Xcode to enable extension")
        case .granted:
            return Text("Granted")
        case .unknown:
            return Text("")
        }
    }

    var extensionPermissionBadge: BadgeItem? {
        switch store.isExtensionPermissionGranted {
        case .notGranted:
            return .init(text: "Not Granted", level: .danger)
        case .disabled:
            return .init(text: "Disabled", level: .danger)
        default:
            return nil
        }
    }

    var extensionPermissionAction: () -> Void {
        switch store.isExtensionPermissionGranted {
        case .disabled:
            return { shouldShowRestartXcodeAlert = true }
        default:
            return NSWorkspace.openXcodeExtensionsPreferences
        }
    }

    var body: some View {
        SettingsSection(title: "General") {
            SettingsToggle(
                title: "Quit GitHub Copilot when Xcode App is closed",
                isOn: $quitXPCServiceOnXcodeAndAppQuit
            )
            Divider()
            SettingsLink(
                url: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
                title: "Accessibility Permission",
                subtitle: accessibilityPermissionSubtitle,
                badge: store.isAccessibilityPermissionGranted == .notGranted ?
                    .init(
                        text: "Not Granted",
                        level: .danger
                    ) : nil
            )
            Divider()
            SettingsLink(
                action: extensionPermissionAction,
                title: "Extension Permission",
                subtitle: extensionPermissionSubtitle,
                badge: extensionPermissionBadge
            )
        } footer: {
            HStack {
                Spacer()
                AdaptiveHelpLink(action: { NSWorkspace.shared.open(
                    URL(string: "https://github.com/github/CopilotForXcode/blob/main/TROUBLESHOOTING.md")!
                )})
            }
        }
        .alert(
            "Enable Extension Permission",
            isPresented: $shouldPresentExtensionPermissionAlert
        ) {
            Button(
                "Open System Preferences",
                action: {
                    NSWorkspace.openXcodeExtensionsPreferences()
                }).keyboardShortcut(.defaultAction)
            Button("View How-to Guide", action: {
                let url = "https://github.com/github/CopilotForXcode/blob/main/TROUBLESHOOTING.md#extension-permission"
                NSWorkspace.shared.open(URL(string: url)!)
            })
            Button("Close", role: .cancel, action: {})
        } message: {
            Text("To enable faster and full-featured code completion, navigate to:\nExtensions → Xcode Source Editor → GitHub Copilot for Xcode.")
        }
        .task {
            if extensionPermissionShown { return }
            extensionPermissionShown = true
            shouldPresentExtensionPermissionAlert = true
        }
        .alert(
            "Restart Xcode?",
            isPresented: $shouldShowRestartXcodeAlert
        ) {
            Button("Restart Now") {
                NSWorkspace.restartXcode()
            }.keyboardShortcut(.defaultAction)

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Quit and restart Xcode to enable Github Copilot for Xcode extension.")
        }
    }
}

#Preview {
    GeneralSettingsView(
        store: .init(initialState: .init(), reducer: { General() })
    )
}
