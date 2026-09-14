import Foundation

/// Whether a Habit is done-or-not or an amount (CONTEXT.md "Habit"). Raw values are stored.
enum HabitKind: Int16, CaseIterable {
    case yesNo = 0
    case quantitative = 1
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
    /// The target in force today; nil only for a Habit whose first target starts later.
    let target: HabitTargetRecord?
    let modifiedAt: Date

    /// Whether a Day's Check-in counts as met. A yes/no Habit is met by any Check-in;
    /// quantitative amounts against the target are ticket 05.
    func meets(amount: Double) -> Bool {
        amount > 0
    }
}

/// One entry of a Habit's dated target series (ADR 0003): the amount per Period in force
/// from `effectiveFrom` until a later entry takes over.
struct HabitTargetRecord: Hashable {
    let amount: Double
    let period: HabitPeriod
    let effectiveFrom: Day
}

/// A Check-in as read through the façade (CONTEXT.md "Check-in"): a Day's total for a Habit.
struct CheckInRecord: Hashable {
    let day: Day
    let amount: Double
    let modifiedAt: Date
}
