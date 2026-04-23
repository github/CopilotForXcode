import GitHubCopilotService
import SwiftUI
import SharedUIComponents

struct ModelSheet: View {
    @ObservedObject var dataManager: BYOKModelManagerObservable
    @Environment(\.dismiss) private var dismiss

    @State private var modelId = ""
    @State private var deploymentUrl = ""
    @State private var apiKey = ""
    @State private var customModelName = ""
    @State private var supportToolCalling: Bool = true
    @State private var supportVision: Bool = true

    let provider: BYOKProvider
    let existingModel: BYOKModelInfo?
    
    // Computed property to determine if this is a per-model deployment provider
    private var isPerModelDeployment: Bool {
        provider.authType == .PerModelDeployment
    }
    
    // Computed property to determine if we're editing vs adding
    private var isEditing: Bool {
        existingModel != nil
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

                VStack(alignment: .leading, spacing: 8) {
                    // Deployment/Model Name Section
                    TextFieldsContainer {
                        TextField(isPerModelDeployment ? "Deployment Name" : "Model ID", text: $modelId)
                    }

                    // Endpoint Section (only for per-model deployment)
                    if isPerModelDeployment {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Endpoint")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                                .padding(.horizontal, 8)

                            TextFieldsContainer {
                                TextField("Target URI", text: $deploymentUrl)

                                Divider()

                                SecureField("API Key", text: $apiKey)
                            }
                        }
                    }

                    // Optional Section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optional")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                            .padding(.horizontal, 8)

                        TextFieldsContainer {
                            TextField("Display Name", text: $customModelName)
                        }

                        HStack(spacing: 16) {
                            Toggle("Support Tool Calling", isOn: $supportToolCalling)
                                .toggleStyle(CheckboxToggleStyle())
                            Toggle("Support Vision", isOn: $supportVision)
                                .toggleStyle(CheckboxToggleStyle())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                    }
                }

                HStack(spacing: 8) {
                    Spacer()
                    Button("Cancel") { dismiss() }.buttonStyle(.bordered)
                    Button(isEditing ? "Save" : "Add") { saveModel() }
                        .buttonStyle(.borderedProminent)
                        .disabled(isFormInvalid)
                }
            }
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .padding(20)
        }
        .onAppear {
            loadModelData()
        }
    }

    private var isFormInvalid: Bool {
        let modelIdEmpty = modelId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        if isPerModelDeployment {
            let deploymentUrlEmpty = deploymentUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let apiKeyEmpty = apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return modelIdEmpty || deploymentUrlEmpty || apiKeyEmpty
        } else {
            return modelIdEmpty
        }
    }
    
    private func loadModelData() {
        guard let model = existingModel else { return }
        
        modelId = model.modelId
        customModelName = model.modelCapabilities?.name ?? ""
        supportToolCalling = model.modelCapabilities?.toolCalling ?? true
        supportVision = model.modelCapabilities?.vision ?? true
        
        if isPerModelDeployment {
            deploymentUrl = model.deploymentUrl ?? ""
            apiKey = dataManager
                .filteredApiKeys(
                    for: provider,
                    modelId: modelId
                ).first?.apiKey ?? ""
        }
    }

    private func saveModel() {
        Task {
            do {
                // Trim whitespace and newlines from all input fields
                let trimmedModelId = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedDeploymentUrl = deploymentUrl.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedApiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedCustomModelName = customModelName.trimmingCharacters(in: .whitespacesAndNewlines)

                let modelParams = BYOKModelInfo(
                    providerName: provider,
                    modelId: trimmedModelId,
                    isRegistered: existingModel?.isRegistered ?? true,
                    isCustomModel: true,
                    deploymentUrl: isPerModelDeployment ? trimmedDeploymentUrl : nil,
                    apiKey: isPerModelDeployment ? trimmedApiKey : nil,
                    modelCapabilities: BYOKModelCapabilities(
                        name: trimmedCustomModelName.isEmpty ? trimmedModelId : trimmedCustomModelName,
                        toolCalling: supportToolCalling,
                        vision: supportVision
                    )
                )
                
                if let originalModel = existingModel, trimmedModelId != originalModel.modelId {
                    // Delete existing model if the model ID has changed
                    try await dataManager.deleteModel(originalModel)
                }

                try await dataManager.saveModel(modelParams)
                dismiss()
            } catch {
                dataManager.errorMessages[provider] = "Failed to \(isEditing ? "update" : "add") model: \(error.localizedDescription)"
            }
        }
    }

    private func openHelpLink() {
        NSWorkspace.shared.open(URL(string: BYOKHelpLink)!)
    }
}
