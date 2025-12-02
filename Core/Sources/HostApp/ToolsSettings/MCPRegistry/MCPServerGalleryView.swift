import AppKit
import Client
import CryptoKit
import GitHubCopilotService
import Logger
import SharedUIComponents
import SwiftUI
import XPCShared

enum MCPServerGalleryWindow {
    static let identifier = "MCPServerGalleryWindow"
    private static weak var currentViewModel: MCPServerGalleryViewModel?

    @MainActor static func open(
        serverList: MCPRegistryServerList,
        mcpRegistryEntry: MCPRegistryEntry? = nil
    ) {
        if let existing = NSApp.windows.first(where: { $0.identifier?.rawValue == identifier }) {
            // Update existing window with new data
            update(serverList: serverList, mcpRegistryEntry: mcpRegistryEntry)
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let viewModel = MCPServerGalleryViewModel(
            initialList: serverList,
            mcpRegistryEntry: mcpRegistryEntry
        )
        currentViewModel = viewModel
        
        let controller = NSHostingController(
            rootView: MCPServerGalleryView(
                viewModel: viewModel
            )
        )

        let window = NSWindow(contentViewController: controller)
        window.title = "MCP Servers Marketplace"
        window.identifier = NSUserInterfaceItemIdentifier(identifier)
        window.setContentSize(NSSize(width: 800, height: 600))
        window.minSize = NSSize(width: 600, height: 400)
        window.styleMask.insert([.titled, .closable, .resizable, .miniaturizable])
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @MainActor static func update(
        serverList: MCPRegistryServerList,
        mcpRegistryEntry: MCPRegistryEntry? = nil
    ) {
        currentViewModel?.updateData(serverList: serverList, mcpRegistryEntry: mcpRegistryEntry)
    }
    
    @MainActor static func refreshFromURL(mcpRegistryEntry: MCPRegistryEntry? = nil) async -> Error? {
        return await currentViewModel?.refreshFromURL(mcpRegistryEntry: mcpRegistryEntry)
    }
    
    static func isOpen() -> Bool {
        return NSApp.windows.first(where: { $0.identifier?.rawValue == identifier }) != nil
    }
}

// MARK: - Stable ID helper

extension MCPRegistryServerResponse {
    var stableID: String {
        server.name + server.version
    }
}

private struct IdentifiableServerResponse: Identifiable {
    let response: MCPRegistryServerResponse
    var id: String { response.stableID }
}

struct MCPServerGalleryView: View {
    @ObservedObject var viewModel: MCPServerGalleryViewModel
    @State private var isShowingURLSheet = false
    @State private var searchTask: Task<Void, Never>?

    init(viewModel: MCPServerGalleryViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if let error = viewModel.lastError {
                if let serviceError = error as? XPCExtensionServiceError {
                    Badge(text: serviceError.underlyingError?.localizedDescription ?? serviceError.localizedDescription, level: .danger, icon: "xmark.circle.fill")
                } else {
                    Badge(text: error.localizedDescription, level: .danger, icon: "xmark.circle.fill")
                }
            }
            
            tableHeaderView
            serverListView
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor))
        .background(.ultraThinMaterial)
        .onAppear {
            viewModel.loadInstalledServers()
        }
        .sheet(isPresented: $isShowingURLSheet) {
            urlSheet
        }
        .sheet(isPresented: Binding(
            get: { viewModel.infoSheetServer != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissInfo()
                }
            }
        )) {
            if let server = viewModel.infoSheetServer {
                infoSheet(server)
            }
        }
        .searchable(text: $viewModel.searchText, prompt: "Search")
        .onChange(of: viewModel.searchText) { newValue in
            // Debounce search input before triggering a new server-side query
            searchTask?.cancel()
            searchTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
                if !Task.isCancelled {
                    viewModel.refreshForSearch()
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: { viewModel.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
            
            ToolbarItem {
                Button(action: { isShowingURLSheet = true }) {
                    Image(systemName: "square.and.pencil")
                }
                .help("Configure your MCP Registry Base URL")
            }
        }
    }

    private var tableHeaderView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Name")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .frame(width: 220, alignment: .leading)

                Divider().frame(height: 20)

                Text("Description")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text("Actions")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.trailing, 8)
                .frame(width: 120, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.clear)

