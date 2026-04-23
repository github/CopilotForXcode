import Foundation
import GitHubCopilotService
import ComposableArchitecture
import Status
import SwiftUI
import Cache
import Client

public struct SignInResponse {
    public let status: SignInInitiateStatus
    public let userCode: String
    public let verificationURL: URL
}

@MainActor
public class GitHubCopilotViewModel: ObservableObject {
    // Add static shared instance
    public static let shared = GitHubCopilotViewModel()
    
    @Dependency(\.toast) var toast
    
    @AppStorage("username") var username: String = ""
    
    @Published public var isRunningAction: Bool = false
    @Published public var status: GitHubCopilotAccountStatus?
    @Published public var version: String?
    @Published public var userCode: String?
    @Published public var isSignInAlertPresented = false
    @Published public var signInResponse: SignInResponse?
    @Published public var waitingForSignIn = false
    
    static var copilotAuthService: GitHubCopilotService?
    
    // Make init private to enforce singleton pattern
    private init() {}
    
    public func getGitHubCopilotAuthService() throws -> GitHubCopilotService {
        if let service = Self.copilotAuthService { return service }
        let service = try GitHubCopilotService()
        Self.copilotAuthService = service
        return service
    }
    
    public func preSignIn() async throws -> SignInResponse? {
        let service = try getGitHubCopilotAuthService()
        let result = try await service.signInInitiate()
        
        if result.status == .alreadySignedIn {
            guard let user = result.user else {
                toast("Missing user info.", .error)
                throw NSError(domain: "Missing user info.", code: 0, userInfo: nil)
            }
            await Status.shared.updateAuthStatus(.loggedIn, username: user)
            self.username = user
            broadcastStatusChange()
            return nil
        }
        
        guard let uri = result.verificationUri,
              let userCode = result.userCode,
              let url = URL(string: uri) else {
            toast("Verification URI is incorrect.", .error)
            throw NSError(domain: "Verification URI is incorrect.", code: 0, userInfo: nil)
        }
        return SignInResponse(
            status: SignInInitiateStatus.promptUserDeviceFlow,
            userCode: userCode,
            verificationURL: url
        )
    }
    
    public func signIn() {
        Task {
            isRunningAction = true
            defer { isRunningAction = false }
            do {
                guard let result = try await preSignIn() else { return }
                self.signInResponse = result
                self.isSignInAlertPresented = true
            } catch {
                toast(error.localizedDescription, .error)
            }
        }
    }
    
    public func checkStatus() {
        Task {
            isRunningAction = true
            defer { isRunningAction = false }
            do {
                let service = try getGitHubCopilotAuthService()
                status = try await service.checkStatus()
                version = try await service.version()
                isRunningAction = false
            } catch {
                toast(error.localizedDescription, .error)
            }
        }
    }
    
    public func signOut() {
        Task {
            isRunningAction = true
            defer { isRunningAction = false }
            do {
                let service = try getGitHubCopilotAuthService()
                status = try await service.signOut()
                await Status.shared.updateAuthStatus(.notLoggedIn)
                await Status.shared.updateCLSStatus(.unknown, busy: false, message: "")
                await Status.shared.updateQuotaInfo(nil)
                username = ""
                broadcastStatusChange()
            } catch {
                toast(error.localizedDescription, .error)
            }

            // Sign out all other CLS instances
            do {
                try await GitHubCopilotService.signOutAll()
            } catch {
                // ignore
            }
        }
    }
    
    public func cancelWaiting() {
        waitingForSignIn = false
    }
    
