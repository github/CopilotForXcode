import SwiftUI
import ConversationServiceProvider
import AppKitExtension

public struct CreateCustomCopilotFileView: View {
    public let promptType: PromptType
    public let editorPluginVersion: String
    public let getCurrentProjectURL: () async -> URL?
    public let onSuccess: (String) -> Void
    public let onError: (String) -> Void

    @State private var fileName = ""
    @State private var projectURL: URL?
    @State private var fileAlreadyExists = false

    @Environment(\.dismiss) private var dismiss

    public init(
        promptType: PromptType,
        editorPluginVersion: String,
        getCurrentProjectURL: @escaping () async -> URL?,
        onSuccess: @escaping (String) -> Void,
        onError: @escaping (String) -> Void
    ) {
        self.promptType = promptType
        self.editorPluginVersion = editorPluginVersion
        self.getCurrentProjectURL = getCurrentProjectURL
        self.onSuccess = onSuccess
        self.onError = onError
    }

    public var body: some View {
        Form {
            VStack(alignment: .center, spacing: 20) {
                HStack(alignment: .center) {
                    Spacer()
                    Text("Create \(promptType.displayName)").font(.headline)
                    Spacer()
                    AdaptiveHelpLink(action: openHelpLink)
                }

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    TextFieldsContainer {
                        TextField("File name", text: Binding(
                            get: { fileName },
                            set: { newValue in
                                fileName = newValue
                                updateFileExistence()
                            }
                        ))
                        .disableAutocorrection(true)
                        .textContentType(.none)
                        .onSubmit {
                            Task { await createPromptFile() }
                        }
                    }

                    validationMessageView
                }

                HStack(spacing: 8) {
                    Spacer()
                    Button("Cancel", role: .cancel) { dismiss() }
                    Button("Create") { Task { await createPromptFile() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(disableCreateButton)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .textFieldStyle(.plain)
            .multilineTextAlignment(.trailing)
            .padding(20)
        }
        .frame(width: 350, height: 190)
        .onAppear {
            fileName = ""
            Task { await resolveProjectURL() }
        }
    }

    // MARK: - Derived values

    private var trimmedFileName: String {
        fileName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var disableCreateButton: Bool {
        trimmedFileName.isEmpty || fileAlreadyExists
    }

    @ViewBuilder
    private var validationMessageView: some View {
        HStack(alignment: .center, spacing: 6) {
            if fileAlreadyExists && !trimmedFileName.isEmpty {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("'.github/\(promptType.directoryName)/\(trimmedFileName)\(promptType.fileExtension)' already exists")
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
            } else if trimmedFileName.isEmpty {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text("Enter the name of \(promptType.rawValue) file")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Location:")
                    .foregroundColor(.primary)
                    .padding(.leading, 10)
                    .layoutPriority(1)
                Text(".github/\(promptType.directoryName)/\(trimmedFileName)\(promptType.fileExtension)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Actions / Helpers

    private func openHelpLink() {
        if let url = URL(string: promptType.helpLink(editorPluginVersion: editorPluginVersion)) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Resolves the active project URL (if any) and updates state.
    private func resolveProjectURL() async {
        let projectURL = await getCurrentProjectURL()
        await MainActor.run {
            self.projectURL = projectURL
            updateFileExistence()
        }
    }

    private func updateFileExistence() {
        let name = trimmedFileName
        guard !name.isEmpty, let projectURL else {
            fileAlreadyExists = false
            return
        }
        let filePath = promptType.getFilePath(fileName: name, projectURL: projectURL)
        fileAlreadyExists = FileManager.default.fileExists(atPath: filePath.path)
    }

    /// Creates the prompt file if it doesn't already exist.
    private func createPromptFile() async {
        guard let projectURL else {
            await MainActor.run {
                onError("No active workspace found")
            }
            return
        }

        let directoryPath = promptType.getDirectoryPath(projectURL: projectURL)
        let filePath = promptType.getFilePath(fileName: trimmedFileName, projectURL: projectURL)

        // Re-check existence to avoid race with external creation.
        if FileManager.default.fileExists(atPath: filePath.path) {
            await MainActor.run {
                self.fileAlreadyExists = true
                onError("\(promptType.displayName) '\(trimmedFileName)\(promptType.fileExtension)' already exists")
            }
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: directoryPath,
                withIntermediateDirectories: true
            )

            try promptType.defaultTemplate.write(to: filePath, atomically: true, encoding: .utf8)

            await MainActor.run {
                onSuccess("Created \(promptType.rawValue) file '\(trimmedFileName)\(promptType.fileExtension)'")
                NSWorkspace.openFileInXcode(fileURL: filePath)
                dismiss()
            }
        } catch {
            await MainActor.run {
                onError("Failed to create \(promptType.rawValue) file: \(error)")
            }
        }
    }
}
