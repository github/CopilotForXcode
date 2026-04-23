import SwiftUI

struct SuggestionSection: View {
    @AppStorage(\.realtimeSuggestionToggle) var realtimeSuggestionToggle
    @AppStorage(\.suggestionFeatureEnabledProjectList) var suggestionFeatureEnabledProjectList
    @AppStorage(\.acceptSuggestionWithTab) var acceptSuggestionWithTab
    @AppStorage(\.realtimeNESToggle) var realtimeNESToggle
    @State var isSuggestionFeatureDisabledLanguageListViewOpen = false
    @State private var shouldPresentTurnoffSheet = false
    @ObservedObject private var featureFlags = FeatureFlagManager.shared

    var realtimeSuggestionBinding : Binding<Bool> {
        Binding(
            get: { realtimeSuggestionToggle },
            set: {
                if !$0 {
                    shouldPresentTurnoffSheet = true
                } else {
                    realtimeSuggestionToggle = $0
                }
            }
        )
    }

    var body: some View {
        SettingsSection(title: "Suggestion Settings") {
            SettingsToggle(
                title: "Enable completions while typing",
                isOn: realtimeSuggestionBinding
            )
            
            if featureFlags.isEditorPreviewEnabled {
                Divider()
                SettingsToggle(
                    title: "Enable Next Edit Suggestions (NES)",
                    isOn: $realtimeNESToggle
                )
            }
            
            Divider()
            SettingsToggle(
                title: "Accept suggestions with Tab",
                isOn: $acceptSuggestionWithTab
            )
        } footer: {
            HStack {
                Spacer()
                Button("Disabled language list") {
                    isSuggestionFeatureDisabledLanguageListViewOpen = true
                }
            }
        }
        .sheet(isPresented: $isSuggestionFeatureDisabledLanguageListViewOpen) {
            DisabledLanguageList(isOpen: $isSuggestionFeatureDisabledLanguageListViewOpen)
        }
        .alert(
            "Disable suggestions while typing",
            isPresented: $shouldPresentTurnoffSheet
        ) {
            Button("Disable") { realtimeSuggestionToggle = false }
            Button("Cancel", role: .cancel, action: {})
        } message: {
            Text("""
                If you disable requesting suggestions while typing, you will \
                not see any suggestions until requested manually.
                """)
        }
    }
}

#Preview {
    SuggestionSection()
}
