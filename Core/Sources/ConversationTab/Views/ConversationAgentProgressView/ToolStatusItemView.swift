import SwiftUI
import ConversationServiceProvider
import SharedUIComponents
import ComposableArchitecture
import MarkdownUI

struct ToolStatusItemView: View {

    let tool: AgentToolCall

    @AppStorage(\.chatFontSize) var chatFontSize

    @State private var isHoveringFileLink = false

    var statusIcon: some View {
        Group {
            switch tool.status {
            case .running:
                ProgressView()
                    .controlSize(.small)
                    .scaledScaleEffect(0.7)
            case .completed:
                Image(systemName: "checkmark")
                    .foregroundColor(.secondary)
            case .error:
                Image(systemName: "xmark")
                    .foregroundColor(.red.opacity(0.5))
            case .cancelled:
                Image(systemName: "slash.circle")
                    .foregroundColor(.gray.opacity(0.5))
            case .waitForConfirmation:
                EmptyView()
            case .accepted:
                EmptyView()
            }
        }
        .scaledFont(size: chatFontSize - 1, weight: .medium)
    }

    @ViewBuilder
    var progressTitleText: some View {
        if tool.name == ServerToolName.findFiles.rawValue {
            searchProgressView(
                pattern: "Searched for files matching query: (.*)",
                prefix: "Searched for files matching ",
                singularSuffix: "match",
                pluralSuffix: "matches"
            )
        } else if tool.name == ServerToolName.findTextInFiles.rawValue {
            searchProgressView(
                pattern: "Searched for text in files matching query: (.*)",
                prefix: "Searched for text in files matching ",
                singularSuffix: "result",
                pluralSuffix: "results"
            )
        } else if tool.name == ServerToolName.readFile.rawValue || tool.name == CopilotToolName.readFile.rawValue {
            readFileProgressView
        } else if tool.name == ToolName.createFile.rawValue {
            createFileProgressView
        } else if tool.name == ServerToolName.replaceString.rawValue {
            replaceStringProgressView
        } else if tool.name == ToolName.insertEditIntoFile.rawValue {
            insertEditIntoFileProgressView
        } else if tool.name == ServerToolName.codebase.rawValue {
            codebaseSearchProgressView
        } else {
            otherToolsProgressView
        }
    }

    @ViewBuilder
    func searchProgressView(pattern: String, prefix: String, singularSuffix: String, pluralSuffix: String) -> some View {
        let message = tool.progressMessage ?? ""
        let matchCountText: String = {
            if let parsed = parsedFileListResult {
                let suffix = parsed.count == 1 ? singularSuffix : pluralSuffix
                return "\(parsed.count) \(suffix)"
            }
            return ""
        }()

        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
           let range = Range(match.range(at: 1), in: message) {

            let query = String(message[range])
            let suffix = matchCountText.isEmpty ? "" : ": \(matchCountText)"

            HStack(spacing: 0) {
                Text(prefix)
                Text(query)
                    .scaledFont(size: chatFontSize - 1, weight: .regular, design: .monospaced)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(SecondarySystemFillColor)
                    .foregroundColor(.secondary)
                    .cornerRadius(4)
                    .padding(.horizontal, 2)
                Text(suffix)
            }
        } else {
            let displayMessage: String = {
                if message.isEmpty {
                    return matchCountText
                } else {
                    return message + (matchCountText.isEmpty ? "" : ": \(matchCountText)")
                }
            }()

            markdownView(text: displayMessage)
        }
    }

    @ViewBuilder
    var readFileProgressView: some View {
        let pattern = #"^Read file \[(?<name>.+?)\]\((?<path>.+?)\)(?:, lines (?<start>\d+) to (?<end>\d+))?"#
        fileOperationProgressView(prefix: "Read", pattern: pattern) { match in
            let message = tool.progressMessage ?? ""
            if let startRange = Range(match.range(withName: "start"), in: message),
               let endRange = Range(match.range(withName: "end"), in: message) {
                let start = String(message[startRange])
                let end = String(message[endRange])
                Text(": \(start)-\(end)")
                    .foregroundColor(.secondary)
                    .scaledFont(size: chatFontSize - 1)
            }
        }
    }

