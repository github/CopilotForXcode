import Client
import CryptoKit
import Foundation
import GitHubCopilotService
import Logger
import SwiftUI

@MainActor
final class MCPServerGalleryViewModel: ObservableObject {
    // Input invariants
    private let pageSize: Int

    // User / UI state
    @Published var searchText: String = ""

    // Data
    @Published private(set) var servers: [MCPRegistryServerDetail]
    @Published private(set) var installedServers: Set<String> = []
    @Published private(set) var registryMetadata: MCPRegistryServerListMetadata?

    // Loading flags
    @Published private(set) var isInitialLoading: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published private(set) var isRefreshing: Bool = false

    // Transient presentation state
    @Published var pendingServer: MCPRegistryServerDetail?
    @Published var infoSheetServer: MCPRegistryServerDetail?
    @Published var mcpRegistryEntry: MCPRegistryEntry?
    @Published private(set) var lastError: Error?

    @AppStorage(\.mcpRegistryURL) var mcpRegistryURL
    @AppStorage(\.mcpRegistryURLHistory) private var mcpRegistryURLHistory

    // Service integration
    private let registryService = MCPRegistryService.shared

    init(
        initialList: MCPRegistryServerList,
        mcpRegistryEntry: MCPRegistryEntry? = nil,
        pageSize: Int = 30
    ) {
        self.pageSize = pageSize
        servers = initialList.servers
        registryMetadata = initialList.metadata
        self.mcpRegistryEntry = mcpRegistryEntry
    }

    // MARK: - Derived Data

    var filteredServers: [MCPRegistryServerDetail] {
        // First filter for only latest official servers
        let latestServers = servers.filter { server in
            server.meta?.official?.isLatest == true
        }

        // Then apply search filter if search text is present
        let key = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return latestServers }

