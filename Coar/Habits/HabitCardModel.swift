import Foundation

/// Everything a habit card shows, derived once per render from the façade's records: the
/// streak and heatmap are computed here through the pure rules, never stored.
struct HabitCardModel: Hashable, Identifiable {
    let id: HabitRecord.ID
    let emoji: String
    let name: String
    let isDoneToday: Bool
    let streak: Int
    /// "day" / "days" in the Habit's Period.
    let streakUnit: String
    let heatmap: [Heatmap.Cell]

    init(habit: HabitRecord, checkIns: [CheckInRecord], today: Day, columns: Int = HeatmapView.columns) {
        let met = Set(checkIns.filter { Self.meets(habit: habit, amount: $0.amount) }.map(\.day))
        let streak = Streak.days(met: met, today: today)
        self.init(
            id: habit.id,
            emoji: habit.emoji,
            name: habit.name,
            isDoneToday: met.contains(today),
            streak: streak,
            streakUnit: (habit.target?.period ?? .day).streakUnit(streak),
            heatmap: Heatmap.cells(endingOn: today, columns: columns, met: met)
        )
    }

    init(id: HabitRecord.ID, emoji: String, name: String, isDoneToday: Bool, streak: Int, streakUnit: String, heatmap: [Heatmap.Cell]) {
        self.id = id
        self.emoji = emoji
        self.name = name
        self.isDoneToday = isDoneToday
        self.streak = streak
        self.streakUnit = streakUnit
        self.heatmap = heatmap
    }

    /// Whether a Day's Check-in counts as met: any Check-in for a yes/no Habit, the target
    /// amount for a quantitative one.
    static func meets(habit: HabitRecord, amount: Double) -> Bool {
        switch habit.kind {
        case .yesNo: return amount > 0
        case .quantitative: return amount >= (habit.target?.amount ?? .infinity)
        }
    }
}
