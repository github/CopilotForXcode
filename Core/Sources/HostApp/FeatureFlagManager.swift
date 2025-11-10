import Client
import Combine
import Foundation
import GitHubCopilotService
import Logger
import SwiftUI

/// Centralized manager for GitHub Copilot feature flags in the HostApp
/// Use as @StateObject or @ObservedObject in SwiftUI views
@MainActor
public class FeatureFlagManager: ObservableObject {
    public static let shared = FeatureFlagManager()
    
    // MARK: - Published Properties
    
    @Published public private(set) var isAgentModeEnabled = true
    @Published public private(set) var isBYOKEnabled = true
    @Published public private(set) var isMCPEnabled = true
    @Published public private(set) var isEditorPreviewEnabled = true
    @Published public private(set) var isChatEnabled = true
    @Published public private(set) var isCodeReviewEnabled = true
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var lastUpdateTime: Date?
    private let updateThrottle: TimeInterval = 1.0 // Prevent excessive updates
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationObserver()
        Task {
            await updateFeatureFlags()
        }
    }
    
    // MARK: - Public Methods
    
    /// Manually refresh feature flags from the service
    public func refresh() async {
        await updateFeatureFlags()
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObserver() {
        DistributedNotificationCenter.default()
            .publisher(for: .gitHubCopilotFeatureFlagsDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.updateFeatureFlags()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateFeatureFlags() async {
        // Throttle updates to prevent excessive calls
        if let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) < updateThrottle {
            return
        }
        
        lastUpdateTime = Date()
        
        do {
            let service = try getService()
            guard let featureFlags = try await service.getCopilotFeatureFlags() else {
                Logger.client.info("Feature flags returned nil, using defaults")
                return
            }
            
            // Update all flags at once
            isAgentModeEnabled = featureFlags.agentMode
            isBYOKEnabled = featureFlags.byok
            isMCPEnabled = featureFlags.mcp
            isEditorPreviewEnabled = featureFlags.editorPreviewFeatures
            isChatEnabled = featureFlags.chat
            isCodeReviewEnabled = featureFlags.ccr
            
            Logger.client.info("Feature flags updated: agentMode=\(featureFlags.agentMode), byok=\(featureFlags.byok), mcp=\(featureFlags.mcp), editorPreview=\(featureFlags.editorPreviewFeatures)")
        } catch {
            Logger.client.error("Failed to update feature flags: \(error.localizedDescription)")
        }
    }
}

// MARK: - Environment Key

private struct FeatureFlagManagerKey: EnvironmentKey {
    static let defaultValue = FeatureFlagManager.shared
}

public extension EnvironmentValues {
    var featureFlagManager: FeatureFlagManager {
        get { self[FeatureFlagManagerKey.self] }
        set { self[FeatureFlagManagerKey.self] = newValue }
    }
}

// MARK: - View Extension

public extension View {
    /// Inject the feature flag manager into the environment
    func withFeatureFlagManager(_ manager: FeatureFlagManager = .shared) -> some View {
        self.environment(\.featureFlagManager, manager)
    }
}
