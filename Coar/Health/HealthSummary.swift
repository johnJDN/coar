import Foundation

/// The Sleep and Steps pages' summaries (pure rules, values in, values out): a week against
/// the one before, and how often a Day met the target. Values are per Day in any one unit.
enum HealthSummary {

    /// The average a Day over the 7 Days ending yesterday (today is still going), and over
    /// the 7 before. Only Days with a value count, as on the Habits tab. Nil when the recent
    /// week has none; `previous` is nil when that week has none.
    static func week(_ values: [Day: Double], today: Day) -> (recent: Double, previous: Double?)? {
        func average(_ offsets: ClosedRange<Int>) -> Double? {
            let found = offsets.compactMap { values[today.advanced(by: -$0)] }
            return found.isEmpty ? nil : found.reduce(0, +) / Double(found.count)
        }
        guard let recent = average(1...7) else { return nil }
        return (recent, average(8...14))
    }

    /// The change from `previous` to `recent` as a whole percentage: "up 12%", "down 4%",
    /// "about the same" within 2%.
    static func changeText(from previous: Double, to recent: Double) -> String {
        guard previous > 0 else { return "" }
        let percent = Int(((recent - previous) / previous * 100).rounded())
        if abs(percent) < 2 { return "about the same as the week before" }
        return "\(percent > 0 ? "up" : "down") \(abs(percent))% on the week before"
    }

    struct TargetRecord: Equatable {
        /// Days among `days` with a value at or over the target, and how many had a value.
        let met: Int
        let judged: Int
        /// Days met in a row, ending today, or yesterday while today hasn't met it yet.
        let inARow: Int
    }

    /// How often the Days in `days` met `target` (at least). A Day without a value isn't
    /// judged and breaks a run.
    static func target(_ target: Double, values: [Day: Double], days: [Day], today: Day) -> TargetRecord {
        let judged = days.compactMap { values[$0] }
        var run = 0
        var day = (values[today] ?? 0) >= target ? today : today.advanced(by: -1)
        while let value = values[day], value >= target {
            run += 1
            day = day.advanced(by: -1)
        }
        return TargetRecord(met: judged.filter { $0 >= target }.count, judged: judged.count, inARow: run)
    }
}

/// A Sleep or Steps target the pages draw: the daily amount of the user's tracked Habit for
/// that metric (CONTEXT.md "Tracked habit"), in the chart's unit (hours, steps). A weekly
/// Habit's amount is an average a Day, so it reads the same way.
struct HealthTarget: Equatable {
    let amount: Double
    let habitName: String

    /// The first tracked "at least" Habit for `metric` in the user's order, with its target in
    /// force today; nil when there is none.
    @MainActor
    static func current(for metric: HealthMetric, store: Store, today: Day) -> HealthTarget? {
        let habits = (try? store.habits()) ?? []
        let habit = habits.first { $0.kind == .tracked && $0.tracking?.metric == metric.trackedMetric && $0.tracking?.comparison == .atLeast }
        guard let habit, let target = habit.target(inForceOn: today) else { return nil }
        return HealthTarget(amount: target.amount, habitName: habit.name)
    }
}
