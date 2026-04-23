import ComposableArchitecture
import Dependencies
import Foundation
import LaunchAgentManager
import SwiftUI
import Toast
import UpdateChecker
import Client
import Logger
import Combine

@MainActor
public let hostAppStore: StoreOf<HostApp> = .init(initialState: .init(), reducer: { HostApp() })

public struct TabContainer: View {
    let store: StoreOf<HostApp>
    @ObservedObject var toastController: ToastController
    @ObservedObject private var featureFlags = FeatureFlagManager.shared
    @State private var tabBarItems = [TabBarItem]()
    @Binding var tag: TabIndex

    public init() {
        toastController = ToastControllerDependencyKey.liveValue
        store = hostAppStore
        _tag = Binding(
            get: { hostAppStore.state.activeTabIndex },
            set: { hostAppStore.send(.setActiveTab($0)) }
        )
    }

    init(store: StoreOf<HostApp>, toastController: ToastController) {
        self.store = store
        self.toastController = toastController
        _tag = Binding(
            get: { store.state.activeTabIndex },
            set: { store.send(.setActiveTab($0)) }
        )
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 0) {
                TabBar(tag: $tag, tabBarItems: tabBarItems)
                    .padding(.bottom, 8)
                ZStack(alignment: .center) {
                    GeneralView(store: store.scope(state: \.general, action: \.general)).tabBarItem(for: .general)
                    AdvancedSettings().tabBarItem(for: .advanced)
                    if featureFlags.isAgentModeEnabled {
                        MCPConfigView().tabBarItem(for: .tools)
                    }
                    if featureFlags.isBYOKEnabled {
                        BYOKConfigView().tabBarItem(for: .byok)
                    }
                }
                .environment(\.tabBarTabTag, tag)
                .frame(minHeight: 400)
            }
            .focusable(false)
            .padding(.top, 8)
            .background(Color(nsColor: .controlBackgroundColor))
            .handleToast()
            .onPreferenceChange(TabBarItemPreferenceKey.self) { items in
                tabBarItems = items
            }
            .onAppear {
                store.send(.appear)
            }
            .onChange(of: featureFlags.isAgentModeEnabled) { isEnabled in
                if hostAppStore.state.activeTabIndex == .tools && !isEnabled {
                    hostAppStore.send(.setActiveTab(.general))
                }
            }
            .onChange(of: featureFlags.isBYOKEnabled) { isEnabled in
                if hostAppStore.state.activeTabIndex == .byok && !isEnabled {
                    hostAppStore.send(.setActiveTab(.general))
                }
            }
        }
    }
}

struct TabBar: View {
    @Binding var tag: TabIndex
    fileprivate var tabBarItems: [TabBarItem]

    var body: some View {
        HStack {
            ForEach(tabBarItems) { tab in
                TabBarButton(
                    currentTag: $tag,
                    tag: tab.tag,
                    title: tab.title,
                    image: tab.image,
                    isSystemImage: tab.isSystemImage
                )
            }
        }
    }
}

struct TabBarButton: View {
    @Binding var currentTag: TabIndex
    @State var isHovered = false
    var tag: TabIndex
    var title: String
    var image: String
    var isSystemImage: Bool = true
    
    private var tabImage: Image {
        isSystemImage ? Image(systemName: image) : Image(image)
    }

    private var isSelected: Bool {
        tag == currentTag
    }

    var body: some View {
        Button(action: {
            self.currentTag = tag
        }) {
            VStack(spacing: 2) {
                tabImage
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                Text(title)
            }
            .foregroundColor(isSelected ? .blue : .gray)
            .font(.body)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .padding(.top, 4)
            .background(
                isSelected
                    ? Color(nsColor: .textColor).opacity(0.1)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .background(
                isHovered
                    ? Color(nsColor: .textColor).opacity(0.05)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .onHover(perform: { yes in
            isHovered = yes
        })
        .buttonStyle(.borderless)
    }
}

private struct TabBarTabViewWrapper<Content: View>: View {
    @Environment(\.tabBarTabTag) var tabBarTabTag
    var tag: TabIndex
    var title: String
    var image: String
    var isSystemImage: Bool = true
    var content: () -> Content

    var body: some View {
        Group {
            if tag == tabBarTabTag {
                content()
            } else {
                Color.clear
            }
        }
        .preference(
            key: TabBarItemPreferenceKey.self,
            value: [.init(tag: tag, title: title, image: image, isSystemImage: isSystemImage)]
        )
    }
}

private extension View {
    func tabBarItem(for tag: TabIndex) -> some View {
        TabBarTabViewWrapper(
            tag: tag,
            title: tag.title,
            image: tag.image,
            isSystemImage: tag.isSystemImage,
            content: { self }
        )
    }
}

private struct TabBarItem: Identifiable, Equatable {
    var id: TabIndex { tag }
    var tag: TabIndex
    var title: String
    var image: String
    var isSystemImage: Bool = true
}

private struct TabBarItemPreferenceKey: PreferenceKey {
    static var defaultValue: [TabBarItem] = []
    static func reduce(value: inout [TabBarItem], nextValue: () -> [TabBarItem]) {
        value.append(contentsOf: nextValue())
    }
}

private struct TabBarTabTagKey: EnvironmentKey {
    static var defaultValue: TabIndex = .general
}

private extension EnvironmentValues {
    var tabBarTabTag: TabIndex {
        get { self[TabBarTabTagKey.self] }
        set { self[TabBarTabTagKey.self] = newValue }
    }
}

struct UpdateCheckerKey: EnvironmentKey {
    static var defaultValue: UpdateCheckerProtocol = NoopUpdateChecker()
}

public extension EnvironmentValues {
    var updateChecker: UpdateCheckerProtocol {
        get { self[UpdateCheckerKey.self] }
        set { self[UpdateCheckerKey.self] = newValue }
    }
}

// MARK: - Previews

struct TabContainer_Previews: PreviewProvider {
    static var previews: some View {
        TabContainer()
            .frame(width: 800)
    }
}

struct TabContainer_Toasts_Previews: PreviewProvider {
    static var previews: some View {
        TabContainer(
            store: .init(initialState: .init(), reducer: { HostApp() }),
            toastController: .init(messages: [
                .init(id: UUID(), level: .info, content: Text("info")),
                .init(id: UUID(), level: .error, content: Text("error")),
                .init(id: UUID(), level: .warning, content: Text("warning")),
            ])
        )
        .frame(width: 800)
    }
}

@available(macOS 14.0, *)
@MainActor
public struct SettingsEnvironment: View {
    @Environment(\.openSettings) public var openSettings: OpenSettingsAction
    
    public init() {}
    
    public var body: some View {
        EmptyView().onAppear {
            openSettings()
        }
    }
    
    public func open() {
        let controller = NSHostingController(rootView: self)
        let window = NSWindow(contentViewController: controller)
        window.orderFront(nil)
        // Close the temporary window after settings are opened
        DispatchQueue.main.async {
            window.close()
        }
    }
}
