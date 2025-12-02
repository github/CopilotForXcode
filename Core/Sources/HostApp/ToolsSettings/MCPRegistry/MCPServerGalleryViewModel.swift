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
    @Published private(set) var servers: [MCPRegistryServerResponse]
    @Published private(set) var installedServers: Set<String> = []
    @Published private(set) var registryMetadata: MCPRegistryServerListMetadata?

    // Loading flags
    @Published private(set) var isInitialLoading: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published private(set) var isRefreshing: Bool = false

    // Transient presentation state
    @Published var pendingServer: MCPRegistryServerResponse?
    @Published var infoSheetServer: MCPRegistryServerResponse?
    @Published var mcpRegistryEntry: MCPRegistryEntry?
    @Published private(set) var lastError: Error?

    @AppStorage(\.mcpRegistryBaseURL) var mcpRegistryBaseURL
    @AppStorage(\.mcpRegistryBaseURLHistory) private var mcpRegistryBaseURLHistory

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

    var filteredServers: [MCPRegistryServerResponse] {
        // Only filter for latest official servers; search is handled server-side.
        // Also ensure we don't surface duplicate stable IDs, which can confuse SwiftUI's diffing.
        var seen = Set<String>()
        return servers.compactMap { server in
            let id = server.stableID
            if seen.contains(id) { return nil }
            seen.insert(id)
            return server
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
            return registryService.isServerInstalled(server.server)
        }

        // Fallback to the existing key-based check for backwards compatibility
        let key = createRegistryServerKey(registryBaseURL: mcpRegistryBaseURL, serverName: serverId)
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
            
            // Clear the current server list and search text
            servers = []
            registryMetadata = nil
            searchText = ""

            // Load servers from the base URL with empty query
            _ = await loadServerList(resetToFirstPage: true)
        }
    }
    
    // Called from Settings view to refresh with optional new registry entry
    func refreshFromURL(mcpRegistryEntry: MCPRegistryEntry? = nil) async -> Error? {
        isRefreshing = true
        defer { isRefreshing = false }
        
        // Clear the current server list and reset search text when URL changes
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

    /// Refresh the server list in response to a search query change without
    /// resetting the search text. This is used by the debounced searchable field.
    func refreshForSearch() {
        Task {
            isRefreshing = true
            defer { isRefreshing = false }

            // Clear current data but keep the active search query
            servers = []
            registryMetadata = nil

            _ = await loadServerList(resetToFirstPage: true)
        }
    }

    func showInfo(_ server: MCPRegistryServerResponse) {
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

            let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

            let serverList = try await service.listMCPRegistryServers(
                .init(
                    baseUrl: registryService.getRegistryURL(),
                    cursor: cursor,
                    limit: pageSize,
                    search: trimmedQuery.isEmpty ? nil : trimmedQuery,
                    version: "latest"
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

            mcpRegistryBaseURLHistory.addToHistory(mcpRegistryBaseURL)
            
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
                let api = registry["api"] as? [String: Any],
                let baseUrl = api["baseUrl"] as? String,
                let mcpServer = registry["mcpServer"] as? [String: Any],
                let name = mcpServer["name"] as? String
            else { continue }

            installedServers.insert(
                createRegistryServerKey(registryBaseURL: baseUrl, serverName: name)
            )
        }
    }

    private func createRegistryServerKey(registryBaseURL: String, serverName: String) -> String {
        return registryService.createRegistryServerKey(registryBaseURL: registryBaseURL, serverName: serverName)
    }

    // MARK: - Installation Options Helper

    func getInstallationOptions(for server: MCPRegistryServerDetail) -> [InstallationOption] {
        return registryService.getAllInstallationOptions(for: server)
    }
}
