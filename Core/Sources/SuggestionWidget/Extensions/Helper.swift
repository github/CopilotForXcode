import AppKit

struct LocationStrategyHelper {
    
    /// `lineNumber` is 0-based
    ///
    /// - Parameters:
    ///    - length: If specified, use this length instead of the actual line length. Useful when you want to get the exact line height and y that ignores the unwrappded lines.
    static func getLineFrame(
        _ lineNumber: Int,
        in editor: AXUIElement,
        with lines: [String],
        length: Int? = nil
    ) -> CGRect? {
        guard editor.isSourceEditor,
              lineNumber < lines.count && lineNumber >= 0
        else {
            return nil
        }
        
        var characterPosition = 0
        for i in 0..<lineNumber {
            // +1 for newline character
            characterPosition += lines[i].count + 1
        }
        
        let rangeLength: Int = {
            if let length {
                return min(length, lines[lineNumber].count)
            } else {
                return lines[lineNumber].count
            }
        }()
        
        var range = CFRange(location: characterPosition, length: rangeLength)
        guard let rangeValue = AXValueCreate(AXValueType.cfRange, &range) else {
            return nil
        }
        
        guard let boundsValue: AXValue = try? editor.copyParameterizedValue(
            key: kAXBoundsForRangeParameterizedAttribute,
            parameters: rangeValue
        ) else {
            return nil
        }
        
        var rect = CGRect.zero
        let success = AXValueGetValue(boundsValue, .cgRect, &rect)
        
        return success ? rect : nil
    }
}
