import Foundation

/// The rest-timer trigger (Seam 2; `docs/brief.md` "Rest timer", CONTEXT.md "Superset"):
/// completing a set starts the timer, except inside a Superset, where the timer starts only
/// after a set of the group's last Exercise, so it never fires between A1 and A2. The
/// duration is the Exercise's rest default, or 120 s when it has none.
enum RestTimerRule {

    static let fallbackSeconds = 120

    /// Whether completing a set on the row at `index` starts the timer, given every row's
    /// Superset group in Workout order. A row on its own always does; a grouped row only
    /// when no later row shares its group.
    static func starts(afterSetOn index: Int, groups: [Int?]) -> Bool {
        guard groups.indices.contains(index) else { return false }
        guard let group = groups[index] else { return true }
        return !groups[(index + 1)...].contains(group)
    }

    /// The Exercise's rest default, or 120 s when it has none.
    static func seconds(restDefault: Int?) -> Int {
        guard let restDefault, restDefault > 0 else { return fallbackSeconds }
        return restDefault
    }
}

extension WorkoutRecord {

    /// How long to rest after completing a set on `rowID`; nil when the rule says no timer
    /// (the row is not the last of its Superset, or is not in this Workout).
    func restSeconds(afterSetOn rowID: WorkoutExerciseRecord.ID) -> Int? {
        guard let index = exercises.firstIndex(where: { $0.id == rowID }),
              RestTimerRule.starts(afterSetOn: index, groups: exercises.map(\.supersetGroup))
        else { return nil }
        return RestTimerRule.seconds(restDefault: exercises[index].restSeconds)
    }
}
