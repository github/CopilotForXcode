import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
public struct NESSuggestionPanelFeature {
    @ObservableState
    public struct State: Equatable {
        static let baseFontSize: CGFloat = 13
        static let defaultLineHeight: Double = 18
        
        var nesContent: NESCodeSuggestionProvider? {
            didSet { closeNotificationByUser = false }
        }
        var colorScheme: ColorScheme = .light
        var firstLineIndent: Double = 0
        var lineHeight: Double = Self.defaultLineHeight
        var lineFontSize: Double {
            Self.baseFontSize * fontSizeScale
        }
        var isPanelDisplayed: Bool = false
        public var isPanelOutOfFrame: Bool = false
        var closeNotificationByUser: Bool = false
        // TODO: handle warnings
        //        var warningMessage: String?
        //        var warningURL: String?
        var opacity: Double {
            guard isPanelDisplayed else { return 0 }
            if isPanelOutOfFrame { return 0 }
            guard nesContent != nil else { return 0 }
            return 1
        }
        var menuViewOpacity: Double {
            guard nesContent != nil else { return 0 }
            guard isPanelDisplayed else { return 0 }
            return isPanelOutOfFrame ? 0 : 1
        }
        var diffViewOpacity: Double { menuViewOpacity }
        var notificationViewOpacity: Double {
            guard nesContent != nil else { return 0 }
            guard isPanelDisplayed else { return 0 }
            return isPanelOutOfFrame ? 1 : 0
        }
        var fontSizeScale: Double {
            (lineHeight / Self.defaultLineHeight * 100).rounded() / 100
        }
    }
    
    public enum Action: Equatable {
        case onUserCloseNotification
    }
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onUserCloseNotification:
                state.closeNotificationByUser = true
                return .none
            }
        }
    }
}
