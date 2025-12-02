import AppKit
import AXExtension
import AXHelper
import ConversationServiceProvider
import Foundation
import JSONRPC
import Logger
import XcodeInspector
import ChatAPIService

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
        Thread.sleep(forTimeInterval: 0.5)
        // Get the focused element directly from the app (like XcodeInspector does)
        guard let focusedElement: AXUIElement = xcodeInstance.appElement.focusedElement
        else {
            throw NSError(domain: "Failed to access xcode element", code: 0)
        }
        
        // Find the source editor element using XcodeInspector's logic
        guard let editorElement = focusedElement.findSourceEditorElement() else {
            throw NSError(domain: "Could not find source editor element", code: 0)
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
        
        guard let refreshedFocusedElement: AXUIElement = xcodeInstance.appElement.focusedElement,
              let refreshedEditorElement = refreshedFocusedElement.findSourceEditorElement()
        else {
            throw NSError(domain: "Failed to access xcode element", code: 0)
        }
        
        // Verify the content was applied by reading it back
        do {
            let newContent: String = try refreshedEditorElement.copyValue(key: kAXValueAttribute)
            Logger.client.info("Successfully read back new content, length: \(newContent.count)")
            
            return newContent
        } catch {
            Logger.client.error("Failed to read back new content: \(error)")
            if let axError = error as? AXError {
                Logger.client.error("AX Error code when reading back: \(axError.rawValue)")
            }
            throw error
        }
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
                    throw NSError(domain: "Failed to get the app that opens file.", code: 0)
                }
                
                let appInstanceInspector = AppInstanceInspector(runningApplication: app)
                guard appInstanceInspector.isXcode
                else {
                    throw NSError(domain: "The file is not opened in Xcode.", code: 0)
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
}
