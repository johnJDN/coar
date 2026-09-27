import UIKit
import os

/// The Workouts of one Day, pushed from the month grid when the Day has more than one
/// (two Workouts on a Day are allowed: an AM and a PM session both count). One card per
/// Workout, earliest first; tapping opens it, the Active Workout in the logger.
final class WorkoutsOnDayViewController: ScreenViewController {

    private static let logger = Logger(category: "Train")

    private let dependencies: AppDependencies
    private let day: Day

    init(dependencies: AppDependencies, day: Day) {
        self.dependencies = dependencies
        self.day = day
        super.init(title: day.title())
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render()
    }

    private func render() {
        let workouts: [WorkoutRecord]
        do {
            workouts = try dependencies.store.workouts(on: day)
        } catch {
            Self.logger.error("Failed to read Workouts: \(error, privacy: .public)")
            return
        }
        navigationItem.subtitle = TrainText.count(workouts.count, "workout")
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for workout in workouts {
            let card = WorkoutCardControl(workout: workout, distanceUnit: DistanceUnit(dependencies.preferences.massUnit))
            card.addAction(UIAction { [weak self] _ in self?.open(workout) }, for: .touchUpInside)
            contentStack.addArrangedSubview(card)
        }
    }

    private func open(_ workout: WorkoutRecord) {
        navigationController?.pushViewController(WorkoutScreens.screen(for: workout, dependencies: dependencies), animated: true)
    }
}

enum WorkoutScreens {
    /// The screen a Workout opens in: the logger while it is active, the read-only detail
    /// once finished.
    static func screen(for workout: WorkoutRecord, dependencies: AppDependencies) -> UIViewController {
        workout.isActive
            ? WorkoutLoggerViewController(dependencies: dependencies, workoutID: workout.id)
            : WorkoutDetailViewController(dependencies: dependencies, workoutID: workout.id)
    }
}
