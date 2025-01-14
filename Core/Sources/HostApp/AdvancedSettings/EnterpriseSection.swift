import Combine
import SwiftUI
import Toast

struct EnterpriseSection: View {
    @AppStorage(\.gitHubCopilotEnterpriseURI) var gitHubCopilotEnterpriseURI
    @AppStorage(\.nodeExtraCaCerts) var nodeExtraCaCerts
    @Environment(\.toast) var toast

    var body: some View {
        SettingsSection(title: "Enterprise") {
            SettingsTextField(
                title: "Auth provider URL",
                prompt: "https://your-enterprise.ghe.com",
                text: DebouncedBinding($gitHubCopilotEnterpriseURI, handler: enterpriseUrlChanged).binding
            )
            SettingsTextField(
                title: "Node extra CA certs",
                prompt: "Path to extra CA certs (requires restart)",
                text: DebouncedBinding($nodeExtraCaCerts, handler: nodeExtraCaCertsChanged).binding
            )
        }
    }

    func enterpriseUrlChanged(_ url: String) {
        if !url.isEmpty {
            validateAuthURL(url)
        }
        NotificationCenter.default.post(
            name: .gitHubCopilotShouldRefreshEditorInformation,
            object: nil
        )
    }

    func nodeExtraCaCertsChanged(_ path: String) {
        NotificationCenter.default.post(
            name: .gitHubCopilotShouldRefreshEditorInformation,
            object: nil
        )
    }

    func validateAuthURL(_ url: String) {
        let maybeURL = URL(string: url)
        guard let parsedURl = maybeURL else {
            toast("Invalid URL", .error)
            return
        }
        if parsedURl.scheme != "https" {
            toast("URL scheme must be https://", .error)
            return
        }
    }
}

#Preview {
    EnterpriseSection()
}
