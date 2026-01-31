import SwiftUI

extension View {
    @ViewBuilder
    func transparentBackground() -> some View {
        if #available(macOS 14.0, *) {
            self.scrollContentBackground(.hidden).alternatingRowBackgrounds(.disabled)
        } else {
            self
        }
    }
}
