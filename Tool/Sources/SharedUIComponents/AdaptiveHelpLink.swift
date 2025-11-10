import SwiftUI

/// A small adaptive help link button that uses the native `HelpLink` on macOS 14+
/// and falls back to a styled question-mark button on earlier versions.
public struct AdaptiveHelpLink: View {
    let action: () -> Void
    var controlSize: ControlSize = .small
    
    public init(controlSize: ControlSize = .small, action: @escaping () -> Void) {
        self.controlSize = controlSize
        self.action = action
    }
    
    public var body: some View {
        Group {
            if #available(macOS 14.0, *) {
                HelpLink(action: action)
            } else {
                Button(action: action) {
                    Image(systemName: "questionmark")
                }
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.05), radius: 0, x: 0, y: 0)
                .shadow(color: .black.opacity(0.3), radius: 1.25, x: 0, y: 0.5)
            }
        }
        .controlSize(controlSize)
    }
}
