import Foundation

/// Progression (CONTEXT.md): how one Exercise has moved over time, as Estimated 1RM per
/// Workout. Estimated 1RM is Epley, w × (1 + r/30); a Workout's value is the best one among
/// its completed Logged Sets of the Exercise. Pure rule functions: records in, values out.
enum Progression {

    /// One Workout's value: the best Estimated 1RM it holds for the Exercise.
    struct Point: Hashable, Identifiable {
        let workoutID: WorkoutRecord.ID
        /// When the Workout started, so two on one Day still stand apart.
        let date: Date
        let kilograms: Double
        var id: WorkoutRecord.ID { workoutID }
    }

    /// Epley: the single-rep maximum a set's weight and reps imply.
    static func estimatedOneRepMax(kilograms: Double, reps: Int) -> Double {
        kilograms * (1 + Double(reps) / 30)
    }

    /// The highest Estimated 1RM among the completed sets; nil when none counts. A set with
    /// no weight lifted or no reps says nothing about a single-rep max and is skipped.
    static func best(of sets: [LoggedSetRecord]) -> Double? {
        sets.lazy
            .filter { $0.isCompleted && $0.kilograms > 0 && $0.reps > 0 }
            .map { estimatedOneRepMax(kilograms: $0.kilograms, reps: $0.reps) }
            .max()
    }

    /// One point per Workout containing the Exercise, in the order given; a Workout with no
    /// counting set of the Exercise contributes none. Every row of the Exercise in a Workout
    /// pools into that Workout's best.
    static func points(for exerciseID: ExerciseRecord.ID, in workouts: [WorkoutRecord]) -> [Point] {
        workouts.compactMap { workout in
            best(of: workout.loggedSets(of: exerciseID)).map { Point(workoutID: workout.id, date: workout.startedAt, kilograms: $0) }
        }
    }
}

extension WorkoutRecord {
    /// Every Logged Set of the Exercise across the Workout's rows, in row then set order.
    func loggedSets(of exerciseID: ExerciseRecord.ID) -> [LoggedSetRecord] {
        exercises.filter { $0.exerciseID == exerciseID }.flatMap(\.sets)
    }
}
