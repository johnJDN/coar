import UIKit

/// Delete permanently, offered only on archived things (DESIGN.md §7b): a coral trash button
/// beside Restore, and an action sheet that says what goes with it before anything is lost.
/// Archive stays the everyday way to tidy up; this is for clearing out for good.
enum DeletePermanently {

    /// The grey Restore capsule the trash sits after.
    static func restoreButton(for name: String, action: @escaping () -> Void) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Restore"
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor.fill
        configuration.baseForegroundColor = UIColor.textPrimary
        configuration.buttonSize = .small
        let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in action() })
        button.accessibilityLabel = "Restore \(name)"
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    /// The small capsule trash button that sits after Restore.
    static func button(for name: String, action: @escaping () -> Void) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.image = UIImage(systemName: "trash")
        configuration.cornerStyle = .capsule
        configuration.baseBackgroundColor = UIColor.fill
        configuration.baseForegroundColor = UIColor.accentCoral
        configuration.buttonSize = .small
        let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in action() })
        button.accessibilityLabel = "Delete \(name) permanently"
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    /// "Delete Eggs?", what else changes, "This cannot be undone.", then Delete permanently.
    static func confirmation(name: String, consequences: [String], onDelete: @escaping () -> Void) -> UIAlertController {
        let alert = UIAlertController(
            title: "Delete \(name)?",
            message: (consequences + ["This cannot be undone."]).joined(separator: " "),
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "Delete permanently", style: .destructive) { _ in onDelete() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        return alert
    }

    /// "Push", "Push and Pull", "Legs, Push and Pull".
    static func list(_ names: [String]) -> String {
        ListFormatter.localizedString(byJoining: names)
    }
}
