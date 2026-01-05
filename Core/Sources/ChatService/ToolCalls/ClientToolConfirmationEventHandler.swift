import Foundation
import ConversationServiceProvider
import JSONRPC

extension ChatService {
    typealias ToolConfirmationCompletion = (AnyJSONRPCResponse) -> Void

    func handleClientToolConfirmationEvent(
        request: InvokeClientToolConfirmationRequest,
        completion: @escaping ToolConfirmationCompletion
    ) {
        guard let params = request.params else { return }
        guard isConversationIdValid(params.conversationId) else { return }

        Task { [weak self] in
            guard let self else { return }
            let shouldAutoApprove = await shouldAutoApprove(params: params)
            let parentTurnId = parentTurnIdForTurnId(params.turnId)

            let toolCallStatus: AgentToolCall.ToolCallStatus = shouldAutoApprove
                ? .accepted
                : .waitForConfirmation

            appendToolCallHistory(
                turnId: params.turnId,
                editAgentRounds: makeEditAgentRounds(params: params, status: toolCallStatus),
                parentTurnId: parentTurnId
            )

            let toolCallRequest = ToolCallRequest(
                requestId: request.id,
                turnId: params.turnId,
                roundId: params.roundId,
                toolCallId: params.toolCallId,
                completion: completion
            )

            if shouldAutoApprove {
                sendToolConfirmationResponse(toolCallRequest, accepted: true)
            } else {
                storePendingToolCallRequest(toolCallId: params.toolCallId, request: toolCallRequest)
            }
        }
    }

    private func shouldAutoApprove(params: InvokeClientToolParams) async -> Bool {
        let mcpServerName = ToolAutoApprovalManager.extractMCPServerName(from: params.title ?? "")
        let confirmationMessage = params.message ?? ""

        if let mcpServerName {
            let allowed = await ToolAutoApprovalManager.shared.isMCPAllowed(
                conversationId: params.conversationId,
                serverName: mcpServerName,
                toolName: params.name
            )

            if allowed {
                return true
            }
        }

        if ToolAutoApprovalManager.isSensitiveFileOperation(message: confirmationMessage) {
            let fileKey = ToolAutoApprovalManager.sensitiveFileKey(from: confirmationMessage)
            let allowed = await ToolAutoApprovalManager.shared.isSensitiveFileAllowed(
                conversationId: params.conversationId,
                toolName: params.name,
                fileKey: fileKey
            )

            if allowed {
                return true
            }
        }

        return false
    }

    func makeEditAgentRounds(params: InvokeClientToolParams, status: AgentToolCall.ToolCallStatus) -> [AgentRound] {
        [
            AgentRound(
                roundId: params.roundId,
                reply: "",
                toolCalls: [
                    AgentToolCall(
                        id: params.toolCallId,
                        name: params.name,
                        status: status,
                        invokeParams: params,
                        title: params.title
                    )
                ]
            )
        ]
    }
}
