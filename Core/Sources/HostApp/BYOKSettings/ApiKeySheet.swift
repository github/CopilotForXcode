import GitHubCopilotService
import SwiftUI
import SharedUIComponents

struct ApiKeySheet: View {
    @ObservedObject var dataManager: BYOKModelManagerObservable
    @Environment(\.dismiss) private var dismiss

    @State private var apiKey = ""
    @State private var showDeleteConfirmation = false
    @State private var showPopOver = false
    @State private var keepCustomModels = true
    let provider: BYOKProvider

    private var hasExistingApiKey: Bool {
        dataManager.hasApiKey(for: provider)
    }

    private var isFormInvalid: Bool {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            VStack(alignment: .center, spacing: 20) {
                HStack(alignment: .center) {
                    Spacer()
                    Text("\(provider.title)").font(.headline)
                    Spacer()
                    AdaptiveHelpLink(action: openHelpLink)
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextFieldsContainer {
                        SecureField("API Key", text: $apiKey)
                    }

                    if hasExistingApiKey {
                        HStack(spacing: 8) {
                            Toggle("Keep Custom Models", isOn: $keepCustomModels)
                                .toggleStyle(CheckboxToggleStyle())

                            Button(action: {}) {
                                Image(systemName: "questionmark.circle")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.primary)
                            .onHover { hovering in
                                showPopOver = hovering
                            }
                            .popover(isPresented: $showPopOver, arrowEdge: .bottom) {
                                Text("Retains custom models \nafter API key updates.")
                                    .multilineTextAlignment(.leading)
                                    .padding(4)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                }

                HStack(spacing: 8) {
                    if hasExistingApiKey {
                        Button("Delete", role: .destructive) {
                            showDeleteConfirmation = true
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
                    }

                    Spacer()
                    Button("Cancel", role: .cancel) { dismiss() }
                    Button(hasExistingApiKey ? "Update" : "Add") { updateApiKey() }
                        .buttonStyle(.borderedProminent)
                        .disabled(isFormInvalid)
                }
            }
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .padding(20)
        }
        .onAppear {
            loadExistingApiKey()
        }
    }

    private func loadExistingApiKey() {
        apiKey = dataManager.filteredApiKeys(for: provider).first?.apiKey ?? ""
    }

    private func updateApiKey() {
        Task {
            do {
                let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

                var savedCustomModels: [BYOKModelInfo] = []

                // If updating an existing API key and keeping custom models, save them first
                if hasExistingApiKey && keepCustomModels {
                    savedCustomModels = dataManager.filteredModels(for: provider)
                        .filter { $0.isCustomModel }
                }

                // For updates, delete the original API key first
                if hasExistingApiKey {
                    try await dataManager.deleteApiKey(providerName: provider)
                }

                // Save the new API key
                try await dataManager.saveApiKey(trimmedApiKey, providerName: provider)

                // If we saved custom models and should keep them, restore them
                if hasExistingApiKey && keepCustomModels && !savedCustomModels.isEmpty {
                    for customModel in savedCustomModels {
                        // Restore the custom model with the same properties
                        try await dataManager.saveModel(customModel)
                    }
                }

                dismiss()

                // Fetch default models from the provider
                await dataManager.listModelsWithFetch(providerName: provider)
            } catch {
                // Error is already handled in dataManager methods
                // The error message will be displayed in the provider view
            }
        }
    }

    private func deleteApiKey() {
        Task {
            do {
                try await dataManager.deleteApiKey(providerName: provider)
                dismiss()
            } catch {
                // Error handling could be improved here, but keeping it simple for now
                // The error will be reflected in the UI when the sheet dismisses
            }
        }
    }

    private func openHelpLink() {
        NSWorkspace.shared.open(URL(string: BYOKHelpLink)!)
    }
}
