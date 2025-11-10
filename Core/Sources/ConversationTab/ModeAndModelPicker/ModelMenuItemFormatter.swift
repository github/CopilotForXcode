import AppKit
import Foundation

public struct ScopeCache {
    var modelMultiplierCache: [String: String] = [:]
    var cachedMaxWidth: CGFloat = 0
    var lastModelsHash: Int = 0
}

// MARK: - Model Menu Item Formatting
public struct ModelMenuItemFormatter {
    public static let minimumPadding: Int = 48

    public static let attributes: [NSAttributedString.Key: NSFont] = [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]
    
    public static var spaceWidth: CGFloat {
        "\u{200A}".size(withAttributes: attributes).width
    }

    public static var minimumPaddingWidth: CGFloat {
        spaceWidth * CGFloat(minimumPadding)
    }

    /// Creates an attributed string for model menu items with proper spacing and formatting
    public static func createModelMenuItemAttributedString(
        modelName: String,
        isSelected: Bool,
        multiplierText: String,
        targetWidth: CGFloat? = nil
    ) -> AttributedString {
        let displayName = isSelected ? "✓ \(modelName)" : "    \(modelName)"

        var fullString = displayName
        var attributedString = AttributedString(fullString)

        if !multiplierText.isEmpty {
            let displayNameWidth = displayName.size(withAttributes: attributes).width
            let multiplierTextWidth = multiplierText.size(withAttributes: attributes).width

            // Calculate padding needed
            let neededPaddingWidth: CGFloat
            
            if let targetWidth = targetWidth {
                neededPaddingWidth = targetWidth - displayNameWidth - multiplierTextWidth
            } else {
                neededPaddingWidth = minimumPaddingWidth
            }
            
            let finalPaddingWidth = max(neededPaddingWidth, minimumPaddingWidth)
            let numberOfSpaces = Int(round(finalPaddingWidth / spaceWidth))
            let padding = String(repeating: "\u{200A}", count: max(minimumPadding, numberOfSpaces))
            fullString = "\(displayName)\(padding)\(multiplierText)"

            attributedString = AttributedString(fullString)

            if let range = attributedString.range(
                of: multiplierText,
                options: .backwards
            ) {
                attributedString[range].foregroundColor = .secondary
            }
        }

        return attributedString
    }
    
    /// Gets the multiplier text for a model (e.g., "2x", "Included", provider name, or "Variable")
    public static func getMultiplierText(for model: LLMModel) -> String {
        if model.isAutoModel {
            return "Variable"
        } else if let billing = model.billing {
            let multiplier = billing.multiplier
            if multiplier == 0 {
                return "Included"
            } else {
                let numberPart = multiplier.truncatingRemainder(dividingBy: 1) == 0
                    ? String(format: "%.0f", multiplier)
                    : String(format: "%.2f", multiplier)
                return "\(numberPart)x"
            }
        } else if let providerName = model.providerName, !providerName.isEmpty {
            return providerName
        } else {
            return ""
        }
    }
}
