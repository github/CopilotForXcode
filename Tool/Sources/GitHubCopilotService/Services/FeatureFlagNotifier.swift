import Combine
import SwiftUI
import JSONRPC

public extension Notification.Name {
    static let gitHubCopilotFeatureFlagsDidChange = Notification
        .Name("com.github.CopilotForXcode.CopilotFeatureFlagsDidChange")
}

public enum ExperimentValue: Hashable, Codable {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case stringArray([String])
}

public typealias ActiveExperimentForFeatureFlags = [String: ExperimentValue]

public struct DidChangeFeatureFlagsParams: Hashable, Codable {
    let envelope: [String: JSONValue]
    let token: [String: String]
    let activeExps: ActiveExperimentForFeatureFlags
    let byok: Bool?
}

public struct FeatureFlags: Hashable, Codable {
    public var restrictedTelemetry: Bool
    public var snippy: Bool
    public var chat: Bool
    public var inlineChat: Bool
    public var projectContext: Bool
    public var agentMode: Bool
    public var mcp: Bool
    public var ccr: Bool // Copilot Code Review
    public var byok: Bool
    public var editorPreviewFeatures: Bool
    public var activeExperimentForFeatureFlags: ActiveExperimentForFeatureFlags
    public var agentModeAutoApproval: Bool

    public init(
        restrictedTelemetry: Bool = true,
        snippy: Bool = true,
        chat: Bool = true,
        inlineChat: Bool = true,
        projectContext: Bool = true,
        agentMode: Bool = true,
        mcp: Bool = true,
        ccr: Bool = true,
        byok: Bool = true,
        editorPreviewFeatures: Bool = true,
        activeExperimentForFeatureFlags: ActiveExperimentForFeatureFlags = [:],
        agentModeAutoApproval: Bool = true
    ) {
        self.restrictedTelemetry = restrictedTelemetry
        self.snippy = snippy
        self.chat = chat
        self.inlineChat = inlineChat
        self.projectContext = projectContext
        self.agentMode = agentMode
        self.mcp = mcp
        self.ccr = ccr
        self.byok = byok
        self.editorPreviewFeatures = editorPreviewFeatures
        self.activeExperimentForFeatureFlags = activeExperimentForFeatureFlags
        self.agentModeAutoApproval = agentModeAutoApproval
    }
}

public protocol FeatureFlagNotifier {
    var didChangeFeatureFlagsParams: DidChangeFeatureFlagsParams { get }
    var featureFlagsDidChange: PassthroughSubject<FeatureFlags, Never> { get }
    func handleFeatureFlagNotification(_ didChangeFeatureFlagsParams: DidChangeFeatureFlagsParams)
}

public class FeatureFlagNotifierImpl: FeatureFlagNotifier {
    public var didChangeFeatureFlagsParams: DidChangeFeatureFlagsParams
    public var featureFlags: FeatureFlags
    public static let shared = FeatureFlagNotifierImpl()
    public var featureFlagsDidChange: PassthroughSubject<FeatureFlags, Never>
    
    init(
        didChangeFeatureFlagsParams: DidChangeFeatureFlagsParams = .init(
            envelope: [:],
            token: [:],
            activeExps: [:],
            byok: nil
        ),
        featureFlags: FeatureFlags = FeatureFlags(),
        featureFlagsDidChange: PassthroughSubject<FeatureFlags, Never> = PassthroughSubject<FeatureFlags, Never>()
    ) {
        self.didChangeFeatureFlagsParams = didChangeFeatureFlagsParams
        self.featureFlags = featureFlags
        self.featureFlagsDidChange = featureFlagsDidChange
    }
    
    private func updateFeatureFlags() {
        let xcodeChat = self.didChangeFeatureFlagsParams.envelope["xcode_chat"]?.boolValue != false
        let chatEnabled = self.didChangeFeatureFlagsParams.envelope["chat_enabled"]?.boolValue != false
        self.featureFlags.restrictedTelemetry = self.didChangeFeatureFlagsParams.token["rt"] != "0"
        self.featureFlags.snippy = self.didChangeFeatureFlagsParams.token["sn"] != "0"
        self.featureFlags.chat = xcodeChat && chatEnabled
        self.featureFlags.inlineChat = chatEnabled
        self.featureFlags.agentMode = self.didChangeFeatureFlagsParams.token["agent_mode"] != "0"
        self.featureFlags.mcp = self.didChangeFeatureFlagsParams.token["mcp"] != "0"
        self.featureFlags.ccr = self.didChangeFeatureFlagsParams.token["ccr"] != "0"
        self.featureFlags.byok = self.didChangeFeatureFlagsParams.byok != false
        self.featureFlags.editorPreviewFeatures = self.didChangeFeatureFlagsParams.token["editor_preview_features"] != "0"
        self.featureFlags.activeExperimentForFeatureFlags = self.didChangeFeatureFlagsParams.activeExps
        self.featureFlags.agentModeAutoApproval = self.didChangeFeatureFlagsParams.token["agent_mode_auto_approval"] != "0"
    }

    public func handleFeatureFlagNotification(_ didChangeFeatureFlagsParams: DidChangeFeatureFlagsParams) {
        self.didChangeFeatureFlagsParams = didChangeFeatureFlagsParams
        updateFeatureFlags()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.featureFlagsDidChange.send(self.featureFlags)
            DistributedNotificationCenter.default().post(name: .gitHubCopilotFeatureFlagsDidChange, object: nil)
        }
    }
}
