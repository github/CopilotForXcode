import AppKit
import Combine
import Foundation
import JSONRPC
import LanguageServerProtocol
import Logger

public protocol DynamicOAuthRequestHandler {
    func handleDynamicOAuthRequest(
        _ request: DynamicOAuthRequest,
        completion: @escaping (AnyJSONRPCResponse) -> Void
    )
}

public final class DynamicOAuthRequestHandlerImpl: NSObject, DynamicOAuthRequestHandler {
    public static let shared = DynamicOAuthRequestHandlerImpl()
    
    // MARK: - Constants
    
    private enum LayoutConstants {
        static let containerWidth: CGFloat = 450
        static let fieldWidth: CGFloat = 330
        static let labelWidth: CGFloat = 100
        static let labelX: CGFloat = 4
        static let fieldX: CGFloat = 100
        
        static let spacing: CGFloat = 8
        static let hintSpacing: CGFloat = 4
        static let labelHeight: CGFloat = 17
        static let fieldHeight: CGFloat = 28
        static let labelVerticalOffset: CGFloat = 6
        
        static let hintFontSize: CGFloat = 11
        static let regularFontSize: CGFloat = 13
    }
    
    private enum Strings {
        static let clientIdLabel = "Client ID *"
        static let clientSecretLabel = "Client Secret"
        static let clientIdPlaceholder = "OAuth client ID (azye39d...)"
        static let clientSecretPlaceholder = "OAuth client secret (wer32o50f...) or leave it blank"
        static let okButton = "OK"
        static let cancelButton = "Cancel"
    }

    public func handleDynamicOAuthRequest(
        _ request: DynamicOAuthRequest,
        completion: @escaping (AnyJSONRPCResponse) -> Void
    ) {
        guard let params = request.params else { return }
        Logger.gitHubCopilot.debug("Received Dynamic OAuth Request: \(params)")
        Task { @MainActor in
            let response = self.dynamicOAuthRequestAlert(params)
            let jsonResult = try? JSONEncoder().encode(response)
            let jsonValue = (try? JSONDecoder().decode(JSONValue.self, from: jsonResult ?? Data())) ?? JSONValue.null
            completion(AnyJSONRPCResponse(id: request.id, result: jsonValue))
        }
    }

    @MainActor
    func dynamicOAuthRequestAlert(_ params: DynamicOAuthParams) -> DynamicOAuthResponse? {
        let alert = configureAlert(with: params)
        let (clientIdField, clientSecretField) = createAccessoryView(for: alert, params: params)
        
        let modalResponse = alert.runModal()
        
        return handleAlertResponse(
            modalResponse,
            clientIdField: clientIdField,
            clientSecretField: clientSecretField
        )
    }
    
    // MARK: - Alert Configuration
    
    @MainActor
    private func configureAlert(with params: DynamicOAuthParams) -> NSAlert {
        let alert = NSAlert()
        alert.messageText = params.header ?? params.title
        alert.informativeText = params.detail
        alert.alertStyle = .warning
        alert.addButton(withTitle: Strings.okButton)
        alert.addButton(withTitle: Strings.cancelButton)
        return alert
    }
    
    // MARK: - Accessory View Creation
    
    @MainActor
    private func createAccessoryView(
        for alert: NSAlert,
        params: DynamicOAuthParams
    ) -> (clientIdField: NSTextField, clientSecretField: NSSecureTextField) {
        let (clientIdHint, clientIdHintHeight) = createHintLabel(
            text: params.inputs.first(where: { $0.value == "clientId" })?.description ?? ""
        )
        
        let (clientSecretHint, clientSecretHintHeight) = createHintLabel(
            text: params.inputs.first(where: { $0.value == "clientSecret" })?.description ?? ""
        )
        
        let totalHeight = calculateTotalHeight(
            clientIdHintHeight: clientIdHintHeight,
            clientSecretHintHeight: clientSecretHintHeight
        )
        
        let containerView = NSView(frame: NSRect(
            x: 0,
            y: 0,
            width: LayoutConstants.containerWidth,
            height: totalHeight
        ))
        
        let clientIdField = NSTextField()
        let clientSecretField = NSSecureTextField()
        
        layoutComponents(
            in: containerView,
            clientIdField: clientIdField,
            clientSecretField: clientSecretField,
            clientIdHint: clientIdHint,
            clientSecretHint: clientSecretHint,
            clientIdHintHeight: clientIdHintHeight,
            clientSecretHintHeight: clientSecretHintHeight,
            params: params
        )
        
        alert.accessoryView = containerView
        
        return (clientIdField, clientSecretField)
    }
    
    // MARK: - Component Creation
    
