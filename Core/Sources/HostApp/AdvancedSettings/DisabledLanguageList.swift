import SuggestionBasic
import SwiftUI
import SharedUIComponents

extension List {
    @ViewBuilder
    func removeBackground() -> some View {
        scrollContentBackground(.hidden)
            .listRowBackground(EmptyView())
    }
}

struct DisabledLanguageList: View {
    final class Settings: ObservableObject {
        @AppStorage(\.suggestionFeatureDisabledLanguageList)
        var suggestionFeatureDisabledLanguageList: [String]

        init(suggestionFeatureDisabledLanguageList: AppStorage<[String]>? = nil) {
            if let list = suggestionFeatureDisabledLanguageList {
                _suggestionFeatureDisabledLanguageList = list
            }
        }
    }

    var isOpen: Binding<Bool>
    @State var isAddingNewProject = false
    @StateObject var settings = Settings()

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(nsColor: .separatorColor)).frame(height: 28)
 
                HStack {
                    Button(action: {
                        self.isOpen.wrappedValue = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    .buttonStyle(.plain)
                    Text("Disabled Languages")
                        .font(.system(size: 13, weight: .bold))
                    Spacer()
                }
                .frame(height: 28)
            }

            List {
                ForEach(
                    settings.suggestionFeatureDisabledLanguageList,
                    id: \.self
                ) { language in
                    HStack {
                        Text(language.capitalized)
                            .contextMenu {
                                Button("Remove") {
                                    settings.suggestionFeatureDisabledLanguageList.removeAll(
                                        where: { $0 == language }
                                    )
                                }
                            }
                        Spacer()

                        Button(action: {
                            settings.suggestionFeatureDisabledLanguageList.removeAll(
                                where: { $0 == language }
                            )
                        }) {
                            Image(systemName: "trash.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .modify { view in
                    view.listRowSeparator(.hidden).listSectionSeparator(.hidden)
                }
            }
            .removeBackground()
            .overlay {
                if settings.suggestionFeatureDisabledLanguageList.isEmpty {
                    Text("""
                    Empty
                    Disable the language of a file from the Copilot menu in the status bar.
                    """)
                    .multilineTextAlignment(.center)
                    .padding()
                }
            }
        }
        .focusable(false)
        .frame(width: 300, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    DisabledLanguageList(
        isOpen: .constant(true),
        settings: .init(suggestionFeatureDisabledLanguageList: .init(wrappedValue: [
            "hello/2",
            "hello/3",
            "hello/4",
        ], "SuggestionFeatureDisabledLanguageListView_Preview"))
    )
}


