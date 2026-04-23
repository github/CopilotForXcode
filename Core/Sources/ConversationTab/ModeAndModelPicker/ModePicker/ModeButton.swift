import SwiftUI
import SharedUIComponents

public struct ModeButton: View {
    let title: String
    let isSelected: Bool
    let activeBackground: Color
    let activeTextColor: Color
    let inactiveTextColor: Color
    let action: () -> Void
    
    public var body: some View {
        Button(action: action) {
            Text(title)
                .scaledFont(size: 12)
                .scaledPadding(.horizontal, 6)
                .scaledPadding(.vertical, 2)
                .frame(maxHeight: .infinity, alignment: .center)
                .background(isSelected ? activeBackground : Color.clear)
                .foregroundColor(isSelected ? activeTextColor : inactiveTextColor)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 0.375, x: 0, y: 1)
                .shadow(color: .black.opacity(0.15), radius: 0.125, x: 0, y: 0.25)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                    .inset(by: -0.25)
                    .stroke(.black.opacity(0.02), lineWidth: 0.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
