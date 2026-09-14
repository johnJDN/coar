import Foundation

/// Everything a habit card shows, derived once per render from the façade's records: the
/// streak and heatmap are computed here through the pure rules, never stored.
struct HabitCardModel: Hashable, Identifiable {
    let id: HabitRecord.ID
    let emoji: String
    let name: String
    /// Every Day whose Check-in met the target.
    let met: Set<Day>
    let isDoneToday: Bool
    let streak: Int
    /// "day" / "days"; ticket 05 counts weekly Habits in weeks.
    let streakUnit: String
    let heatmap: [Heatmap.Cell]

    init(habit: HabitRecord, checkIns: [CheckInRecord], today: Day, columns: Int = Heatmap.columns) {
        let met = Set(checkIns.filter { habit.meets(amount: $0.amount) }.map(\.day))
        let streak = Streak.days(met: met, today: today)
        id = habit.id
        emoji = habit.emoji
        name = habit.name
        self.met = met
        isDoneToday = met.contains(today)
        self.streak = streak
        streakUnit = HabitPeriod.day.streakUnit(streak)
        heatmap = Heatmap.cells(endingOn: today, columns: columns, met: met)
    }
}
