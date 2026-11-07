import UIKit
import os

/// The Workouts and walks of one Day, pushed from the month grid when the Day has more than
/// one (two Workouts on a Day are allowed: an AM and a PM session both count). One card each,
/// earliest first; tapping a Workout opens it, the Active Workout in the logger, and a walk
/// its note.
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
        var cards: [WorkoutRecord.ID: WorkoutCardControl] = [:]
        for workout in workouts {
            let card = WorkoutCardControl(workout: workout, distanceUnit: DistanceUnit(dependencies.preferences.massUnit))
            card.addAction(UIAction { [weak self] _ in self?.open(workout) }, for: .touchUpInside)
            contentStack.addArrangedSubview(card)
            cards[workout.id] = card
        }
        effortTask?.cancel()
        effortTask = Task { [weak self] in
            guard let self else { return }
            let texts = await WorkoutEffort.texts(for: workouts, store: dependencies.store, reader: dependencies.healthWorkouts)
            guard !Task.isCancelled else { return }
            for (id, text) in texts { cards[id]?.showEffort(text) }
        }
        loadWalks(after: workouts)
    }

    private var effortTask: Task<Void, Never>?
    private var walksTask: Task<Void, Never>?

    /// Read after the Workouts' cards are on screen, and placed among them by time.
    private func loadWalks(after workouts: [WorkoutRecord]) {
        walksTask?.cancel()
        walksTask = Task { [weak self] in
            guard let self, let found = try? await dependencies.healthWorkouts.healthWorkouts(on: day), !Task.isCancelled else { return }
            let linked = (try? dependencies.store.linkedHealthWorkoutIDs()) ?? []
            let walks = CalendarWalks.byDay(found, linked: linked)[day] ?? []
            let notes = (try? dependencies.store.workoutNotes(for: walks.map(\.id))) ?? [:]
            var starts = workouts.map(\.startedAt)
            for walk in walks {
                let card = WalkCardControl(walk: walk, note: notes[walk.id])
                card.addAction(UIAction { [weak self] _ in self?.open(walk) }, for: .touchUpInside)
                let index = starts.firstIndex { $0 > walk.start } ?? starts.count
                starts.insert(walk.start, at: index)
                contentStack.insertArrangedSubview(card, at: index)
            }
            navigationItem.subtitle = TrainText.count(starts.count, "workout")
        }
    }

    private func open(_ walk: HealthWorkout) {
        let sheet = WorkoutNoteViewController(store: dependencies.store, workout: walk) { [weak self] in self?.render() }
        present(sheet.inSheet(detents: [.large()]), animated: true)
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