    @ViewBuilder
    var createFileProgressView: some View {
        let pattern = #"^Created \[(?<name>.+?)\]\((?<path>.+?)\)"#
        fileOperationProgressView(suffix: "created successfully.", pattern: pattern)
    }
    @ViewBuilder
    var replaceStringProgressView: some View {
        let pattern = #"^Edited \[(?<name>.+?)\]\((?<path>.+?)\) with replace_string_in_file tool"#
        fileOperationProgressView(prefix: "Edited", suffix: "with replace_string_in_file tool.", pattern: pattern)
    }

    @ViewBuilder
    var insertEditIntoFileProgressView: some View {
        let pattern = #"^Edited \[(?<name>.+?)\]\((?<path>.+?)\) with insert_edit_into_file tool"#
        fileOperationProgressView(prefix: "Edited", suffix: "with insert_edit_into_file tool.", pattern: pattern)
    }

    @ViewBuilder
    var codebaseSearchProgressView: some View {
        let pattern = #"^Searched (?<target>.+) for "(?<query>.+)", (?<count>no|\d+) results?$"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let message = tool.progressMessage,
           let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
           let targetRange = Range(match.range(withName: "target"), in: message),
           let queryRange = Range(match.range(withName: "query"), in: message),
           let countRange = Range(match.range(withName: "count"), in: message) {

            let target = String(message[targetRange])
            let query = String(message[queryRange])
            let countStr = String(message[countRange])
            let count = countStr == "no" ? "0" : countStr
            let suffix = count == "1" ? "result" : "results"

            HStack(spacing: 0) {
                Text("Searched \(target) for ")
                Text(query)
                    .scaledFont(size: chatFontSize - 1, weight: .regular, design: .monospaced)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(SecondarySystemFillColor)
                    .foregroundColor(.secondary)
                    .cornerRadius(4)
                    .padding(.horizontal, 2)
                Text(": \(count) \(suffix)")
            }
        } else {
            markdownView(text: tool.progressMessage ?? "")
        }
    }

