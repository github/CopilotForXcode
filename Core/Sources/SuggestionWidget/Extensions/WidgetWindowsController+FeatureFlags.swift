import GitHubCopilotService

extension WidgetWindowsController {
    
    @MainActor
    var isNESFeatureFlagEnabled: Bool {
        FeatureFlagNotifierImpl.shared.featureFlags.editorPreviewFeatures
    }
    
    func setupFeatureFlagObservers() {
        Task { @MainActor in
            let sinker = FeatureFlagNotifierImpl.shared.featureFlagsDidChange
                .sink(receiveValue: { [weak self] _ in
                    self?.onFeatureFlagChanged()
                })
            
            await self.storeCancellables([sinker])
        }
    }
    
    @MainActor
    func onFeatureFlagChanged() {
        if !isNESFeatureFlagEnabled {
            hideAllNESWindows()
        }
    }
}
