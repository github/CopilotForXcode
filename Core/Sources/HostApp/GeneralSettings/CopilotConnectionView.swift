import ComposableArchitecture
import GitHubCopilotViewModel
import SwiftUI
import Client

struct CopilotConnectionView: View {
    @AppStorage("username") var username: String = ""
    @Environment(\.toast) var toast
    @StateObject var viewModel: GitHubCopilotViewModel

    let store: StoreOf<General>

    var body: some View {
        WithPerceptionTracking {
            VStack {
                connection
                    .padding(.bottom, 20)
                copilotResources
            }
        }
    }
    
    var accountStatusString: String {
        switch store.xpcServiceAuthStatus.status {
        case .loggedIn:
            return "Active"
        case .notLoggedIn:
            return "Not Signed In"
        case .notAuthorized:
            return "No Subscription"
        case .unknown:
            return "Loading..."
        }
    }

    var accountStatus: some View {
        SettingsButtonRow(
            title: "GitHub Account Status Permissions",
            subtitle: "GitHub Account: \(accountStatusString)"
        ) {
            if viewModel.isRunningAction || viewModel.waitingForSignIn {
                ProgressView().controlSize(.small)
            }
            Button("Refresh Connection") {
                store.send(.reloadStatus)
            }
            if viewModel.waitingForSignIn {
                Button("Cancel") {
                    viewModel.cancelWaiting()
                }
            } else if store.xpcServiceAuthStatus.status == .notLoggedIn {
                Button("Log in to GitHub") {
                    viewModel.signIn()
                }
                .alert(
                    viewModel.signInResponse?.userCode ?? "",
                    isPresented: $viewModel.isSignInAlertPresented,
                    presenting: viewModel.signInResponse) { _ in
                        Button("Cancel", role: .cancel, action: {})
                        Button(
                            "Copy Code and Open",
                            action: { viewModel.copyAndOpen(fromHostApp: true) }
                        )
                    } message: { response in
                        Text("""
                               Please enter the above code in the \
                               GitHub website to authorize your \
                               GitHub account with Copilot for Xcode.
                               
                               \(response?.verificationURL.absoluteString ?? "")
                               """)
                    }
            }
            if store.xpcServiceAuthStatus.status == .loggedIn || store.xpcServiceAuthStatus.status == .notAuthorized {
                Button("Log Out from GitHub") {
                    Task {
                        viewModel.signOut()
                        viewModel.isSignInAlertPresented = false
                        let service = try getService()
                        do {
                            try await service.signOutAllGitHubCopilotService()
                        } catch {
                            toast(error.localizedDescription, .error)
                        }
                    }
                }
            }
        }
    }

    var connection: some View {
        SettingsSection(
            title: "Account Settings",
            showWarning: store.xpcServiceAuthStatus.status == .notAuthorized
        ) {
            accountStatus
            Divider()
            if store.xpcServiceAuthStatus.status == .notAuthorized {
                SettingsLink(
                    url: "https://github.com/features/copilot/plans",
                    title: "Enable powerful AI features for free with the GitHub Copilot Free plan"
                )
                Divider()
            }
            SettingsLink(
                url: "https://github.com/settings/copilot",
                title: "GitHub Copilot Account Settings"
            )
        }
        .onReceive(DistributedNotificationCenter.default().publisher(for: .authStatusDidChange)) { _ in
            store.send(.reloadStatus)
        }
    }

    var copilotResources: some View {
        SettingsSection(title: "Copilot Resources") {
            SettingsLink(
                url: "https://docs.github.com/en/copilot",
                title: "View Copilot Documentation"
            )
            Divider()
            SettingsLink(
                url: "https://github.com/github/CopilotForXcode/discussions",
                title: "View Copilot Feedback Forum"
            )
        }
    }
}


#Preview {
    CopilotConnectionView(
        viewModel: GitHubCopilotViewModel.shared,
        store: .init(initialState: .init(), reducer: { General() })
    )
}

#Preview("Running") {
    let runningModel =  GitHubCopilotViewModel.shared
    runningModel.isRunningAction = true
    return CopilotConnectionView(
        viewModel: GitHubCopilotViewModel.shared,
        store: .init(initialState: .init(), reducer: { General() })
    )
}
