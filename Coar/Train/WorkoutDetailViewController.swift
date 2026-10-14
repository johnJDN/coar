import UIKit
import os

/// A finished Workout, pushed from the month grid or Recent workouts: the Plan's name as the
/// title, when it ran, and one `Card` per Exercise row listing its Logged Sets in the
/// display unit (ADR 0004); an Activity shows its duration, distance, and notes instead.
/// Edit opens the logger in editing mode (an Activity: its sheet), for fixing what was
/// logged; the `…` menu unlinks its Watch workout when it has one and deletes it, with a
/// confirmation. The Apple Watch card above the sets links a Health Workout and shows its
/// effort, read live from Apple Health (`.scratch/watch-link/`).
final class WorkoutDetailViewController: ScreenViewController {

    private static let logger = Logger(category: "Train")

    private let dependencies: AppDependencies
    private let workoutID: WorkoutRecord.ID
    private var workout: WorkoutRecord?
    private var unitObservation: MassUnitObservation?
    private let watchCard = WatchLinkCardControl()
    private let moreButton = UIBarButtonItem(image: UIImage(systemName: "ellipsis"))
    private var healthTask: Task<Void, Never>?

    init(dependencies: AppDependencies, workoutID: WorkoutRecord.ID) {
        self.dependencies = dependencies
        self.workoutID = workoutID
        super.init(title: "")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        moreButton.accessibilityLabel = "More"
        updateMenu()
        let edit = UIBarButtonItem(title: "Edit", primaryAction: UIAction(title: "Edit") { [weak self] _ in self?.edit() })
        navigationItem.rightBarButtonItems = [edit, moreButton]
        watchCard.addAction(UIAction { [weak self] _ in self?.presentLinkSheet() }, for: .touchUpInside)
        watchCard.onLink = { [weak self] in self?.link($0) }
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
        updateMenu()
        contentStack.addArrangedSubview(watchCard)
        loadHealth(for: workout)
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

    // MARK: - Apple Watch

    private func updateMenu() {
        var items: [UIMenuElement] = []
        if workout?.healthWorkoutID != nil {
            items.append(UIAction(title: "Unlink Watch workout", image: UIImage(systemName: "link.badge.minus")) { [weak self] _ in self?.link(nil) })
        }
        items.append(UIAction(title: "Delete workout", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
            self?.confirmDelete()
        })
        moreButton.menu = UIMenu(children: items)
    }

    /// Reads Apple Health quietly, with no prompt: before the first link nothing comes back
    /// and the card invites one; the prompt comes with the sheet.
    private func loadHealth(for workout: WorkoutRecord) {
        healthTask?.cancel()
        watchCard.render(.loading)
        healthTask = Task { [weak self] in
            guard let self else { return }
            let reader = dependencies.healthWorkouts
            if let link = workout.healthWorkoutID {
                let found = try? await reader.healthWorkouts(withIDs: [link])[link]
                guard !Task.isCancelled else { return }
                watchCard.render(found.map { .linked($0) } ?? .linkedMissing)
            } else {
                let day = (try? await reader.healthWorkouts(on: workout.day)) ?? []
                let taken = (try? dependencies.store.linkedHealthWorkoutIDs(excluding: workout.id)) ?? []
                guard !Task.isCancelled else { return }
                let span = (start: workout.startedAt, end: workout.finishedAt ?? workout.startedAt)
                watchCard.render(.unlinked(suggestion: HealthWorkout.suggestion(for: span, among: day, alreadyLinked: taken)))
            }
        }
    }

    private func presentLinkSheet() {
        guard let workout, !workout.isActive else { return }
        present(HealthWorkoutPickerViewController.sheet(dependencies: dependencies, workout: workout, onLinked: { [weak self] in self?.render() }), animated: true)
    }

    /// Links the Health Workout, or unlinks with nil.
    private func link(_ healthWorkout: HealthWorkout?) {
        do {
            try dependencies.store.linkHealthWorkout(healthWorkout?.id, to: workoutID)
        } catch {
            Self.logger.error("Failed to link Health Workout: \(error, privacy: .public)")
            return
        }
        render()
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
