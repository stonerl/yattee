import Repeat
import SwiftUI
import SwiftUIIntrospect

struct FocusableSearchTextField: View {
    @ObservedObject private var state = SearchModel.shared

    var body: some View {
        SearchTextField()
        #if os(macOS)
            .introspect(.textField, on: .macOS(.v12, .v13, .v14)) { textField in
                state.textField = textField
            }
            .onAppear {
                DispatchQueue.main.async {
                    state.textField?.becomeFirstResponder()
                }
            }
        #elseif os(iOS)
            .introspect(.textField, on: .iOS(.v15, .v16, .v17)) { textField in
                state.textField = textField
            }
            .onChange(of: state.focused) { newValue in
                if newValue, let textField = state.textField, !textField.isFirstResponder {
                    textField.becomeFirstResponder()
                    textField.selectedTextRange = textField.textRange(from: textField.beginningOfDocument, to: textField.endOfDocument)
                }
            }
        #endif
    }
}
