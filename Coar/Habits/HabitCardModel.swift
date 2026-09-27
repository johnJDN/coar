import Foundation

/// Everything a habit card (and its detail) shows, derived once per render from the
/// façade's records through the pure rules; nothing here is stored. Each Day is judged
/// against the target in force on it and each Monday-to-Sunday week against the target in
/// force on its Sunday (ADR 0003), so raising a target never repaints history. The Streak
/// is counted in the Period in force today; Periods judged under another Period do not
/// count, so a switch from days to weeks starts the weekly Streak at the week of the switch.
struct HabitCardModel: Hashable, Identifiable {
    let id: HabitRecord.ID
    let emoji: String
    let name: String
    let kind: HabitKind
    /// The Period the Habit is counted in today; a day without any target.
    let period: HabitPeriod
    /// The target in force today; nil only without any target.
    let target: HabitTargetRecord?
    /// Today's Check-in total; 0 without one.
    let todayAmount: Double
    /// Checklist Habits: the active Items, and how many of them are ticked in the current
    /// Period (today, or this week). Zero for the other kinds.
    let itemCount: Int
    let tickedItemCount: Int
    /// Yes/no: today has a Check-in. Quantitative: the current Period has met its target.
    let isDoneToday: Bool
    let streak: Int
    /// "day" / "days" / "week" / "weeks", matching `period`.
    let streakUnit: String
    /// Weekly Habits: "2 of 3 this week". Nil for daily ones.
    let weekCaption: String?
    /// The cell level of every Day with a Check-in, up to today. Yes/no Days are binary
    /// whatever the Period; quantitative Days fall into the four buckets.
    let levels: [Day: Heatmap.Level]
    let heatmap: [Heatmap.Cell]
    /// Weekly Habits: one dot per heatmap column, filled when that week met its target. Nil
    /// for daily ones, which have no dot row.
    let weekDots: [Bool]?
    /// The first Day a Check-in can be edited on: any past Day once the Habit has a target
    /// (the first target covers the time before it); nil without one.
    let editableFrom: Day?

    init(habit: HabitRecord, checkIns: [CheckInRecord], today: Day, columns: Int = Heatmap.columns) {
        let past = checkIns.filter { $0.day <= today }
        // A checklist Day's amount is how many Items it ticked.
        let amounts = Dictionary(
            past.map { ($0.day, habit.kind == .checklist ? Double($0.itemIDs.count) : $0.amount) },
            uniquingKeysWith: { $1 }
        )
        let target = habit.target(inForceOn: today)
        let period = target?.period ?? .day

        var levels: [Day: Heatmap.Level] = [:]
        var metDays: Set<Day> = []
        for (day, amount) in amounts {
            let inForce = habit.target(inForceOn: day)
            switch habit.kind {
            case .yesNo: levels[day] = inForce != nil && amount > 0 ? .done : .empty
            case .quantitative, .checklist: levels[day] = Heatmap.level(amount: amount, target: inForce?.amount)
            }
            // A daily yes/no Habit is met by any Check-in, whatever amount its target stores.
            if let inForce, inForce.period == .day, habit.kind == .yesNo ? amount > 0 : amount >= inForce.amount {
                metDays.insert(day)
            }
        }

        // A checklist week counts each Item once, however many Days ticked it.
        let weekTotals: [Day: Double] = habit.kind == .checklist
            ? Dictionary(grouping: past, by: { $0.day.startOfWeek }).mapValues { Double(Checklist.ticked(in: $0, period: .week, containing: $0[0].day).count) }
            : Dictionary(amounts.map { ($0.key.startOfWeek, $0.value) }, uniquingKeysWith: +)
        let metWeeks = Set(weekTotals.compactMap { monday, total -> Day? in
            guard let inForce = habit.target(inForceOn: monday.advanced(by: 6)), inForce.period == .week, total >= inForce.amount else { return nil }
            return monday
        })

        let streak = period == .week ? Streak.weeks(met: metWeeks, today: today) : Streak.days(met: metDays, today: today)
        let todayAmount = amounts[today] ?? 0

        id = habit.id
        emoji = habit.emoji
        name = habit.name
        kind = habit.kind
        self.period = period
        self.target = target
        self.todayAmount = todayAmount
        isDoneToday = switch habit.kind {
        case .yesNo: todayAmount > 0
        case .quantitative, .checklist: period == .week ? metWeeks.contains(today.startOfWeek) : metDays.contains(today)
        }
        itemCount = habit.items.count
        let active = Set(habit.items.map(\.id))
        tickedItemCount = habit.kind == .checklist ? Checklist.ticked(in: past, period: period, containing: today).intersection(active).count : 0
        self.streak = streak
        streakUnit = period.streakUnit(streak)
        if let target, period == .week {
            weekCaption = "\(HabitAmount.text(weekTotals[today.startOfWeek] ?? 0)) of \(HabitAmount.text(target.amount)) this week"
        } else {
            weekCaption = nil
        }
        self.levels = levels
        heatmap = Heatmap.cells(endingOn: today, columns: columns, levels: levels)
        weekDots = period == .week ? Heatmap.weeks(endingOn: today, columns: columns).map(metWeeks.contains) : nil
        editableFrom = habit.targets.isEmpty ? nil : .distantPast
    }
}
