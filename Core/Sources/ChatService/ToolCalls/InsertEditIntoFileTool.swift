import AppKit
import AXExtension
import AXHelper
import ConversationServiceProvider
import Foundation
import JSONRPC
import Logger
import XcodeInspector
import ChatAPIService

public enum InsertEditError: LocalizedError {
    case missingEditorElement(file: URL)
    case openingApplicationUnavailable
    case fileNotOpenedInXcode
    case fileURLMismatch(expected: URL, actual: URL?)
    
    public var errorDescription: String? {
        switch self {
        case .missingEditorElement(let file):
            return "Could not find source editor element for file \(file.lastPathComponent)."
        case .openingApplicationUnavailable:
            return "Failed to get the application that opened the file."
        case .fileNotOpenedInXcode:
            return "The file is not currently opened in Xcode."
        case .fileURLMismatch(let expected, let actual):
            return "The currently focused file URL \(actual?.lastPathComponent ?? "unknown") does not match the expected file URL \(expected.lastPathComponent)."
        }
    }
}

public class InsertEditIntoFileTool: ICopilotTool {
    public static let name = ToolName.insertEditIntoFile
    
    public func invokeTool(
        _ request: InvokeClientToolRequest,
        completion: @escaping (AnyJSONRPCResponse) -> Void,
        contextProvider: (any ToolContextProvider)?
    ) -> Bool {
        guard let params = request.params,
              let input = request.params?.input,
              let code = input["code"]?.value as? String,
              let filePath = input["filePath"]?.value as? String,
              let contextProvider
        else {
            completeResponse(request, status: .error, response: "Invalid parameters", completion: completion)
            return true
        }
        
        do {
            let fileURL = URL(fileURLWithPath: filePath)
            let originalContent = try String(contentsOf: fileURL, encoding: .utf8)
            
            InsertEditIntoFileTool.applyEdit(for: fileURL, content: code, contextProvider: contextProvider) { newContent, error in
                if let error = error {
                    self.completeResponse(
                        request,
                        status: .error,
                        response: error.localizedDescription,
                        completion: completion
                    )
                    return
                }
                
                guard let newContent = newContent
                else {
                    self.completeResponse(request, status: .error, response: "Failed to apply edit", completion: completion)
                    return
                }
                
                let fileEdit: FileEdit = .init(fileURL: fileURL, originalContent: originalContent, modifiedContent: code, toolName: InsertEditIntoFileTool.name)
                contextProvider.updateFileEdits(by: fileEdit)
                
                let editAgentRounds: [AgentRound] = [
                    .init(
                        roundId: params.roundId,
                        reply: "",
                        toolCalls: [
                            .init(
                                id: params.toolCallId,
                                name: params.name,
                                status: .completed,
                                invokeParams: params
                            )
                        ]
                    )
                ]
                
                contextProvider
                    .updateChatHistory(params.turnId, editAgentRounds: editAgentRounds, fileEdits: [fileEdit])
                
                self.completeResponse(request, response: newContent, completion: completion)
            }
            
        } catch {
            completeResponse(
                request,
                status: .error,
                response: error.localizedDescription,
                completion: completion
            )
        }
        
        return true
    }
    