    @ViewBuilder
    func fileOperationProgressView<Content: View>(
        prefix: String? = nil,
        suffix: String? = nil,
        pattern: String,
        @ViewBuilder extraContent: (NSTextCheckingResult) -> Content = { _ in EmptyView() }
    ) -> some View {
        let message = tool.progressMessage ?? ""

        if tool.name == ToolName.createFile.rawValue, tool.status == .error {
            if let input = tool.invokeParams?.input, let filePath = input["filePath"]?.value as? String {
                let url = URL(fileURLWithPath: filePath)
                let name = url.lastPathComponent
                HStack(spacing: 4) {
                    drawFileIcon(url)
                        .scaledToFit()
                        .scaledFrame(width: 16, height: 16)
                    Text(name).scaledFont(size: chatFontSize - 1)
                    Text("File creation failed")
                }
            } else {
                markdownView(text: message)
            }
        } else if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)),
           let nameRange = Range(match.range(withName: "name"), in: message),
           let pathRange = Range(match.range(withName: "path"), in: message) {

            let name = String(message[nameRange])
            let pathString = String(message[pathRange])
            let url = URL(string: pathString).flatMap { $0.scheme == "file" ? $0 : nil } ?? URL(fileURLWithPath: pathString)

            HStack(spacing: 4) {
                if let prefix {
                    Text(prefix)
                }

                drawFileIcon(url)
                    .scaledToFit()
                    .scaledFrame(width: 16, height: 16)

                Button(action: {
                    NSWorkspace.shared.open(url)
                }) {
                    Text(name)
                        .scaledFont(size: chatFontSize - 1)
                        .foregroundColor(isHoveringFileLink ? .primary : .secondary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHoveringFileLink = hovering
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }

                if let suffix {
                    Text(suffix)
                }

                extraContent(match)
                    .padding(.leading, -4)
            }
        } else {
            markdownView(text: message)
        }
    }

    @ViewBuilder
    var otherToolsProgressView: some View {
        let message: String = {
            var msg = tool.progressMessage ?? ""
            if tool.name == ToolName.createFile.rawValue {
                if let input = tool.invokeParams?.input, let filePath = input["filePath"]?.value as? String {
                    let fileURL = URL(fileURLWithPath: filePath)
                    msg += ": [\(fileURL.lastPathComponent)](\(fileURL.absoluteString))"
                }
            }
            return msg
        }()

        if message.isEmpty {
            GenericToolTitleView(toolStatus: "Running", toolName: tool.name)
        } else {
            markdownView(text: message)
        }
    }

    func markdownView(text: String) -> some View {
        ThemedMarkdownText(
            text: text,
            context: .init(supportInsert: false),
            foregroundColor: .secondary
        )
        .environment(\.openURL, OpenURLAction { url in
            if url.scheme == "file" || url.isFileURL {
                NSWorkspace.shared.open(url)
                return .handled
            } else {
                return .systemAction
            }
        })
    }

    var progressErrorText: some View {
        ThemedMarkdownText(
            text: tool.error ?? "",
            context: .init(supportInsert: false),
            foregroundColor: .secondary
        )
    }

    var progress: some View {
        HStack(spacing: 4) {
            statusIcon
                .scaledFrame(width: 16, height: 16)

            progressTitleText
                .scaledFont(size: chatFontSize - 1)
                .lineLimit(1)

            Spacer()
        }
        .help(tool.progressMessage ?? "")
    }

    var toolResultText: String? {
        tool.result?.compactMap({ item -> String? in
            if case .text(let s) = item { return s }
            return nil
        }).joined(separator: "\n")
    }

    func extractCreateFileContent(from text: String) -> String {
        let pattern = #"(?s)<file_created.*?>\n?(.*?)\n?</file_created>"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return text
    }

    func extractInsertEditContent(from text: String) -> String {
        let pattern = #"(?s)<file_after_edit.*?>\n?(.*?)\n?</file_after_edit>"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
           let range = Range(match.range(at: 1), in: text) {
            return String(text[range])
        }
        return text
    }

    var parsedFileListResult: (count: Int, files: [FileSearchResult])? {
        guard let resultText = toolResultText,
              !resultText.isEmpty else {
            return nil
        }

        // Parse find_files result
        if tool.name == ServerToolName.findFiles.rawValue {
            if resultText.hasPrefix("No files found") {
                return (0, [])
            }

            let pattern = "Found (\\d+) files? matching query:"
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: resultText, range: NSRange(resultText.startIndex..., in: resultText)),
               let range = Range(match.range(at: 1), in: resultText),
               let count = Int(resultText[range]) {

                if let newlineIndex = resultText.firstIndex(of: "\n") {
                    let filesPart = resultText[resultText.index(after: newlineIndex)...]
                    let files = filesPart.split(separator: "\n").map { FileSearchResult(file: String($0)) }
                    return (count, files)
                }
            }
        }

        // Parse grep_search result
        if tool.name == ServerToolName.findTextInFiles.rawValue {
            if resultText.contains("no results") {
                return (0, [])
            }

            let countPattern = "Searched text for: .*, (\\d+) results?"
            var count = 0
            if let regex = try? NSRegularExpression(pattern: countPattern),
               let match = regex.firstMatch(in: resultText, range: NSRange(resultText.startIndex..., in: resultText)),
               let range = Range(match.range(at: 1), in: resultText),
               let parsedCount = Int(resultText[range]) {
                count = parsedCount
            }

            var files: [FileSearchResult] = []
            let lines = resultText.split(separator: "\n")
            // Skip the first line which is the summary
            if lines.count > 1 {
                for line in lines.dropFirst() {
                    let parts = line.split(separator: ":", maxSplits: 2)
                    if parts.count >= 2 {
                        let path = String(parts[0])
                        if let lineNumber = Int(parts[1]) {
                            let content = parts.count > 2 ? String(parts[2]) : nil
                            files.append(FileSearchResult(file: path, startLine: lineNumber, content: content))
                        } else {
                            files.append(FileSearchResult(file: path))
                        }
                    }
                }
            }

            return (count, files)
        }

        // Parse list_dir result
        if tool.name == ServerToolName.listDir.rawValue {
            let files = resultText.split(separator: "\n").map { FileSearchResult(file: String($0)) }
            return (files.count, files)
        }

        return nil
    }

    var parsedCodebaseSearchResult: (count: Int, files: [FileSearchResult])? {
        guard let details = tool.resultDetails, !details.isEmpty else { return nil }

        var files: [FileSearchResult] = []
        for item in details {
            if case .fileLocation(let location) = item {
                files
                    .append(
                        FileSearchResult(
                            file: location.uri,
                            startLine: location.range.start.line,
                            endLine: location.range.end.line
                        )
                    )
            }
        }

        return (files.count, files)
    }

    var body: some View {
        WithPerceptionTracking {
            if tool.name == ToolName.createFile.rawValue, let resultText = toolResultText, !resultText.isEmpty {
                ToolStatusDetailsView(
                    title: progress,
                    content: markdownView(text: extractCreateFileContent(from: resultText))
                )
            } else if tool.name == ServerToolName.replaceString.rawValue, let resultText = toolResultText, !resultText.isEmpty {
                ToolStatusDetailsView(
                    title: progress,
                    content: markdownView(text: resultText)
                )
            } else if tool.name == ToolName.insertEditIntoFile.rawValue, let resultText = toolResultText, !resultText.isEmpty {
                ToolStatusDetailsView(
                    title: progress,
                    content: markdownView(text: extractInsertEditContent(from: resultText))
                )
            } else if tool.status == .error {
                ToolStatusDetailsView(
                    title: progress,
                    content: progressErrorText
                )
            } else if let result = parsedFileListResult,
                      !result.files.isEmpty {
                ExpandableFileListView(
                    progressMessage: progressTitleText,
                    files: result.files,
                    chatFontSize: chatFontSize,
                    helpText: tool.progressMessage ?? ""
                )
                .scaledPadding(.horizontal, 6)
            } else if let result = parsedCodebaseSearchResult,
                      !result.files.isEmpty {
                ExpandableFileListView(
                    progressMessage: progressTitleText,
                    files: result.files,
                    chatFontSize: chatFontSize,
                    helpText: tool.progressMessage ?? ""
                )
                .scaledPadding(.horizontal, 6)
            } else {
                progress.scaledPadding(.horizontal, 6)
            }
        }
    }
}


