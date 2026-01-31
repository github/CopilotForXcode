import SwiftUI
import SharedUIComponents

extension View {
    func settingsContainerStyle(isExpanded: Bool) -> some View {
        self
            .cornerRadius(12)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .inset(by: 0.5)
                    .stroke(SecondarySystemFillColor, lineWidth: 1)
                    .animation(.easeInOut(duration: 0.3), value: isExpanded)
            )
            .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
}