        return latestServers.filter {
            $0.name.lowercased().contains(key) ||
                $0.description.lowercased().contains(key)
        }
    }

    var shouldShowLoadMoreSentinel: Bool {
        // Show load more sentinel if there's more data available
        if let next = registryMetadata?.nextCursor, !next.isEmpty {
            return true
        }
        return false
    }

    func isServerInstalled(serverId: String) -> Bool {
        // Find the server by ID and check installation status using the service
        if let server = servers.first(where: { $0.stableID == serverId }) {
            return registryService.isServerInstalled(server)
        }

        // Fallback to the existing key-based check for backwards compatibility
        let key = createRegistryServerKey(registryURL: mcpRegistryURL, serverId: serverId)
        return installedServers.contains(key)
    }

    func hasNoDeployments(_ server: MCPRegistryServerDetail) -> Bool {
        return server.remotes?.isEmpty ?? true && server.packages?.isEmpty ?? true
    }

    // MARK: - User Intents (Updated with Service Integration)

    func requestInstall(_ server: MCPRegistryServerDetail) {
        Task {
            await installServer(server)
        }
    }

    func requestInstallWithConfiguration(_ server: MCPRegistryServerDetail, configuration: String) {
        Task {
            await installServer(server, configuration: configuration)
        }
    }

    func installServer(_ server: MCPRegistryServerDetail, configuration: String? = nil) async {
        do {
            let installationOption: InstallationOption?

            if let configName = configuration {
                // Find the specific installation option
                let options = registryService.getAllInstallationOptions(for: server)
                installationOption = options.first { option in
                    option.displayName.contains(configName) ||
                        option.description.contains(configName)
                }
            } else {
                installationOption = nil
            }

            try await registryService.installMCPServer(server, installationOption: installationOption)

            // Refresh installed servers list
            loadInstalledServers()

            Logger.client.info("Successfully installed MCP Server '\(server.name)'")

        } catch {
            Logger.client.error("Failed to install server '\(server.name)': \(error)")
            // TODO: Consider adding error handling UI feedback here
        }
    }

    func uninstallServer(_ server: MCPRegistryServerDetail) async {
        do {
            try await registryService.uninstallMCPServer(server)

            // Refresh installed servers list
            loadInstalledServers()

            Logger.client.info("Successfully uninstalled MCP Server '\(server.name)'")

        } catch {
            Logger.client.error("Failed to uninstall server '\(server.name)': \(error)")
            // TODO: Consider adding error handling UI feedback here
        }
    }

    func refresh() {
        Task {
            isRefreshing = true
            defer { isRefreshing = false }
            
            // Clear the current server list
            servers = []
            registryMetadata = nil
            searchText = ""

            // Load servers from the base URL
            _ = await loadServerList(resetToFirstPage: true)
        }
    }
    
    // Called from Settings view to refresh with optional new registry entry
    func refreshFromURL(mcpRegistryEntry: MCPRegistryEntry? = nil) async -> Error? {
        isRefreshing = true
        defer { isRefreshing = false }
        
        // Clear the current server list immediately
        servers = []
        registryMetadata = nil
        searchText = ""
        self.mcpRegistryEntry = mcpRegistryEntry
        Logger.client.info("Cleared gallery view model data for refresh")
        
        // Load servers from the base URL
        let error = await loadServerList(resetToFirstPage: true)
        
        // Reload installed servers after fetching new data
        loadInstalledServers()
        
        return error
    }
    
    func updateData(serverList: MCPRegistryServerList, mcpRegistryEntry: MCPRegistryEntry? = nil) {
        servers = serverList.servers
        registryMetadata = serverList.metadata
        self.mcpRegistryEntry = mcpRegistryEntry
        searchText = ""
        loadInstalledServers()
        Logger.client.info("Updated gallery view model with \(serverList.servers.count) servers and registry entry: \(String(describing: mcpRegistryEntry))")
    }
    
    func clearData() {
        servers = []
        registryMetadata = nil
        searchText = ""
        Logger.client.info("Cleared gallery view model data")
    }

    func showInfo(_ server: MCPRegistryServerDetail) {
        infoSheetServer = server
    }

    func dismissInfo() {
        infoSheetServer = nil
    }

    // MARK: - Data Loading

    func loadMoreIfNeeded() {
        guard !isLoadingMore,
              !isInitialLoading,
              let nextCursor = registryMetadata?.nextCursor,
              !nextCursor.isEmpty
        else { return }

        Task {
            await loadServerList(resetToFirstPage: false)
        }
    }

    private func loadServerList(resetToFirstPage: Bool) async -> Error? {
        if resetToFirstPage {
            isInitialLoading = true
        } else {
            isLoadingMore = true
        }

        defer {
            isInitialLoading = false
            isLoadingMore = false
        }
        
        lastError = nil

        do {
            let service = try getService()
            let cursor = resetToFirstPage ? nil : registryMetadata?.nextCursor

            let serverList = try await service.listMCPRegistryServers(
                .init(
                    baseUrl: mcpRegistryURL,
                    cursor: cursor,
                    limit: pageSize
                )
            )

            if resetToFirstPage {
                // Replace all servers when refreshing or resetting
                servers = serverList?.servers ?? []
                registryMetadata = serverList?.metadata
            } else {
                // Append when loading more
                servers.append(contentsOf: serverList?.servers ?? [])
                registryMetadata = serverList?.metadata
            }

            mcpRegistryURLHistory.addToHistory(mcpRegistryURL)
            
            return nil
        } catch {
            Logger.client.error("Failed to load MCP servers: \(error)")
            lastError = error
            return error
        }
    }

    func loadInstalledServers() {
        // Clear the set and rebuild it
        installedServers.removeAll()

        let configFileURL = URL(fileURLWithPath: mcpConfigFilePath)
        guard FileManager.default.fileExists(atPath: mcpConfigFilePath),
              let data = try? Data(contentsOf: configFileURL),
              let currentConfig = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let serversDict = currentConfig["servers"] as? [String: Any] else {
            return
        }

        for (_, serverConfig) in serversDict {
            guard
                let serverConfigDict = serverConfig as? [String: Any],
                let metadata = serverConfigDict["x-metadata"] as? [String: Any],
                let registry = metadata["registry"] as? [String: Any],
                let registryUrl = registry["url"] as? String,
                let serverId = registry["serverId"] as? String
            else { continue }

            installedServers.insert(
                createRegistryServerKey(registryURL: registryUrl, serverId: serverId)
            )
        }
    }

    private func createRegistryServerKey(registryURL: String, serverId: String) -> String {
        return registryService.createRegistryServerKey(registryURL: registryURL, serverId: serverId)
    }

    // MARK: - Installation Options Helper

    func getInstallationOptions(for server: MCPRegistryServerDetail) -> [InstallationOption] {
        return registryService.getAllInstallationOptions(for: server)
    }
}
