import SwiftUI

public struct ConditionalFontWeight: ViewModifier {
    let weight: Font.Weight?

    public init(weight: Font.Weight?) {
        self.weight = weight
    }

    public func body(content: Content) -> some View {
        content.fontWeight(weight)
    }
}

public extension View {
    func conditionalFontWeight(_ weight: Font.Weight?) -> some View {
        self.modifier(ConditionalFontWeight(weight: weight))
    }
}
