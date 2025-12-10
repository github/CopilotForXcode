import Foundation
import ConversationServiceProvider

public protocol ChatMemory {
    /// The message history.
    var history: [ChatMessage] { get async }
    /// Update the message history.
    func mutateHistory(_ update: (inout [ChatMessage]) -> Void) async
}

public extension ChatMemory {
    func appendMessage(_ message: ChatMessage) async {
        await mutateHistory { history in
            if let parentTurnId = message.parentTurnId {
                history.removeAll { $0.id == message.id }
                
                guard let parentIndex = history.firstIndex(where: { $0.id == parentTurnId }) else {
                    return
                }
                
                var parentMessage = history[parentIndex]
                
                if !message.editAgentRounds.isEmpty {
                    var parentRounds = parentMessage.editAgentRounds
                    
                    if let lastParentRoundIndex = parentRounds.indices.last {
                        var existingSubRounds = parentRounds[lastParentRoundIndex].subAgentRounds ?? []
                        
                        for messageRound in message.editAgentRounds {
                            if let subIndex = existingSubRounds.firstIndex(where: { $0.roundId == messageRound.roundId }) {
                                existingSubRounds[subIndex].reply = existingSubRounds[subIndex].reply + messageRound.reply
                                
                                if let messageToolCalls = messageRound.toolCalls, !messageToolCalls.isEmpty {
                                    var mergedToolCalls = existingSubRounds[subIndex].toolCalls ?? []
                                    for newToolCall in messageToolCalls {
                                        if let toolCallIndex = mergedToolCalls.firstIndex(where: { $0.id == newToolCall.id }) {
                                            mergedToolCalls[toolCallIndex].status = newToolCall.status
                                            if let progressMessage = newToolCall.progressMessage, !progressMessage.isEmpty {
                                                mergedToolCalls[toolCallIndex].progressMessage = progressMessage
                                            }
                                            if let result = newToolCall.result, !result.isEmpty {
                                                mergedToolCalls[toolCallIndex].result = result
                                            }
                                            if let resultDetails = newToolCall.resultDetails, !resultDetails.isEmpty {
                                                mergedToolCalls[toolCallIndex].resultDetails = resultDetails
                                            }
                                            if let error = newToolCall.error, !error.isEmpty {
                                                mergedToolCalls[toolCallIndex].error = error
                                            }
                                            if let invokeParams = newToolCall.invokeParams {
                                                mergedToolCalls[toolCallIndex].invokeParams = invokeParams
                                            }
                                            if let title = newToolCall.title {
                                                mergedToolCalls[toolCallIndex].title = title
                                            }
                                        } else {
                                            mergedToolCalls.append(newToolCall)
                                        }
                                    }
                                    existingSubRounds[subIndex].toolCalls = mergedToolCalls
                                }
                            } else {
                                existingSubRounds.append(messageRound)
                            }
                        }
                        
                        parentRounds[lastParentRoundIndex].subAgentRounds = existingSubRounds
                        parentMessage.editAgentRounds = parentRounds
                    }
                }
                
                history[parentIndex] = parentMessage
            } else if let index = history.firstIndex(where: { $0.id == message.id }) {
                history[index].mergeMessage(with: message)
            } else {
                history.append(message)
            }
        }
    }

    /// Remove a message from the history.
    func removeMessage(_ id: String) async {
        await mutateHistory {
            $0.removeAll { $0.id == id }
        }
    }
    
    /// Remove multiple messages from the history by their IDs.
    func removeMessages(_ ids: [String]) async {
        await mutateHistory { history in
            history.removeAll { message in
                ids.contains(message.id)
            }
        }
    }

    /// Clear the history.
    func clearHistory() async {
        await mutateHistory { $0.removeAll() }
    }
}

extension ChatMessage {
    mutating func mergeMessage(with message: ChatMessage) {
        self.content = self.content + message.content
        
        var seen = Set<ConversationReference>()
        self.references = (self.references + message.references).filter { seen.insert($0).inserted }
        
        self.followUp = message.followUp ?? self.followUp
        
        self.suggestedTitle = message.suggestedTitle ?? self.suggestedTitle
        
        self.errorMessages = self.errorMessages + message.errorMessages
        
        self.panelMessages = self.panelMessages + message.panelMessages
        
        if !message.steps.isEmpty {
            var mergedSteps = self.steps
            
            for newStep in message.steps {
                if let index = mergedSteps.firstIndex(where: { $0.id == newStep.id }) {
                    mergedSteps[index] = newStep
                } else {
                    mergedSteps.append(newStep)
                }
            }
            
            self.steps = mergedSteps
        }
        
        if !message.editAgentRounds.isEmpty {
            let mergedAgentRounds = mergeEditAgentRounds(
                oldRounds: self.editAgentRounds, 
                newRounds: message.editAgentRounds
            )
            
            self.editAgentRounds = mergedAgentRounds
        }
        
        self.parentTurnId = message.parentTurnId ?? self.parentTurnId
        
        self.codeReviewRound = message.codeReviewRound
        
        self.fileEdits = mergeFileEdits(oldEdits: self.fileEdits, newEdits: message.fileEdits)
        
        self.turnStatus = message.turnStatus ?? self.turnStatus
        
        // merge modelName and billingMultiplier
        self.modelName = message.modelName ?? self.modelName
        self.billingMultiplier = message.billingMultiplier ?? self.billingMultiplier
    }
    
