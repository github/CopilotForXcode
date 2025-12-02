import Client
import Foundation
import GitHubCopilotService
import Logger
import SwiftUI

// MARK: - Installation Option

public struct InstallationOption {
    public let displayName: String
    public let description: String
    public let config: [String: Any]
    public let isDefault: Bool

    public init(displayName: String, description: String, config: [String: Any], isDefault: Bool = false) {
        self.displayName = displayName
        self.description = description
        self.config = config
        self.isDefault = isDefault
    }
}

// MARK: - Registry Types

private struct RegistryType {
    let displayName: String
    let commandName: String
    
    func buildArguments(for package: Package) -> [String] {
        let identifier = package.identifier
        let version = package.version ?? ""
        
        switch package.registryType {
        case "npm":
            return ["-y", version.isEmpty ? identifier : "\(identifier)@\(version)"]
        case "pypi":
            return [version.isEmpty ? identifier : "\(identifier)==\(version)"]
        case "oci":
            return ["run", "-i", "--rm", version.isEmpty ? identifier : "\(identifier):\(version)"]
        case "nuget":
            var args = [version.isEmpty ? identifier : "\(identifier)@\(version)", "--yes"]
            if package.packageArguments?.isEmpty == false { args.append("--") }
            return args
        default:
            return [version.isEmpty ? identifier : "\(identifier)@\(version)"]
        }
    }
}

private let registryTypes: [String: RegistryType] = [
    "npm": RegistryType(displayName: "NPM", commandName: "npx"),
    "pypi": RegistryType(displayName: "PyPI", commandName: "uvx"),
    "oci": RegistryType(displayName: "OCI", commandName: "docker"),
    "nuget": RegistryType(displayName: "NuGet", commandName: "dnx")
]

public extension Remote {
    var transportType: TransportType {
        switch self {
        case .streamableHTTP(let transport):
            return transport.type
        case .sse(let transport):
            return transport.type
        }
    }

    var url: String {
        switch self {
        case .streamableHTTP(let transport):
            return transport.url
        case .sse(let transport):
            return transport.url
        }
    }

    var headers: [KeyValueInput]? {
        switch self {
        case .streamableHTTP(let transport):
            return transport.headers
        case .sse(let transport):
            return transport.headers
        }
    }
}

// MARK: - MCP Registry Service

@MainActor
public class MCPRegistryService: ObservableObject {
    public static let shared = MCPRegistryService()
    public static let apiVersion = "v0.1"
    @AppStorage(\.mcpRegistryBaseURL) var mcpRegistryBaseURL
    
    private init() {}

    public static func getServerName(from serverDetail: MCPRegistryServerDetail) -> String {
        return serverDetail.name
    }

