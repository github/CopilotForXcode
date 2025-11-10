import Combine
import SwiftUI
import JSONRPC

public extension Notification.Name {
    static let gitHubCopilotPolicyDidChange = Notification
        .Name("com.github.CopilotForXcode.CopilotPolicyDidChange")
}

public struct CopilotPolicy: Hashable, Codable {
    public var mcpContributionPointEnabled: Bool = true
    public var customAgentEnabled: Bool = true
    public var subagentEnabled: Bool = true
    public var cveRemediatorAgentEnabled: Bool = true

    enum CodingKeys: String, CodingKey {
        case mcpContributionPointEnabled = "mcp.contributionPoint.enabled"
        case customAgentEnabled = "customAgent.enabled"
        case subagentEnabled = "subagent.enabled"
        case cveRemediatorAgentEnabled = "cveRemediatorAgent.enabled"
    }
}

public protocol CopilotPolicyNotifier {
    var copilotPolicy: CopilotPolicy { get }
    var policyDidChange: PassthroughSubject<CopilotPolicy, Never> { get }
    func handleCopilotPolicyNotification(_ policy: CopilotPolicy)
}

public class CopilotPolicyNotifierImpl: CopilotPolicyNotifier {
    public private(set) var copilotPolicy: CopilotPolicy
    public static let shared = CopilotPolicyNotifierImpl()
    public var policyDidChange: PassthroughSubject<CopilotPolicy, Never>

    init(
        copilotPolicy: CopilotPolicy = CopilotPolicy(),
        policyDidChange: PassthroughSubject<CopilotPolicy, Never> = PassthroughSubject<CopilotPolicy, Never>()
    ) {
        self.copilotPolicy = copilotPolicy
        self.policyDidChange = policyDidChange
    }

    public func handleCopilotPolicyNotification(_ policy: CopilotPolicy) {
        self.copilotPolicy = policy
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.policyDidChange.send(self.copilotPolicy)
            DistributedNotificationCenter.default().post(name: .gitHubCopilotPolicyDidChange, object: nil)
        }
    }
}
