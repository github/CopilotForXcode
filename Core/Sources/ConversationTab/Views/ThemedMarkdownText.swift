import Foundation
import MarkdownUI
import SwiftUI
import ChatService
import ComposableArchitecture
import SuggestionBasic
import ChatTab
import SharedUIComponents

public struct MarkdownActionProvider {
    let supportInsert: Bool
    let onInsert: ((String) -> Void)?
    
    public init(supportInsert: Bool = true, onInsert: ((String) -> Void)? = nil) {
        self.supportInsert = supportInsert
        self.onInsert = onInsert
    }
}

public struct ThemedMarkdownText: View {
    @AppStorage(\.syncChatCodeHighlightTheme) var syncCodeHighlightTheme
    @AppStorage(\.codeForegroundColorLight) var codeForegroundColorLight
    @AppStorage(\.codeBackgroundColorLight) var codeBackgroundColorLight
    @AppStorage(\.codeForegroundColorDark) var codeForegroundColorDark
    @AppStorage(\.codeBackgroundColorDark) var codeBackgroundColorDark
    @AppStorage(\.chatFontSize) var chatFontSize
    @Environment(\.colorScheme) var colorScheme
    
    static let defaultForegroundColor: Color = .primary
    
    @StateObject private var fontScaleManager = FontScaleManager.shared
    
    let foregroundColor: Color
    
    var fontScale: Double {
        fontScaleManager.currentScale
    }
    
    var scaledChatCodeFont: NSFont {
        .monospacedSystemFont(ofSize: 12 * fontScale, weight: .regular)
    }
    
    var scaledChatFontSize: CGFloat {
        chatFontSize * fontScale
    }

    let text: String
    let context: MarkdownActionProvider

    public init(text: String, context: MarkdownActionProvider, foregroundColor: Color? = nil) {
        self.text = text
        self.context = context
        self.foregroundColor = foregroundColor ?? Self.defaultForegroundColor
    }
    
    init(text: String, chat: StoreOf<Chat>) {
        self.text = text
        
        self.context = .init(onInsert: { content in 
            chat.send(.insertCode(content))
        })
        self.foregroundColor = Self.defaultForegroundColor
    }

    public var body: some View {
        Markdown(text)
            .textSelection(.enabled)
            .markdownTheme(.custom(
                fontSize: scaledChatFontSize,
                foregroundColor: foregroundColor,
                codeFont: scaledChatCodeFont,
                codeBlockBackgroundColor: {
                    if syncCodeHighlightTheme {
                        if colorScheme == .light, let color = codeBackgroundColorLight.value {
                            return color.swiftUIColor
                        } else if let color = codeBackgroundColorDark.value {
                            return color.swiftUIColor
                        }
                    }

                    return Color(nsColor: .textBackgroundColor).opacity(0.7)
                }(),
                codeBlockLabelColor: {
                    if syncCodeHighlightTheme {
                        if colorScheme == .light,
                           let color = codeForegroundColorLight.value
                        {
                            return color.swiftUIColor.opacity(0.5)
                        } else if let color = codeForegroundColorDark.value {
                            return color.swiftUIColor.opacity(0.5)
                        }
                    }
                    return Color.secondary.opacity(0.7)
                }(),
                context: context
            ))
    }
}

// MARK: - Theme

extension MarkdownUI.Theme {
    static func custom(
        fontSize: Double,
        foregroundColor: Color,
        codeFont: NSFont,
        codeBlockBackgroundColor: Color,
        codeBlockLabelColor: Color,
        context: MarkdownActionProvider
    ) -> MarkdownUI.Theme {
        .gitHub.text {
            ForegroundColor(foregroundColor)
            BackgroundColor(Color.clear)
            FontSize(fontSize)
        }
        .codeBlock { configuration in
            MarkdownCodeBlockView(
                codeBlockConfiguration: configuration,
                codeFont: codeFont,
                codeBlockBackgroundColor: codeBlockBackgroundColor,
                codeBlockLabelColor: codeBlockLabelColor,
                context: context
            )
        }
    }
}

struct MarkdownCodeBlockView: View {
    let codeBlockConfiguration: CodeBlockConfiguration
    let codeFont: NSFont
    let codeBlockBackgroundColor: Color
    let codeBlockLabelColor: Color
    let context: MarkdownActionProvider
    
    var body: some View {
        let wrapCode = UserDefaults.shared.value(for: \.wrapCodeInChatCodeBlock)

        if wrapCode {
            AsyncCodeBlockView(
                fenceInfo: codeBlockConfiguration.language,
                content: codeBlockConfiguration.content,
                font: codeFont
            )
            .codeBlockLabelStyle()
            .codeBlockStyle(
                codeBlockConfiguration,
                backgroundColor: codeBlockBackgroundColor,
                labelColor: codeBlockLabelColor,
                context: context
            )
            // Force recreation when font size changes
            .id("code-block-\(codeFont.pointSize)")
        } else {
            ScrollView(.horizontal) {
                AsyncCodeBlockView(
                    fenceInfo: codeBlockConfiguration.language,
                    content: codeBlockConfiguration.content,
                    font: codeFont
                )
                .codeBlockLabelStyle()
            }
            .workaroundForVerticalScrollingBugInMacOS()
            .codeBlockStyle(
                codeBlockConfiguration,
                backgroundColor: codeBlockBackgroundColor,
                labelColor: codeBlockLabelColor,
                context: context
            )
            // Force recreation when font size changes
            .id("code-block-\(codeFont.pointSize)")
        }
    }
}

struct ThemedMarkdownText_Previews: PreviewProvider {
    static var previews: some View {
        let chatTabInfo = ChatTabInfo(id: "id", workspacePath: "path", username: "name")
        ThemedMarkdownText(
            text:"""
    ```swift
    let sumClosure: (Int, Int) -> Int = { (a: Int, b: Int) in
        return a + b
    }
    ```
    """,
            context: .init(onInsert: {_ in  print("Inserted") }))
    }
}
