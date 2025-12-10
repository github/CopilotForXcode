import SwiftUI
import ChatService
import Perception
import ComposableArchitecture
import GitHubCopilotService
import JSONRPC
import SharedUIComponents
import OrderedCollections
import ConversationServiceProvider
import ChatAPIService

struct WorkingSetView: View {
    let chat: StoreOf<Chat>
    
    private let r: Double = 8
    
    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 4) {
                
                WorkingSetHeader(chat: chat)
                    .scaledFrame(height: 24)
                    .scaledPadding(.leading, 7)
                
                VStack(spacing: 0) {
                    ForEach(chat.fileEditMap.elements, id: \.key.path) { element in
                        FileEditView(chat: chat, fileEdit: element.value)
                    }
                }
            }
            .scaledPadding(.horizontal, 5)
            .scaledPadding(.top, 8)
            .scaledPadding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedCorners(tl: r, tr: r, bl: 0, br: 0)
                    .fill(.ultraThickMaterial)
            )
            .overlay(
                RoundedCorners(tl: r, tr: r, bl: 0, br: 0)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
        }
    }
}

struct WorkingSetHeader: View {
    let chat: StoreOf<Chat>
    
    @Environment(\.colorScheme) var colorScheme
    
    func getTitle() -> String {
        return chat.fileEditMap.count > 1 ? "\(chat.fileEditMap.count) files changed" : "1 file changed"
    }
    
    @ViewBuilder
    private func buildActionButton(
        text: String,
        textForegroundColor: Color = .white,
        textBackgroundColor: Color = .gray,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(text)
                .scaledFont(.body)
                .foregroundColor(textForegroundColor)
                .scaledPadding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(textBackgroundColor)
                .cornerRadius(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
                .scaledFrame(width: 60, height: 15, alignment: .center)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    var body: some View {
        WithPerceptionTracking {
            HStack(spacing: 0) {
                Text(getTitle())
                    .foregroundColor(.secondary)
                    .scaledFont(size: 13)
                
                Spacer()
                
                if chat.fileEditMap.contains(where: {_, fileEdit in
                    return fileEdit.status == .none
                }) {
                    HStack(spacing: -10) {
                        /// Undo all edits
                        buildActionButton(
                            text: "Undo",
                            textForegroundColor: colorScheme == .dark ? .white : .black,
                            textBackgroundColor: Color("WorkingSetHeaderUndoButtonColor")
                        ) {
                            chat.send(.undoEdits(fileURLs: chat.fileEditMap.values.map { $0.fileURL }))
                        }
                        .help("Undo All Edits")
                        
                        /// Keep all edits
                        buildActionButton(text: "Keep", textBackgroundColor: Color("WorkingSetHeaderKeepButtonColor")) {
                            chat.send(.keepEdits(fileURLs: chat.fileEditMap.values.map { $0.fileURL }))
                        }
                        .help("Keep All Edits")
                    }
                    
                } else {
                    buildActionButton(text: "Done") {
                        chat.send(.resetEdits)
                    }
                    .help("Done")
                }
            }
            
        }
    }
}

struct FileEditView: View {
    let chat: StoreOf<Chat>
    let fileEdit: FileEdit
    @State private var isHovering = false
    
    enum ActionButtonImageType {
        case system(String), asset(String)
    }
    
    @ViewBuilder
    private func buildActionButton(
        imageType: ActionButtonImageType,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                switch imageType {
                case .system(let name):
                    Image(systemName: name)
                        .scaledFont(size: 15, weight: .regular)
                case .asset(let name):
                    Image(name)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaledFrame(height: 16)
                }
            }
            .foregroundColor(.white)
            .scaledFrame(width: 22)
            .frame(maxHeight: .infinity)
        }
        .buttonStyle(HoverButtonStyle(padding: 0, hoverColor: .white.opacity(0.2)))
        .help(help)
    }
    
    var actionButtons: some View {
        HStack(spacing: 0) {
            if fileEdit.status == .none {
                buildActionButton(
                    imageType: .system("xmark"),
                    help: "Remove file"
                ) {
                    chat.send(.discardFileEdits(fileURLs: [fileEdit.fileURL]))
                }
                buildActionButton(
                    imageType: .asset("DiffEditor"),
                    help: "Open changes in Diff Editor"
                ) {
                    chat.send(.openDiffViewWindow(fileURL: fileEdit.fileURL))
                }
                buildActionButton(
                    imageType: .asset("Discard"),
                    help: "Undo"
                ) {
                    chat.send(.undoEdits(fileURLs: [fileEdit.fileURL]))
                }
                buildActionButton(
                    imageType: .system("checkmark"),
                    help: "Keep"
                ) {
                    chat.send(.keepEdits(fileURLs: [fileEdit.fileURL]))
                }
            }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .center, spacing: 4) {
                drawFileIcon(fileEdit.fileURL)
                    .scaledToFit()
                    .scaledFrame(width: 16, height: 16)
                    .foregroundColor(.secondary)
                
                Text(fileEdit.fileURL.lastPathComponent)
                    .scaledFont(size: 13)
                    .foregroundColor(isHovering ? .white : Color("WorkingSetItemColor"))
            }
            
            Spacer()
            
            if isHovering {
                actionButtons
                    .padding(.trailing, 8)
            }
        }
        .onHover { hovering in
            isHovering = hovering
        }
        .scaledPadding(.leading, 7)
        .scaledFrame(height: 24)
        .hoverRadiusBackground(
            isHovered: isHovering,
            hoverColor: Color.blue,
            cornerRadius: 5,
            showBorder: true
        )
        .onTapGesture {
            chat.send(.openDiffViewWindow(fileURL: fileEdit.fileURL))
        }
    }
}


struct WorkingSetView_Previews: PreviewProvider {
    static let fileEditMap: OrderedDictionary<URL, FileEdit> = [
        URL(fileURLWithPath: "file:///f1.swift"): FileEdit(fileURL: URL(fileURLWithPath: "file:///f1.swift"), originalContent: "single line", modifiedContent: "single line 1", toolName: ToolName.insertEditIntoFile),
        URL(fileURLWithPath: "file:///f2.swift"): FileEdit(fileURL: URL(fileURLWithPath: "file:///f2.swift"), originalContent: "multi \n line \n end", modifiedContent: "another \n mut \n li \n", status: .kept, toolName: ToolName.insertEditIntoFile)
    ]
    
    static var previews: some View {
        WorkingSetView(
            chat: .init(
                initialState: .init(
                    history: ChatPanel_Preview.history,
                    isReceivingMessage: true,
                    fileEditMap: fileEditMap
                ),
                reducer: { Chat(service: ChatService.service(for: ChatPanel_Preview.chatTabInfo)) }
            )
        )
    }
}