    public func copyAndOpen(fromHostApp: Bool = false) {
        waitingForSignIn = true
        guard let signInResponse else {
            toast("Missing sign in details.", .error)
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
        pasteboard.setString(signInResponse.userCode, forType: NSPasteboard.PasteboardType.string)
        toast("Sign-in code \(signInResponse.userCode) copied", .info)
        NSWorkspace.shared.open(signInResponse.verificationURL)
        waitForSignIn(fromHostApp: fromHostApp)
    }
    
    public func waitForSignIn(fromHostApp: Bool = false) {
        Task {
            do {
                guard waitingForSignIn else { return }
                guard let signInResponse else {
                    waitingForSignIn = false
                    return
                }
                let service = try getGitHubCopilotAuthService()
                let (username, status) = try await service.signInConfirm(userCode: signInResponse.userCode)
                waitingForSignIn = false
                self.username = username
                self.status = status
                await Status.shared.updateAuthStatus(.loggedIn, username: username)
                broadcastStatusChange()
                if !fromHostApp {
                    let models = try? await service.models()
                    if let models = models, !models.isEmpty {
                        CopilotModelManager.updateLLMs(models)
                    }
                } else {
                    let xpcService = try getService()
                    _ = try? await xpcService.updateCopilotModels()
                }
            } catch let error as GitHubCopilotError {
                switch error {
                case .languageServerError(.timeout):
                    waitForSignIn(fromHostApp: fromHostApp)
                    return
                case .languageServerError(
                    .serverError(
                        code: CLSErrorCode.deviceFlowFailed.rawValue,
                        message: _,
                        data: _
                    )
                ):
                    await showSignInFailedAlert(error: error)
                    waitingForSignIn = false
                    return
                default:
                    throw error
                }
            } catch {
                toast(error.localizedDescription, .error)
            }
        }
    }
    
    private func extractSigninErrorMessage(error: GitHubCopilotError) -> String {
        let errorDescription = error.localizedDescription
        
        // Handle specific EACCES permission denied errors
        if errorDescription.contains("EACCES") {
            // Look for paths wrapped in single quotes
            let pattern = "'([^']+)'"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: errorDescription.utf16.count)
                if let match = regex.firstMatch(in: errorDescription, options: [], range: range) {
                    let pathRange = Range(match.range(at: 1), in: errorDescription)!
                    let path = String(errorDescription[pathRange])
                    return path
                }
            }
        }
        
