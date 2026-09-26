import UIKit
import os

/// A finished Workout, pushed from the month grid or Recent workouts: the Plan's name as the
/// title, when it ran, and one `Card` per Exercise row listing its Logged Sets in the
/// display unit (ADR 0004). Read-only: history is a record of what happened (ADR 0003).
/// The `…` menu deletes it, with a confirmation, for a Workout logged by mistake.
final class WorkoutDetailViewController: ScreenViewController {

    private static let logger = Logger(category: "Train")

    private let dependencies: AppDependencies
    private let workoutID: WorkoutRecord.ID
    private var unitObservation: MassUnitObservation?

    init(dependencies: AppDependencies, workoutID: WorkoutRecord.ID) {
        self.dependencies = dependencies
        self.workoutID = workoutID
        super.init(title: "")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        let delete = UIAction(title: "Delete workout", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
            self?.confirmDelete()
        }
        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: [delete]))
        more.accessibilityLabel = "More"
        navigationItem.rightBarButtonItem = more
        unitObservation = dependencies.preferences.observeMassUnit { [weak self] in self?.render() }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    private func render() {
        let workout: WorkoutRecord
        do {
            guard let read = try dependencies.store.workout(workoutID) else { return }
            workout = read
        } catch {
            Self.logger.error("Failed to read Workout: \(error, privacy: .public)")
            return
        }
        let unit = dependencies.preferences.massUnit
        title = workout.title
        navigationItem.subtitle = Self.subtitle(for: workout)

        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if workout.exercises.isEmpty {
            contentStack.addArrangedSubview(CardView.emptyState(caption: "No sets were logged.", accessibilityLabel: "No sets were logged."))
        }
        for row in workout.exercises {
            let subtitle = [workout.supersetLabel(for: row.id), TrainText.count(row.sets.count, "set")].compactMap { $0 }.joined(separator: " · ")
            contentStack.addArrangedSubview(CardView.setHistory(title: row.name, subtitle: subtitle, sets: row.sets, in: unit))
        }
    }

    /// Deleting removes its sets from history and from every Exercise's Progression.
    private func confirmDelete() {
        let alert = UIAlertController(
            title: "Delete this workout?",
            message: "Its sets leave your history and progression charts. This can't be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self else { return }
            do {
                try dependencies.store.discardWorkout(workoutID)
            } catch {
                Self.logger.error("Failed to delete Workout: \(error, privacy: .public)")
                return
            }
            navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }

    /// "Sep 10 · 6:12 PM · 50 min".
    private static func subtitle(for workout: WorkoutRecord) -> String {
        var parts = [workout.day.shortText, TrainText.timeText(workout.startedAt)]
        if let finishedAt = workout.finishedAt {
            parts.append(TrainText.duration(from: workout.startedAt, to: finishedAt))
        }
        return parts.joined(separator: " · ")
    }
}
