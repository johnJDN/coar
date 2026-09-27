import Foundation

/// What a tracked Habit watches (CONTEXT.md "Tracked habit"): data Coar already has, read
/// rather than checked in. Raw values are stored; 0 means the Habit is not tracked.
enum TrackedMetric: Int16, CaseIterable {
    case sleep = 1
    case steps = 2
    case workouts = 3
    case foodLogged = 4
    case weighIns = 5
    case calories = 6
    case protein = 7
    case fat = 8
    case carbs = 9

    var title: String {
        switch self {
        case .sleep: return "Sleep"
        case .steps: return "Steps"
        case .workouts: return "Workouts"
        case .foodLogged: return "Food logged"
        case .weighIns: return "Weigh-ins"
        case .calories: return "Calories"
        case .protein: return "Protein"
        case .fat: return "Fat"
        case .carbs: return "Carbs"
        }
    }

    var emoji: String {
        switch self {
        case .sleep: return "😴"
        case .steps: return "👟"
        case .workouts: return "🏋️"
        case .foodLogged: return "🍽️"
        case .weighIns: return "⚖️"
        case .calories: return "🔥"
        case .protein: return "🥩"
        case .fat: return "🥑"
        case .carbs: return "🍚"
        }
    }

    /// A Day either has it or not: a Workout, an Entry, a Body Weight. The target is then a
    /// number of Days a week (or every Day).
    var isDayCount: Bool {
        self == .workouts || self == .foodLogged || self == .weighIns
    }

    var macro: Macro? {
        switch self {
        case .calories: return .calories
        case .protein: return .protein
        case .fat: return .fat
        case .carbs: return .carbs
        default: return nil
        }
    }

    /// Where the values come from, for the detail.
    var source: String {
        switch self {
        case .sleep, .steps: return "From Apple Health"
        case .workouts: return "From your workouts"
        case .foodLogged, .calories, .protein, .fat, .carbs: return "From your food log"
        case .weighIns: return "From your Body Weight"
        }
    }

    /// What a new one starts as: the common goal for this metric.
    var defaults: (comparison: HabitComparison, period: HabitPeriod, amount: Double) {
        switch self {
        case .sleep: return (.atLeast, .week, 7)
        case .steps: return (.atLeast, .week, 7_000)
        case .workouts: return (.atLeast, .week, 3)
        case .foodLogged: return (.atLeast, .day, 1)
        case .weighIns: return (.atLeast, .week, 3)
        case .calories, .fat, .carbs: return (.atMost, .day, 110)
        case .protein: return (.atLeast, .day, 90)
        }
    }
}

/// Which side of the target counts: at least (sleep, steps, protein) or at most (calories
/// on a cut). Raw values are stored.
enum HabitComparison: Int16, CaseIterable {
    case atLeast = 0
    case atMost = 1

    var title: String {
        switch self {
        case .atLeast: return "At least"
        case .atMost: return "At most"
        }
    }

    func passes(_ value: Double, _ target: Double) -> Bool {
        switch self {
        case .atLeast: return value >= target
        case .atMost: return value <= target
        }
    }
}

/// A tracked Habit's metric and direction. Its target amount is in the metric's own terms:
/// hours of sleep, steps, Days a week, or a macro as a percentage of that Day's Target.
struct HabitTracking: Hashable {
    let metric: TrackedMetric
    let comparison: HabitComparison

    /// "7 h" "average a night", "3" "days a week", "110%" "of target at most".
    func summary(amount: Double, period: HabitPeriod) -> (value: String, unit: String) {
        let at = comparison == .atMost ? "at most" : "at least"
        switch (metric, period) {
        case (.sleep, .day): return (valueText(amount), "a night, \(at)")
        case (.sleep, .week): return (valueText(amount), "average a night, \(at)")
        case (.steps, .day): return (valueText(amount), "steps a day, \(at)")
        case (.steps, .week): return (valueText(amount), "average steps a day, \(at)")
        case (_, .day) where metric.isDayCount: return ("Every", "day")
        case (_, .week) where metric.isDayCount: return (HabitAmount.text(amount), amount == 1 ? "day a week" : "days a week")
        case (_, .day): return (valueText(amount), "of target each day, \(at)")
        case (_, .week): return (valueText(amount), "of target on average, \(at)")
        }
    }

