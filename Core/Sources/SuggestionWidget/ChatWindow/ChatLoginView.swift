import SwiftUI
import Perception
import GitHubCopilotViewModel
import SharedUIComponents

struct ChatLoginView: View {
    @StateObject var viewModel: GitHubCopilotViewModel
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0){
                VStack(spacing: 24) {
                    Spacer()
                    VStack(spacing: 8) {
                        Image("CopilotLogo")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFill()
                            .scaledFrame(width: 60.0, height: 60.0)
                            .foregroundColor(.secondary)
                        
                        Text("Welcome to Copilot")
                            .scaledFont(.largeTitle)
                            .multilineTextAlignment(.center)
                        
                        Text("Your AI-powered coding assistant")
                            .scaledFont(.body)
                            .multilineTextAlignment(.center)
                    }
                    
                    CopilotIntroView()
                    
                    VStack(spacing: 8) {
                        Button("Sign Up for Copilot Free") {
                            if let url = URL(string: "https://github.com/features/copilot/plans") {
                                openURL(url)
                            }
                        }
                        .scaledFont(.body)
                        .buttonStyle(.borderedProminent)
                        
                        HStack{
                            Text("Already have an account?")
                                .scaledFont(.body)
                            
                            Button("Sign In") { viewModel.signIn() }
                                .scaledFont(.body)
                                .buttonStyle(.borderless)
                                .foregroundColor(Color("TextLinkForegroundColor"))
                            
                            if viewModel.isRunningAction || viewModel.waitingForSignIn {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                    .scaledPadding(.top, 16)
                    
                    Spacer()
                    Text("Copilot Free and Copilot Pro may show [public code](https://aka.ms/github-copilot-match-public-code) suggestions and collect telemetry. You can change these [GitHub settings](https://aka.ms/github-copilot-settings) at any time. By continuing, you agree to our [terms](https://github.com/customer-terms/github-copilot-product-specific-terms) and [privacy policy](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).")
                        .scaledFont(.system(size: 12))
                }
                .padding()
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            }
            .xcodeStyleFrame()
            .ignoresSafeArea(edges: .top)
            .alert(
                viewModel.signInResponse?.userCode ?? "",
                isPresented: $viewModel.isSignInAlertPresented,
                presenting: viewModel.signInResponse
            ) { _ in
                Button("Cancel", role: .cancel, action: {})
                    .scaledFont(.body)
                
                Button("Copy Code and Open", action: { viewModel.copyAndOpen(fromHostApp: false) })
                    .scaledFont(.body)
            } message: { response in
                Text("""
                    Please enter the above code in the GitHub website \
                    to authorize your GitHub account with Copilot for Xcode.
                    
                    \(response?.verificationURL.absoluteString ?? "")
                    """)
            }
        }
    }
}

struct ChatLoginView_Previews: PreviewProvider {
    static var previews: some View {
        ChatLoginView(viewModel: GitHubCopilotViewModel.shared)
    }
}
