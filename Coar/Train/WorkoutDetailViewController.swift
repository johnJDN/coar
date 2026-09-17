import UIKit
import os

/// A finished Workout, pushed from the month grid or Recent workouts: the Plan's name as the
/// title, when it ran, and one `Card` per Exercise row listing its Logged Sets in the
/// display unit (ADR 0004). Read-only: history is a record of what happened (ADR 0003).
final class WorkoutDetailViewController: ScreenViewController {

    private static let logger = Logger(category: "Train")

    private let dependencies: AppDependencies
    private let workoutID: WorkoutRecord.ID
    private var unitObserver: NSObjectProtocol?

    init(dependencies: AppDependencies, workoutID: WorkoutRecord.ID) {
        self.dependencies = dependencies
        self.workoutID = workoutID
        super.init(title: "")
    }

    deinit {
        if let unitObserver { NotificationCenter.default.removeObserver(unitObserver) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
        unitObserver = NotificationCenter.default.addObserver(
            forName: Preferences.massUnitDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.render() }
        }
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

    /// "Sep 10 · 6:12 PM · 50 min".
    private static func subtitle(for workout: WorkoutRecord) -> String {
        var parts = [TrainText.dayText(workout.day), TrainText.timeText(workout.startedAt)]
        if let finishedAt = workout.finishedAt {
            parts.append(TrainText.duration(from: workout.startedAt, to: finishedAt))
        }
        return parts.joined(separator: " · ")
    }
}
