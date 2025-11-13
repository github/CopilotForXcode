import ChatAPIService
import ConversationServiceProvider
import Foundation

/// Helper methods for updating tool call status in chat history
/// Handles both main turn tool calls and subagent tool calls
struct ToolCallStatusUpdater {
    /// Finds the message containing the tool call, handling both main turns and subturns
    static func findMessageContainingToolCall(
        _ toolCallRequest: ToolCallRequest?,
        conversationTurnTracking: ConversationTurnTrackingState,
        history: [ChatMessage]
    ) async -> ChatMessage? {
        guard let request = toolCallRequest else { return nil }

        // If this is a subturn, find the parent turn; otherwise use the request's turnId
        let turnIdToFind = conversationTurnTracking.turnParentMap[request.turnId] ?? request.turnId

        return history.first(where: { $0.id == turnIdToFind && $0.role == .assistant })
    }

    /// Searches for a tool call in agent rounds (including nested subagent rounds) and creates an update
    ///
    /// Note: Parent turns can have multiple sequential subturns, but they don't appear simultaneously.
    /// Subturns are merged into the parent's last round's subAgentRounds array by ChatMemory.
    static func findAndUpdateToolCall(
        toolCallId: String,
        newStatus: AgentToolCall.ToolCallStatus,
        in agentRounds: [AgentRound]
    ) -> AgentRound? {
        // First, search in main rounds (for regular tool calls)
        for round in agentRounds {
            if let toolCalls = round.toolCalls {
                for toolCall in toolCalls where toolCall.id == toolCallId {
                    return AgentRound(
                        roundId: round.roundId,
                        reply: "",
                        toolCalls: [
                            AgentToolCall(
                                id: toolCallId,
                                name: toolCall.name,
                                status: newStatus
                            ),
                        ]
                    )
                }
            }
        }

        // If not found in main rounds, search in subagent rounds (for subturn tool calls)
        // Subturns are nested under the parent round's subAgentRounds
        for round in agentRounds {
            guard let subAgentRounds = round.subAgentRounds else { continue }

            for subRound in subAgentRounds {
                guard let toolCalls = subRound.toolCalls else { continue }

                for toolCall in toolCalls where toolCall.id == toolCallId {
                    // Create an update that will be merged into the parent's subAgentRounds
                    // ChatMemory.appendMessage will handle the merging logic
                    let subagentRound = AgentRound(
                        roundId: subRound.roundId,
                        reply: "",
                        toolCalls: [
                            AgentToolCall(
                                id: toolCallId,
                                name: toolCall.name,
                                status: newStatus
                            ),
                        ]
                    )
                    return AgentRound(
                        roundId: round.roundId,
                        reply: "",
                        toolCalls: [],
                        subAgentRounds: [subagentRound]
                    )
                }
            }
        }

        return nil
    }

    /// Creates a message update with the new tool call status
    static func createMessageUpdate(
        targetMessage: ChatMessage,
        updatedRound: AgentRound
    ) -> ChatMessage {
        return ChatMessage(
            id: targetMessage.id,
            chatTabID: targetMessage.chatTabID,
            clsTurnID: targetMessage.clsTurnID,
            role: .assistant,
            content: "",
            references: [],
            steps: [],
            editAgentRounds: [updatedRound],
            turnStatus: .inProgress
        )
    }
}
