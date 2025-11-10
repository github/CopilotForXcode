import SwiftUI
import SharedUIComponents

public struct DisclosureSettingsRow<Title: View, Subtitle: View, Actions: View>: View {
    @Binding private var isExpanded: Bool
    private let isEnabled: Bool
    private let background: Color
    private let padding: EdgeInsets
    private let spacing: CGFloat
    private let accessibilityLabel: (Bool) -> String
    private let onToggle: ((Bool, Bool) -> Void)?
    @ViewBuilder private let title: () -> Title
    @ViewBuilder private let subtitle: () -> Subtitle
    @ViewBuilder private let actions: () -> Actions

    public init(
        isExpanded: Binding<Bool>,
        isEnabled: Bool = true,
        background: Color = QuaternarySystemFillColor.opacity(0.75),
        padding: EdgeInsets = EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20),
        spacing: CGFloat = 16,
        accessibilityLabel: @escaping (Bool) -> String = { expanded in expanded ? "collapse" : "expand" },
        onToggle: ((Bool, Bool) -> Void)? = nil,
        @ViewBuilder title: @escaping () -> Title,
        @ViewBuilder subtitle: @escaping (() -> Subtitle) = { EmptyView() },
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        _isExpanded = isExpanded
        self.isEnabled = isEnabled
        self.background = background
        self.padding = padding
        self.spacing = spacing
        self.accessibilityLabel = accessibilityLabel
        self.onToggle = onToggle
        self.title = title
        self.subtitle = subtitle
        self.actions = actions
    }

    public var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.footnote.bold())
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.3), value: isExpanded)
                        .opacity(isEnabled ? 1 : 0)
                        .allowsHitTesting(isEnabled)
                    title()
                }
                .padding(.vertical, 4)

                subtitle()
                    .padding(.leading, 16)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
            actions()
        }
        .padding(padding)
        .background(background)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEnabled else { return }
            let previous = isExpanded
            withAnimation(.easeInOut) {
                isExpanded.toggle()
            }
            onToggle?(previous, isExpanded)
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabel(isExpanded))
    }
}
