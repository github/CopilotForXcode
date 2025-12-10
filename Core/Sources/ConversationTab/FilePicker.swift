import ComposableArchitecture
import ConversationServiceProvider
import SharedUIComponents
import SwiftUI
import SystemUtils

public struct FilePicker: View {
    @Binding var allFiles: [ConversationAttachedReference]?
    let workspaceURL: URL?
    var onSubmit: (_ file: ConversationAttachedReference) -> Void
    var onExit: () -> Void
    @FocusState private var isSearchBarFocused: Bool
    @State private var searchText = ""
    @State private var selectedId: Int = 0
    @State private var localMonitor: Any? = nil
    @AppStorage(\.chatFontSize) var chatFontSize
    
    // Only showup direct sub directories
    private var defaultReferencesForDisplay: [ConversationAttachedReference]? {
        guard let allFiles else { return nil }
        
        let directories = allFiles
            .filter { $0.isDirectory }
            .filter {
                guard case let .directory(directory) = $0 else {
                    return false
                }
                
                return directory.depth == 1
            }
            
        let files = allFiles.filter { !$0.isDirectory }
        
        return directories + files
    }
    
    private var filteredReferences: [ConversationAttachedReference]? {
        if searchText.isEmpty {
            return defaultReferencesForDisplay
        }
        
        return allFiles?.filter { ref in 
            ref.url.lastPathComponent.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private static let defaultEmptyStateText = "No results found."
    private static let isIndexingStateText = "Indexing files, try later..."
    
    private var emptyStateAttributedString: AttributedString? {
        var message = allFiles == nil ? FilePicker.isIndexingStateText : FilePicker.defaultEmptyStateText
        if let workspaceURL = workspaceURL {
            let status = FileUtils.checkFileReadability(at: workspaceURL.path)
            if let errorMessage = status.errorMessage(using: ContextUtils.workspaceReadabilityErrorMessageProvider) {
                message = errorMessage
            }
        }
        
        return try? AttributedString(markdown: message)
    }
    
    private var emptyStateView: some View {
        Group {
            if let attributedString = emptyStateAttributedString {
                Text(attributedString)
            } else {
                Text(FilePicker.defaultEmptyStateText)
            }
        }
    }

    public var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search files...", text: $searchText)
                        .scaledFont(.body)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(searchText.isEmpty ? Color(nsColor: .placeholderTextColor) : Color(nsColor: .textColor))
                        .focused($isSearchBarFocused)
                        .onChange(of: searchText) { newValue in
                            selectedId = 0
                        }
                        .onAppear() {
                            isSearchBarFocused = true
                        }

                    Button(action: {
                        withAnimation {
                            onExit()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .scaledFont(.body)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(HoverButtonStyle())
                    .help("Close")
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.gray.opacity(0.1))
                )
                .cornerRadius(6)
                .padding(.horizontal, 4)
                .padding(.top, 4)

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            if allFiles == nil || filteredReferences?.isEmpty == true {
                                emptyStateView
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 4)
                                    .padding(.vertical, 4)
                            } else {
                                ForEach(Array((filteredReferences ?? []).enumerated()), id: \.element) { index, ref in
                                    FileRowView(ref: ref, id: index, selectedId: $selectedId)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            onSubmit(ref)
                                            selectedId = index
                                            isSearchBarFocused = true
                                        }
                                        .id(index)
                                }
                            }
                        }
                        .id(filteredReferences?.hashValue)
                    }
                    .frame(maxHeight: 200)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                    .onAppear {
                        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                            if !isSearchBarFocused { // if file search bar is not focused, ignore the event
                                return event
                            }

                            switch event.keyCode {
                            case 126: // Up arrow
                                moveSelection(up: true, proxy: proxy)
                                return nil
                            case 125: // Down arrow
                                moveSelection(up: false, proxy: proxy)
                                return nil
                            case 36: // Return key
                                handleEnter()
                                return nil
                            case 53: // Esc key
                                withAnimation {
                                    onExit()
                                }
                                return nil
                            default:
                                break
                            }
                            return event
                        }
                    }
                    .onDisappear {
                        if let monitor = localMonitor {
                            NSEvent.removeMonitor(monitor)
                            localMonitor = nil
                        }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
    }

    private func moveSelection(up: Bool, proxy: ScrollViewProxy) {
        guard let refs = filteredReferences, !refs.isEmpty else { return }
        let nextId = selectedId + (up ? -1 : 1)
        selectedId = max(0, min(nextId, refs.count - 1))
        proxy.scrollTo(selectedId, anchor: .bottom)
    }

    private func handleEnter() {
        guard let refs = filteredReferences, !refs.isEmpty && selectedId < refs.count else {
            return
        }
        
        onSubmit(refs[selectedId])
    }
}

struct FileRowView: View {
    @State private var isHovered = false
    let ref: ConversationAttachedReference
    let id: Int
    @Binding var selectedId: Int

    var body: some View {
        WithPerceptionTracking {
            HStack(alignment: .center) {
                drawFileIcon(ref.url, isDirectory: ref.isDirectory)
                    .scaledToFit()
                    .scaledFrame(width: 16, height: 16)
                    .hoverSecondaryForeground(isHovered: selectedId == id)
                    .padding(.leading, 4)
                
                HStack(spacing: 4) {
                    Text(ref.displayName)
                        .scaledFont(.body)
                        .hoverPrimaryForeground(isHovered: selectedId == id)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .layoutPriority(1)
                    
                    Text(ref.relativePath)
                        .scaledFont(.caption)
                        .hoverSecondaryForeground(isHovered: selectedId == id)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        // Ensure relative path remains visible even when display name is very long
                        .frame(minWidth: 80, alignment: .leading)
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
            .hoverRadiusBackground(isHovered: isHovered || selectedId == id,
                                   hoverColor: (selectedId == id ? nil : Color.gray.opacity(0.1)),
                                   cornerRadius: 6)
            .onHover(perform: { hovering in
                isHovered = hovering
            })
            .help(ref.url.path)
        }
    }
}
