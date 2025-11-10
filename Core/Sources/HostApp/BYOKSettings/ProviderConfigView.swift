import Client
import GitHubCopilotService
import Logger
import SharedUIComponents
import SwiftUI

struct ModelConfig: Identifiable {
    let id = UUID()
    var name: String
    var isSelected: Bool
}

struct BYOKProviderConfigView: View {
    let provider: BYOKProvider
    @ObservedObject var dataManager: BYOKModelManagerObservable
    let onSheetRequested: (BYOKSheetType) -> Void
    @Binding var isExpanded: Bool

    @State private var selectedModelId: String? = nil
    @State private var isSelectedCustomModel: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var isSearchBarVisible: Bool = false
    @State private var searchText: String = ""

    @Environment(\.colorScheme) var colorScheme

    private var hasApiKey: Bool { dataManager.hasApiKey(for: provider) }
    private var hasModels: Bool { dataManager.hasModels(for: provider) }
    private var allModels: [BYOKModelInfo] { dataManager.filteredModels(for: provider) }
    private var filteredModels: [BYOKModelInfo] {
        let base = allModels
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return base }
        return base.filter { model in
            let modelIdMatch = model.modelId.lowercased().contains(trimmed)
            let nameMatch = (model.modelCapabilities?.name ?? "").lowercased().contains(trimmed)
            return modelIdMatch || nameMatch
        }
    }

    private var isProviderEnabled: Bool { allModels.contains { $0.isRegistered } }
    private var errorMessage: String? { dataManager.errorMessages[provider] }
    private var deleteModelTooltip: String {
        if let selectedModelId = selectedModelId {
            if isSelectedCustomModel {
                return "Delete this model from the list."
            } else {
                return "\(allModels.first(where: { $0.modelId == selectedModelId })?.modelCapabilities?.name ?? selectedModelId) is the default model from \(provider.title) and can’t be removed."
            }
        }
        return "Select a model to delete."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ProviderHeaderRowView

            if hasApiKey && isExpanded {
                Group {
                    if !filteredModels.isEmpty {
                        ModelsListSection
                    } else if !allModels.isEmpty && !searchText.isEmpty {
                        VStack(spacing: 0) {
                            Divider()
                            Text("No models match \"\(searchText)\"")
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                        }
                    }
                }
                .padding(.vertical, 0)
                .background(QuaternarySystemFillColor.opacity(0.75))
                .transition(.opacity.combined(with: .scale(scale: 1, anchor: .top)))

                FooterToolBar
            }
        }
        .onChange(of: searchText) { _ in
            // Clear selection if filtered out
            if let selected = selectedModelId,
               !filteredModels.contains(where: { $0.modelId == selected }) {
                selectedModelId = nil
                isSelectedCustomModel = false
            }
        }
        .cornerRadius(12)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .inset(by: 0.5)
                .stroke(SecondarySystemFillColor, lineWidth: 1)
                .animation(.easeInOut(duration: 0.3), value: isExpanded)
        )
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }

    // MARK: - UI Components

    private var ProviderLabelView: some View {
        Text(provider.title)
            .foregroundColor(
                hasApiKey ? .primary : Color(
                    nsColor: colorScheme == .light ? .tertiaryLabelColor : .secondaryLabelColor
                )
            )
            .bold() +
            Text(hasModels ? " (\(allModels.filter { $0.isRegistered }.count) of \(allModels.count) Enabled)" : "")
            .foregroundColor(.primary)
    }

    private var ProviderHeaderRowView: some View {
        DisclosureSettingsRow(
            isExpanded: $isExpanded,
            isEnabled: hasApiKey,
            accessibilityLabel: { expanded in "\(provider.title) \(expanded ? "collapse" : "expand")" },
            onToggle: { wasExpanded, nowExpanded in
                if wasExpanded && !nowExpanded && isSearchBarVisible {
                    searchText = ""
                    withAnimation(.easeInOut) { isSearchBarVisible = false }
                }
            },
            title: { ProviderLabelView },
            actions: {
                Group {
                    if let errorMessage = errorMessage {
                        Badge(
                            text: "Can't connect. Check your API key or network.",
                            level: .danger,
                            icon: "xmark.circle.fill"
                        )
                        .help("Unable to connect to \(provider.title). \(errorMessage) Refresh or recheck your key setup.")
                    }
                    if hasApiKey {
                        if dataManager.isLoadingProvider(provider) {
                            ProgressView().controlSize(.small)
                        } else {
                            ConfiguredProviderActions
                        }
                    } else {
                        UnconfiguredProviderAction
                    }
                }
                .padding(.trailing, 4)
                .frame(height: 30)
            }
        )
    }

    @ViewBuilder
    private var ConfiguredProviderActions: some View {
        HStack(spacing: 8) {
            if provider.authType == .GlobalApiKey && isExpanded {
                CollapsibleSearchField(searchText: $searchText, isExpanded: $isSearchBarVisible)

                Button(action: { Task {
                    await dataManager.listModelsWithFetch(providerName: provider)
                }}) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: openAddApiKeySheetType) {
                    Image(systemName: "key")
                }
                .buttonStyle(HoverButtonStyle())

                Button(action: { showDeleteConfirmation = true }) {
                    Image(systemName: "trash")
                }
                .confirmationDialog(
                    "Delete \(provider.title) API Key?",
                    isPresented: $showDeleteConfirmation

                ) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) { deleteApiKey() }
                } message: {
                    Text("This will remove all linked models and configurations. Still want to delete it?")
                }
                .buttonStyle(HoverButtonStyle())
            }

            Toggle("", isOn: Binding(
                get: { isProviderEnabled },
                set: { newValue in updateAllModels(isRegistered: newValue) }
            ))
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
    }

    private var UnconfiguredProviderAction: some View {
        Button(
            provider.authType == .PerModelDeployment ? "Add Model" : "Add",
            systemImage: "plus"
        ) {
            openAddApiKeySheetType()
        }
    }

    private var ModelsListSection: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(filteredModels, id: \.modelId) { model in
                Divider()
                ModelRowView(
                    model: model,
                    dataManager: dataManager,
                    isSelected: selectedModelId == model.modelId,
                    onSelection: {
                        selectedModelId = selectedModelId == model.modelId ? nil : model.modelId
                        isSelectedCustomModel = selectedModelId != nil && model.isCustomModel
                    },
                    onEditRequested: { model in
                        openEditModelSheet(for: model)
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var FooterToolBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 8) {
                Button(action: openAddModelSheet) {
                    Image(systemName: "plus")
                }
                .foregroundColor(.primary)
                .font(.title2)
                .buttonStyle(.borderless)

                Divider()

                Group {
                    if isSelectedCustomModel {
                        Button(action: deleteSelectedModel) {
                            Image(systemName: "minus")
                        }
                        .buttonStyle(.borderless)
                    } else {
                        Image(systemName: "minus")
                    }
                }
                .font(.title2)
                .foregroundColor(
                    isSelectedCustomModel ? .primary : Color(
                        nsColor: .quaternaryLabelColor
                    )
                )
                .help(deleteModelTooltip)

                Spacer()
            }
            .frame(height: 20)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TertiarySystemFillColor)
        }
        .transition(.opacity.combined(with: .scale(scale: 1, anchor: .top)))
    }

    // MARK: - Actions

    private func openAddApiKeySheetType() {
        switch provider.authType {
        case .GlobalApiKey:
            onSheetRequested(.apiKey(provider))
        case .PerModelDeployment:
            onSheetRequested(.model(provider))
        }
    }

    private func openAddModelSheet() {
        onSheetRequested(.model(provider, nil)) // nil for adding new model
    }

    private func openEditModelSheet(for model: BYOKModelInfo) {
        onSheetRequested(.model(provider, model)) // pass model for editing
    }

    private func deleteApiKey() {
        Task {
            do {
                try await dataManager.deleteApiKey(providerName: provider)
            } catch {
                Logger.client.error("Failed to delete API key for \(provider.title): \(error)")
            }
        }
    }

    private func deleteSelectedModel() {
        guard let selectedModelId = selectedModelId,
              let selectedModel = allModels.first(where: { $0.modelId == selectedModelId }) else {
            return
        }

        self.selectedModelId = nil
        isSelectedCustomModel = false

        Task {
            do {
                try await dataManager.deleteModel(selectedModel)
            } catch {
                Logger.client.error("Failed to delete model for \(provider.title): \(error)")
            }
        }
    }

    private func updateAllModels(isRegistered: Bool) {
        Task {
            do {
                try await dataManager.updateAllModels(providerName: provider, isRegistered: isRegistered)
            } catch {
                Logger.client.error("Failed to register models for \(provider.title): \(error)")
            }
        }
    }
}
