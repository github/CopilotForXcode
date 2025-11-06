import ComposableArchitecture
import SwiftUI
import Foundation
import SharedUIComponents
import XcodeInspector
import Logger

struct NESMenuView: View {
    let store: StoreOf<NESSuggestionPanelFeature>
    
    @State private var menuController: NESMenuController
    
    init(store: StoreOf<NESSuggestionPanelFeature>) {
        self.store = store
        self._menuController = State(
            initialValue: NESMenuController(
                fontSize: store.lineFontSize,
                fontSizeScale: store.fontSizeScale,
                store: store
            )
        )
    }
    
    var body: some View {
        WithPerceptionTracking {
            let lineHeight = store.lineHeight
            let fontSizeScale = store.fontSizeScale
            let fontSize = store.lineFontSize
            if store.isPanelDisplayed && !store.isPanelOutOfFrame && store.nesContent != nil {
                NESMenuButtonView(
                    menuController: menuController,
                    fontSize: fontSize
                )
                .id("nes-menu-button")
                .frame(width: lineHeight, height: calcMenuHeight(by: lineHeight))
                .padding(.horizontal, 3 * fontSizeScale)
                .padding(.leading, 1 * fontSizeScale)
                .padding(.vertical, 3 * fontSizeScale)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color("LightBluePrimary"))
                )
                .opacity(store.menuViewOpacity)
                .onChange(of: store.lineFontSize) {
                    menuController.fontSize = $0
                }
                .onChange(of: store.fontSizeScale) {
                    menuController.fontSizeScale = $0
                }
            }
        }
    }
    
    private func calcMenuHeight(by lineHeight: Double) -> Double {
        return (lineHeight * 2 / 3 * 100).rounded() / 100
    }
}
