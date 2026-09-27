import Foundation

/// The checklist Habit's rule (CONTEXT.md "Item"): an Item ticked on any Day of a Period
/// counts for the whole Period, once. A daily list starts fresh each Day; on a weekly list a
/// friend texted on Monday stays ticked until Sunday. A pure rule function: Check-ins in,
/// ticked Items out.
enum Checklist {

    /// The Items ticked in the Period holding `day`: that Day for a daily Habit, its
    /// Monday-to-Sunday week for a weekly one.
    static func ticked(in checkIns: [CheckInRecord], period: HabitPeriod, containing day: Day) -> Set<HabitItemRecord.ID> {
        switch period {
        case .day:
            return checkIns.filter { $0.day == day }.reduce(into: []) { $0.formUnion($1.itemIDs) }
        case .week:
            let monday = day.startOfWeek
            return checkIns.filter { $0.day.startOfWeek == monday }.reduce(into: []) { $0.formUnion($1.itemIDs) }
        }
    }

    /// The goal a list changed from `oldCount` to `newCount` Items should carry: one that
    /// asked for every Item keeps asking for every Item; any other keeps its number, capped
    /// at the new count. Nil when nothing needs to change.
    static func goal(current: Double, oldCount: Int, newCount: Int) -> Double? {
        guard newCount > 0 else { return nil }
        let next = current >= Double(oldCount) ? Double(newCount) : min(current, Double(newCount))
        return next == current ? nil : next
    }
}
