import UIKit

/// How every number field in the app behaves once it begins editing, as one app-wide rule
/// rather than per-field code. SwiftUI `TextField`s are backed by `UITextField`, so
/// observing begin-editing reaches both halves (ADR 0001). A number field is any
/// `UITextField` with a number or decimal pad.
///
/// - Its whole contents are selected, so typing replaces the value ("3" over a "1" is 3,
///   never 31) and tapping away keeps it.
/// - A UIKit field gets a keyboard bar with Done, because number pads have no return key
///   and the keyboard could otherwise only be dismissed by scrolling. A field that already
///   has its own accessory view keeps it. SwiftUI's fields ignore an accessory attached this
///   way (seen in the simulator, though the property reads back set), so SwiftUI forms add
///   `keyboardDoneBar()` themselves.
enum NumberFieldBehavior {

    private static var observer: NSObjectProtocol?

    static func install() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UITextField.textDidBeginEditingNotification, object: nil, queue: .main
        ) { note in
            guard let field = note.object as? UITextField, isNumberField(field) else { return }
            MainActor.assumeIsolated { attachDoneBar(to: field) }
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

    @MainActor static func attachDoneBar(to field: UITextField) {
        guard field.inputAccessoryView == nil else { return }
        field.inputAccessoryView = doneBar(for: field)
        field.reloadInputViews()
    }

    /// A keyboard bar with Done at the trailing edge that dismisses the keyboard.
    @MainActor static func doneBar(for field: UITextField) -> UIToolbar {
        let bar = UIToolbar()
        bar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak field] _ in field?.resignFirstResponder() }),
        ]
        bar.sizeToFit()
        return bar
    }
}

extension UICollectionView {
    /// Dragging the list dismisses the keyboard, following the finger (DESIGN.md: every
    /// screen with text input). Bounces even when the content is shorter than the screen,
    /// so a short form can still be dragged.
    func dismissesKeyboardOnDrag() {
        keyboardDismissMode = .interactive
        alwaysBounceVertical = true
    }
}

import SwiftUI

extension View {
    /// A keyboard bar with Done for a SwiftUI form. SwiftUI drives the keyboard of its own
    /// text fields and ignores an accessory view attached from UIKit, so its forms declare
    /// the bar here instead; `NumberFieldBehavior` then finds the field's accessory taken
    /// and leaves it. Done ends editing whichever field has focus.
    func keyboardDoneBar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
    }
}
