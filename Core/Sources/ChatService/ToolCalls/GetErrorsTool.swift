import JSONRPC
import Foundation
import ConversationServiceProvider
import XcodeInspector
import AppKit

public class GetErrorsTool: ICopilotTool {
    public func invokeTool(
        _ request: InvokeClientToolRequest,
        completion: @escaping (AnyJSONRPCResponse) -> Void,
        contextProvider: ToolContextProvider?
    ) -> Bool {
        guard let params = request.params,
              let input = params.input,
              let filePaths = input["filePaths"]?.value as? [String]
        else {
            completeResponse(request, completion: completion)
            return true
        }
                
        guard let xcodeInstance = XcodeInspector.shared.xcodes.first(
            where: {
                $0.workspaceURL?.path == contextProvider?.chatTabInfo.workspacePath
            }),
              let documentURL = xcodeInstance.realtimeDocumentURL,
              filePaths.contains(where: { URL(fileURLWithPath: $0) == documentURL })
        else {
            completeResponse(request, completion: completion)
            return true
        }
        
        /// Not leveraging the `getFocusedEditorContent` in `XcodeInspector`.
        /// As the resolving should be sync. Especially when completion the JSONRPCResponse
        let focusedElement: AXUIElement? = try? xcodeInstance.appElement.copyValue(key: kAXFocusedUIElementAttribute)
        let focusedEditor: SourceEditor?
        if let editorElement = focusedElement, editorElement.isNonNavigatorSourceEditor {
            focusedEditor = .init(runningApplication: xcodeInstance.runningApplication, element: editorElement)
        } else if let element = focusedElement, let editorElement = element.firstParent(
            where: \.isNonNavigatorSourceEditor
        ) {
            focusedEditor = .init(runningApplication: xcodeInstance.runningApplication, element: editorElement)
        } else {
            focusedEditor = nil
        }
        
        var errors: String = ""
        
        if let focusedEditor
        {
            let editorContent = focusedEditor.getContent()
            let errorArray: [String] = editorContent.lineAnnotations.map {
                """
                <uri>\(documentURL.absoluteString)</uri>
                <error>
                    <message>\($0.message)</message>
                    <range>
                        <start>
                            <line>\($0.line)</line>
                            <character>0</character>
                        </start>
                        <end>
                            <line>\($0.line)</line>
                            <character>0</character>
                        </end>
                    </range>
                </error>
                """
            }
            errors = errorArray.joined(separator: "\n")
        }
        
        completeResponse(request, response: errors, completion: completion)
        return true
    }
}
