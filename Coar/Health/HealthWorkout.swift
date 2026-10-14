import Foundation

/// A workout Apple Health holds for the user, usually one the Apple Watch recorded
/// (CONTEXT.md "Health Workout"): its kind, when it ran, and its effort. Read live and never
/// stored (ADR 0002); a Workout keeps only `id` once linked.
struct HealthWorkout: Equatable, Identifiable {
    let id: UUID
    /// "Strength training", "Run", "Pickleball"; "Workout" for a kind Coar has no name for.
    let name: String
    let start: Date
    let end: Date
    /// Active energy burned (not the resting energy of the same minutes), when Health has it.
    let activeKilocalories: Double?
    /// Average heart rate in beats per minute, when Health has it.
    let averageHeartRate: Double?

    var duration: TimeInterval { end.timeIntervalSince(start) }

    /// "320 cal", "320 cal · 118 bpm", "118 bpm"; nil with neither (CONTEXT.md "Effort").
    var effortText: String? {
        HealthWorkout.effortText(kilocalories: activeKilocalories, heartRate: averageHeartRate)
    }

    static func effortText(kilocalories: Double?, heartRate: Double?) -> String? {
        let parts = [
            kilocalories.map { "\(Int($0.rounded())) cal" },
            heartRate.map { "\(Int($0.rounded())) bpm" },
        ].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

extension HealthWorkout {

    /// The Health Workouts a finished Workout could be linked to: those on its Day that no
    /// other Workout has, best match first. A match is by how much the two overlap in time;
    /// those that don't overlap at all come after, nearest first, so a Workout logged after
    /// the fact (and timed roughly) can still be linked by hand.
    static func candidates(
        for workout: (start: Date, end: Date),
        among healthWorkouts: [HealthWorkout],
        alreadyLinked: Set<UUID>
    ) -> [HealthWorkout] {
        healthWorkouts
            .filter { !alreadyLinked.contains($0.id) }
            .map { ($0, overlap($0, workout)) }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return distance(lhs.0, workout) < distance(rhs.0, workout)
            }
            .map(\.0)
    }

    /// The one Health Workout to offer with a single tap: the only candidate that overlaps
    /// the Workout in time, and nil when there are none or several.
    static func suggestion(
        for workout: (start: Date, end: Date),
        among healthWorkouts: [HealthWorkout],
        alreadyLinked: Set<UUID>
    ) -> HealthWorkout? {
        let overlapping = candidates(for: workout, among: healthWorkouts, alreadyLinked: alreadyLinked)
            .filter { overlap($0, workout) > 0 }
        return overlapping.count == 1 ? overlapping[0] : nil
    }

    /// Seconds the Health Workout and the span share.
    private static func overlap(_ healthWorkout: HealthWorkout, _ span: (start: Date, end: Date)) -> TimeInterval {
        max(0, min(healthWorkout.end, span.end).timeIntervalSince(max(healthWorkout.start, span.start)))
    }

    /// Seconds between the two, 0 when they overlap.
    private static func distance(_ healthWorkout: HealthWorkout, _ span: (start: Date, end: Date)) -> TimeInterval {
        if healthWorkout.end < span.start { return span.start.timeIntervalSince(healthWorkout.end) }
        if healthWorkout.start > span.end { return healthWorkout.start.timeIntervalSince(span.end) }
        return 0
    }
}

/// The one reader of Health Workouts (CONTEXT.md "Health Workout"): the Watch's sessions for
/// a Day, and any by identifier, read live and never persisted (ADR 0002). Its own
/// permission, asked for when the user first links one, so reading sleep and steps never
/// shows a second prompt. Faked in tests.
protocol HealthWorkoutReader: AnyObject {
    /// Shows the system prompt for workouts, active energy, and heart rate. HealthKit shows
    /// it once; later calls return at once.
    func requestWorkoutAccess() async throws
    /// The Health Workouts that started on `day`, earliest first. Empty when there are none
    /// or the read was not allowed: HealthKit never says which.
    func healthWorkouts(on day: Day) async throws -> [HealthWorkout]
    /// The Health Workouts with these identifiers, by identifier; those Health no longer
    /// holds, or may not be read, are missing.
    func healthWorkouts(withIDs ids: [UUID]) async throws -> [UUID: HealthWorkout]
}

#if DEBUG
/// Canned Health Workouts for looking at the Watch link in a simulator, which has no Watch:
/// launch a debug build with `-FakeHealthWorkouts`. Every Day has a strength session from
/// 6:05 to 6:55 PM (matching the sample Workout) and a short morning walk; their identifiers
/// come from the Day, so a link survives a relaunch. Never used by tests.
final class DebugHealthWorkoutReader: HealthWorkoutReader {

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-FakeHealthWorkouts")
    }

    func requestWorkoutAccess() async throws {}

    func healthWorkouts(on day: Day) async throws -> [HealthWorkout] {
        let calendar = Calendar.current
        let at = { (hour: Int, minute: Int) in calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day.start(in: calendar))! }
        return [
            HealthWorkout(id: Self.id(day, 1), name: "Walk", start: at(7, 30), end: at(7, 50), activeKilocalories: 95, averageHeartRate: 92),
            HealthWorkout(id: Self.id(day, 2), name: "Strength training", start: at(18, 5), end: at(18, 55), activeKilocalories: 318.4, averageHeartRate: 118.2),
        ]
    }

    func healthWorkouts(withIDs ids: [UUID]) async throws -> [UUID: HealthWorkout] {
        let day = Day.today()
        var found: [UUID: HealthWorkout] = [:]
        for offset in -60...0 {
            for workout in try await healthWorkouts(on: day.advanced(by: offset)) where ids.contains(workout.id) {
                found[workout.id] = workout
            }
        }
        return found
    }

    private static func id(_ day: Day, _ number: Int) -> UUID {
        var bytes = Array("\(day.rawValue)#\(number)".utf8).prefix(16)
        bytes += Array(repeating: 0, count: 16 - bytes.count)
        let b = Array(bytes)
        return UUID(uuid: (b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]))
    }
}
#endif
