import SwiftUI
import AppKit
import GitHubCopilotService
import SharedUIComponents
import Foundation

@available(macOS 13.0, *)
struct MCPServerDetailSheet: View {
    let server: MCPRegistryServerDetail
    let meta: ServerMeta
    @State private var selectedTab = TabType.Packages
    @State private var expandedPackages: Set<Int> = []
    @State private var expandedRemotes: Set<Int> = []
    @State private var packageConfigs: [Int: [String: Any]] = [:]
    @State private var remoteConfigs: [Int: [String: Any]] = [:]
    // Track installation progress per item so we can disable buttons / show feedback
    @State private var installingPackages: Set<Int> = []
    @State private var installingRemotes: Set<Int> = []
    // Track whether the server (any option) is already installed
    @State private var isInstalled: Bool
    // Overwrite confirmation alert
    @State private var showOverwriteAlert: Bool = false
    @State private var pendingInstallAction: (() -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    
    enum TabType: String, CaseIterable, Identifiable {
        case Packages, Remotes, Metadata
        var id: Self { self }
    }

    init(response: MCPRegistryServerResponse) {
        self.server = response.server
        self.meta = response.meta
        // Determine installed status using registry service (same logic as gallery view)
        _isInstalled = State(initialValue: MCPRegistryService.shared.isServerInstalled(server))
    }

    // Shared visual constants
    private let labelColumnWidth: CGFloat = 80
    private let detailTopPadding: CGFloat = 6
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            // Tab selector
            tabSelector
            
            // Content
            OverlayScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .Packages:
                        packagesTab
                    case .Remotes:
                        remotesTab
                    case .Metadata:
                        metadataTab
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 400)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: { dismiss() }) { Text("Close") }
            }
            ToolbarItem(placement: .secondaryAction) {
                if isInstalled {
                    Button("Open Config") { openConfig() }
                        .help("Open mcp.json")
                }
            }
        }
        .toolbarRole(.automatic)
        .frame(width: 600, height: 450)
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            isInstalled = MCPRegistryService.shared.isServerInstalled(server)
        }
        .alert("Overwrite Existing Installation?", isPresented: $showOverwriteAlert) {
            Button("Cancel", role: .cancel) { pendingInstallAction = nil }
            Button("Overwrite", role: .destructive) {
                pendingInstallAction?()
                pendingInstallAction = nil
            }
        } message: {
            Text("Installing this option will replace the currently installed variant of this server.")
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text(server.title ?? server.name)
                    .font(.system(size: 18, weight: .semibold))
                
                if meta.official.status == .deprecated {
                    statusBadge(meta.official.status)
                }
                
                Spacer()
            }
            
            HStack(spacing: 24) {
                HStack(spacing: 6) {
                    Image(systemName: "tag")
                    Text(server.version)
                }
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                
                dateMetadataTag(title: "Published ", dateString: meta.official.publishedAt, image: "clock.arrow.trianglehead.counterclockwise.rotate.90")

                dateMetadataTag(title: "Updated ", dateString: meta.official.updatedAt, image: "icloud.and.arrow.up")

                if let repo = server.repository, !repo.url.isEmpty, !repo.source.isEmpty {
                    if let repoURL = URL(string: repo.url) {  
                        HStack(spacing: 6) {  
                            Image(systemName: "link")  
                            Link(destination: repoURL) {  
                                Text("Repository")  
                            }  
                            .onHover { hovering in  
                                if hovering {  
                                    NSCursor.pointingHand.push()  
                                } else {  
                                    NSCursor.pop()  
                                }  
                            }  
                        }  
                        .font(.system(size: 12))  
                        .foregroundColor(.secondary)  
                    }  
                }
            }
            
            Text(server.description)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
                .padding(.top, 4)
        }
        .padding(28)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func dateMetadataTag(title: String, dateString: String, image: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: image)
            if let date = parseDate(dateString) {
                (Text("\(title)\(relativeDateString(date))"))
                    .help(formatExactDate(date))
            } else {
                Text("\(title) \(dateString)").help(dateString)
            }
        }
        .font(.system(size: 12))
        .foregroundColor(.secondary)
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("Packages (\(server.packages?.count ?? 0))")
                    .tag(TabType.Packages)
                Text("Remotes (\(server.remotes?.count ?? 0))")
                    .tag(TabType.Remotes)
                Text("Metadata")
                    .tag(TabType.Metadata)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
        .overlay(
            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // MARK: - Packages Tab
    
    private var packagesTab: some View {
        Group {
            if let packages = server.packages, !packages.isEmpty {
                ForEach(Array(packages.enumerated()), id: \.offset) { index, package in
                    packageItem(package, index: index)
                }
            } else {
                EmptyStateView(message: "No packages available for this server", type: .Packages)
            }
        }
    }
    
    private func packageItem(_ package: Package, index: Int) -> some View {
        let isExpanded = expandedPackages.contains(index)
        let optionInstalled = MCPRegistryService.shared.isPackageOptionInstalled(serverDetail: server, package: package)
        let metadata: [ServerInstallationOptionView.Metadata] = {
            var rows: [ServerInstallationOptionView.Metadata] = []
            rows.append(.init(label: "ID", value: package.identifier, monospaced: true))
            if let registryURL = package.registryBaseUrl {
                rows.append(.init(label: "Registry", value: registryURL))
            }
            if let runtime = package.runtimeHint { rows.append(.init(label: "Runtime", value: runtime)) }
            return rows
        }()
        return ServerInstallationOptionView(
            title: package.registryType.registryDisplayText,
            iconSystemName: "shippingbox",
            versionTag: package.version,
            metadata: metadata,
            isExpanded: isExpanded,
            isInstalled: isInstalled, // overall server installed
            isInstalling: installingPackages.contains(index),
            showUninstall: optionInstalled,
            labelColumnWidth: labelColumnWidth,
            onToggleExpand: {
                if isExpanded {
                    expandedPackages.remove(index)
                } else {
                    expandedPackages.insert(index)
                    if packageConfigs[index] == nil { packageConfigs[index] = generateServerConfig(for: package) }
                }
            },
            onInstall: { handlePackageInstallButton(package, index: index, optionInstalled: optionInstalled) },
            onUninstall: { uninstallServer() },
            config: packageConfigs[index]
        )
    }
    
    // MARK: - Remotes Tab
    
    private var remotesTab: some View {
        Group {
            if let remotes = server.remotes, !remotes.isEmpty {
                ForEach(Array(remotes.enumerated()), id: \.offset) { index, remote in
                    remoteItem(remote, index: index)
                }
            } else {
                EmptyStateView(
                    message: "No remote endpoints configured for this server",
                    type: .Remotes
                )
            }
        }
    }
    
    private func remoteItem(_ remote: Remote, index: Int) -> some View {
        let isExpanded = expandedRemotes.contains(index)
        let optionInstalled = MCPRegistryService.shared.isRemoteOptionInstalled(serverDetail: server, remote: remote)
        let metadata: [ServerInstallationOptionView.Metadata] = [
            .init(label: "URL", value: remote.url, monospaced: true)
        ]
        return ServerInstallationOptionView(
            title: remote.transportType.displayText,
            iconSystemName: "globe",
            versionTag: nil,
            metadata: metadata,
            isExpanded: isExpanded,
            isInstalled: isInstalled,
            isInstalling: installingRemotes.contains(index),
            showUninstall: optionInstalled,
            labelColumnWidth: labelColumnWidth,
            onToggleExpand: {
                if isExpanded {
                    expandedRemotes.remove(index)
                } else {
                    expandedRemotes.insert(index)
                    if remoteConfigs[index] == nil { remoteConfigs[index] = generateServerConfig(for: remote) }
                }
            },
            onInstall: { handleRemoteInstallButton(remote, index: index, optionInstalled: optionInstalled) },
            onUninstall: { uninstallServer() },
            config: remoteConfigs[index]
        )
    }
    
    // MARK: - Metadata Tab
    
    private var metadataTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            officialMetadataSection(meta.official)
        }
    }
    
    private func officialMetadataSection(_ official: OfficialMeta) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Official Registry")
                    .font(.system(size: 14, weight: .medium))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                metadataRow(
                    label: "Published",
                    value: parseDate(official.publishedAt) != nil ? formatExactDate(
                        parseDate(official.publishedAt)!
                    ) : official.publishedAt
                )
                metadataRow(
                    label: "Updated",
                    value: parseDate(official.updatedAt) != nil ? formatExactDate(
                        parseDate(official.updatedAt)!
                    ) : official.updatedAt
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
        )
    }
    
    private func metadataRow(label: String, value: String, isLink: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            if isLink, let url = URL(string: value) {
                Link(value, destination: url)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.blue)
            } else {
                Text(value)
                    .font(.system(size: 12, design: label.contains("ID") || label.contains("Commit") ? .monospaced : .default))
                    .foregroundColor(.primary)
                    .textSelection(.enabled)
            }
        }
    }
    
    private func serverConfigView(_ config: [String: Any]) -> some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(formatConfigAsJSON(config))
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 2)
            }
            .padding(12)
            
            CopyButton {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(formatConfigAsJSON(config), forType: .string)
            }
            .padding(6)
            .help("Copy configuration to clipboard")
        }
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
    
    
    private func formatConfigAsJSON(_ config: [String: Any]) -> String {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
    
    // MARK: - Configuration Generation Helpers
    
    private func generateServerConfig(for package: Package) -> [String: Any] {
        return MCPRegistryService.shared.createServerConfig(for: server, package: package)
    }
    
    private func generateServerConfig(for remote: Remote) -> [String: Any] {
        return MCPRegistryService.shared.createServerConfig(for: server, remote: remote)
    }

    // MARK: - Install Helpers

    private func performPackageInstall(_ package: Package, index: Int) {
        guard !installingPackages.contains(index) else { return }
        installingPackages.insert(index)
        Task {
            let config = packageConfigs[index] ?? generateServerConfig(for: package)
            // Cache generated config for preview if needed later
            if packageConfigs[index] == nil { packageConfigs[index] = config }
            let option = InstallationOption(
                displayName: package.registryType.registryDisplayText,
                description: "Install \(package.identifier)",
                config: config
            )
            do {
                try await MCPRegistryService.shared.installMCPServer(server, installationOption: option)
                // Mark installed locally so UI reflects the state immediately
                isInstalled = true
            } catch {
                // Silently fail for now; could surface error UI later
            }
            installingPackages.remove(index)
        }
    }

    private func handlePackageInstallButton(_ package: Package, index: Int, optionInstalled: Bool) {
        if isInstalled && !optionInstalled {
            // Show overwrite confirmation
            pendingInstallAction = { performPackageInstall(package, index: index) }
            showOverwriteAlert = true
        } else {
            performPackageInstall(package, index: index)
        }
    }

    private func performRemoteInstall(_ remote: Remote, index: Int) {
        guard !installingRemotes.contains(index) else { return }
        installingRemotes.insert(index)
        Task {
            let config = remoteConfigs[index] ?? generateServerConfig(for: remote)
            if remoteConfigs[index] == nil { remoteConfigs[index] = config }
            let option = InstallationOption(
                displayName: "\(remote.transportType.rawValue)",
                description: "Install remote endpoint \(remote.url)",
                config: config
            )
            do {
                try await MCPRegistryService.shared.installMCPServer(server, installationOption: option)
                isInstalled = true
            } catch {
                // Silently fail for now
            }
            installingRemotes.remove(index)
        }
    }

    private func handleRemoteInstallButton(_ remote: Remote, index: Int, optionInstalled: Bool) {
        if isInstalled && !optionInstalled {
            pendingInstallAction = { performRemoteInstall(remote, index: index) }
            showOverwriteAlert = true
        } else {
            performRemoteInstall(remote, index: index)
        }
    }

    private func uninstallServer() {
        Task {
            do {
                try await MCPRegistryService.shared.uninstallMCPServer(server)
                isInstalled = false
            } catch {
                // TODO: Consider surfacing error to user
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func statusBadge(_ status: ServerStatus) -> some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color.orange)
            .padding(.horizontal, 6)
            .help("The server is deprecated.")
    }
    
    private struct EmptyStateView: View {
        let message: String
        let type: PackageType
        
        enum PackageType: String {
            case Packages, Remotes, Metadata
        }
        
        var Logo: some View {
            switch type {
            case .Packages:
                return Image(systemName: "shippingbox")
            case .Remotes:
                return Image(systemName: "globe")
            case .Metadata:
                return Image(systemName: "info.circle")
            }
        }
        
        var body: some View {
            VStack(spacing: 12) {
                Logo.font(.system(size: 32))
                
                Text(message)
                    .font(.system(size: 13))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
    }
    
    // MARK: - Utilities
    
    private func parseDate(_ dateString: String) -> Date? {
        // Try multiple ISO8601 formatters in order of specificity
        let formatters: [ISO8601DateFormatter] = [
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return formatter
            }(),
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime]
                return formatter
            }(),
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withTimeZone]
                return formatter
            }(),
            {
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime]
                return formatter
            }()
        ]
        
        // Try each formatter until one succeeds
        for formatter in formatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    private func formatExactDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    private func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Open Config / Selection Support

    private func openConfig() {
        // Simplified to just open the MCP config file, mirroring manual install behavior.
        let url = URL(fileURLWithPath: mcpConfigFilePath)
        NSWorkspace.shared.open(url)
    }
}

