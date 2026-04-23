import ConversationServiceProvider
import SharedUIComponents
import SwiftUI

struct ContextSizeButton: View {
    let contextSizeInfo: ContextSizeInfo
    @State private var isHovering = false
    @State private var showPopover = false
    @State private var isClickTriggered = false
    @State private var hoverTask: Task<Void, Never>?
    @State private var dismissTask: Task<Void, Never>?

    private let ringSize: CGFloat = 11
    private let lineWidth: CGFloat = 1.5

    var body: some View {
        Button(action: {
            hoverTask?.cancel()
            dismissTask?.cancel()
            isClickTriggered = true
            showPopover = true
        }) {
            HStack(spacing: 4) {
                DonutChart(
                    percentage: contextSizeInfo.utilizationPercentage,
                    ringColor: ringColor,
                    size: ringSize,
                    lineWidth: lineWidth
                )

                if isHovering {
                    Text("\(Int(contextSizeInfo.utilizationPercentage))%")
                        .scaledFont(size: 11, weight: .medium)
                        .foregroundColor(.primary)
                        .transition(.opacity)
                }
            }
            .scaledPadding(.horizontal, 6)
            .scaledPadding(.vertical, 4)
        }
        .buttonStyle(HoverButtonStyle(padding: 0))
        .accessibilityLabel("Context size")
        .accessibilityValue(Text("\(Int(contextSizeInfo.utilizationPercentage)) percent of context tokens used"))
        .accessibilityHint("Shows details about the current context size and token usage.")
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
            hoverTask?.cancel()
            if hovering {
                dismissTask?.cancel()
                hoverTask = Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !Task.isCancelled else { return }
                    isClickTriggered = false
                    showPopover = true
                }
            } else if !isClickTriggered {
                scheduleDismiss()
            }
        }
        .onChange(of: showPopover) { newValue in
            if !newValue {
                isClickTriggered = false
            }
        }
        .popover(isPresented: $showPopover, arrowEdge: .bottom) {
            ContextSizePopover(info: contextSizeInfo)
                .onHover { hovering in
                    if hovering {
                        dismissTask?.cancel()
                    } else if !isClickTriggered {
                        scheduleDismiss()
                    }
                }
        }
    }

    private func scheduleDismiss() {
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            showPopover = false
        }
    }

    private var ringColor: Color {
        let pct = contextSizeInfo.utilizationPercentage
        if pct >= 80 { return Color("WarningYellow") }
        return .secondary
    }
}

private struct DonutChart: View {
    let percentage: Double
    let ringColor: Color
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(nsColor: .quaternaryLabelColor), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(percentage / 100, 1.0))
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .scaledFrame(width: size, height: size)
    }
}

private struct ContextSizePopover: View {
    let info: ContextSizeInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // MARK: Context Window
            VStack(alignment: .leading, spacing: 6) {
                Text("Context Window")
                    .scaledFont(.headline)

                HStack {
                    Text("\(formatTokens(info.totalUsedTokens)) / \(formatTokens(info.totalTokenLimit)) tokens")
                    Spacer()
                    Text(formatPercentage(info.utilizationPercentage))
                }
                .scaledFont(.callout)

                ProgressView(value: min(info.utilizationPercentage, 100), total: 100)
                    .tint(progressColor)
            }

            // MARK: System
            VStack(alignment: .leading, spacing: 4) {
                Text("System")
                    .scaledFont(.headline)
                    .scaledPadding(.bottom, 4)

                tokenRow("System Instructions", tokens: info.systemPromptTokens)
                tokenRow("Tool Definitions", tokens: info.toolDefinitionTokens)
            }

            // MARK: User
            VStack(alignment: .leading, spacing: 4) {
                Text("User")
                    .scaledFont(.headline)
                    .scaledPadding(.bottom, 4)

                tokenRow("Messages", tokens: info.userMessagesTokens + info.assistantMessagesTokens)
                tokenRow("Attached Files", tokens: info.attachedFilesTokens)
                tokenRow("Tool Results", tokens: info.toolResultsTokens)
            }

            // TODO: Depends on CLS for manual compression
        }
        .scaledPadding(.vertical, 20)
        .scaledPadding(.horizontal, 16)
        .scaledFrame(width: 240)
    }

    private var progressColor: Color {
        let pct = info.utilizationPercentage
        if pct >= 80 { return Color(nsColor: .systemYellow) }
        return .accentColor
    }

    private func tokenRow(_ label: String, tokens: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(percentage(for: tokens))
        }
        .scaledFont(.callout)
    }

    private func percentage(for tokens: Int) -> String {
        guard info.totalTokenLimit > 0 else { return "0%" }
        let pct = Double(tokens) / Double(info.totalTokenLimit) * 100
        return formatPercentage(pct)
    }

    private func formatPercentage(_ pct: Double) -> String {
        if pct == 0 { return "0%" }
        return String(format: "%.1f%%", pct)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1000 {
            let k = Double(count) / 1000.0
            return String(format: "%.1fK", k)
        }
        return "\(count)"
    }
}
