import SwiftUI
import SharedUIComponents

public struct CardGroupBoxStyle: GroupBoxStyle {
    public var backgroundColor: Color
    public var borderColor: Color
    public init(
        backgroundColor: Color = QuaternarySystemFillColor.opacity(0.75),
        borderColor: Color = SecondarySystemFillColor
    ) {
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
    }
    public func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            configuration.label.foregroundColor(.primary)
            configuration.content.foregroundColor(.primary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .inset(by: 0.5)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}
