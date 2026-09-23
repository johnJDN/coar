import Foundation

/// Whether a Habit is done-or-not or an amount (CONTEXT.md "Habit"). Raw values are stored.
enum HabitKind: Int16, CaseIterable {
    case yesNo = 0
    case quantitative = 1

    var title: String {
        switch self {
        case .yesNo: return "Yes / no"
        case .quantitative: return "Amount"
        }
    }
}

/// The span a Habit's target applies over (CONTEXT.md "Period"). Raw values are stored.
enum HabitPeriod: Int16, CaseIterable {
    case day = 0
    case week = 1

    var title: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        }
    }

    /// The unit a Streak in this Period is counted in.
    func streakUnit(_ count: Int) -> String {
        switch self {
        case .day: return count == 1 ? "day" : "days"
        case .week: return count == 1 ? "week" : "weeks"
        }
    }
}

/// A Habit as read through the façade.
struct HabitRecord: Hashable, Identifiable {
    let id: UUID
    let emoji: String
    let name: String
    let kind: HabitKind
    let isArchived: Bool
    let sortOrder: Int
    /// The dated target series (ADR 0003), earliest first; one record per effective-from Day.
    let targets: [HabitTargetRecord]
    let modifiedAt: Date

    /// The target in force on a Day: the record with the latest effective-from Day on or
    /// before it. The first record also covers every Day before it, so a Habit created today
    /// can be backfilled; later records stay dated, so a change never repaints history.
    /// Nil only for a Habit with no target at all.
    func target(inForceOn day: Day) -> HabitTargetRecord? {
        targets.last { $0.effectiveFrom <= day } ?? targets.first
    }
}

/// Amounts as the Habits screens show them: whole numbers plain, a fraction kept when there
/// is one, and the quick-add steps the number sheet offers against a target.
enum HabitAmount {

    static func text(_ amount: Double) -> String {
        amount.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// Three `+N` steps scaled to the target's magnitude: 20 pages gets +1 +5 +10, 100
    /// push-ups +10 +50 +100. Small targets step by 1, 2, 5; no target uses 1, 5, 10.
    static func quickAdds(target: Double?) -> [Double] {
        guard let target, target >= 10 else { return target == nil ? [1, 5, 10] : [1, 2, 5] }
        let scale = pow(10, floor(log10(target)) - 1)
        return [1, 5, 10].map { $0 * scale }
    }
}

/// One entry of a Habit's dated target series (ADR 0003): the amount per Period in force
/// from `effectiveFrom` until a later entry takes over.
struct HabitTargetRecord: Hashable {
    let amount: Double
    let period: HabitPeriod
    let effectiveFrom: Day

    /// The target as a value and its unit: "20" "a day", "3" "days a week", "1" "a day".
    func summary(for kind: HabitKind) -> (value: String, unit: String) {
        let value = HabitAmount.text(amount)
        switch (kind, period) {
        case (.yesNo, .week): return (value, amount == 1 ? "day a week" : "days a week")
        case (_, .day): return (value, "a day")
        case (.quantitative, .week): return (value, "a week")
        }
    }
}

/// A Check-in as read through the façade (CONTEXT.md "Check-in"): a Day's total for a Habit.
struct CheckInRecord: Hashable {
    let day: Day
    let amount: Double
    let modifiedAt: Date
}
