import CoreData
import Foundation

/// The façade's Workout surface: starting (a deep copy of the Plan, ADR 0003), logging sets
/// mid-Workout, finishing, the optional write-back to the Plan, and history by Day.
extension Store {

    /// Posted on the main queue after a Workout starts, finishes, or is discarded, with the
    /// `Store` as the object; the shell's accessory bar re-reads the Active Workout on it.
    static let activeWorkoutDidChange = Notification.Name("Store.activeWorkoutDidChange")

    // MARK: - Start

    /// Starts a Workout now: from a Plan, copying every row (name snapshot, Exercise
    /// reference, Superset group, rest default) and its Planned Sets as pre-filled Logged
    /// Sets; or empty when `planID` is nil. Saved at once, so closing the app loses nothing.
    /// While a Workout is already active there is no second one: that one is returned
    /// (CONTEXT.md "Active Workout").
    @discardableResult
    func startWorkout(from planID: PlanRecord.ID?, at now: Date = Date(), in calendar: Calendar = .current) throws -> WorkoutRecord {
        if let active = try activeWorkout() { return active }
        let workout = Workout(context: context)
        workout.id = UUID()
        workout.startedAt = now
        workout.day = Day(now, in: calendar).rawValue
        if let planID, let plan = try fetchPlan(planID) {
            workout.plan = plan
            for (position, planRow) in plan.exerciseObjects.sorted(by: Self.bySortOrder).enumerated() {
                let row = makeWorkoutExercise(from: planRow.exercise, name: planRow.exercise?.name, position: position, in: workout)
                row.supersetGroup = planRow.supersetGroup
                for (setPosition, planned) in planRow.plannedSetObjects.sorted(by: Self.bySortOrder).enumerated() {
                    let set = makeLoggedSet(position: setPosition, in: row)
                    set.targetKilograms = NSNumber(value: planned.targetKilograms)
                    set.repMin = NSNumber(value: planned.repMin)
                    set.repMax = NSNumber(value: planned.repMax)
                    set.kilograms = planned.targetKilograms
                    set.reps = planned.repMin
                }
            }
        }
        try save()
        notifyActiveWorkoutChanged()
        return WorkoutRecord(workout)!
    }

    /// The one Workout with no `finishedAt`, if any.
    func activeWorkout() throws -> WorkoutRecord? {
        let request = Workout.fetchRequest()
        request.predicate = NSPredicate(format: "finishedAt == nil")
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first.flatMap(WorkoutRecord.init)
    }

    func workout(_ id: WorkoutRecord.ID) throws -> WorkoutRecord? {
        try fetchWorkout(id).flatMap(WorkoutRecord.init)
    }

    // MARK: - Mid-Workout edits

    /// Appends an Exercise row to the Workout with its own copy of the Exercise's name and
    /// rest default and `PlanDraft.defaultSets.count` blank sets. The Plan, if any, is
    /// untouched (ADR 0003).
    func addExercise(_ exerciseID: ExerciseRecord.ID, to workoutID: WorkoutRecord.ID) throws {
        guard let workout = try fetchWorkout(workoutID), let exercise = try fetchExercise(exerciseID) else { return }
        let row = makeWorkoutExercise(from: exercise, name: exercise.name, position: workout.exerciseObjects.count, in: workout)
        for position in 0..<PlanDraft.defaultSets.count {
            makeLoggedSet(position: position, in: row)
        }
        try save()
    }

    /// Removes the row and its Logged Sets.
    func removeExercise(_ id: WorkoutExerciseRecord.ID) throws {
        guard let row = try fetchWorkoutExercise(id) else { return }
        context.delete(row)
        try save()
    }

    /// Appends a set to the row, pre-filled with the last set's weight and reps (blank when
    /// the row has none), uncompleted, with no target of its own.
    func addLoggedSet(to rowID: WorkoutExerciseRecord.ID) throws {
        guard let row = try fetchWorkoutExercise(rowID) else { return }
        let existing = row.loggedSetObjects.sorted(by: Self.bySortOrder)
        let set = makeLoggedSet(position: existing.count, in: row)
        set.kilograms = existing.last?.kilograms ?? 0
        set.reps = existing.last?.reps ?? 0
        try save()
    }

