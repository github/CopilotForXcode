import AppKit
import Logger
import SharedUIComponents
import SwiftUI

struct MCPManualInstallView: View {
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            DisclosureSettingsRow(
                isExpanded: $isExpanded,
                accessibilityLabel: { $0 ? "Collapse MCP configuration section" : "Expand MCP configuration section" },
                title: { Text("MCP Configuration").font(.headline) },
                subtitle: { Text("Add MCP Servers to power AI with tools for files, databases, and external APIs.") },
                actions: {
                    HStack(spacing: 8) {
                        Button {
                            openMCPRunTimeLogFolder()
                        } label: {
                            HStack(spacing: 0) {
                                Image(systemName: "folder")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 12, height: 12, alignment: .center)
                                    .padding(4)
                                Text("Open MCP Log Folder")
                            }
                            .conditionalFontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .help("Open MCP Runtime Log Folder")

                        Button {
                            openConfigFile()
                        } label: {
                            HStack(spacing: 0) {
                                Image(systemName: "square.and.pencil")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 12, height: 12, alignment: .center)
                                    .padding(4)
                                Text("Edit Config")
                            }
                            .conditionalFontWeight(.semibold)
                        }
                        .buttonStyle(.bordered)
                        .help("Configure your MCP server")
                    }
                    .padding(.vertical, 12)
                }
            )

            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Example Configuration").foregroundColor(.primary.opacity(0.85))
                        CopyButton(
                            copy: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(exampleConfig, forType: .string)
                            },
                            foregroundColor: .primary.opacity(0.85),
                            fontWeight: .semibold
                        )
                        .frame(width: 10, height: 10)
                    }
                    .padding(.leading, 4)

                    exampleConfigView()
                }
                .padding(.top, 8)
                .padding([.leading, .trailing, .bottom], 20)
                .background(QuaternarySystemFillColor.opacity(0.75))
                .transition(.opacity.combined(with: .scale(scale: 1, anchor: .top)))
            }
        }
        .cornerRadius(12)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .inset(by: 0.5)
                .stroke(SecondarySystemFillColor, lineWidth: 1)
                .animation(.easeInOut(duration: 0.3), value: isExpanded)
        )
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }

    var exampleConfig: String {
        """
        {
            "servers": {
                "my-mcp-server": {
                    "type": "stdio",
                    "command": "my-command",
                    "args": [],
                    "env": {
                        "TOKEN": "my_token"
                    }
                }
            }
        }
        """
    }

    @ViewBuilder
    private func exampleConfigView() -> some View {
        Text(exampleConfig)
            .font(.system(.body, design: .monospaced))
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(nsColor: .textBackgroundColor).opacity(0.5)
            )
            .textSelection(.enabled)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .inset(by: 0.5)
                    .stroke(Color("GroupBoxStrokeColor"), lineWidth: 1)
            )
    }

    private func openMCPRunTimeLogFolder() {
        let url = URL(
            fileURLWithPath: FileLoggingLocation.mcpRuntimeLogsPath.description,
            isDirectory: true
        )

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.createDirectory(
                    atPath: url.path,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
            } catch {
                Logger.client.error("Failed to create MCP runtime log folder: \(error)")
                return
            }
        }

        NSWorkspace.shared.open(url)
    }

    private func openConfigFile() {
        let url = URL(fileURLWithPath: mcpConfigFilePath)
        NSWorkspace.shared.open(url)
    }
}
