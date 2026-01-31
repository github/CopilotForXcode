import Client
import ComposableArchitecture
import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let showHideWidget = Self("ShowHideWidget")
}

public enum TabIndex: Int, CaseIterable {
    case general = 0
    case advanced = 1
    case tools = 2
    case byok = 3
    
    var title: String {
        switch self {
        case .general: return "General"
        case .advanced: return "Advanced"
        case .tools: return "Tools"
        case .byok: return "Models"
        }
    }
    
    var image: String {
        switch self {
        case .general: return "CopilotLogo"
        case .advanced: return "gearshape.2.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .byok: return "Model"
        }
    }
    
    var isSystemImage: Bool {
        switch self {
        case .general, .byok: return false
        default: return true
        }
    }
}

public enum ToolsSubTab: String, CaseIterable, Identifiable {
    case MCP, BuiltIn, AutoApprove
    public var id: Self { self }
}

@Reducer
public struct HostApp {
    @ObservableState
    public struct State: Equatable {
        var general = General.State()
        public var activeTabIndex: TabIndex = .general
        public var activeToolsSubTab: ToolsSubTab = .MCP
    }

    public enum Action: Equatable {
        case appear
        case general(General.Action)
        case setActiveTab(TabIndex)
        case setActiveToolsSubTab(ToolsSubTab)
    }

    @Dependency(\.toast) var toast
    
    init() {
        KeyboardShortcuts.userDefaults = .shared
    }

    public var body: some ReducerOf<Self> {
        Scope(state: \.general, action: /Action.general) {
            General()
        }

        Reduce { state, action in
            switch action {
            case .appear:
                return .none

            case .general:
                return .none

            case .setActiveTab(let index):
                state.activeTabIndex = index
                return .none

            case .setActiveToolsSubTab(let tab):
                state.activeToolsSubTab = tab
                return .none
            }
        }
    }
}

import Dependencies
import Preferences

struct UserDefaultsDependencyKey: DependencyKey {
    static var liveValue: UserDefaultsType = UserDefaults.shared
    static var previewValue: UserDefaultsType = {
        let it = UserDefaults(suiteName: "HostAppPreview")!
        it.removePersistentDomain(forName: "HostAppPreview")
        return it
    }()

    static var testValue: UserDefaultsType = {
        let it = UserDefaults(suiteName: "HostAppTest")!
        it.removePersistentDomain(forName: "HostAppTest")
        return it
    }()
}

extension DependencyValues {
    var userDefaults: UserDefaultsType {
        get { self[UserDefaultsDependencyKey.self] }
        set { self[UserDefaultsDependencyKey.self] = newValue }
    }
}