    private func mergeEditAgentRounds(oldRounds: [AgentRound], newRounds: [AgentRound]) -> [AgentRound] {
        var mergedAgentRounds = oldRounds
        
        for newRound in newRounds {
            if let index = mergedAgentRounds.firstIndex(where: { $0.roundId == newRound.roundId }) {
                mergedAgentRounds[index].reply = mergedAgentRounds[index].reply + newRound.reply
                
                if newRound.toolCalls != nil, !newRound.toolCalls!.isEmpty {
                    var mergedToolCalls = mergedAgentRounds[index].toolCalls ?? []
                    for newToolCall in newRound.toolCalls! {
                        if let toolCallIndex = mergedToolCalls.firstIndex(where: { $0.id == newToolCall.id }) {
                            mergedToolCalls[toolCallIndex].status = newToolCall.status
                            if let progressMessage = newToolCall.progressMessage, !progressMessage.isEmpty {
                                mergedToolCalls[toolCallIndex].progressMessage = newToolCall.progressMessage
                            }
                            if let result = newToolCall.result, !result.isEmpty {
                                mergedToolCalls[toolCallIndex].result = result
                            }
                            if let resultDetails = newToolCall.resultDetails, !resultDetails.isEmpty {
                                mergedToolCalls[toolCallIndex].resultDetails = resultDetails
                            }
                            if let error = newToolCall.error, !error.isEmpty {
                                mergedToolCalls[toolCallIndex].error = newToolCall.error
                            }
                            if let invokeParams = newToolCall.invokeParams {
                                mergedToolCalls[toolCallIndex].invokeParams = invokeParams
                            }
                        } else {
                            mergedToolCalls.append(newToolCall)
                        }
                    }
                    mergedAgentRounds[index].toolCalls = mergedToolCalls
                }
                
                if let newSubAgentRounds = newRound.subAgentRounds, !newSubAgentRounds.isEmpty {
                    var mergedSubRounds = mergedAgentRounds[index].subAgentRounds ?? []
                    for newSubRound in newSubAgentRounds {
                        if let subIndex = mergedSubRounds.firstIndex(where: { $0.roundId == newSubRound.roundId }) {
                            mergedSubRounds[subIndex].reply = mergedSubRounds[subIndex].reply + newSubRound.reply
                            
                            if let subToolCalls = newSubRound.toolCalls, !subToolCalls.isEmpty {
                                var mergedSubToolCalls = mergedSubRounds[subIndex].toolCalls ?? []
                                for newSubToolCall in subToolCalls {
                                    if let toolCallIndex = mergedSubToolCalls.firstIndex(where: { $0.id == newSubToolCall.id }) {
                                        mergedSubToolCalls[toolCallIndex].status = newSubToolCall.status
                                        if let progressMessage = newSubToolCall.progressMessage, !progressMessage.isEmpty {
                                            mergedSubToolCalls[toolCallIndex].progressMessage = newSubToolCall.progressMessage
                                        }
                                        if let error = newSubToolCall.error, !error.isEmpty {
                                            mergedSubToolCalls[toolCallIndex].error = newSubToolCall.error
                                        }
                                        if let result = newSubToolCall.result, !result.isEmpty {
                                            mergedSubToolCalls[toolCallIndex].result = result
                                        }
                                        if let resultDetails = newSubToolCall.resultDetails, !resultDetails.isEmpty {
                                            mergedSubToolCalls[toolCallIndex].resultDetails = resultDetails
                                        }
                                        if let invokeParams = newSubToolCall.invokeParams {
                                            mergedSubToolCalls[toolCallIndex].invokeParams = invokeParams
                                        }
                                    } else {
                                        mergedSubToolCalls.append(newSubToolCall)
                                    }
                                }
                                mergedSubRounds[subIndex].toolCalls = mergedSubToolCalls
                            }
                        } else {
                            mergedSubRounds.append(newSubRound)
                        }
                    }
                    mergedAgentRounds[index].subAgentRounds = mergedSubRounds
                }
            } else {
                mergedAgentRounds.append(newRound)
            }
        }
        
        return mergedAgentRounds
    }
    
    private func mergeFileEdits(oldEdits: [FileEdit], newEdits: [FileEdit]) -> [FileEdit] {
        var edits = oldEdits
        
        for newEdit in newEdits {
            if let index = edits.firstIndex(
                where: { $0.fileURL == newEdit.fileURL && $0.toolName == newEdit.toolName }
            ) {
                edits[index].modifiedContent = newEdit.modifiedContent
                edits[index].status = newEdit.status
            } else {
                edits.append(newEdit)
            }
        }
        
        return edits
    }
}
