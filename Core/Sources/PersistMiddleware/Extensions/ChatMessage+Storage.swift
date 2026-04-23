import Foundation
import ChatAPIService
import Persist
import Logger
import ConversationServiceProvider

extension ChatMessage {
    
    struct TurnItemData: Codable {
        var content: String
        var contentImageReferences: [ImageReference]
        var rating: ConversationRating
        var references: [ConversationReference]
        var followUp: ConversationFollowUp?
        var suggestedTitle: String?
        var errorMessages: [String] = []
        var steps: [ConversationProgressStep]
        var editAgentRounds: [AgentRound]
        var parentTurnId: String?
        var panelMessages: [CopilotShowMessageParams]
        var fileEdits: [FileEdit]
        var turnStatus: ChatMessage.TurnStatus?
        let requestType: RequestType
        var modelName: String?
        var billingMultiplier: Float?

        // Custom decoder to provide default value for steps
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            content = try container.decode(String.self, forKey: .content)
            contentImageReferences = try container.decodeIfPresent([ImageReference].self, forKey: .contentImageReferences) ?? []
            rating = try container.decode(ConversationRating.self, forKey: .rating)
            references = try container.decode([ConversationReference].self, forKey: .references)
            followUp = try container.decodeIfPresent(ConversationFollowUp.self, forKey: .followUp)
            suggestedTitle = try container.decodeIfPresent(String.self, forKey: .suggestedTitle)
            errorMessages = try container.decodeIfPresent([String].self, forKey: .errorMessages) ?? []
            steps = try container.decodeIfPresent([ConversationProgressStep].self, forKey: .steps) ?? []
            editAgentRounds = try container.decodeIfPresent([AgentRound].self, forKey: .editAgentRounds) ?? []
            parentTurnId = try container.decodeIfPresent(String.self, forKey: .parentTurnId)
            panelMessages = try container.decodeIfPresent([CopilotShowMessageParams].self, forKey: .panelMessages) ?? []
            fileEdits = try container.decodeIfPresent([FileEdit].self, forKey: .fileEdits) ?? []
            turnStatus = try container.decodeIfPresent(ChatMessage.TurnStatus.self, forKey: .turnStatus)
            requestType = try container.decodeIfPresent(RequestType.self, forKey: .requestType) ?? .conversation
            modelName = try container.decodeIfPresent(String.self, forKey: .modelName)
            billingMultiplier = try container.decodeIfPresent(Float.self, forKey: .billingMultiplier)
        }

        // Default memberwise init for encoding
        init(
            content: String,
            contentImageReferences: [ImageReference]? = nil,
            rating: ConversationRating,
            references: [ConversationReference],
            followUp: ConversationFollowUp?,
            suggestedTitle: String?,
            errorMessages: [String] = [],
            steps: [ConversationProgressStep]?,
            editAgentRounds: [AgentRound]? = nil,
            parentTurnId: String? = nil,
            panelMessages: [CopilotShowMessageParams]? = nil,
            fileEdits: [FileEdit]? = nil,
            turnStatus: ChatMessage.TurnStatus? = nil,
            requestType: RequestType = .conversation,
            modelName: String? = nil,
            billingMultiplier: Float? = nil
        ) {
            self.content = content
            self.contentImageReferences = contentImageReferences ?? []
            self.rating = rating
            self.references = references
            self.followUp = followUp
            self.suggestedTitle = suggestedTitle
            self.errorMessages = errorMessages
            self.steps = steps ?? []
            self.editAgentRounds = editAgentRounds ?? []
            self.parentTurnId = parentTurnId
            self.panelMessages = panelMessages ?? []
            self.fileEdits = fileEdits ?? []
            self.turnStatus = turnStatus
            self.requestType = requestType
            self.modelName = modelName
            self.billingMultiplier = billingMultiplier
        }
    }
    
    func toTurnItem() -> TurnItem {
        let turnItemData = TurnItemData(
            content: self.content,
            contentImageReferences: self.contentImageReferences,
            rating: self.rating,
            references: self.references,
            followUp: self.followUp,
            suggestedTitle: self.suggestedTitle,
            errorMessages: self.errorMessages,
            steps: self.steps,
            editAgentRounds: self.editAgentRounds,
            parentTurnId: self.parentTurnId,
            panelMessages: self.panelMessages,
            fileEdits: self.fileEdits,
            turnStatus: self.turnStatus,
            requestType: self.requestType,
            modelName: self.modelName,
            billingMultiplier: self.billingMultiplier
        )
        
        // TODO: handle exception
        let encoder = JSONEncoder()
        let encodeData = (try? encoder.encode(turnItemData)) ?? Data()
        let data = String(data: encodeData, encoding: .utf8) ?? "{}"
        
        return TurnItem(id: self.id, conversationID: self.chatTabID, CLSTurnID: self.clsTurnID, role: role.rawValue, data: data, createdAt: self.createdAt, updatedAt: self.updatedAt)
    }
    
    static func from(_ turnItem: TurnItem) -> ChatMessage? {
        var chatMessage: ChatMessage? = nil
                
        do {
            if let jsonData = turnItem.data.data(using: .utf8) {
                let decoder = JSONDecoder()
                let turnItemData = try decoder.decode(TurnItemData.self, from: jsonData)
                
                chatMessage = .init(
                    id: turnItem.id,
                    chatTabID: turnItem.conversationID,
                    clsTurnID: turnItem.CLSTurnID,
                    role: ChatMessage.Role(rawValue: turnItem.role)!,
                    content: turnItemData.content,
                    contentImageReferences: turnItemData.contentImageReferences,
                    references: turnItemData.references,
                    followUp: turnItemData.followUp,
                    suggestedTitle: turnItemData.suggestedTitle,
                    errorMessages: turnItemData.errorMessages,
                    rating: turnItemData.rating,
                    steps: turnItemData.steps,
                    editAgentRounds: turnItemData.editAgentRounds,
                    parentTurnId: turnItemData.parentTurnId,
                    panelMessages: turnItemData.panelMessages,
                    fileEdits: turnItemData.fileEdits,
                    turnStatus: turnItemData.turnStatus,
                    requestType: turnItemData.requestType,
                    modelName: turnItemData.modelName,
                    billingMultiplier: turnItemData.billingMultiplier,
                    createdAt: turnItem.createdAt,
                    updatedAt: turnItem.updatedAt
                )
            }
        } catch {
            Logger.client.error("Failed to restore chat message: \(error)")
        }
        
        return chatMessage
    }
}

extension Array where Element == ChatMessage {
    func toTurnItems() -> [TurnItem] {
        return self.map { $0.toTurnItem() }
    }
}
