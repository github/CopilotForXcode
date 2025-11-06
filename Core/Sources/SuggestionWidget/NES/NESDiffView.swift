import SwiftUI
import ComposableArchitecture
import SuggestionBasic

struct NESDiffView: View {
    var store: StoreOf<NESSuggestionPanelFeature>

    var body: some View {
        WithPerceptionTracking {
            if store.isPanelDisplayed,
               !store.isPanelOutOfFrame,
               let nesContent = store.nesContent,
               let originalCodeSnippet = nesContent.getOriginalCodeSnippet()
            {
                let nesCode = nesContent.code
                
                ScrollView(showsIndicators: true) {
                    Group {
                        if nesContent.range.isOneLine && nesCode.components(separatedBy: .newlines).count <= 1 {
                            InlineDiffView(
                                store: store,
                                segments: DiffBuilder.inlineSegments(
                                    oldLine: originalCodeSnippet,
                                    newLine: nesCode
                                )
                            )
                        } else {
                            LineDiffView(
                                store: store,
                                segments: DiffBuilder.lineSegments(
                                    oldContent: originalCodeSnippet,
                                    newContent: nesCode
                                )
                            )
                        }
                    }
                }
                .padding(.leading, 12 * store.fontSizeScale)
                .padding(.trailing, 10 * store.fontSizeScale)
                .padding(.vertical, 4 * store.fontSizeScale)
                .xcodeStyleFrame()
                .opacity(store.diffViewOpacity)
            }
        }
    }
}


private struct AccentStrip: View {
    let store: StoreOf<NESSuggestionPanelFeature>
    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(.blue)
            .frame(width: 4 * store.fontSizeScale)
    }
}

struct InlineDiffView: View {
    let store: StoreOf<NESSuggestionPanelFeature>
    let segments: [DiffSegment]
    
    var body: some View {
        HStack(spacing: 0) {
            AccentStrip(store: store)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        buildSegmentView(segment)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    @ViewBuilder
    func buildSegmentView(_ segment: DiffSegment) -> some View {
        Text(verbatim: segment.text.diffDisplayEscaped())
            .lineLimit(1)
            .font(.system(size: store.lineFontSize, weight: .medium))
            .padding(.vertical, 4 * store.fontSizeScale)
            .background(
                Rectangle()
                    .fill(segment.backgroundColor)
            )
            .alignmentGuide(.firstTextBaseline) { d in
                d[.firstTextBaseline]
            }
    }
}


struct LineDiffView: View {
    let store: StoreOf<NESSuggestionPanelFeature>
    let segments: [DiffSegment]
    
    var body: some View {
        HStack(spacing: 0) {
            AccentStrip(store: store)
            
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    buildSegmentView(segment)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    func buildSegmentView(_ segment: DiffSegment) -> some View {
        Text(segment.text.diffDisplayEscaped())
            .font(.system(size: store.lineFontSize, weight: .medium))
            .multilineTextAlignment(.leading)
            .padding(.vertical, 4 * store.fontSizeScale)
            .background(
                Rectangle()
                    .fill(segment.backgroundColor)
            )
    }
}


extension DiffSegment {
    var backgroundColor: Color {
        switch change {
        case .added: return Color("editor.focusedStackFrameHighlightBackground")
        case .removed: return Color("editorOverviewRuler.inlineChatRemoved")
        case .unchanged: return .clear
        }
    }
}

private extension String {
    func diffDisplayEscaped() -> String {
        var escaped = ""
        for scalar in unicodeScalars {
            switch scalar {
            case "\n": escaped.append("\\n")
            case "\r": escaped.append("\\r")
            case "\t": escaped.append("\\t")
            default: escaped.append(Character(scalar))
            }
        }
        return escaped
    }
}
