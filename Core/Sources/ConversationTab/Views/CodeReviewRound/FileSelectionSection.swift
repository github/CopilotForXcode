import ComposableArchitecture
import ConversationServiceProvider
import LanguageServerProtocol
import SharedUIComponents
import SwiftUI

// MARK: - File Selection Section

struct FileSelectionSection: View {
    let store: StoreOf<Chat>
    let round: CodeReviewRound
    let changedFileUris: [DocumentUri]
    @Binding var selectedFileUris: [DocumentUri]
    @AppStorage(\.chatFontSize) private var chatFontSize
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FileSelectionHeader(fileCount: selectedFileUris.count)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            FileSelectionList(
                store: store,
                fileUris: changedFileUris,
                reviewStatus: round.status,
                selectedFileUris: $selectedFileUris
            )
            
            if round.status == .waitForConfirmation {
                FileSelectionActions(
                    store: store,
                    roundId: round.id,
                    selectedFileUris: selectedFileUris
                )
            }
        }
        .padding(12)
        .background(CodeReviewCardBackground())
    }
}

// MARK: - File Selection Components

private struct FileSelectionHeader: View {
    let fileCount: Int
    @AppStorage(\.chatFontSize) private var chatFontSize
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image("codeReview")
                .resizable()
                .scaledToFit()
                .scaledFrame(width: 16, height: 16)
            
            Text("You’ve selected following \(fileCount) file(s) with code changes. Review them or unselect any files you don't need, then click Continue.")
                .scaledFont(.system(size: chatFontSize))
                .multilineTextAlignment(.leading)
        }
    }
}

private struct FileSelectionActions: View {
    let store: StoreOf<Chat>
    let roundId: String
    let selectedFileUris: [DocumentUri]
    
    var body: some View {
        HStack(spacing: 4) {
            Button("Cancel") {
                store.send(.codeReview(.cancel(id: roundId)))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .scaledFont(.body)
            
            Button("Continue") {
                store.send(.codeReview(.accept(id: roundId, selectedFiles: selectedFileUris)))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .scaledFont(.body)
        }
    }
}

// MARK: - File Selection List

private struct FileSelectionList: View {
    let store: StoreOf<Chat>
    let fileUris: [DocumentUri]
    let reviewStatus: CodeReviewRound.Status
    @State private var isExpanded = false
    @State private var checkboxMixedState: CheckboxMixedState = .off
    @Binding var selectedFileUris: [DocumentUri]
    @AppStorage(\.chatFontSize) private var chatFontSize
    @StateObject private var fontScaleManager = FontScaleManager.shared
    
    var fontScale: Double {
        fontScaleManager.currentScale
    }
    
    private static let defaultVisibleFileCount = 5
    
    private var hasMoreFiles: Bool {
        fileUris.count > Self.defaultVisibleFileCount
    }
    
    var body: some View {
        let visibleFileUris = Array(fileUris.prefix(Self.defaultVisibleFileCount))
        let additionalFileUris = Array(fileUris.dropFirst(Self.defaultVisibleFileCount))
        
        WithPerceptionTracking {
            VStack(alignment: .leading, spacing: 4) {
                // Select All checkbox for all files
                selectedAllCheckbox
                    .disabled(reviewStatus != .waitForConfirmation)
                    .scaledFrame(maxHeight: 16)
                                
                FileToggleList(
                    fileUris: visibleFileUris,
                    reviewStatus: reviewStatus,
                    selectedFileUris: $selectedFileUris,
                    onSelectionChange: updateMixedState
                )
                .padding(.leading, 16)
                
                if hasMoreFiles {
                    if !isExpanded {
                        ExpandFilesButton(isExpanded: $isExpanded)
                    }
                    
                    if isExpanded {
                        FileToggleList(
                            fileUris: additionalFileUris,
                            reviewStatus: reviewStatus,
                            selectedFileUris: $selectedFileUris,
                            onSelectionChange: updateMixedState
                        )
                        .padding(.leading, 16)
                    }
                }
            }
        }
        .frame(alignment: .leading)
        .onAppear {
            updateMixedState()
        }
    }
    
    private var selectedAllCheckbox: some View {
        let selectedCount = selectedFileUris.count
        let totalCount = fileUris.count
        let title = "All (\(selectedCount)/\(totalCount))"
        let font: NSFont = .systemFont(ofSize: chatFontSize * fontScale)
        
        return MixedStateCheckbox(
            title: title,
            font: font,
            state: $checkboxMixedState
        ) {
            switch checkboxMixedState {
            case .off, .mixed:
                // Select all files
                selectedFileUris = fileUris
            case .on:
                // Deselect all files
                selectedFileUris = []
            }
            updateMixedState()
        }
    }
    
    private func updateMixedState() {
        let selectedSet = Set(selectedFileUris)
        let selectedCount = fileUris.filter { selectedSet.contains($0) }.count
        let totalCount = fileUris.count
        
        if selectedCount == 0 {
            checkboxMixedState = .off
        } else if selectedCount == totalCount {
            checkboxMixedState = .on
        } else {
            checkboxMixedState = .mixed
        }
    }
}

private struct ExpandFilesButton: View {
    @Binding var isExpanded: Bool
    @AppStorage(\.chatFontSize) private var chatFontSize
    
    var body: some View {
        HStack(spacing: 2) {
            Image("chevron.down")
                .resizable()
                .scaledToFit()
                .scaledFrame(width: 16, height: 16)
            
            Button(action: { isExpanded = true }) {
                Text("Show more")
                    .underline()
                    .scaledFont(.system(size: chatFontSize))
                    .lineSpacing(20)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .foregroundColor(.blue)
    }
}

private struct FileToggleList: View {
    let fileUris: [DocumentUri]
    let reviewStatus: CodeReviewRound.Status
    @Binding var selectedFileUris: [DocumentUri]
    let onSelectionChange: () -> Void
    
    var body: some View {
        ForEach(fileUris, id: \.self) { fileUri in
            FileSelectionRow(
                fileUri: fileUri,
                reviewStatus: reviewStatus,
                isSelected: createSelectionBinding(for: fileUri)
            )
        }
    }
    
    private func createSelectionBinding(for fileUri: DocumentUri) -> Binding<Bool> {
        Binding<Bool>(
            get: { selectedFileUris.contains(fileUri) },
            set: { isSelected in
                if isSelected {
                    if !selectedFileUris.contains(fileUri) {
                        selectedFileUris.append(fileUri)
                    }
                } else {
                    selectedFileUris.removeAll { $0 == fileUri }
                }
                
                onSelectionChange()
            }
        )
    }
}

private struct FileSelectionRow: View {
    let fileUri: DocumentUri
    let reviewStatus: CodeReviewRound.Status
    @Binding var isSelected: Bool
    
    private var fileURL: URL? {
        URL(string: fileUri)
    }
    
    private var isInteractionEnabled: Bool {
        reviewStatus == .waitForConfirmation
    }
    
    var body: some View {
        HStack(alignment: .center) {
            Toggle(isOn: $isSelected) {
                HStack(spacing: 8) {
                    drawFileIcon(fileURL)
                        .scaledToFit()
                        .scaledFrame(width: 16, height: 16)
                    
                    Text(fileURL?.lastPathComponent ?? fileUri)
                        .scaledFont(.body)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .toggleStyle(CheckboxToggleStyle())
            .disabled(!isInteractionEnabled)
            
            Spacer()
        }
    }
}
