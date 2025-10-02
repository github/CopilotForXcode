import Foundation
import Logger
import IOKit
import CryptoKit

public class SystemUtils {
    public static let shared = SystemUtils()

    // Static properties for constant values
    public static let machineId: String = {
        return shared.computeMachineId()
    }()

    public static let osVersion: String = {
        return "\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.patchVersion)"
    }()

    public static let xcodeVersion: String? = {
        return shared.computeXcodeVersion()
    }()

    public static let editorVersionString: String = {
        return "Xcode/\(xcodeVersion ?? "0.0.0")"
    }()

    public static let editorPluginVersion: String? = {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }()

    public static let editorPluginVersionString: String = {
        return "\(editorPluginVersion ?? "0.0.0")"
    }()

    public static let build: String = {
        return shared.isDeveloperMode() ? "dev" : ""
    }()

    public static let buildType: String = {
        return shared.isDeveloperMode() ? "true" : "false"
    }()

    private init() {}

    // Renamed to computeMachineId since it's now an internal implementation detail
    private func computeMachineId() -> String {
        // Original getMachineId implementation
        let matchingDict = IOServiceMatching("IOEthernetInterface") as NSMutableDictionary
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        
        if result != KERN_SUCCESS {
            return UUID().uuidString
        }
        
        var macAddress: String = ""
        var service = IOIteratorNext(iterator)
        
        while service != 0 {
            var parentService: io_object_t = 0
            let kernResult = IORegistryEntryGetParentEntry(service, "IOService", &parentService)
            
            if kernResult == KERN_SUCCESS {
                let propertyPtr = UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>.allocate(capacity: 1)
                _ = IORegistryEntryCreateCFProperties(
                    parentService,
                    propertyPtr,
                    kCFAllocatorDefault,
                    0
                )
                
                if let properties = propertyPtr.pointee?.takeUnretainedValue() as? [String: Any],
                   let data = properties["IOMACAddress"] as? Data {
                    macAddress = data.map { String(format: "%02x", $0) }.joined()
                    IOObjectRelease(parentService)
                    break
                }
                
                IOObjectRelease(parentService)
            }
            
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
        
        IOObjectRelease(iterator)
        
        // Hash the MAC address using SHA256
        if !macAddress.isEmpty, let macData = macAddress.data(using: .utf8) {
            let hashedData = SHA256.hash(data: macData)
            return hashedData.compactMap { String(format: "%02x", $0) }.joined()
        }
        
        return "unknown"
    }

    public func getXcodeBinaryPath() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        let path: String
        if identifier == "x86_64" {
            path = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/copilot-language-server").path
        } else if identifier == "arm64" {
            path = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/copilot-language-server-arm64").path
        } else {
            fatalError("Unsupported architecture")
        }

        return path
    }
    
    private func computeXcodeVersion() -> String? {
        let process = Process()
        let pipe = Pipe()

        defer {
            pipe.fileHandleForReading.closeFile()
            if process.isRunning {
                process.terminate()
            }
        }

        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["xcodebuild", "-version"]
        process.standardOutput = pipe

        do {
            try process.run()
        } catch {
            print("Error running xcrun xcodebuild: \(error)")
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = output.split(separator: "\n")
        return lines.first?.split(separator: " ").last.map(String.init)
    }
    
    public func getEditorVersionString() -> String {
        return "Xcode/\(computeXcodeVersion() ?? "0.0.0")"
    }
    
    public func getEditorPluginVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    public func getEditorPluginVersionString() -> String {
        return "copilot-xcode/\(getEditorPluginVersion() ?? "0.0.0")"
    }
    
    public func getBuild() -> String {
        return isDeveloperMode() ? "dev" : ""
    }
    
    public func getBuildType() -> String {
        return isDeveloperMode() ? "true" : "false"
    }
    
    func isDeveloperMode() -> Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// Returns the environment of a login shell (to get correct PATH and other variables)
    public func getLoginShellEnvironment(shellPath: String = "/bin/zsh") -> [String: String]? {
        do {
            guard let output = try Self.executeCommand(
                path: shellPath, 
                arguments: ["-i", "-l", "-c", "env"])
            else { return nil }
            
            var env: [String: String] = [:]
            for line in output.split(separator: "\n") {
                if let idx = line.firstIndex(of: "=") {
                    let key = String(line[..<idx])
                    let value = String(line[line.index(after: idx)...])
                    env[key] = value
                }
            }
            return env
        } catch {
            Logger.client.error("Failed to get login shell environment: \(error.localizedDescription)")
            return nil
        }
    }
    
    public static func executeCommand(
        inDirectory directory: String = NSHomeDirectory(),
        path: String,
        arguments: [String]
    ) throws -> String? {
        let task = Process()
        let pipe = Pipe()
        
        defer {
            pipe.fileHandleForReading.closeFile()
            if task.isRunning {
                task.terminate()
            }
        }
        
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        task.standardOutput = pipe
        task.currentDirectoryURL = URL(fileURLWithPath: directory)

        var accumulatedOutput = Data()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard data.isEmpty else { // End of file
                return accumulatedOutput.append(data)
            }

            handle.readabilityHandler = nil // Stop observing
        }
        
        try task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: accumulatedOutput + data, encoding: .utf8)
    }

    public func appendCommonBinPaths(path: String) -> String {
        let homeDirectory = NSHomeDirectory()
        let commonPaths = [
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            homeDirectory + "/.local/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
        ]
        
        let paths = path.split(separator: ":").map { String($0) }
        var newPath = path
        for commonPath in commonPaths {
            if FileManager.default.fileExists(atPath: commonPath) && !paths.contains(commonPath) {
                newPath += (newPath.isEmpty ? "" : ":") + commonPath
            }
        }

        return newPath
    }
}
