import SwiftUI
import ComposableArchitecture
import ConversationServiceProvider
import SharedUIComponents

// MARK: - Review Results Section

struct ReviewResultsSection: View {
    let store: StoreOf<Chat>
    let round: CodeReviewRound
    @State private var isExpanded = false
    @AppStorage(\.chatFontSize) private var chatFontSize
    
    private static let defaultVisibleReviewCount = 5
    
    private var fileComments: [CodeReviewResponse.FileComment] {
        round.response?.fileComments ?? []
    }
    
    private var visibleReviewCount: Int { 
        isExpanded ? fileComments.count : min(fileComments.count, Self.defaultVisibleReviewCount)
    }
    
    private var hasMoreReviews: Bool {
        fileComments.count > Self.defaultVisibleReviewCount
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ReviewResultsHeader(
                reviewStatus: round.status,
                chatFontSize: chatFontSize
            )
            .padding(8)
            .background(CodeReviewHeaderBackground())
            
            if !fileComments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ReviewResultsList(
                        store: store,
                        fileComments: Array(fileComments.prefix(visibleReviewCount))
                    )
                }
                .padding(.horizontal, 8)
                .padding(.bottom, !hasMoreReviews || isExpanded ? 8 : 0)
            }
            
            if hasMoreReviews && !isExpanded {
                ExpandReviewsButton(isExpanded: $isExpanded)
            }
        }
        .background(CodeReviewCardBackground())
    }
}

private struct ReviewResultsHeader: View {
    let reviewStatus: CodeReviewRound.Status
    let chatFontSize: CGFloat
    
    var body: some View {
        HStack(spacing: 4) {
            Text("Reviewed Changes")
                .scaledFont(size: chatFontSize)
            
            Spacer()
        }
    }
}


private struct ExpandReviewsButton: View {
    @Binding var isExpanded: Bool
    
    var body: some View {
        HStack {
            Spacer()
            
            Button {
                isExpanded = true
            } label: {
                Image("chevron.down")
                    .resizable()
                    .scaledToFit()
                    .scaledFrame(width: 16, height: 16)
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
        }
        .padding(.vertical, 2)
        .background(CodeReviewHeaderBackground())
    }
}

private struct ReviewResultsList: View {
    let store: StoreOf<Chat>
    let fileComments: [CodeReviewResponse.FileComment]
    
    var body: some View {
        ForEach(fileComments, id: \.self) { fileComment in
            if let fileURL = fileComment.url {
                ReviewResultRow(
                    store: store,
                    fileURL: fileURL, 
                    comments: fileComment.comments
                )
            }
        }
    }
}

private struct ReviewResultRow: View {
    let store: StoreOf<Chat>
    let fileURL: URL
    let comments: [ReviewComment]
    @State private var isExpanded = false
    
    private var commentCountText: String {
        comments.count == 1 ? "1 comment" : "\(comments.count) comments"
    }
    
    private var hasComments: Bool {
        !comments.isEmpty
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            ReviewResultRowContent(
                store: store,
                fileURL: fileURL,
                comments: comments,
                commentCountText: commentCountText,
                hasComments: hasComments
            )
        }
    }
}

private struct ReviewResultRowContent: View {
    let store: StoreOf<Chat>
    let fileURL: URL
    let comments: [ReviewComment]
    let commentCountText: String
    let hasComments: Bool
    @State private var isHovered: Bool = false
    
    @AppStorage(\.chatFontSize) private var chatFontSize
    
    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            drawFileIcon(fileURL)
                .scaledToFit()
                .scaledFrame(width: 16, height: 16)
            
            Button(action: {
                if hasComments {
                    store.send(.codeReview(.onFileClicked(fileURL, comments[0].range.end.line)))
                }
            }) {
                Text(fileURL.lastPathComponent)
                    .scaledFont(.system(size: chatFontSize))
                    .foregroundColor(isHovered ? Color("ItemSelectedColor") : .primary)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(!hasComments)
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }

            Text(commentCountText)
                .scaledFont(size: chatFontSize - 1)
                .lineSpacing(20)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}