    @MainActor
    private func createHintLabel(text: String) -> (label: NSTextField, height: CGFloat) {
        let hint = NSTextField(wrappingLabelWithString: text)
        hint.font = NSFont.systemFont(ofSize: LayoutConstants.hintFontSize)
        hint.textColor = NSColor.secondaryLabelColor
        let height = hint.sizeThatFits(NSSize(
            width: LayoutConstants.fieldWidth,
            height: CGFloat.greatestFiniteMagnitude
        )).height
        return (hint, height)
    }
    
    @MainActor
    private func createInputField(placeholder: String) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.font = NSFont.systemFont(ofSize: LayoutConstants.regularFontSize)
        field.isEditable = true
        return field
    }
    
    @MainActor
    private func createSecureField(placeholder: String) -> NSSecureTextField {
        let field = NSSecureTextField()
        field.placeholderString = placeholder
        field.font = NSFont.systemFont(ofSize: LayoutConstants.regularFontSize)
        field.isEditable = true
        return field
    }
    
    @MainActor
    private func createLabel(text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: LayoutConstants.regularFontSize)
        label.alignment = .left
        return label
    }
    
    // MARK: - Layout
    
    private func calculateTotalHeight(
        clientIdHintHeight: CGFloat,
        clientSecretHintHeight: CGFloat
    ) -> CGFloat {
        return clientSecretHintHeight + LayoutConstants.hintSpacing + LayoutConstants.fieldHeight +
            LayoutConstants.spacing + clientIdHintHeight + LayoutConstants.hintSpacing +
            LayoutConstants.fieldHeight
    }
    
    @MainActor
    private func layoutComponents(
        in containerView: NSView,
        clientIdField: NSTextField,
        clientSecretField: NSSecureTextField,
        clientIdHint: NSTextField,
        clientSecretHint: NSTextField,
        clientIdHintHeight: CGFloat,
        clientSecretHintHeight: CGFloat,
        params: DynamicOAuthParams
    ) {
        var currentY: CGFloat = 0
        
        // Client Secret section (bottom)
        layoutFieldSection(
            in: containerView,
            field: clientSecretField,
            label: createLabel(text: Strings.clientSecretLabel),
            hint: clientSecretHint,
            hintHeight: clientSecretHintHeight,
            placeholder: params.inputs.first(where: { $0.value == "clientSecret" })?.placeholder ?? Strings.clientSecretPlaceholder,
            currentY: &currentY,
            isLastSection: false
        )
        
        // Client ID section (top)
        layoutFieldSection(
            in: containerView,
            field: clientIdField,
            label: createLabel(text: Strings.clientIdLabel),
            hint: clientIdHint,
            hintHeight: clientIdHintHeight,
            placeholder: params.inputs.first(where: { $0.value == "clientId" })?.placeholder ?? Strings.clientIdPlaceholder,
            currentY: &currentY,
            isLastSection: true
        )
    }
    
    @MainActor
    private func layoutFieldSection(
        in containerView: NSView,
        field: NSTextField,
        label: NSTextField,
        hint: NSTextField,
        hintHeight: CGFloat,
        placeholder: String,
        currentY: inout CGFloat,
        isLastSection: Bool
    ) {
        // Position hint
        hint.frame = NSRect(
            x: LayoutConstants.fieldX,
            y: currentY,
            width: LayoutConstants.fieldWidth,
            height: hintHeight
        )
        currentY += hintHeight + LayoutConstants.hintSpacing
        
        // Position field
        field.frame = NSRect(
            x: LayoutConstants.fieldX,
            y: currentY,
            width: LayoutConstants.fieldWidth,
            height: LayoutConstants.fieldHeight
        )
        field.placeholderString = placeholder
        
        // Position label
        label.frame = NSRect(
            x: LayoutConstants.labelX,
            y: currentY + LayoutConstants.labelVerticalOffset,
            width: LayoutConstants.labelWidth,
            height: LayoutConstants.labelHeight
        )
        
        // Add to container
        containerView.addSubview(label)
        containerView.addSubview(field)
        containerView.addSubview(hint)
        
        if !isLastSection {
            currentY += LayoutConstants.fieldHeight + LayoutConstants.spacing
        }
    }
    
    // MARK: - Response Handling
    
    private func handleAlertResponse(
        _ response: NSApplication.ModalResponse,
        clientIdField: NSTextField,
        clientSecretField: NSSecureTextField
    ) -> DynamicOAuthResponse? {
        guard response == .alertFirstButtonReturn else {
            return nil
        }
        
        let clientId = clientIdField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientId.isEmpty else {
            Logger.gitHubCopilot.info("Client ID is required but was not provided")
            return nil
        }
        
        let clientSecret = clientSecretField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return DynamicOAuthResponse(
            clientId: clientId,
            clientSecret: clientSecret
        )
    }
}
