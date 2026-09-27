import Foundation

/// A Workout as read through the façade (CONTEXT.md "Workout"): one training session on a
/// Day, holding its own copy of the Exercises performed and their Logged Sets (ADR 0003),
/// or an Activity (pickleball, a run) with no sets. Active while `finishedAt` is nil
/// (CONTEXT.md "Active Workout").
struct WorkoutRecord: Hashable, Identifiable {
    let id: UUID
    let startedAt: Date
    let day: Day
    let finishedAt: Date?
    /// The Plan it was started from, for grouping; nil for an empty Workout or once the
    /// Plan is gone.
    let planID: PlanRecord.ID?
    /// The Plan's name as it stands now, or its last name once the Plan is deleted; nil
    /// for an Empty workout.
    let planName: String?
    let exercises: [WorkoutExerciseRecord]
    /// Set for an Activity (CONTEXT.md "Activity"); nil for a strength Workout.
    var activity: WorkoutActivity? = nil
    let modifiedAt: Date

    var isActive: Bool { finishedAt == nil }

    /// "Pickleball" for an Activity; "Push", or "Empty workout" when it was not started
    /// from a Plan.
    var title: String { activity?.name ?? planName ?? "Empty workout" }

    /// How long it ran; nil while active.
    var duration: TimeInterval? { finishedAt.map { $0.timeIntervalSince(startedAt) } }

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

    /// "A1", "A2" for the first Superset's rows; nil for a row on its own.
    func supersetLabel(for rowID: WorkoutExerciseRecord.ID) -> String? {
        guard let index = exercises.firstIndex(where: { $0.id == rowID }) else { return nil }
        return SupersetLabel.text(at: index, groups: exercises.map(\.supersetGroup))
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

/// What an Activity carries beyond its time: a name, and optionally how far and a note.
struct WorkoutActivity: Hashable {
    let name: String
    /// Metres; nil when none was entered.
    let distanceMeters: Double?
    let notes: String?
}