            Divider()
        }
    }

    private var serverListView: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    serverRows

                    if viewModel.shouldShowLoadMoreSentinel {
                        Color.clear
                            .frame(height: 1)
                            .onAppear { viewModel.loadMoreIfNeeded() }
                            .accessibilityHidden(true)
                    }

                    if viewModel.isLoadingMore {
                        HStack {
                            Spacer()
                            ProgressView()
                                .padding(.vertical, 12)
                            Spacer()
                        }
                    }
                }
            }
            
            if viewModel.isRefreshing {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading servers...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
            }
        }
    }

    private var serverRows: some View {
        ForEach(Array(viewModel.filteredServers.enumerated()), id: \.element.stableID) { index, server in
            let isInstalled = viewModel.isServerInstalled(serverId: server.stableID)
            row(for: server, index: index, isInstalled: isInstalled)
                .background(rowBackground(for: index))
                .cornerRadius(8)
                .onAppear {
                    handleRowAppear(index: index)
                }
        }
    }

    private var urlSheet: some View {
        MCPRegistryURLSheet(
            mcpRegistryEntry: viewModel.mcpRegistryEntry,
            onURLUpdated: {
                viewModel.refresh()
            }
        )
        .frame(width: 500, height: 200)
    }

    private func rowBackground(for index: Int) -> Color {
        index.isMultiple(of: 2) ? Color.clear : Color.primary.opacity(0.03)
    }

    private func handleRowAppear(index: Int) {
        let currentFilteredCount = viewModel.filteredServers.count
        let totalServerCount = viewModel.servers.count

        // Prefetch when approaching the end of filtered results
        if index >= currentFilteredCount - 5 {
            // If we're filtering and the filtered results are small compared to total servers,
            // or if we're near the end of all available data, try to load more
            if currentFilteredCount < 20 || index >= totalServerCount - 5 {
                viewModel.loadMoreIfNeeded()
            }
        }
    }

    // MARK: - Subviews

    private func row(for response: MCPRegistryServerResponse, index: Int, isInstalled: Bool) -> some View {
        HStack {
            Text(response.server.title ?? response.server.name)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 8)
                .frame(width: 220, alignment: .leading)

            Divider().frame(height: 20).foregroundColor(Color.clear)

            Text(response.server.description)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                if isInstalled {
                    Button("Uninstall") {
                        Task {
                            await viewModel.uninstallServer(response.server)
                        }
                    }
                    .buttonStyle(DestructiveButtonStyle())
                    .help("Uninstall")
                } else {
                    if #available(macOS 13.0, *) {
                        SplitButton(
                            title: "Install",
                            isDisabled: viewModel.hasNoDeployments(response.server),
                            primaryAction: {
                                // Install with default configuration
                                Task {
                                    await viewModel.installServer(response.server)
                                }
                            },
                            menuItems: viewModel.getInstallationOptions(for: response.server).map { option in
                                SplitButtonMenuItem(title: option.displayName) {
                                    Task {
                                        await viewModel.installServer(response.server, configuration: option.displayName)
                                    }
                                }
                            }
                        )
                        .help("Install")
                    } else {
                        Button("Install") {
                            Task {
                                await viewModel.installServer(response.server)
                            }
                        }
                        .disabled(viewModel.hasNoDeployments(response.server))
                        .help("Install")
                    }
                }

                Button {
                    viewModel.showInfo(response)
                } label: {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.trailing)
                }
                .buttonStyle(.plain)
                .help("View Details")
            }
            .padding(.horizontal, 8)
            .frame(width: 120, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func infoSheet(_ response: MCPRegistryServerResponse) -> some View {
        if #available(macOS 13.0, *) {
            return AnyView(MCPServerDetailSheet(response: response))
        } else {
            return AnyView(EmptyView())
        }
    }
}

func defaultInstallation(for server: MCPRegistryServerDetail) -> String {
    // Get the first available type from remotes or packages
    if let firstRemote = server.remotes?.first {
        return firstRemote.transportType.rawValue
    }
    if let firstPackage = server.packages?.first {
        return firstPackage.registryType
    }
    return ""
}
