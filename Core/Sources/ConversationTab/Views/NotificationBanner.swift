import SwiftUI
import SharedUIComponents

public enum BannerStyle { 
    case warning
    
    var iconName: String {
        switch self {
        case .warning: return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .warning: return .orange
        }
    }
}

struct NotificationBanner<Content: View>: View {
    var style: BannerStyle
    @ViewBuilder var content: () -> Content
    @AppStorage(\.chatFontSize) var chatFontSize
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: style.iconName)
                    .foregroundColor(style.color)
                
                VStack(alignment: .leading, spacing: 8) {
                    content()
                }
            }
            .scaledFont(size: chatFontSize - 1)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .scaledPadding(.vertical, 10)
        .scaledPadding(.horizontal, 12)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
    }
}
