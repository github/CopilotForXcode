import Foundation
import ConversationServiceProvider
import ChatAPIService

extension ChatService {
    // MARK: - File Edit
    
    public func updateFileEdits(by fileEdit: FileEdit) {
        if let existingFileEdit = self.fileEditMap[fileEdit.fileURL] {
            self.fileEditMap[fileEdit.fileURL] = .init(
                fileURL: fileEdit.fileURL,
                originalContent: existingFileEdit.originalContent,
                modifiedContent: fileEdit.modifiedContent,
                toolName: existingFileEdit.toolName
            )
        } else {
            self.fileEditMap[fileEdit.fileURL] = fileEdit
        }
    }
    
    public func undoFileEdit(for fileURL: URL) throws {
        guard var fileEdit = self.fileEditMap[fileURL],
              fileEdit.status == .none
        else { return }
        
        switch fileEdit.toolName {
        case .insertEditIntoFile:
            InsertEditIntoFileTool.applyEdit(for: fileURL, content: fileEdit.originalContent)
        case .createFile:
            try CreateFileTool.undo(for: fileURL)
        default:
            return
        }
        
        fileEdit.status = .undone
        self.fileEditMap[fileURL] = fileEdit
    }
    
    public func keepFileEdit(for fileURL: URL) {
        guard var fileEdit = self.fileEditMap[fileURL], fileEdit.status == .none
        else { return }
        
        fileEdit.status = .kept
        self.fileEditMap[fileURL] = fileEdit
    }
    
    public func resetFileEdits() {
        self.fileEditMap = [:]
    }
    
    public func discardFileEdit(for fileURL: URL) throws {
        try self.undoFileEdit(for: fileURL)
        self.fileEditMap.removeValue(forKey: fileURL)
    }
}
