import AppKit
import Foundation
import Logger

class AppDelegate: NSObject, NSApplicationDelegate {}

let bundleIdentifierBase = Bundle(url: Bundle.main.bundleURL.appendingPathComponent(
    "GitHub Copilot For Xcode Extension.app"
))?.object(forInfoDictionaryKey: "BUNDLE_IDENTIFIER_BASE") as? String ?? "com.github.CopilotForXcode"

let serviceIdentifier = bundleIdentifierBase + ".CommunicationBridge"
let appDelegate = AppDelegate()
let delegate = ServiceDelegate()
let listener = NSXPCListener(machServiceName: serviceIdentifier)
listener.delegate = delegate
listener.resume()
let app = NSApplication.shared
app.delegate = appDelegate
Logger.communicationBridge.info("Communication bridge started")
app.run()

func checkForManagedProperties() -> Bool {
    // Implement the logic to check for managed properties
    // Return true if managed properties are found, otherwise false
    return false
}

if checkForManagedProperties() {
    Logger.communicationBridge.error("Managed properties detected. Exiting.")
    exit(1)
}