    public static func applyEdit(
        for fileURL: URL,
        content: String,
        contextProvider: any ToolContextProvider,
        xcodeInstance: AppInstanceInspector
    ) throws -> String {
        guard let editorElement = Self.getEditorElement(by: xcodeInstance, for: fileURL)
        else {
            throw InsertEditError.missingEditorElement(file: fileURL)
        }
        
        // Check if element supports kAXValueAttribute before reading
        var value: String = ""
        do {
            value = try editorElement.copyValue(key: kAXValueAttribute)
        } catch {
            if let axError = error as? AXError {
                Logger.client.error("AX Error code: \(axError.rawValue)")
            }
            throw error
        }
        
        let lines = value.components(separatedBy: .newlines)
        
        do {
            try Self.checkOpenedFileURL(for: fileURL, xcodeInstance: xcodeInstance)
                    
            try AXHelper().injectUpdatedCodeWithAccessibilityAPI(
                .init(
                    content: content,
                    newSelection: nil,
                    modifications: [
                        .deletedSelection(
                            .init(start: .init(line: 0, character: 0), end: .init(line: lines.count - 1, character: (lines.last?.count ?? 100) - 1))
                        ),
                        .inserted(0, [content])
                    ]
                ),
                focusElement: editorElement
            )
        } catch {
            Logger.client.error("Failed to inject code for insert edit into file: \(error.localizedDescription)")
            throw error
        }
        
        // Verify the content was applied by reading it back
        return try Self.getCurrentEditorContent(for: fileURL, by: xcodeInstance)
    }
    
    public static func applyEdit(
        for fileURL: URL,
        content: String,
        contextProvider: any ToolContextProvider,
        completion: ((String?, Error?) -> Void)? = nil
    ) {
        NSWorkspace.openFileInXcode(fileURL: fileURL) { app, error in
            do {
                if let error = error { throw error }
                
                guard let app = app
                else {
                    throw InsertEditError.openingApplicationUnavailable
                }
                
                let appInstanceInspector = AppInstanceInspector(runningApplication: app)
                guard appInstanceInspector.isXcode
                else {
                    throw InsertEditError.fileNotOpenedInXcode
                }
                                
                let newContent = try applyEdit(
                    for: fileURL,
                    content: content,
                    contextProvider: contextProvider,
                    xcodeInstance: appInstanceInspector
                )
                
                Task {
                    await WorkspaceInvocationCoordinator().invokeFilespaceUpdate(fileURL: fileURL, content: newContent)
                    if let completion = completion { completion(newContent, nil) }
                }
            } catch {
                if let completion = completion { completion(nil, error) }
                Logger.client.info("Failed to apply edit for file at \(fileURL), \(error)")
            }
        }
    }
    
    /// Get the source editor element with retries for specific file URL
    private static func getEditorElement(
        by xcodeInstance: AppInstanceInspector,
        for fileURL: URL,
        retryTimes: Int = 6,
        delay: TimeInterval = 0.5
    ) -> AXUIElement? {
        var remainingAttempts = max(1, retryTimes)
        
        while remainingAttempts > 0 {
            guard let realtimeURL = xcodeInstance.appElement.realtimeDocumentURL,
                  realtimeURL == fileURL,
                  let focusedElement = xcodeInstance.appElement.focusedElement,
                  let editorElement = focusedElement.findSourceEditorElement()
            else {
                if remainingAttempts > 1 {
                    Thread.sleep(forTimeInterval: delay)
                }
                
                remainingAttempts -= 1
                continue
            }
            
            return editorElement
        }
        
        Logger.client.error("Editor element not found for \(fileURL.lastPathComponent) after \(retryTimes) attempts.")
        return nil
    }

    // Check if current opened file is the target URL
    private static func checkOpenedFileURL(
        for fileURL: URL,
        xcodeInstance: AppInstanceInspector
    ) throws {
        let realtimeDocumentURL = xcodeInstance.realtimeDocumentURL
        
        if realtimeDocumentURL != fileURL {
            throw InsertEditError.fileURLMismatch(expected: fileURL, actual: realtimeDocumentURL)
        }
    }
    
    private static func getCurrentEditorContent(for fileURL: URL, by xcodeInstance: AppInstanceInspector) throws -> String {
        guard let editorElement = getEditorElement(by: xcodeInstance, for: fileURL, retryTimes: 1)
        else {
            throw InsertEditError.missingEditorElement(file: fileURL)
        }
        
        return try editorElement.copyValue(key: kAXValueAttribute)
    }
}

private extension AppInstanceInspector {
    var realtimeDocumentURL: URL? {
        appElement.realtimeDocumentURL
    }
}
