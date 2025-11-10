import SwiftUI

struct SettingsToggle: View {
    static let defaultPadding: CGFloat = 10
    
    let title: String
    let subtitle: String?
    let isOn: Binding<Bool>
    let badge: BadgeItem?

    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>, badge: BadgeItem? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.isOn = isOn
        self.badge = badge
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading) {
                HStack(spacing: 6) {
                    Text(title).font(.body)
                    
                    if let badge = badge {
                        Badge(badgeItem: badge)
                            .allowsHitTesting(true)
                    }
                }
                
                if let subtitle = subtitle {
                    Text(subtitle).font(.footnote)
                }
            }
            Spacer()
            Toggle(isOn: isOn) {}
                .controlSize(.mini)
                .toggleStyle(.switch)
                .padding(.vertical, 4)
        }
        .padding(SettingsToggle.defaultPadding)
    }
}

#Preview {
    SettingsToggle(title: "Test", isOn: .constant(true))
}