    public func getRegistryBaseURL() throws -> String {
        let url = mcpRegistryBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else {
            throw MCPRegistryError.registryURLNotConfigured
        }
        return url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    public func getRegistryURL() throws -> String {
        return try getRegistryBaseURL() + "/\(MCPRegistryService.apiVersion)/servers"
    }

    // MARK: - Installation Options

    public func getAllInstallationOptions(for serverDetail: MCPRegistryServerDetail) -> [InstallationOption] {
        var options: [InstallationOption] = []

        // Add remote options
        serverDetail.remotes?.enumerated().forEach { index, remote in
            let config = createServerConfig(for: serverDetail, remote: remote)
            options.append(InstallationOption(
                displayName: "\(remote.transportType.displayText): \(remote.url)",
                description: "Connect to remote server at \(remote.url)",
                config: config,
                isDefault: index == 0 && options.isEmpty
            ))
        }

        // Add package options
        serverDetail.packages?.enumerated().forEach { index, package in
            let config = createServerConfig(for: serverDetail, package: package)
            let registryDisplay = package.registryType.registryDisplayText

            options.append(InstallationOption(
                displayName: "\(registryDisplay) : \(package.identifier)",
                description: "Install \(package.identifier) from \(registryDisplay)",
                config: config,
                isDefault: index == 0 && options.isEmpty
            ))
        }

        return options
    }

    public func createServerConfiguration(for serverDetail: MCPRegistryServerDetail) throws -> [String: Any] {
        let options = getAllInstallationOptions(for: serverDetail)
        guard let defaultOption = options.first(where: { $0.isDefault }) ?? options.first else {
            throw MCPRegistryError.noInstallationOptionsAvailable(serverName: serverDetail.name)
        }
        return defaultOption.config
    }

    // MARK: - Install/Uninstall Operations

    public func installMCPServer(_ serverDetail: MCPRegistryServerDetail, installationOption: InstallationOption? = nil) async throws {
        Logger.client.info("Installing MCP Server '\(serverDetail.name)'...")

        let serverConfig: [String: Any]
        if let option = installationOption {
            serverConfig = option.config
        } else {
            serverConfig = try createServerConfiguration(for: serverDetail)
        }

        var currentConfig = loadConfiguration() ?? [:]
        if currentConfig["servers"] == nil {
            currentConfig["servers"] = [String: Any]()
        }

        guard var serversDict = currentConfig["servers"] as? [String: Any] else {
            throw MCPRegistryError.invalidConfigurationStructure
        }

        serversDict[serverDetail.name] = serverConfig
        currentConfig["servers"] = serversDict

        try saveConfiguration(currentConfig)
        Logger.client.info("Successfully installed MCP Server '\(serverDetail.name)'")
    }

    public func uninstallMCPServer(_ serverDetail: MCPRegistryServerDetail) async throws {
        Logger.client.info("Uninstalling MCP Server '\(serverDetail.name)'...")

        var currentConfig = loadConfiguration() ?? [:]
        guard var serversDict = currentConfig["servers"] as? [String: Any] else {
            throw MCPRegistryError.serverNotFound(serverName: serverDetail.name)
        }

        guard serversDict[serverDetail.name] != nil else {
            throw MCPRegistryError.serverNotFound(serverName: serverDetail.name)
        }

        serversDict.removeValue(forKey: serverDetail.name)
        currentConfig["servers"] = serversDict

        try saveConfiguration(currentConfig)
        Logger.client.info("Successfully uninstalled MCP Server '\(serverDetail.name)'")
    }

    // MARK: - Configuration Creation

    public func createServerConfig(for serverDetail: MCPRegistryServerDetail, remote: Remote) -> [String: Any] {
        var config: [String: Any] = [
            "type": "http",
            "url": remote.url
        ]

        // Add headers if present
        if let headers = remote.headers, !headers.isEmpty {
            let headersDict = Dictionary(headers.map { ($0.name, $0.value ?? "") }) { first, _ in first }
            config["requestInit"] = ["headers": headersDict]
        }

        addMetadata(to: &config, serverDetail: serverDetail)
        return config
    }

    public func createServerConfig(for serverDetail: MCPRegistryServerDetail, package: Package) -> [String: Any] {
        let registryType = registryTypes[package.registryType]
        let command = package.runtimeHint ?? registryType?.commandName ?? package.registryType

        var config: [String: Any] = [
            "type": "stdio",
            "command": command
        ]

        // Build arguments
        var args: [String] = []
        
        // Runtime arguments
        package.runtimeArguments?.forEach { args.append(contentsOf: extractArgumentValues(from: $0)) }
        
        // Default arguments if no runtime arguments
        if package.runtimeArguments?.isEmpty != false {
            args
                .append(
                    contentsOf: registryType?.buildArguments(for: package) ?? [package.identifier]
                )
        }
        
        // Package arguments
        package.packageArguments?.forEach { args.append(contentsOf: extractArgumentValues(from: $0)) }
        
        config["args"] = args

        // Environment variables
        if let envVars = package.environmentVariables, !envVars.isEmpty {
            config["env"] = Dictionary(envVars.map { ($0.name, $0.value ?? "") }) { first, _ in first }
        }

        addMetadata(to: &config, serverDetail: serverDetail)
        return config
    }

    private func addMetadata(to config: inout [String: Any], serverDetail: MCPRegistryServerDetail) {
        guard let baseURL = try? getRegistryBaseURL() else { return }

        let api: [String: Any] = [
            "baseUrl": baseURL,
            "version": MCPRegistryService.apiVersion
        ]

        let mcpServer: [String: Any] = [
            "name": Self.getServerName(from: serverDetail),
            "version": serverDetail.version
        ]

        config["x-metadata"] = [
            "registry": [
                "api": api,
                "mcpServer": mcpServer
            ]
        ]
    }

    private func extractArgumentValues(from argument: Argument) -> [String] {
        switch argument {
        case let .positional(positionalArg):
            return (positionalArg.value ?? positionalArg.valueHint).map { [$0] } ?? []
        case let .named(namedArg):
            return [namedArg.name] + (namedArg.value.map { [$0] } ?? [])
        }
    }

    // MARK: - Configuration File Management

    private func loadConfiguration() -> [String: Any]? {
        let configFileURL = URL(fileURLWithPath: mcpConfigFilePath)
        guard FileManager.default.fileExists(atPath: mcpConfigFilePath),
              let data = try? Data(contentsOf: configFileURL),
              let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return jsonObject
    }

    private func saveConfiguration(_ config: [String: Any]) throws {
        let configFileURL = URL(fileURLWithPath: mcpConfigFilePath)
        
        // Ensure directory exists
        let configDirectory = configFileURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: configDirectory.path) {
            try FileManager.default.createDirectory(at: configDirectory, withIntermediateDirectories: true)
        }

        // Save configuration
        let jsonData = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted])
        try jsonData.write(to: configFileURL)

        // Note: UserDefaults update and notification will be handled by ToolsConfigView's file monitor
        // with debouncing to prevent duplicate notifications
    }

    // MARK: - Server Installation Status

    public func isServerInstalled(_ serverDetail: MCPRegistryServerDetail) -> Bool {
        guard let config = loadConfiguration(),
              let serversDict = config["servers"] as? [String: Any],
              let expectedKey = expectedRegistryKey(for: serverDetail) else { return false }
        return serversDict.values.contains { (value) -> Bool in
            guard let serverConfigDict = value as? [String: Any],
                  let key = registryKey(from: serverConfigDict) else { return false }
            return key == expectedKey
        }
    }

    // MARK: - Option Installed Helpers

    public func isPackageOptionInstalled(serverDetail: MCPRegistryServerDetail, package: Package) -> Bool {
        guard isServerInstalled(serverDetail),
              let config = loadConfiguration(),
              let serversDict = config["servers"] as? [String: Any],
              let expectedKey = expectedRegistryKey(for: serverDetail) else { return false }

        let command = package.runtimeHint ?? registryTypes[package.registryType]?.commandName ?? (
            package.registryType
        )
        let expectedArgsFirst: String? = {
            var args: [String] = []
            package.runtimeArguments?.forEach { args.append(contentsOf: extractArgumentValues(from: $0)) }
            if package.runtimeArguments?.isEmpty != false {
                args.append(
                    contentsOf: registryTypes[package.registryType]?.buildArguments(for: package) ?? [package.identifier]
                )
            }
            package.packageArguments?.forEach { args.append(contentsOf: extractArgumentValues(from: $0)) }
            return args.first
        }()

        return serversDict.values.contains { value in
            guard let cfg = value as? [String: Any],
                  let key = registryKey(from: cfg),
                  key == expectedKey,
                  (cfg["type"] as? String)?.lowercased() == "stdio",
                  let c = cfg["command"] as? String,
                  let args = cfg["args"] as? [String] else { return false }
            return c == command && args.first == expectedArgsFirst
        }
    }

    public func isRemoteOptionInstalled(serverDetail: MCPRegistryServerDetail, remote: Remote) -> Bool {
      guard isServerInstalled(serverDetail),
          let config = loadConfiguration(),
          let serversDict = config["servers"] as? [String: Any],
          let expectedKey = expectedRegistryKey(for: serverDetail) else { return false }

      return serversDict.values.contains { value in
        guard let cfg = value as? [String: Any],
            let key = registryKey(from: cfg),
            key == expectedKey,
            (cfg["type"] as? String)?.lowercased() == "http",
            let url = cfg["url"] as? String else { return false }
        return url == remote.url
      }
    }

    public func createRegistryServerKey(registryBaseURL: String, serverName: String) -> String {
        let trimmedBaseURL = registryBaseURL
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(trimmedBaseURL)|\(serverName)"
    }

    // MARK: - Registry Key Helpers
    
    private func expectedRegistryKey(for serverDetail: MCPRegistryServerDetail) -> String? {
        guard let registryBaseURL = try? getRegistryBaseURL() else { return nil }
        return createRegistryServerKey(
            registryBaseURL: registryBaseURL,
            serverName: Self.getServerName(from: serverDetail)
        )
    }

    private func registryKey(from serverConfig: [String: Any]) -> String? {
        guard let metadata = serverConfig["x-metadata"] as? [String: Any],
              let registry = metadata["registry"] as? [String: Any],
              let api = registry["api"] as? [String: Any],
              let baseUrl = api["baseUrl"] as? String,
              let mcpServer = registry["mcpServer"] as? [String: Any],
              let name = mcpServer["name"] as? String else { return nil }
          return createRegistryServerKey(registryBaseURL: baseUrl, serverName: name)
    }
}

// MARK: - Error Types

public enum MCPRegistryError: LocalizedError {
    case registryURLNotConfigured
    case noInstallationOptionsAvailable(serverName: String)
    case invalidConfigurationStructure
    case serverNotFound(serverName: String)
    case configurationFileError(String)

    public var errorDescription: String? {
        switch self {
        case .registryURLNotConfigured:
            return "MCP Registry base URL is not configured. Please configure the registry URL in Settings > Tools > GitHub Copilot > MCP to browse and install servers from the registry."
        case let .noInstallationOptionsAvailable(serverName):
            return "Cannot create server configuration for '\(serverName)' - no installation options available"
        case .invalidConfigurationStructure:
            return "Invalid MCP configuration file structure"
        case let .serverNotFound(serverName):
            return "MCP Server '\(serverName)' not found in configuration"
        case let .configurationFileError(message):
            return "Configuration file error: \(message)"
        }
    }
}

// MARK: - Extensions

extension String {
    var registryDisplayText: String {
        return registryTypes[self]?.displayName ?? self.capitalized
    }
}
