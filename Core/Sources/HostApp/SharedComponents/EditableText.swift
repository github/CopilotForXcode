import SwiftUI
import Perception

struct EditableText: View {
    let title: String
    let initialText: String
    let onCommit: (String) -> Bool

    @State private var text: String
    @State private var lastCommittedText: String
    @State private var isReverting: Bool = false

    init(_ title: String, text: String, onCommit: @escaping (String) -> Bool) {
        self.title = title
        self.initialText = text
        self._text = State(initialValue: text)
        self._lastCommittedText = State(initialValue: text)
        self.onCommit = onCommit
    }

    var body: some View {
        TextField(title, text: $text, onEditingChanged: { editing in
            if !editing {
                commit()
            }
        })
        .onSubmit {
            commit()
        }
        .onChange(of: initialText) { newValue in
            if text != newValue {
                text = newValue
            }
            if lastCommittedText != newValue {
                lastCommittedText = newValue
            }
        }
    }

    private func commit() {
        guard !isReverting else { return }
        guard text != lastCommittedText else { return }
        
        if onCommit(text) {
            lastCommittedText = text
        } else {
            isReverting = true
            // Async revert to ensure textField updates even during focus change
            DispatchQueue.main.async {
                text = lastCommittedText
                isReverting = false
            }
        }
    }
}