    func removeLoggedSet(_ id: LoggedSetRecord.ID) throws {
        guard let set = try fetchLoggedSet(id) else { return }
        context.delete(set)
        try save()
    }

    /// Writes what was typed for a set: the weight in kilograms (ADR 0004), the reps, and
    /// whether it is complete. Persisted at once.
    func updateLoggedSet(_ id: LoggedSetRecord.ID, kilograms: Double, reps: Int, isCompleted: Bool) throws {
        guard let set = try fetchLoggedSet(id) else { return }
        set.kilograms = kilograms
        set.reps = Int32(reps)
        set.isCompleted = isCompleted
        try save()
    }

    // MARK: - Finish

    /// Ends the Workout: Logged Sets not marked complete are deleted, so history holds only
    /// sets actually performed, and `finishedAt` is stamped. Returns the Workout as it now
    /// stands. Finishing a Workout that is already finished changes nothing.
    @discardableResult
    func finishWorkout(_ id: WorkoutRecord.ID, at now: Date = Date()) throws -> WorkoutRecord {
        guard let workout = try fetchWorkout(id) else { throw WorkoutError.notFound }
        if workout.finishedAt == nil {
            for row in workout.exerciseObjects {
                for set in row.loggedSetObjects where !set.isCompleted {
                    context.delete(set)
                }
            }
            workout.finishedAt = now
            try save()
            notifyActiveWorkoutChanged()
        }
        return WorkoutRecord(workout)!
    }

    /// The opt-in write-back offered on Finish: each completed set's weight goes to the
    /// Plan's Planned Set at the same position of the matching row (rows pair by Exercise, in
    /// order). Reps, the exercise list, and set counts are never touched; a set with no
    /// weight (0 kg) writes nothing, so a bodyweight set never blanks a target. Nothing
    /// happens when the Workout has no Plan or the Plan is gone.
    func updatePlanTargets(from workoutID: WorkoutRecord.ID) throws {
        guard let workout = try fetchWorkout(workoutID), let plan = workout.plan else { return }
        var planRows = plan.exerciseObjects.sorted(by: Self.bySortOrder)
        for row in workout.exerciseObjects.sorted(by: Self.bySortOrder) {
            guard let exercise = row.exercise,
                  let match = planRows.firstIndex(where: { $0.exercise === exercise })
            else { continue }
            let planRow = planRows.remove(at: match)
            let targets = planRow.plannedSetObjects.sorted(by: Self.bySortOrder)
            let completed = row.loggedSetObjects.sorted(by: Self.bySortOrder).filter(\.isCompleted)
            for (target, set) in zip(targets, completed) where set.kilograms > 0 {
                target.targetKilograms = set.kilograms
            }
        }
        try save()
    }

    /// Deletes the Workout and everything in it; for a mistaken start or a stale one.
    func discardWorkout(_ id: WorkoutRecord.ID) throws {
        guard let workout = try fetchWorkout(id) else { return }
        context.delete(workout)
        try save()
        notifyActiveWorkoutChanged()
    }

    // MARK: - History

