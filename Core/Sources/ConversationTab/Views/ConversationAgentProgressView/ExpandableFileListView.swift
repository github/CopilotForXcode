import SwiftUI
import SharedUIComponents
import AppKit
import Terminal

struct FileSearchResult: Hashable {
    var file: String
    var startLine: Int? = nil
    var endLine: Int? = nil
    var content: String? = nil
}

struct ExpandableFileListView<ProgressMessage: View>: View {
    var progressMessage: ProgressMessage
    var files: [FileSearchResult]
    var chatFontSize: Double
    var helpText: String
    var onFileClick: ((String) -> Void)? = nil
    var fileHelpTexts: [String: String]? = nil
    
    @State private var isExpanded: Bool = false
    
    init(
        progressMessage: ProgressMessage,
        files: [FileSearchResult],
        chatFontSize: Double,
        helpText: String,
        onFileClick: ((String) -> Void)? = nil,
        fileHelpTexts: [String: String]? = nil
    ) {
        self.progressMessage = progressMessage
        self.files = files
        self.chatFontSize = chatFontSize
        self.helpText = helpText
        self.onFileClick = onFileClick
        self.fileHelpTexts = fileHelpTexts
    }
    
    init(
        progressMessage: ProgressMessage,
        files: [String],
        chatFontSize: Double,
        helpText: String,
        onFileClick: ((String) -> Void)? = nil,
        fileHelpTexts: [String: String]? = nil
    ) {
        self.init(
            progressMessage: progressMessage,
            files: files.map { FileSearchResult(file: $0) },
            chatFontSize: chatFontSize,
            helpText: helpText,
            onFileClick: onFileClick,
            fileHelpTexts: fileHelpTexts
        )
    }
    
    private let maxVisibleRows = 5
    private let chevronWidth: CGFloat = 16
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with chevron on the left
            Button(action: {
                isExpanded.toggle()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .scaledFrame(width: chevronWidth, height: chevronWidth)
                        .scaledFont(size: 10, weight: .medium)
                        .foregroundColor(.secondary)

                    progressMessage
                        .scaledFont(size: chatFontSize - 1)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(helpText)
            
            if isExpanded {
                HStack(alignment: .top, spacing: 0) {
                    // Vertical line aligned with chevron center
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .scaledFrame(width: 1)
                        .scaledPadding(.leading, chevronWidth / 2 - 0.5)
                    
                    // File list
                    VStack(alignment: .leading, spacing: 0) {
                        if files.count <= maxVisibleRows {
                            ForEach(files, id: \.self) { fileItem in
                                fileRow(for: fileItem)
                            }
                        } else {
                            ThinScrollView {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(files, id: \.self) { fileItem in
                                        fileRow(for: fileItem)
                                    }
                                }
                            }
                            .frame(height: CGFloat(maxVisibleRows) * 23)
                        }
                    }
                    .scaledPadding(.leading, chevronWidth / 2)
                }
                .scaledPadding(.top, 4)
            }
        }
    }
    
    @ViewBuilder
    private func fileRow(for fileItem: FileSearchResult) -> some View {
        let filePath = fileItem.file
        let isDirectory = filePath.hasSuffix("/")
        let cleanPath = isDirectory ? String(filePath.dropLast()) : filePath
        let url = URL(string: cleanPath).flatMap { $0.scheme == "file" ? $0 : nil } ?? URL(fileURLWithPath: cleanPath)
        let displayName: String = {
            var name = isDirectory ? url.lastPathComponent + "/" : url.lastPathComponent
            if let line = fileItem.startLine, !isDirectory {
                name += ": \(line)"
                if let endLine = fileItem.endLine {
                    name += "-\(endLine)"
                }
            }
            return name
        }()
        
        Button(action: {
            if let onFileClick = onFileClick {
                onFileClick(filePath)
            } else {
                if let line = fileItem.startLine, !isDirectory {
                    Task {
                        let terminal = Terminal()
                        do {
                            _ = try await terminal.runCommand(
                                "/usr/bin/xed",
                                arguments: [
                                    "-l",
                                    String(line),
                                    url.path
                                ],
                                environment: [
                                    "TARGET_FILE": url.path
                                ]
                            )
                        } catch {
                            print("Failed to open file with xed: \(error)")
                            NSWorkspace.shared.open(url)
                        }
                    }
                } else {
                    NSWorkspace.shared.open(url)
                }
            }
        }) {
            HStack(alignment: .center, spacing: 6) {
                drawFileIcon(url, isDirectory: isDirectory)
                    .scaledToFit()
                    .scaledFrame(width: 13, height: 13)
                    .foregroundColor(.secondary)

                Text(displayName)
                    .scaledFont(size: chatFontSize - 1)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .help(fileHelpTexts?[filePath] ?? url.path)
        .buttonStyle(HoverButtonStyle())
    }
}

// NSScrollView wrapper for thin, overlay-style scrollbars
struct ThinScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        
        let hostingView = NSHostingView(rootView: content)
        scrollView.documentView = hostingView
        
        // Ensure the hosting view can expand vertically
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        if let hostingView = scrollView.documentView as? NSHostingView<Content> {
            hostingView.rootView = content
            hostingView.invalidateIntrinsicContentSize()
        }
    }
}
