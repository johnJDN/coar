import SwiftUI
import UIKit
import os

/// The new-habit sheet. Hosts `HabitForm` per ADR 0001; Save creates the Habit through the
/// façade with its first target in force from today.
final class HabitFormViewController: UIHostingController<HabitForm> {

    private static let logger = Logger(category: "Habits")

    private let dependencies: AppDependencies
    private let onCreated: () -> Void
    private var draft: HabitForm.Draft
    private let saveItem = UIBarButtonItem(systemItem: .save)

    /// `kind` pre-picks the kind: the Habits tab's Tracked tab starts a tracked Habit.
    init(dependencies: AppDependencies, kind: HabitKind = .yesNo, onCreated: @escaping () -> Void) {
        self.dependencies = dependencies
        self.onCreated = onCreated
        let draft = HabitForm.Draft(kind: kind)
        self.draft = draft
        super.init(rootView: HabitForm { _ in })
        rootView = HabitForm(draft: draft) { [weak self] in self?.draftChanged($0) }
        title = "New Habit"
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        saveItem.primaryAction = UIAction(title: "Save") { [weak self] _ in self?.save() }
        saveItem.isEnabled = draft.isComplete
        navigationItem.rightBarButtonItem = saveItem
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    /// The sheet the Habits tab presents.
    static func sheet(dependencies: AppDependencies, kind: HabitKind = .yesNo, onCreated: @escaping () -> Void) -> UIViewController {
        HabitFormViewController(dependencies: dependencies, kind: kind, onCreated: onCreated).inSheet(detents: [.large()])
    }

    private func draftChanged(_ draft: HabitForm.Draft) {
        self.draft = draft
        saveItem.isEnabled = draft.isComplete
    }

    private func save() {
        guard draft.isComplete, let amount = draft.target.amount else { return }
        do {
            try dependencies.store.createHabit(
                emoji: draft.resolvedEmoji, name: draft.resolvedName, kind: draft.target.kind, targetAmount: amount, period: draft.target.period,
                items: draft.namedItems, tracking: draft.target.kind == .tracked ? draft.target.tracking : nil
            )
            onCreated()
            dismiss(animated: true)
        } catch {
            Self.logger.error("Failed to create Habit: \(error, privacy: .public)")
        }
    }
}
