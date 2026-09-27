import UIKit
import os

/// A finished Workout, pushed from the month grid or Recent workouts: the Plan's name as the
/// title, when it ran, and one `Card` per Exercise row listing its Logged Sets in the
/// display unit (ADR 0004); an Activity shows its duration, distance, and notes instead.
/// Edit opens the logger in editing mode (an Activity: its sheet), for fixing what was
/// logged; the `…` menu deletes it, with a confirmation.
final class WorkoutDetailViewController: ScreenViewController {

    private static let logger = Logger(category: "Train")

    private let dependencies: AppDependencies
    private let workoutID: WorkoutRecord.ID
    private var workout: WorkoutRecord?
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
        let edit = UIBarButtonItem(title: "Edit", primaryAction: UIAction(title: "Edit") { [weak self] _ in self?.edit() })
        navigationItem.rightBarButtonItems = [edit, more]
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
            self.workout = read
        } catch {
            Self.logger.error("Failed to read Workout: \(error, privacy: .public)")
            return
        }
        let unit = dependencies.preferences.massUnit
        title = workout.title
        navigationItem.subtitle = TrainText.when(workout)

        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if let activity = workout.activity {
            contentStack.addArrangedSubview(Self.activityCard(activity, duration: workout.duration, distanceUnit: DistanceUnit(unit)))
            return
        }
        if workout.exercises.isEmpty {
            contentStack.addArrangedSubview(CardView.emptyState(caption: "No sets were logged.", accessibilityLabel: "No sets were logged."))
        }
        for row in workout.exercises {
            let subtitle = [workout.supersetLabel(for: row.id), TrainText.count(row.sets.count, "set")].compactMap { $0 }.joined(separator: " · ")
            contentStack.addArrangedSubview(CardView.setHistory(title: row.name, subtitle: subtitle, sets: row.sets, in: unit))
        }
    }

    /// A row per fact: how long, how far (when entered), and the note (when written).
    private static func activityCard(_ activity: WorkoutActivity, duration: TimeInterval?, distanceUnit: DistanceUnit) -> UIView {
        let card = CardView(title: "Activity", systemImage: "figure.run", iconTint: UIColor.accentGreen)
        var facts: [(String, String)] = []
        if let duration {
            facts.append(("Duration", TrainText.duration(minutes: Int((duration / 60).rounded()))))
        }
        if let meters = activity.distanceMeters {
            facts.append(("Distance", distanceUnit.text(meters: meters)))
        }
        for (label, value) in facts {
            let name = UILabel()
            name.text = label
            name.font = UIFont.bodyText
            name.textColor = UIColor.textSecondary
            name.adjustsFontForContentSizeCategory = true
            let number = UILabel()
            number.text = value
            number.font = UIFont.metricNumber
            number.textColor = UIColor.textPrimary
            number.adjustsFontForContentSizeCategory = true
            number.setContentHuggingPriority(.required, for: .horizontal)
            let row = UIStackView(arrangedSubviews: [name, number])
            row.axis = .horizontal
            row.alignment = .firstBaseline
            card.contentStack.addArrangedSubview(row)
        }
        if let notes = activity.notes {
            let label = UILabel()
            label.text = notes
            label.font = UIFont.bodyText
            label.textColor = UIColor.textPrimary
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
            card.contentStack.addArrangedSubview(label)
        }
        return card
    }

    private func edit() {
        guard let workout else { return }
        if workout.activity != nil {
            present(PastWorkoutViewController.sheet(dependencies: dependencies, purpose: .editActivity(workout), onChange: { [weak self] in self?.render() }), animated: true)
        } else {
            navigationController?.pushViewController(WorkoutLoggerViewController(dependencies: dependencies, workoutID: workoutID, mode: .editing), animated: true)
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
}
