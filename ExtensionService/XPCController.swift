import Foundation
import Logger
import XPCShared

final class XPCController: XPCServiceDelegate {
    let bridge: XPCCommunicationBridge
    let xpcListener: NSXPCListener
    let xpcServiceDelegate: ServiceDelegate

    var pingTask: Task<Void, Error>?

    init() {
        let bridge = XPCCommunicationBridge(logger: .client)
        let listener = NSXPCListener.anonymous()
        let delegate = ServiceDelegate()
        listener.delegate = delegate
        listener.resume()
        xpcListener = listener
        xpcServiceDelegate = delegate
        self.bridge = bridge

        Task {
            bridge.setDelegate(self)
            createPingTask()
        }
    }
    
    func quit() async {
        bridge.setDelegate(nil)
        pingTask?.cancel()
        try? await bridge.quit()
    }

    deinit {
        xpcListener.invalidate()
        pingTask?.cancel()
    }

    func createPingTask() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            var consecutiveFailures = 0
            var backoffDelay = 1_000_000_000 // Start with 1 second
            
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await self.bridge.updateServiceEndpoint(self.xpcListener.endpoint)
                    // Reset on success
                    consecutiveFailures = 0
                    backoffDelay = 1_000_000_000
                    try await Task.sleep(nanoseconds: 60_000_000_000) // 60 seconds between successful pings
                } catch {
                    consecutiveFailures += 1
                    // Log only on 1st, 5th (31 sec), 10th failures, etc. to avoid flooding
                    let shouldLog = consecutiveFailures == 1 || consecutiveFailures % 5 == 0
                    
                    #if DEBUG
                    // No log, but you should run CommunicationBridge, too.
                    #else
                    if consecutiveFailures == 5 {
                        await MainActor.run {
                            showBackgroundPermissionAlert()
                        }
                    }
                    if shouldLog {
                        Logger.service.error("Failed to connect to bridge (\(consecutiveFailures) consecutive failures): \(error.localizedDescription)")
                    }
                    #endif
                    
                    // Exponential backoff with a cap
                    backoffDelay = min(backoffDelay * 2, 120_000_000_000) // Cap at 120 seconds
                    try await Task.sleep(nanoseconds: UInt64(backoffDelay))
                }
            }
        }
    }

    func connectionDidInvalidate() async {
        // ignore
    }

    func connectionDidInterrupt() async {
        createPingTask() // restart the ping task so that it can bring the bridge back immediately.
    }
}

