import SharedUIComponents
import SwiftUI

struct ChatModelPicker: View {
    let selectedModel: LLMModel?
    let copilotModels: [LLMModel]
    let byokModels: [LLMModel]
    let isBYOKFFEnabled: Bool
    let currentCache: ScopeCache

    @StateObject private var fontScaleManager = FontScaleManager.shared

    private var fontScale: Double {
        fontScaleManager.currentScale
    }

    var body: some View {
        ModelPickerButton(
            selectedModel: selectedModel,
            copilotModels: copilotModels,
            byokModels: byokModels,
            isBYOKFFEnabled: isBYOKFFEnabled,
            currentCache: currentCache,
            fontScale: fontScale
        )
        .fixedSize(horizontal: false, vertical: true)
    }
}
