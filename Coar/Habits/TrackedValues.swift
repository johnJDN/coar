import Foundation
import os

/// Reads a tracked Habit's values, one per Day, in the metric's own terms (`Tracked`):
/// hours asleep (by wake Day), steps, 1 for a Day with a Workout, an Entry, or a Body
/// Weight, and a macro as a percentage of that Day's Target. A Day with nothing to read has
/// no value. Covers the heatmap's weeks.
enum TrackedValues {

    private static let logger = Logger(category: "Habits")

    @MainActor
    static func load(_ tracking: HabitTracking, store: Store, health: HealthReader, today: Day) async -> [Day: Double] {
        let start = today.startOfWeek.advanced(by: -7 * (Heatmap.columns - 1))
        var days: [Day] = []
        var day = start
        while day <= today {
            days.append(day)
            day = day.advanced(by: 1)
        }
        do {
            switch tracking.metric {
            case .sleep:
                return try await health.timeAsleep(wakingOn: days).mapValues { $0 / 3_600 }
            case .steps:
                return try await health.steps(on: days).mapValues(Double.init)
            case .workouts:
                return Dictionary(uniqueKeysWithValues: try store.workoutDays(from: start, to: today).map { ($0, 1) })
            case .foodLogged:
                return try store.dailyTotals(from: start, to: today).mapValues { _ in 1 }
            case .weighIns:
                let weighed = try store.bodyWeights().map(\.day).filter { $0 >= start && $0 <= today }
                return Dictionary(weighed.map { ($0, 1) }, uniquingKeysWith: { first, _ in first })
            case .calories, .protein, .fat, .carbs:
                guard let macro = tracking.metric.macro else { return [:] }
                return percentages(of: macro, totals: try store.dailyTotals(from: start, to: today), targets: try store.targets())
            }
        } catch {
            logger.error("Failed to read \(tracking.metric.title, privacy: .public) for a tracked Habit: \(error, privacy: .public)")
            return [:]
        }
    }

    /// Each logged Day's macro as a percentage of the Target in force on it; a Day with no
    /// Target for that macro (none yet, or 0) cannot be judged and has no value.
    static func percentages(of macro: Macro, totals: [Day: Macros], targets: [TargetRecord]) -> [Day: Double] {
        totals.reduce(into: [:]) { result, entry in
            guard let target = targets.last(where: { $0.effectiveFrom <= entry.key }), target.macros[macro] > 0 else { return }
            result[entry.key] = entry.value[macro] / target.macros[macro] * 100
        }
    }
}
