import UIKit

/// Every number field in the app selects its whole contents when it begins editing, so
/// typing replaces the value ("3" over a "1" is 3, never 31) and tapping away keeps it.
/// One app-wide rule rather than per-field code: SwiftUI `TextField`s are backed by
/// `UITextField`, so observing begin-editing reaches both halves (ADR 0001). A number field
/// is any `UITextField` with a number or decimal pad.
enum NumberFieldSelection {

    private static var observer: NSObjectProtocol?

    static func install() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UITextField.textDidBeginEditingNotification, object: nil, queue: .main
        ) { note in
            guard let field = note.object as? UITextField, isNumberField(field) else { return }
            // After UIKit has placed the caret from the tap; selecting now would be undone.
            DispatchQueue.main.async { MainActor.assumeIsolated { selectAll(in: field) } }
        }
    }

    static func isNumberField(_ field: UITextField) -> Bool {
        field.keyboardType == .numberPad || field.keyboardType == .decimalPad
    }

    /// Selects by range rather than `selectAll(_:)`, which also pops the edit menu.
    @MainActor static func selectAll(in field: UITextField) {
        guard field.isFirstResponder, field.hasText else { return }
        field.selectedTextRange = field.textRange(from: field.beginningOfDocument, to: field.endOfDocument)
    }
}
