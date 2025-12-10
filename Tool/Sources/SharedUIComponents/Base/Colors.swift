import SwiftUI

public extension Color {
    static var hoverColor: Color { .gray.opacity(0.1) }
    
    static var chatWindowBackgroundColor: Color { Color("ChatWindowBackgroundColor") }
    
    static var successLightGreen: Color { Color("LightGreen") }
    
    static var agentToolStatusDividerColor: Color { Color("AgentToolStatusDividerColor") }
    
    static var agentToolStatusOutlineColor: Color { Color("AgentToolStatusOutlineColor") }
}

public var QuinarySystemFillColor: Color {
    if #available(macOS 14.0, *) {
        return Color(nsColor: .quinarySystemFill)
    } else {
        return Color("QuinarySystemFillColor")
    }
}

public var QuaternarySystemFillColor: Color {
    if #available(macOS 14.0, *) {
        return Color(nsColor: .quaternarySystemFill)
    } else {
        return Color("QuaternarySystemFillColor")
    }
}

public var TertiarySystemFillColor: Color {
    if #available(macOS 14.0, *) {
        return Color(nsColor: .tertiarySystemFill)
    } else {
        return Color("TertiarySystemFillColor")
    }
}

public var SecondarySystemFillColor: Color {
    if #available(macOS 14.0, *) {
        return Color(nsColor: .secondarySystemFill)
    } else {
        return Color("SecondarySystemFillColor")
    }
}