    /// Every Workout on a Day, earliest started first, the Active Workout included.
    func workouts(on day: Day) throws -> [WorkoutRecord] {
        let request = Workout.fetchRequest()
        request.predicate = NSPredicate(format: "day == %@", day.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: true)]
        return try context.fetch(request).compactMap(WorkoutRecord.init)
    }

    /// The Days in the range with at least one Workout: what the month grid marks (a Day with
    /// several is marked once).
    func workoutDays(from start: Day, to end: Day) throws -> Set<Day> {
        let request = Workout.fetchRequest()
        request.predicate = NSPredicate(format: "day >= %@ AND day <= %@", start.rawValue, end.rawValue)
        return Set(try context.fetch(request).compactMap { $0.day.flatMap(Day.init(rawValue:)) })
    }

    /// Every Workout with a row for the Exercise, earliest started first: what Progression
    /// charts. The Active Workout counts too, since its completed sets are real; a Workout
    /// whose rows only carry the Exercise's name (the Exercise since deleted) does not.
    func workouts(containing exerciseID: ExerciseRecord.ID) throws -> [WorkoutRecord] {
        guard let exercise = try fetchExercise(exerciseID) else { return [] }
        let request = Workout.fetchRequest()
        request.predicate = NSPredicate(format: "ANY exercises.exercise == %@", exercise)
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: true)]
        return try context.fetch(request).compactMap(WorkoutRecord.init)
    }

    /// The latest finished Workouts, most recent first; the Active Workout is not history yet.
    func recentWorkouts(limit: Int) throws -> [WorkoutRecord] {
        let request = Workout.fetchRequest()
        request.predicate = NSPredicate(format: "finishedAt != nil")
        request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
        request.fetchLimit = limit
        return try context.fetch(request).compactMap(WorkoutRecord.init)
    }

    // MARK: - Fetches

    func fetchWorkout(_ id: WorkoutRecord.ID) throws -> Workout? {
        let request = Workout.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchWorkoutExercise(_ id: WorkoutExerciseRecord.ID) throws -> WorkoutExercise? {
        let request = WorkoutExercise.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchLoggedSet(_ id: LoggedSetRecord.ID) throws -> LoggedSet? {
        let request = LoggedSet.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    // MARK: - Object building

    private func makeWorkoutExercise(from exercise: Exercise?, name: String?, position: Int, in workout: Workout) -> WorkoutExercise {
        let row = WorkoutExercise(context: context)
        row.id = UUID()
        row.name = name ?? ""
        row.exercise = exercise
        row.restSeconds = exercise?.restSeconds
        row.sortOrder = Int32(position)
        row.workout = workout
        return row
    }

    @discardableResult
    private func makeLoggedSet(position: Int, in row: WorkoutExercise) -> LoggedSet {
        let set = LoggedSet(context: context)
        set.id = UUID()
        set.sortOrder = Int32(position)
        set.isCompleted = false
        set.workoutExercise = row
        return set
    }

    private func notifyActiveWorkoutChanged() {
        NotificationCenter.default.post(name: Self.activeWorkoutDidChange, object: self)
    }

}

enum WorkoutError: Error {
    case notFound
}

// MARK: - Records

private extension WorkoutRecord {
    init?(_ object: Workout) {
        guard let id = object.id, let startedAt = object.startedAt,
              let raw = object.day, let day = Day(rawValue: raw), let modifiedAt = object.modifiedAt
        else { return nil }
        self.init(
            id: id,
            startedAt: startedAt,
            day: day,
            finishedAt: object.finishedAt,
            planID: object.plan?.id,
            planName: object.plan?.name,
            exercises: object.exerciseRecords,
            modifiedAt: modifiedAt
        )
    }
}

extension Workout {
    var exerciseObjects: [WorkoutExercise] {
        Array(exercises as? Set<WorkoutExercise> ?? [])
    }

    /// The rows in the Workout's order.
    var exerciseRecords: [WorkoutExerciseRecord] {
        exerciseObjects.sorted(by: Store.bySortOrder).compactMap { row in
            guard let id = row.id else { return nil }
            return WorkoutExerciseRecord(
                id: id,
                name: row.name ?? "",
                exerciseID: row.exercise?.id,
                supersetGroup: row.supersetGroup?.intValue,
                restSeconds: row.restSeconds?.intValue,
                sets: row.loggedSetRecords
            )
        }
    }
}

extension WorkoutExercise {
    var loggedSetObjects: [LoggedSet] {
        Array(loggedSets as? Set<LoggedSet> ?? [])
    }

    /// The Logged Sets in the row's order.
    var loggedSetRecords: [LoggedSetRecord] {
        loggedSetObjects.sorted(by: Store.bySortOrder).compactMap { set in
            guard let id = set.id else { return nil }
            let target: SetTarget? = set.targetKilograms.map { kilograms in
                SetTarget(kilograms: kilograms.doubleValue, reps: RepRange(min: set.repMin?.intValue ?? 0, max: set.repMax?.intValue ?? 0))
            }
            return LoggedSetRecord(id: id, kilograms: set.kilograms, reps: Int(set.reps), isCompleted: set.isCompleted, target: target)
        }
    }
}
