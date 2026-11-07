import Foundation

/// Walks on the Train calendar (`.scratch/walks/issues/02`): every walk the Watch recorded,
/// indoors or out, read live for the month on show. A walk linked to a Workout is that
/// Workout, as on the Day page, so it isn't a walk here too.
enum CalendarWalks {

    /// What tapping a Day opens.
    enum Tap: Equatable {
        case logPastWorkout
        case workout(WorkoutRecord)
        case walk(HealthWorkout)
        case list
    }

    /// The walks of each Day, earliest first.
    static func byDay(_ healthWorkouts: [HealthWorkout], linked: Set<UUID>, in calendar: Calendar = .current) -> [Day: [HealthWorkout]] {
        let walks = healthWorkouts.filter { $0.isWalk && !linked.contains($0.id) }.sorted { $0.start < $1.start }
        return Dictionary(grouping: walks) { Day($0.start, in: calendar) }
    }

    /// One thing on the Day opens it; several open the Day's list; none offers to log.
    static func tap(workouts: [WorkoutRecord], walks: [HealthWorkout]) -> Tap {
        switch (workouts.first, walks.first, workouts.count + walks.count) {
        case (nil, nil, _): .logPastWorkout
        case (let workout?, _, 1): .workout(workout)
        case (_, let walk?, 1): .walk(walk)
        default: .list
        }
    }
}
