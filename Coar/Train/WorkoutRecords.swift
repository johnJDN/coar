import Foundation

/// A Workout as read through the façade (CONTEXT.md "Workout"): one training session on a
/// Day, holding its own copy of the Exercises performed and their Logged Sets (ADR 0003).
/// Active while `finishedAt` is nil (CONTEXT.md "Active Workout").
struct WorkoutRecord: Hashable, Identifiable {
    let id: UUID
    let startedAt: Date
    let day: Day
    let finishedAt: Date?
    /// The Plan it was started from, for grouping; nil for an empty Workout or once the
    /// Plan is gone.
    let planID: PlanRecord.ID?
    /// The Plan's name as it stands now; nil when there is no Plan.
    let planName: String?
    let exercises: [WorkoutExerciseRecord]
    let modifiedAt: Date

    var isActive: Bool { finishedAt == nil }

    /// "Push", or "Empty workout" when it was not started from a Plan.
    var title: String { planName ?? "Empty workout" }

    /// An Active Workout left this long is offered finish or discard on launch rather than
    /// carried on: the app never guesses the user's numbers.
    static let staleAfter: TimeInterval = 12 * 60 * 60

    func isStale(at now: Date) -> Bool {
        isActive && now.timeIntervalSince(startedAt) >= Self.staleAfter
    }

    var completedSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    var uncompletedSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter { !$0.isCompleted }.count }
    }
}

/// One Exercise row of a Workout: the name as it was when the row was made, the Exercise it
/// came from (for Progression), its Superset group, its rest default, and its Logged Sets.
struct WorkoutExerciseRecord: Hashable, Identifiable {
    let id: UUID
    let name: String
    /// Nil once the Exercise has been deleted; the row keeps its name regardless.
    let exerciseID: ExerciseRecord.ID?
    let supersetGroup: Int?
    let restSeconds: Int?
    let sets: [LoggedSetRecord]
}

/// A Logged Set as read through the façade (CONTEXT.md "Logged Set"): the weight in
/// kilograms (ADR 0004) and the reps, whether it has been completed, and the Planned Set it
/// was pre-filled from when it has one.
struct LoggedSetRecord: Hashable, Identifiable {
    let id: UUID
    let kilograms: Double
    let reps: Int
    let isCompleted: Bool
    let target: SetTarget?
}

/// A Planned Set's target as copied into a Workout at start (ADR 0003).
struct SetTarget: Hashable {
    let kilograms: Double
    let reps: RepRange
}
