import AppKit
import GitHubCopilotService

extension WidgetWindowsController {
    func setupNESSuggestionPanelObservers() {
        Task { @MainActor in
            let nesContentPublisher = store.publisher
                .map(\.panelState.nesSuggestionPanelState.nesContent)
                .removeDuplicates()
                .sink { [weak self] _ in
                    Task { [weak self] in
                        await self?.updateWindowLocation(animated: false, immediately: true)
                    }
                }
            
            await self.storeCancellables([nesContentPublisher])
        }
    }
    
    @MainActor
    func applyOpacityForNESWindows(by noFocus: Bool) {
        guard !noFocus, isNESFeatureFlagEnabled
        else {
            hideAllNESWindows()
            return
        }
        
        displayAllNESWindows()
    }
    
    @MainActor
    func hideAllNESWindows() {
        windows.nesMenuWindow.alphaValue = 0
        windows.nesDiffWindow.setIsVisible(false)
        
        hideNESDiffWindow()
        
        windows.nesNotificationWindow.alphaValue = 0
        windows.nesNotificationWindow.setIsVisible(false)
    }
    
    @MainActor
    func displayAllNESWindows() {
        windows.nesMenuWindow.alphaValue = 1
        windows.nesDiffWindow.setIsVisible(true)
        
        windows.nesDiffWindow.alphaValue = 1
        windows.nesDiffWindow.setIsVisible(true)
        
        windows.nesNotificationWindow.alphaValue = 1
        windows.nesNotificationWindow.setIsVisible(true)
    }
    
    @MainActor
    func hideNESDiffWindow() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            windows.nesDiffWindow.animator().alphaValue = 0
            windows.nesDiffWindow.setIsVisible(false)
        }
    }
    
    @MainActor
    func updateNESDiffWindowFrame(
        _ location: WidgetLocation.NESPanelLocation,
        animated: Bool,
        trigger: WidgetLocation.LocationTrigger
    ) async {
        windows.nesDiffWindow.layoutIfNeeded()
        guard let contentView = windows.nesDiffWindow.contentView
        else {
            return
        }
        
        let effectiveSize: NSSize? = {
            let fittingSize = contentView.fittingSize
            if fittingSize.width > 0 && fittingSize.height > 0 {
                return fittingSize
            }
            
            let intrinsicSize = contentView.intrinsicContentSize
            if intrinsicSize.width > 0 && intrinsicSize.height > 0 {
                return intrinsicSize
            }
            
            return nil
        }()
        
        guard let contentSize = effectiveSize,
              contentSize.width.isFinite,
              contentSize.height.isFinite,
              let frame = location.calcDiffViewFrame(contentSize: contentSize)
        else {
            return
        }
                
        windows.nesDiffWindow.setFrame(
            frame,
            display: false,
            animate: animated
        )
    }
    
    @MainActor
    func updateNESNotificationWindowFrame(
        _ location: WidgetLocation.NESPanelLocation,
        animated: Bool
    ) async {
        var notificationWindowFrame = windows.nesNotificationWindow.frame
        let scrollViewFrame = location.scrollViewFrame
        let screenFrame = location.screenFrame
        
        notificationWindowFrame.origin.x = scrollViewFrame.minX + scrollViewFrame.width / 2 - notificationWindowFrame.width / 2
        notificationWindowFrame.origin.y = screenFrame.height - scrollViewFrame.maxY + Style.nesSuggestionMenuLeadingPadding * 2
        
        windows.nesNotificationWindow.setFrame(
            notificationWindowFrame,
            display: false,
            animate: animated
        )
    }
}
