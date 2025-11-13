import SwiftUI
import ComposableArchitecture
import SharedUIComponents

struct ResponseToolBar: View {
    let id: String
    let chat: StoreOf<Chat>
    let text: String
    let message: DisplayedChatMessage
    @AppStorage(\.chatFontSize) var chatFontSize
    
    var billingMultiplier: String? {
        guard let multiplier = message.billingMultiplier else {
            return nil
        }
        let rounded = (multiplier * 100).rounded() / 100
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        let formattedMultiplier = formatter.string(from: NSNumber(value: rounded)) ?? "\(rounded)"
        return "\(formattedMultiplier)x"
    }
    
    var modelNameAndMultiplierText: String? {
        guard let modelName = message.modelName else {
            return nil
        }
        
        var text = modelName
        
        if let billingMultiplier = billingMultiplier {
            text += " • \(billingMultiplier)"
        }
        
        return text
    }
    
    var body: some View {
        HStack(spacing: 8) {
            
            if let modelNameAndMultiplierText = modelNameAndMultiplierText {
                Text(modelNameAndMultiplierText)
                    .scaledFont(size: chatFontSize - 1)
                    .lineLimit(1)
                    .foregroundColor(.secondary)
                    .help(modelNameAndMultiplierText)
            }
            
            UpvoteButton { rating in
                chat.send(.upvote(id, rating))
            }
            
            DownvoteButton { rating in
                chat.send(.downvote(id, rating))
            }
            
            CopyButton {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                chat.send(.copyCode(id))
            }
        }
    }
}
