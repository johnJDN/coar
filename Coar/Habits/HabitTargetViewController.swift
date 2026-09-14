import SwiftUI
import UIKit
import os

/// The change-target sheet, presented from a Habit's detail. Hosts `HabitTargetForm` per
/// ADR 0001; Save writes a new dated target record effective today (ADR 0003), so past Days
/// keep the target that applied then.
final class HabitTargetViewController: UIHostingController<HabitTargetForm> {

    private static let logger = Logger(category: "Habits")

    private let dependencies: AppDependencies
    private let habitID: HabitRecord.ID
    private let current: HabitTargetDraft
    private let onSaved: () -> Void
    private var draft: HabitTargetDraft
    private let saveItem = UIBarButtonItem(systemItem: .save)

    init(dependencies: AppDependencies, habit: HabitRecord, target: HabitTargetRecord?, onSaved: @escaping () -> Void) {
        self.dependencies = dependencies
        habitID = habit.id
        current = HabitTargetDraft(kind: habit.kind, period: target?.period ?? .day, typedAmount: target?.amount)
        draft = current
        self.onSaved = onSaved
        super.init(rootView: HabitTargetForm(draft: current) { _ in })
        rootView = HabitTargetForm(draft: current) { [weak self] in self?.draftChanged($0) }
        title = "Change Target"
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        saveItem.primaryAction = UIAction(title: "Save") { [weak self] _ in self?.save() }
        saveItem.isEnabled = false
        navigationItem.rightBarButtonItem = saveItem
    }

    @available(*, unavailable)
    @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.background
    }

    /// The sheet the detail presents.
    static func sheet(dependencies: AppDependencies, habit: HabitRecord, target: HabitTargetRecord?, onSaved: @escaping () -> Void) -> UIViewController {
        HabitTargetViewController(dependencies: dependencies, habit: habit, target: target, onSaved: onSaved)
            .inSheet(detents: [.medium(), .large()])
    }

    private func draftChanged(_ draft: HabitTargetDraft) {
        self.draft = draft
        saveItem.isEnabled = draft.amount != nil && (draft.amount != current.amount || draft.period != current.period)
    }

    private func save() {
        guard let amount = draft.amount else { return }
        do {
            try dependencies.store.setHabitTarget(habitID, amount: amount, period: draft.period)
            onSaved()
            dismiss(animated: true)
        } catch {
            Self.logger.error("Failed to change target: \(error, privacy: .public)")
        }
    }
}
