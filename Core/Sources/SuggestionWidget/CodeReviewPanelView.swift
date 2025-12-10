import SwiftUI
import Combine
import XcodeInspector
import ComposableArchitecture
import ConversationServiceProvider
import LanguageServerProtocol
import ChatService
import SharedUIComponents
import ConversationTab

private typealias CodeReviewPanelViewStore = ViewStore<ViewState, CodeReviewPanelFeature.Action>

private struct ViewState: Equatable {
    let reviewComments: [ReviewComment]
    let currentSelectedComment: ReviewComment?
    let currentIndex: Int
    let operatedCommentIds: Set<String>
    var hasNextComment: Bool
    var hasPreviousComment: Bool
    
    var commentsCount: Int { reviewComments.count }
    
    init(state: CodeReviewPanelFeature.State) {
        self.reviewComments = state.currentDocumentReview?.comments ?? []
        self.currentSelectedComment = state.currentSelectedComment
        self.currentIndex = state.currentIndex
        self.operatedCommentIds = state.operatedCommentIds
        self.hasNextComment = state.hasNextComment
        self.hasPreviousComment = state.hasPreviousComment
    }
}

struct CodeReviewPanelView: View {
    let store: StoreOf<CodeReviewPanelFeature>

    var body: some View {
        WithViewStore(self.store, observe: ViewState.init) { viewStore in 
            WithPerceptionTracking {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        HeaderView(viewStore: viewStore)
                            .padding(.bottom, 4)
                        
                        Divider()
                        
                        ContentView(
                            comment: viewStore.currentSelectedComment,
                            viewStore: viewStore
                        )
                        .padding(.top, 16)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .frame(maxWidth: .infinity, maxHeight: Style.codeReviewPanelHeight, alignment: .top)
                    .fixedSize(horizontal: false, vertical: true)
                    .xcodeStyleFrame()
                    .onAppear { viewStore.send(.appear) }
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Header View
private struct HeaderView: View {
    let viewStore: CodeReviewPanelViewStore
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    .frame(width: 24, height: 24)
                
                Image("CopilotLogo")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 12, height: 12)
            }

            Text("Code Review Comment")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            
            if viewStore.commentsCount > 0 {
                Text("(\(viewStore.currentIndex + 1) of \(viewStore.commentsCount))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            NavigationControls(viewStore: viewStore)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Navigation Controls
private struct NavigationControls: View {
    let viewStore: CodeReviewPanelViewStore
    
    var body: some View {
        HStack(spacing: 4) {
            if viewStore.hasPreviousComment {
                Button(action: {
                    viewStore.send(.previous)
                }) {
                    Image(systemName: "arrow.up")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 13, height: 13)
                }
                .buttonStyle(HoverButtonStyle())
                .buttonStyle(PlainButtonStyle())
                .help("Previous")
            }
            
            if viewStore.hasNextComment {
                Button(action: {
                    viewStore.send(.next)
                }) {
                    Image(systemName: "arrow.down")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 13, height: 13)
                }
                .buttonStyle(HoverButtonStyle())
                .buttonStyle(PlainButtonStyle())
                .help("Next")
            }
            
            Button(action: {
                if let id = viewStore.currentSelectedComment?.id {
                    viewStore.send(.close(commentId: id))
                }
            }) {
                Image(systemName: "xmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 13, height: 13)
            }
            .buttonStyle(HoverButtonStyle())
            .buttonStyle(PlainButtonStyle())
            .help("Close")
        }
    }
}

// MARK: - Content View
private struct ContentView: View {
    let comment: ReviewComment?
    let viewStore: CodeReviewPanelViewStore
    
    var body: some View {
        if let comment = comment {
            CommentDetailView(comment: comment, viewStore: viewStore)
        } else {
            EmptyView()
        }
    }
}

// MARK: - Comment Detail View
private struct CommentDetailView: View {
    let comment: ReviewComment
    let viewStore: CodeReviewPanelViewStore
    @AppStorage(\.chatFontSize) var chatFontSize
    
    var lineInfoContent: String {
        let displayStartLine = comment.range.start.line + 1
        let displayEndLine = comment.range.end.line + 1
        
        if displayStartLine == displayEndLine {
            return "Line \(displayStartLine)"
        } else {
            return "Line \(displayStartLine)-\(displayEndLine)"
        }
    }
    
    var lineInfoView: some View {
        Text(lineInfoContent)
            .font(.system(size: chatFontSize))
    }
    
    var kindView: some View {
        Text(comment.kind)
            .font(.system(size: chatFontSize))
            .padding(.horizontal, 6)
            .frame(maxHeight: 20)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .foregroundColor(.hoverColor)
            )
    }
    
    var messageView: some View {
        ScrollView {
            ThemedMarkdownText(
                text: comment.message,
                context: .init(supportInsert: false)
            )
        }
    }
    
    var dismissButton: some View {
        Button(action: {
            viewStore.send(.dismiss(commentId: comment.id))
        }) {
            Text("Dismiss")
        }
        .buttonStyle(.bordered)
        .foregroundColor(.primary)
        .help("Dismiss")
    }
    
    var acceptButton: some View {
        Button(action: {
            viewStore.send(.accept(commentId: comment.id))
        }) {
            Text("Accept")
        }
        .buttonStyle(.borderedProminent)
        .help("Accept")
    }

    private var fileURL: URL? {
        URL(string: comment.uri)
    }

    var fileNameView: some View {
        HStack(alignment: .center, spacing: 8) {
            drawFileIcon(fileURL)
                .scaledToFit()
                .frame(width: 16, height: 16)

            Text(fileURL?.lastPathComponent ?? comment.uri)
                .fontWeight(.semibold)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Compact header with range info and badges in one line
            HStack(alignment: .center, spacing: 8) {
                fileNameView
                
                Spacer()
                
                lineInfoView
                
                kindView
            }
            
            messageView
                .frame(maxHeight: 100)
                .fixedSize(horizontal: false, vertical: true)
            
            // Add suggested change view if suggestion exists
            if let suggestion = comment.suggestion, 
                !suggestion.isEmpty,
               let fileUrl = URL(string: comment.uri),
               let content = try? String(contentsOf: fileUrl)
            {
                SuggestedChangeView(
                    suggestion: suggestion,
                    content: content,
                    range: comment.range,
                    chatFontSize: chatFontSize
                )
                
                if !viewStore.operatedCommentIds.contains(comment.id) {
                    HStack(spacing: 9) {
                        Spacer()
                        
                        dismissButton
                        
                        acceptButton
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Suggested Change View
private struct SuggestedChangeView: View {
    let suggestion: String
    let content: String
    let range: LSPRange
    let chatFontSize: CGFloat
    
    struct DiffLine {
        let content: String
        let lineNumber: Int
        let type: DiffLineType
    }
    
    enum DiffLineType {
        case removed
        case added
    }
    
    var diffLines: [DiffLine] {
        var lines: [DiffLine] = []
        
        // Add removed lines
        let contentLines = content.components(separatedBy: .newlines)
        if range.start.line >= 0 && range.end.line < contentLines.count {
            let removedLines = Array(contentLines[range.start.line...range.end.line])
            for (index, lineContent) in removedLines.enumerated() {
                lines.append(DiffLine(
                    content: lineContent,
                    lineNumber: range.start.line + index + 1,
                    type: .removed
                ))
            }
        }
        
        // Add suggested lines
        let suggestionLines = suggestion.components(separatedBy: .newlines)
        for (index, lineContent) in suggestionLines.enumerated() {
            lines.append(DiffLine(
                content: lineContent,
                lineNumber: range.start.line + index + 1,
                type: .added
            ))
        }
        
        return lines
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Suggested change")
                    .font(.system(size: chatFontSize, weight: .regular))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.leading, 8)
            .padding(.vertical, 6)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
            
            Rectangle()
                .fill(.ultraThickMaterial)
                .frame(height: 1)
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(diffLines.indices, id: \.self) { index in
                        DiffLineView(
                            line: diffLines[index],
                            chatFontSize: chatFontSize
                        )
                    }
                }
            }
            .frame(maxHeight: 150)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(.ultraThickMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Diff Line View
private struct DiffLineView: View {
    let line: SuggestedChangeView.DiffLine
    let chatFontSize: CGFloat
    @State private var contentHeight: CGFloat = 0
    
    private var backgroundColor: SwiftUICore.Color {
        switch line.type {
        case .removed:
            return Color("editorOverviewRuler.inlineChatRemoved")
        case .added:
            return Color("editor.focusedStackFrameHighlightBackground")
        }
    }
    
    private var lineNumberBackgroundColor: SwiftUICore.Color {
        switch line.type {
        case .removed:
            return Color("gitDecoration.deletedResourceForeground")
        case .added:
            return Color("gitDecoration.addedResourceForeground")
        }
    }
    
    private var prefix: String {
        switch line.type {
        case .removed:
            return "-"
        case .added:
            return "+"
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                HStack(spacing: 4) {
                    Text("\(line.lineNumber)")
                    Text(prefix)
                }
            }
            .font(.system(size: chatFontSize))
            .foregroundColor(.white)
            .frame(width: 60, height: contentHeight) // TODO: dynamic set height by font size
            .background(lineNumberBackgroundColor)
            
            // Content section with text wrapping
            VStack(alignment: .leading) {
                Text(line.content)
                    .font(.system(size: chatFontSize))
                    .lineLimit(nil)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .padding(.vertical, 4)
            .padding(.leading, 8)
            .background(backgroundColor)
            .background(
                GeometryReader { geometry in 
                    Color.clear
                        .onAppear { contentHeight = geometry.size.height }
                }
            )
        }
    }
}
