import SwiftUI
import ComposableArchitecture
import Logger

struct NESNotificationView: View {
    let store: StoreOf<NESSuggestionPanelFeature>
    
    init(store: StoreOf<NESSuggestionPanelFeature>) {
        self.store = store
    }
    
    var body: some View {
        WithPerceptionTracking {
            if store.isPanelOutOfFrame,
               !store.closeNotificationByUser,
               store.nesContent != nil {
                
                let fontSize = store.lineFontSize
                let scale = store.fontSizeScale
                
                HStack(spacing: 8) {
                    Image("EditSparkle")
                        .resizable()
                        .scaledToFit()
                        .font(.system(size: calcImageFontSize(fontSize, scale), weight: .medium))
                    
                    HStack(spacing: 4 * scale) {
                        Text("Press")
                        
                        Text("Tab")
                            .foregroundStyle(.secondary)
                        
                        Text("to jump to Next Edit Suggestion")
                    }
                    .font(.system(size: fontSize, weight: .medium))
                    
                    Button(action: {
                        store.send(.onUserCloseNotification)
                    }) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: calcImageFontSize(fontSize, scale), weight: .medium))
                }
                .foregroundStyle(Color(NSColor.controlBackgroundColor))
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.primary)
                )
                .shadow(
                    color: Color("NESShadowColor"),
                    radius: 12,
                    x: 0,
                    y: 3
                )
                .opacity(store.notificationViewOpacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    func calcImageFontSize(_ baseFontSize: CGFloat, _ scale: Double) -> CGFloat {
        return baseFontSize + 2 * scale
    }
}
