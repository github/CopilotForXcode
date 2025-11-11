import Combine
import FileChangeChecker
import GitHubCopilotService
import LaunchAgentManager
import Logger
import Preferences
import Service
import ServiceManagement
import Status
import SwiftUI
import UpdateChecker
import UserDefaultsObserver
import UserNotifications
import XcodeInspector
import XPCShared
import GitHubCopilotViewModel
import StatusBarItemView
import HostAppActivator

let bundleIdentifierBase = Bundle.main
    .object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as! String
let serviceIdentifier = bundleIdentifierBase + ".ExtensionService"

class ExtensionUpdateCheckerDelegate: UpdateCheckerDelegate {
    func prepareForRelaunch(finish: @escaping () -> Void) {
        Task {
            await Service.shared.prepareForExit()
            finish()
        }
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let service = Service.shared
    var statusBarItem: NSStatusItem!
    var axStatusItem: NSMenuItem!
    var extensionStatusItem: NSMenuItem!
    var openCopilotForXcodeItem: NSMenuItem!
    var accountItem: NSMenuItem!
    var authStatusItem: NSMenuItem!
    var quotaItem: NSMenuItem!
    var toggleCompletions: NSMenuItem!
    var toggleIgnoreLanguage: NSMenuItem!
    var toggleNES: NSMenuItem!
    var openChat: NSMenuItem!
    var signOutItem: NSMenuItem!
    var xpcController: XPCController?
    let updateChecker =
        UpdateChecker(
            hostBundle: Bundle(url: HostAppURL!),
            checkerDelegate: ExtensionUpdateCheckerDelegate()
        )
    var xpcExtensionService: XPCExtensionService?
    private var cancellables = Set<AnyCancellable>()
    private var progressView: NSProgressIndicator?

    func applicationDidFinishLaunching(_: Notification) {
        if ProcessInfo.processInfo.environment["IS_UNIT_TEST"] == "YES" { return }
        _ = XcodeInspector.shared
        service.start()
        AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true,
        ] as CFDictionary)
        setupQuitOnUpdate()
        setupQuitOnUserTerminated()
        xpcController = .init()
        Logger.service.info("XPC Service started.")
        NSApp.setActivationPolicy(.accessory)
        buildStatusBarMenu()
        _ = FeatureFlagNotifierImpl.shared
        observeFeatureFlags()
        watchServiceStatus()
        watchAXStatus()
        watchAuthStatus()
        setInitialStatusBarStatus()
        UserDefaults.shared.set(false, for: \.clsWarningDismissedUntilRelaunch)
    }

    @objc func quit() {
        if let hostApp = getRunningHostApp() {
            hostApp.terminate()
        }

        // Start shutdown process in a task
        Task { @MainActor in
            await service.prepareForExit()
            await xpcController?.quit()
            NSApp.terminate(self)
        }
    }

    @objc func openCopilotForXcodeSettings() {
        try? launchHostAppSettings()
    }
    
    @objc func signIntoGitHub() {
        Task { @MainActor in
            let viewModel = GitHubCopilotViewModel.shared
            // Don't trigger the shared viewModel's alert
            do {
                guard let signInResponse = try await viewModel.preSignIn() else {
                    return
                }

                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.messageText = signInResponse.userCode
                alert.informativeText = """
                Please enter the above code in the GitHub website to authorize your \
                GitHub account with Copilot for Xcode.
                \(signInResponse.verificationURL.absoluteString)
                """
                alert.addButton(withTitle: "Copy Code and Open")
                alert.addButton(withTitle: "Cancel")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    viewModel.signInResponse = signInResponse
                    viewModel.copyAndOpen()
                }
            } catch {
                Logger.service.error("GitHub copilot view model Sign in fails: \(error)")
            }
        }
    }
    
    @objc func signOutGitHub() {
        Task { @MainActor in
            let viewModel = GitHubCopilotViewModel.shared
            viewModel.signOut()
        }
    }

    @objc func openGlobalChat() {
        Task { @MainActor in
            let serviceGUI = Service.shared.guiController
            serviceGUI.openGlobalChat()
        }
    }

    func setupQuitOnUpdate() {
        Task {
            guard let url = Bundle.main.executableURL else { return }
            let checker = await FileChangeChecker(fileURL: url)

            // If Xcode or Copilot for Xcode is made active, check if the executable of this program
            // is changed. If changed, quit this program.

            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didActivateApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                    app.isUserOfService
                else { continue }
                guard await checker.checkIfChanged() else {
                    Logger.service.info("Extension Service is not updated, no need to quit.")
                    continue
                }
                Logger.service.info("Extension Service will quit.")
                #if DEBUG
                #else
                quit()
                #endif
            }
        }
    }

    func setupQuitOnUserTerminated() {
        Task {
            // Whenever Xcode or the host application quits, check if any of the two is running.
            // If none, quit the XPC service.

            let sequence = NSWorkspace.shared.notificationCenter
                .notifications(named: NSWorkspace.didTerminateApplicationNotification)
            for await notification in sequence {
                try Task.checkCancellation()
                guard UserDefaults.shared.value(for: \.quitXPCServiceOnXcodeAndAppQuit)
                else { continue }
                guard let app = notification
                    .userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                    app.isUserOfService
                else { continue }
                
                // Check if Xcode is running
                let isXcodeRunning = NSWorkspace.shared.runningApplications.contains { 
                    $0.bundleIdentifier == "com.apple.dt.Xcode" 
                }
                
                if !isXcodeRunning {
                    Logger.client.info("No Xcode instances running, preparing to quit")
                    quit()
                }
            }
        }
    }

    func requestAccessoryAPIPermission() {
        AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as NSString: true,
        ] as NSDictionary)
    }

    @objc func checkForUpdate() {
        guard let updateChecker = updateChecker else {
            Logger.service.error("Unable to check for updates: updateChecker is nil.")
            return
        }
        updateChecker.checkForUpdates()
    }

    func getXPCExtensionService() -> XPCExtensionService {
        if let service = xpcExtensionService { return service }
        let service = XPCExtensionService(logger: .service)
        xpcExtensionService = service
        return service
    }

    func watchServiceStatus() {
        let notifications = NotificationCenter.default.notifications(named: .serviceStatusDidChange)
        Task { [weak self] in
            for await _ in notifications {
                guard let self else { return }
                self.updateStatusBarItem()
            }
        }
    }

    func watchAXStatus() {
        let osNotifications = DistributedNotificationCenter.default().notifications(named: NSNotification.Name("com.apple.accessibility.api"))
        Task { [weak self] in
            for await _ in osNotifications {
                guard let self else { return }
                self.updateStatusBarItem()
            }
        }
    }
    
    
    func observeFeatureFlags() {
        Task { @MainActor in
            FeatureFlagNotifierImpl.shared.featureFlagsDidChange
                .sink(receiveValue: { [weak self] featureFlags in
                    self?.toggleNES.isHidden = !featureFlags.editorPreviewFeatures
                })
        }
    }

    func watchAuthStatus() {
        let notifications = DistributedNotificationCenter.default().notifications(named: .authStatusDidChange)
        Task { [weak self] in
            for await _ in notifications {
                guard self != nil else { return }
                do {
                    let service = try await GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
                    let accountStatus = try await service.checkStatus()
                    if accountStatus == .notSignedIn {
                        try await GitHubCopilotService.signOutAll()
                    }
                } catch {
                    Logger.service.error("Failed to watch auth status: \(error)")
                }
            }
        }
    }

    func setInitialStatusBarStatus() {
        Task {
            let authStatus = await Status.shared.getAuthStatus()
            if authStatus.status == .unknown {
                // temporarily kick off a language server instance to prime the initial auth status
                await forceAuthStatusCheck()
            }
            updateStatusBarItem()
        }
    }

    func forceAuthStatusCheck() async {
        do {
            let service = try await GitHubCopilotViewModel.shared.getGitHubCopilotAuthService()
            let accountStatus = try await service.checkStatus()
            if accountStatus == .ok || accountStatus == .maybeOk {
                let quota = try await service.checkQuota()
                Logger.service.info("User quota checked successfully: \(quota)")
            }
        } catch {
            Logger.service.error("Failed to read auth status: \(error)")
        }
    }
    
    private func configureNotLoggedIn() {
        self.accountItem.view = AccountItemView(
            target: self,
            action: #selector(signIntoGitHub)
        )
        self.authStatusItem.isHidden = true
        self.quotaItem.isHidden = true
        self.toggleCompletions.isHidden = true
        self.toggleIgnoreLanguage.isHidden = true
        self.toggleNES.isHidden = true
        self.signOutItem.isHidden = true
    }

    private func configureLoggedIn(status: StatusResponse) {
        self.accountItem.view = AccountItemView(
            target: self,
            action: nil,
            userName: status.userName ?? ""
        )
        if !status.clsMessage.isEmpty  {
            let CLSMessageSummary = getCLSMessageSummary(status.clsMessage)
            // If the quota is nil, keep the original auth status item
            // Else only log the CLS error other than quota limit reached error
            if CLSMessageSummary.summary == CLSMessageType.other.summary || status.quotaInfo == nil {
                configureCLSAuthStatusItem(
                    summary: CLSMessageSummary,
                    actionTitle: "View Details on GitHub",
                    action: #selector(openGitHubDetailsLink)
                )
            } else if CLSMessageSummary.summary == CLSMessageType.byokLimitedReached.summary {
                configureCLSAuthStatusItem(
                    summary: CLSMessageSummary,
                    actionTitle: "Dismiss",
                    action: #selector(dismissBYOKMessage)
                )
            } else {
                // Explicitly hide to avoid leaving stale content if another CLS state was previously shown.
                self.authStatusItem.isHidden = true
            }
        } else {
            self.authStatusItem.isHidden = true
        }
        
        if let quotaInfo = status.quotaInfo, !quotaInfo.resetDate.isEmpty {
            self.quotaItem.isHidden = false
            self.quotaItem.view = QuotaView(
                chat: .init(
                    percentRemaining: quotaInfo.chat.percentRemaining,
                    unlimited: quotaInfo.chat.unlimited,
                    overagePermitted: quotaInfo.chat.overagePermitted
                ),
                completions: .init(
                    percentRemaining: quotaInfo.completions.percentRemaining,
                    unlimited: quotaInfo.completions.unlimited,
                    overagePermitted: quotaInfo.completions.overagePermitted
                ),
                premiumInteractions: .init(
                    percentRemaining: quotaInfo.premiumInteractions.percentRemaining,
                    unlimited: quotaInfo.premiumInteractions.unlimited,
                    overagePermitted: quotaInfo.premiumInteractions.overagePermitted
                ),
                resetDate: quotaInfo.resetDate,
                copilotPlan: quotaInfo.copilotPlan
            )
        } else {
            self.quotaItem.isHidden = true
        }
        
        self.toggleCompletions.isHidden = false
        self.toggleIgnoreLanguage.isHidden = false
        self.toggleNES.isHidden = false
        self.signOutItem.isHidden = false
    }

    func configureCLSAuthStatusItem(
        summary: CLSMessage,
        actionTitle: String,
        action: Selector
    ) {
        self.authStatusItem.isHidden = false
        self.authStatusItem.title = summary.summary
        let submenu = NSMenu()
        
        let attributedCLSErrorItem = NSMenuItem()
        attributedCLSErrorItem.view = ErrorMessageView(
            errorMessage: summary.detail
        )
        submenu.addItem(attributedCLSErrorItem)
        submenu.addItem(.separator())
        submenu.addItem(
            NSMenuItem(
                title: actionTitle,
                action: action,
                keyEquivalent: ""
            )
        )
        self.authStatusItem.submenu = submenu
        self.authStatusItem.isEnabled = true
    }

    private func configureNotAuthorized(status: StatusResponse) {
        self.accountItem.view = AccountItemView(
            target: self,
            action: nil,
            userName: status.userName ?? ""
        )
        self.authStatusItem.isHidden = false
        self.authStatusItem.title = "No Subscription"
        
        let submenu = NSMenu()
        let attributedNotAuthorizedItem = NSMenuItem()
        attributedNotAuthorizedItem.view = ErrorMessageView(
            errorMessage: "GitHub Copilot features are disabled. Check your subscription to enable them."
        )
        attributedNotAuthorizedItem.isEnabled = true
        submenu.addItem(attributedNotAuthorizedItem)
        
        self.authStatusItem.submenu = submenu
        self.authStatusItem.isEnabled = true
        
        self.quotaItem.isHidden = true
        self.toggleCompletions.isHidden = true
        self.toggleIgnoreLanguage.isHidden = true
        self.toggleNES.isHidden = true
        self.signOutItem.isHidden = false
    }

    private func configureUnknown() {
        self.accountItem.view = AccountItemView(
            target: self,
            action: nil,
            userName: "Unknown User"
        )
        self.authStatusItem.isHidden = true
        self.quotaItem.isHidden = true
        self.toggleCompletions.isHidden = false
        self.toggleIgnoreLanguage.isHidden = false
        self.toggleNES.isHidden = false
        self.signOutItem.isHidden = false
    }

    func updateStatusBarItem() {
        Task { @MainActor in
            let status = await Status.shared.getStatus()
            /// Update status bar icon
            self.statusBarItem.button?.image = status.icon.nsImage
            
            /// Update auth status related status bar items
            switch status.authStatus {
            case .notLoggedIn: configureNotLoggedIn()
            case .loggedIn: configureLoggedIn(status: status)
            case .notAuthorized: configureNotAuthorized(status: status)
            case .unknown: configureUnknown()
            }
            
            /// Update accessibility permission status bar item
            let exclamationmarkImage = NSImage(
                systemSymbolName: "exclamationmark.circle.fill",
                accessibilityDescription: "Permission not granted"
            )
            exclamationmarkImage?.isTemplate = false
            exclamationmarkImage?.withSymbolConfiguration(.init(paletteColors: [.red]))
            
            if let message = status.message {
                self.axStatusItem.title = message
                if let image = exclamationmarkImage {
                    self.axStatusItem.image = image
                }
                self.axStatusItem.isHidden = false
                self.axStatusItem.isEnabled = status.url != nil
            } else {
                self.axStatusItem.isHidden = true
            }
            
            /// Update settings status bar item
            if status.extensionStatus == .disabled || status.extensionStatus == .notGranted {
                if let image = exclamationmarkImage{
                    if #available(macOS 15.0, *){
                        self.extensionStatusItem.image = image
                        self.extensionStatusItem.title = status.extensionStatus == .notGranted ? "Enable extension for full-featured completion" : "Quit and restart Xcode to enable extension"
                        self.extensionStatusItem.isHidden = false
                        self.extensionStatusItem.isEnabled = status.extensionStatus == .notGranted
                    } else {
                        self.extensionStatusItem.isHidden = true
                        self.openCopilotForXcodeItem.image = image
                    }
                }
            } else {
                self.openCopilotForXcodeItem.image = nil
                self.extensionStatusItem.isHidden = true
            }
            self.markAsProcessing(status.inProgress)
        }
    }

    func markAsProcessing(_ isProcessing: Bool) {
        if !isProcessing {
            // No longer in progress
            progressView?.removeFromSuperview()
            progressView = nil
            return
        }
        if progressView != nil {
            // Already in progress
            return
        }
        let progress = NSProgressIndicator()
        progress.style = .spinning
        progress.sizeToFit()
        progress.frame = statusBarItem.button?.bounds ?? .zero
        progress.isIndeterminate = true
        progress.startAnimation(nil)
        statusBarItem.button?.addSubview(progress)
        statusBarItem.button?.image = nil
        progressView = progress
    }
    
    @objc func openGitHubDetailsLink() {
        Task {
            if let url = URL(string: "https://github.com/copilot") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc func dismissBYOKMessage() {
        Task {
            await Status.shared.updateCLSStatus(.normal, busy: false, message: "")
        }
    }
}

extension NSRunningApplication {
    var isUserOfService: Bool {
        [
            "com.apple.dt.Xcode",
            bundleIdentifierBase,
        ].contains(bundleIdentifier)
    }
}

enum CLSMessageType {
    case chatLimitReached
    case completionLimitReached
    case byokLimitedReached
    case other
    
    var summary: String {
        switch self {
        case .chatLimitReached:
            return "Monthly Chat Limit Reached"
        case .completionLimitReached:
            return "Monthly Completion Limit Reached"
        case .byokLimitedReached:
            return "BYOK Limit Reached"
        case .other:
            return "CLS Error"
        }
    }
}

struct CLSMessage {
    let summary: String
    let detail: String
}

func extractDateFromCLSMessage(_ message: String) -> String? {
    let pattern = #"until (\d{1,2}/\d{1,2}/\d{4}, \d{1,2}:\d{2}:\d{2} [AP]M)"#
    if let range = message.range(of: pattern, options: .regularExpression) {
        return String(message[range].dropFirst(6))
    }
    return nil
}

func getCLSMessageSummary(_ message: String) -> CLSMessage {
    let messageType: CLSMessageType
    
    if message.contains("You've reached your monthly chat messages limit") ||
       message.contains("You've reached your monthly chat messages quota") {
        messageType = .chatLimitReached
    } else if message.contains("Completions limit reached") {
        messageType = .completionLimitReached
    } else if message.contains("BYOK") {
        messageType = .byokLimitedReached
    } else {
        messageType = .other
    }
    
    let detail: String
    if let date = extractDateFromCLSMessage(message) {
        detail = "Visit GitHub to check your usage and upgrade to Copilot Pro or wait until \(date) for your limit to reset."
    } else {
        detail = message
    }
    
    return CLSMessage(summary: messageType.summary, detail: detail)
}
