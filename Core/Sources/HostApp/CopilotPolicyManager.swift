import Client
import Combine
import Foundation
import GitHubCopilotService
import Logger
import SwiftUI

/// Centralized manager for GitHub Copilot policies in the HostApp
/// Use as @StateObject or @ObservedObject in SwiftUI views
@MainActor
public class CopilotPolicyManager: ObservableObject {
    public static let shared = CopilotPolicyManager()
    
    // MARK: - Published Properties
    
    @Published public private(set) var isMCPContributionPointEnabled = true
    @Published public private(set) var isCustomAgentEnabled = true
    @Published public private(set) var isSubagentEnabled = true
    @Published public private(set) var isCVERemediatorAgentEnabled = true
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var lastUpdateTime: Date?
    private let updateThrottle: TimeInterval = 1.0 // Prevent excessive updates
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationObserver()
        Task {
            await updatePolicy()
        }
    }
    
    // MARK: - Public Methods
    
    /// Manually refresh policies from the service
    public func refresh() async {
        await updatePolicy()
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationObserver() {
        DistributedNotificationCenter.default()
            .publisher(for: .gitHubCopilotPolicyDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.updatePolicy()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updatePolicy() async {
        // Throttle updates to prevent excessive calls
        if let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) < updateThrottle {
            return
        }
        
        lastUpdateTime = Date()
        
        do {
            let service = try getService()
            guard let policy = try await service.getCopilotPolicy() else {
                Logger.client.info("Copilot policy returned nil, using defaults")
                return
            }
            
            // Update all policies at once
            isMCPContributionPointEnabled = policy.mcpContributionPointEnabled
            isCustomAgentEnabled = policy.customAgentEnabled
            isSubagentEnabled = policy.subagentEnabled
            isCVERemediatorAgentEnabled = policy.cveRemediatorAgentEnabled
            
            Logger.client.info("Copilot policy updated: customAgent=\(policy.customAgentEnabled), mcp=\(policy.mcpContributionPointEnabled), subagent=\(policy.subagentEnabled)")
        } catch {
            Logger.client.error("Failed to update copilot policy: \(error.localizedDescription)")
        }
    }
}

// MARK: - Environment Key

private struct CopilotPolicyManagerKey: EnvironmentKey {
    static let defaultValue = CopilotPolicyManager.shared
}

public extension EnvironmentValues {
    var copilotPolicyManager: CopilotPolicyManager {
        get { self[CopilotPolicyManagerKey.self] }
        set { self[CopilotPolicyManagerKey.self] = newValue }
    }
}

// MARK: - View Extension

public extension View {
    /// Inject the copilot policy manager into the environment
    func withCopilotPolicyManager(_ manager: CopilotPolicyManager = .shared) -> some View {
        self.environment(\.copilotPolicyManager, manager)
    }
}