    /// A value as the capsule and captions show it: "7.2h", "7.2k", "92%".
    func valueText(_ value: Double) -> String {
        switch metric {
        case .sleep: return value.formatted(.number.precision(.fractionLength(0...1))) + "h"
        case .steps: return value >= 1_000 ? (value / 1_000).formatted(.number.precision(.fractionLength(0...1))) + "k" : "\(Int(value.rounded()))"
        case .workouts, .foodLogged, .weighIns: return HabitAmount.text(value)
        case .calories, .protein, .fat, .carbs: return "\(Int(value.rounded()))%"
        }
    }

    /// A name for a new one, from its settings: "Sleep 7h", "Workouts 3 days a week".
    func defaultName(amount: Double, period: HabitPeriod) -> String {
        switch metric {
        case .foodLogged: return period == .day ? "Log food every day" : "Log food \(HabitAmount.text(amount)) days a week"
        case .weighIns: return period == .day ? "Weigh in every day" : "Weigh in \(HabitAmount.text(amount)) days a week"
        case .workouts: return period == .day ? "Work out every day" : "Work out \(HabitAmount.text(amount)) days a week"
        case .sleep, .steps: return "\(metric.title) \(comparison == .atMost ? "under" : "") \(valueText(amount))".replacingOccurrences(of: "  ", with: " ")
        case .calories, .protein, .fat, .carbs:
            return "\(metric.title) \(comparison == .atMost ? "under" : "over") \(valueText(amount))"
        }
    }
}

/// How a tracked Habit's Periods are judged (a pure rule): each Day's value against the
/// target in force on it, and each week's (its average, or its count of Days for a
/// day-count metric) against the target in force on its Sunday. A Day with no value has
/// nothing to judge: a daily goal misses it (food not logged is a miss), and an average
/// uses only the Days that have one (a night without sleep data does not drag it down).
enum Tracked {

    struct Evaluation: Equatable {
        var levels: [Day: Heatmap.Level] = [:]
        var metDays: Set<Day> = []
        var metWeeks: Set<Day> = []
        /// Each week's average (or count of Days), keyed by its Monday.
        var weekValues: [Day: Double] = [:]
    }

    static func evaluate(_ habit: HabitRecord, tracking: HabitTracking, values: [Day: Double], today: Day) -> Evaluation {
        var result = Evaluation()
        let past = values.filter { $0.key <= today }
        for (day, value) in past {
            guard let inForce = habit.target(inForceOn: day) else { continue }
            if tracking.metric.isDayCount {
                result.levels[day] = value > 0 ? .done : .empty
                if inForce.period == .day, value > 0 { result.metDays.insert(day) }
            } else {
                let passes = tracking.comparison.passes(value, inForce.amount)
                result.levels[day] = tracking.comparison == .atLeast
                    ? Heatmap.level(amount: value, target: inForce.amount)
                    : passes ? .done : .empty
                if inForce.period == .day, passes { result.metDays.insert(day) }
            }
        }
        let weeks = Dictionary(grouping: past, by: { $0.key.startOfWeek })
        for (monday, days) in weeks {
            let value = tracking.metric.isDayCount
                ? Double(days.filter { $0.value > 0 }.count)
                : days.map(\.value).reduce(0, +) / Double(days.count)
            result.weekValues[monday] = value
            guard let inForce = habit.target(inForceOn: monday.advanced(by: 6)), inForce.period == .week else { continue }
            if tracking.comparison.passes(value, inForce.amount) {
                result.metWeeks.insert(monday)
            }
        }
        return result
    }
}
