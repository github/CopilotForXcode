import SwiftUI
import AppKit

public struct CollapsibleSearchField: View {
    @Binding public var searchText: String
    @Binding public var isExpanded: Bool
    public let placeholderString: String
    
    public init(
        searchText: Binding<String>,
        isExpanded: Binding<Bool>,
        placeholderString: String = "Search..."
    ) {
        self._searchText = searchText
        self._isExpanded = isExpanded
        self.placeholderString = placeholderString
    }
    
    public var body: some View {
        Group {
            if isExpanded {
                SearchFieldRepresentable(
                    searchText: $searchText,
                    isExpanded: $isExpanded,
                    placeholderString: placeholderString
                )
                .frame(width: 200, height: 24)
                .transition(.opacity)
            } else {
                Button(action: {
                    isExpanded = true
                }) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .frame(height: 24)
                .transition(.opacity)
            }
        }
    }
}

private struct SearchFieldRepresentable: NSViewRepresentable {
    @Binding var searchText: String
    @Binding var isExpanded: Bool
    let placeholderString: String
    
    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = placeholderString
        searchField.delegate = context.coordinator
        searchField.target = context.coordinator
        searchField.action = #selector(Coordinator.searchFieldDidChange(_:))
        
        // Make the magnifying glass clickable to collapse
        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.searchButtonCell?.target = context.coordinator
            cell.searchButtonCell?.action = #selector(Coordinator.magnifyingGlassClicked(_:))
        }
        
        return searchField
    }
    
    func updateNSView(_ nsView: NSSearchField, context: Context) {
        if nsView.stringValue != searchText {
            nsView.stringValue = searchText
        }
        
        context.coordinator.isExpanded = $isExpanded
        
        // Auto-focus when expanded, only if not already first responder
        if isExpanded && nsView.window?.firstResponder != nsView.currentEditor() {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(searchText: $searchText, isExpanded: $isExpanded)
    }
    
    class Coordinator: NSObject, NSSearchFieldDelegate, NSTextFieldDelegate {
        @Binding var searchText: String
        var isExpanded: Binding<Bool>
        
        init(searchText: Binding<String>, isExpanded: Binding<Bool>) {
            _searchText = searchText
            self.isExpanded = isExpanded
        }
        
        @objc func searchFieldDidChange(_ sender: NSSearchField) {
            searchText = sender.stringValue
        }
        
        @objc func magnifyingGlassClicked(_ sender: Any) {
            // Collapse when magnifying glass is clicked
            DispatchQueue.main.async { [weak self] in
                withAnimation(.easeInOut(duration: 0.2)) {
                    self?.isExpanded.wrappedValue = false
                }
            }
        }
        
        func controlTextDidEndEditing(_ obj: Notification) {
            // Collapse search field when it loses focus and text is empty
            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                DispatchQueue.main.async { [weak self] in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self?.isExpanded.wrappedValue = false
                        self?.searchText = ""
                    }
                }
            }
        }
    }
}