        return errorDescription
    }
    
    private func getSigninErrorTitle(error: GitHubCopilotError) -> String {
        let errorDescription = error.localizedDescription
        
        if errorDescription.contains("EACCES") {
            return "Can't sign you in. The app couldn't create or access files in"
        }
        
        return "Error details:"
    }

    private var accessPermissionCommands: String {
        """
        sudo mkdir -p ~/.config/github-copilot
        sudo chown -R $(whoami):staff ~/.config
        chmod -N ~/.config ~/.config/github-copilot
        """
    }
    
    private var containerBackgroundColor: CGColor {
        let isDarkMode = NSApp.effectiveAppearance.name == .darkAqua
        return isDarkMode 
        ? NSColor.black.withAlphaComponent(0.85).cgColor
        : NSColor.white.withAlphaComponent(0.85).cgColor
    }
    
    // MARK: - Alert Building Functions
    
    private func showSignInFailedAlert(error: GitHubCopilotError) async {
        let alert = NSAlert()
        alert.messageText = "GitHub Copilot Sign-in Failed"
        alert.alertStyle = .critical
        
        let accessoryView = createAlertAccessoryView(error: error)
        alert.accessoryView = accessoryView
        alert.addButton(withTitle: "Copy Commands")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            copyCommandsToClipboard()
        }
    }
    
    private func createAlertAccessoryView(error: GitHubCopilotError) -> NSView {
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 142))
        
        let detailsHeader = createDetailsHeader(error: error)
        accessoryView.addSubview(detailsHeader)
        
        let errorContainer = createErrorContainer(error: error)
        accessoryView.addSubview(errorContainer)
        
        let terminalHeader = createTerminalHeader()
        accessoryView.addSubview(terminalHeader)
        
        let commandsContainer = createCommandsContainer()
        accessoryView.addSubview(commandsContainer)
        
        return accessoryView
    }
    
    private func createDetailsHeader(error: GitHubCopilotError) -> NSView {
        let detailsHeader = NSView(frame: NSRect(x: 16, y: 122, width: 368, height: 20))
        
        let warningIcon = NSImageView(frame: NSRect(x: 0, y: 4, width: 16, height: 16))
        warningIcon.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Warning")
        warningIcon.contentTintColor = NSColor.systemOrange
        detailsHeader.addSubview(warningIcon)

        let detailsLabel = NSTextField(wrappingLabelWithString: getSigninErrorTitle(error: error))
        detailsLabel.frame = NSRect(x: 20, y: 0, width: 346, height: 20)
        detailsLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        detailsLabel.textColor = NSColor.labelColor
        detailsHeader.addSubview(detailsLabel)
        
        return detailsHeader
    }
    
    private func createErrorContainer(error: GitHubCopilotError) -> NSView {
        let errorContainer = NSView(frame: NSRect(x: 16, y: 96, width: 368, height: 22))
        errorContainer.wantsLayer = true
        errorContainer.layer?.backgroundColor = containerBackgroundColor
        errorContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        errorContainer.layer?.borderWidth = 1
        errorContainer.layer?.cornerRadius = 6
        
        let errorMessage = NSTextField(wrappingLabelWithString: extractSigninErrorMessage(error: error))
        errorMessage.frame = NSRect(x: 8, y: 4, width: 368, height: 14)
        errorMessage.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        errorMessage.textColor = NSColor.labelColor
        errorMessage.backgroundColor = .clear
        errorMessage.isBordered = false
        errorMessage.isEditable = false
        errorMessage.drawsBackground = false
        errorMessage.usesSingleLineMode = true
        errorContainer.addSubview(errorMessage)
        
        return errorContainer
    }
    
    private func createTerminalHeader() -> NSView {
        let terminalHeader = NSView(frame: NSRect(x: 16, y: 66, width: 368, height: 20))
        
        let toolIcon = NSImageView(frame: NSRect(x: 0, y: 4, width: 16, height: 16))
        toolIcon.image = NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: "Terminal")
        toolIcon.contentTintColor = NSColor.secondaryLabelColor
        terminalHeader.addSubview(toolIcon)
        
        let terminalLabel = NSTextField(wrappingLabelWithString: "Copy and run the commands below in Terminal, then retry.")
        terminalLabel.frame = NSRect(x: 20, y: 0, width: 346, height: 20)
        terminalLabel.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        terminalLabel.textColor = NSColor.labelColor
        terminalHeader.addSubview(terminalLabel)
        
        return terminalHeader
    }
    
    private func createCommandsContainer() -> NSView {
        let commandsContainer = NSView(frame: NSRect(x: 16, y: 4, width: 368, height: 58))
        commandsContainer.wantsLayer = true
        commandsContainer.layer?.backgroundColor = containerBackgroundColor
        commandsContainer.layer?.borderColor = NSColor.separatorColor.cgColor
        commandsContainer.layer?.borderWidth = 1
        commandsContainer.layer?.cornerRadius = 6
        
        let commandsText = NSTextField(wrappingLabelWithString: accessPermissionCommands)
        commandsText.frame = NSRect(x: 8, y: 8, width: 344, height: 42)
        commandsText.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        commandsText.textColor = NSColor.labelColor
        commandsText.backgroundColor = .clear
        commandsText.isBordered = false
        commandsText.isEditable = false
        commandsText.isSelectable = true
        commandsText.drawsBackground = false
        commandsContainer.addSubview(commandsText)
        
        return commandsContainer
    }
    
    private func copyCommandsToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            self.accessPermissionCommands.replacingOccurrences(of: "\n", with: " && "),
            forType: .string
        )
    }

    public func broadcastStatusChange() {
        DistributedNotificationCenter.default().post(
            name: .authStatusDidChange,
            object: nil
        )
    }
}