private struct ToolStatusDetailsView<Title: View, Content: View>: View {
    var title: Title
    var content: Content

    @State private var isExpanded = false
    @AppStorage(\.fontScale) var fontScale

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            Button(action: {
                isExpanded.toggle()
            }) {
                HStack(spacing: 8) {
                    title

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .resizable()
                        .scaledToFit()
                        .padding(4)
                        .scaledFrame(width: 16, height: 16)
                        .scaledFont(size: 10, weight: .medium)
                }
                .contentShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .scaledPadding(.horizontal, 6)
            .toolStatusStyle(withBackground: !isExpanded, fontScale: fontScale)

            if isExpanded {
                Divider()
                    .background(Color.agentToolStatusDividerColor)

                content
                    .scaledPadding(.horizontal, 8)
            }
        }
        .toolStatusStyle(withBackground: isExpanded, fontScale: fontScale)
    }
}

private extension View {
    func toolStatusStyle(withBackground: Bool, fontScale: CGFloat) -> some View {
        /// Leverage the `modify` extension to avoid refreshing of chat panel `List` view
        self.modify { view in
            if withBackground {
                view
                    .scaledPadding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.agentToolStatusOutlineColor, lineWidth: 1 * fontScale)
                    )
            } else {
                view
            }
        }
    }
}
