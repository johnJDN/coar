import CoreData

/// The façade's Habits surface: Habits, their dated targets, and Check-ins.
extension Store {

    // MARK: - Habits

    /// Creates a Habit at the end of the list with its first target in force from
    /// `effectiveFrom`.
    @discardableResult
    func createHabit(
        emoji: String,
        name: String,
        kind: HabitKind,
        targetAmount: Double,
        period: HabitPeriod,
        effectiveFrom: Day = .today()
    ) throws -> HabitRecord {
        let habit = Habit(context: context)
        habit.id = UUID()
        habit.emoji = emoji
        habit.name = name
        habit.kind = kind.rawValue
        habit.isArchived = false
        habit.sortOrder = try nextHabitSortOrder()

        let target = HabitTarget(context: context)
        target.amount = targetAmount
        target.period = period.rawValue
        target.effectiveFrom = effectiveFrom.rawValue
        target.habit = habit
        try save()
        return HabitRecord(habit)!
    }

    /// Sets the target in force from `effectiveFrom` on, as a new dated record (ADR 0003):
    /// past Days keep the record that applied then. Setting what is already in force on
    /// that Day writes nothing; setting again on a Day that already starts a record
    /// replaces it, so a Day never starts two.
    func setHabitTarget(_ id: HabitRecord.ID, amount: Double, period: HabitPeriod, effectiveFrom: Day = .today()) throws {
        guard let habit = try fetchHabit(id) else { return }
        let inForce = HabitRecord(habit)?.target(inForceOn: effectiveFrom)
        guard inForce?.amount != amount || inForce?.period != period else { return }
        let target = habit.targetObjects.first { $0.effectiveFrom == effectiveFrom.rawValue } ?? HabitTarget(context: context)
        target.amount = amount
        target.period = period.rawValue
        target.effectiveFrom = effectiveFrom.rawValue
        target.habit = habit
        try save()
    }

    /// Active Habits in the user's order.
    func habits() throws -> [HabitRecord] {
        try fetchHabits(archived: false)
    }

    /// Archived Habits in the user's order.
    func archivedHabits() throws -> [HabitRecord] {
        try fetchHabits(archived: true)
    }

    func habit(_ id: HabitRecord.ID) throws -> HabitRecord? {
        try fetchHabit(id).flatMap(HabitRecord.init)
    }

    /// Persists the given order; `ids` lists the active Habits first to last.
    func reorderHabits(_ ids: [HabitRecord.ID]) throws {
        for (position, id) in ids.enumerated() {
            try fetchHabit(id)?.sortOrder = Int32(position)
        }
        try save()
    }

    /// Hides the Habit from the active list; its Check-ins stay (CONTEXT.md "Archived").
    func archiveHabit(_ id: HabitRecord.ID) throws {
        try fetchHabit(id)?.isArchived = true
        try save()
    }

    /// Returns the Habit to the active list, at the end: its old position has been taken.
    func restoreHabit(_ id: HabitRecord.ID) throws {
        guard let habit = try fetchHabit(id) else { return }
        habit.isArchived = false
        habit.sortOrder = try nextHabitSortOrder()
        try save()
    }

    /// Deletes the Habit and, by cascade, every Check-in and target it has.
    func deleteHabitPermanently(_ id: HabitRecord.ID) throws {
        guard let habit = try fetchHabit(id) else { return }
        context.delete(habit)
        try save()
    }

    // MARK: - Check-ins

    /// Records the Habit's total for a Day. At most one Check-in per Habit per Day: checking
    /// in again replaces the amount.
    func checkIn(_ id: HabitRecord.ID, on day: Day, amount: Double) throws {
        guard let habit = try fetchHabit(id) else { return }
        let record = try fetchCheckIn(habit: habit, on: day) ?? CheckIn(context: context)
        record.habit = habit
        record.day = day.rawValue
        record.amount = amount
        try save()
    }

    /// Removes the Day's Check-in, if any: a yes/no Habit toggled off.
    func removeCheckIn(_ id: HabitRecord.ID, on day: Day) throws {
        guard let habit = try fetchHabit(id), let record = try fetchCheckIn(habit: habit, on: day) else { return }
        context.delete(record)
        try save()
    }

    func checkIn(_ id: HabitRecord.ID, on day: Day) throws -> CheckInRecord? {
        guard let habit = try fetchHabit(id) else { return nil }
        return try fetchCheckIn(habit: habit, on: day).flatMap(CheckInRecord.init)
    }

    /// Every Check-in of the Habit in Day order, earliest first; empty for an unknown Habit.
    func checkIns(for id: HabitRecord.ID) throws -> [CheckInRecord] {
        guard let habit = try fetchHabit(id) else { return [] }
        let request = CheckIn.fetchRequest()
        request.predicate = NSPredicate(format: "habit == %@", habit)
        request.sortDescriptors = [NSSortDescriptor(key: "day", ascending: true)]
        return try context.fetch(request).compactMap(CheckInRecord.init)
    }

    // MARK: - Fetches

    private func fetchHabits(archived: Bool) throws -> [HabitRecord] {
        let request = Habit.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == %@", NSNumber(value: archived))
        request.sortDescriptors = [
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: "modifiedAt", ascending: true),
        ]
        return try context.fetch(request).compactMap(HabitRecord.init)
    }

    private func fetchHabit(_ id: HabitRecord.ID) throws -> Habit? {
        let request = Habit.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchCheckIn(habit: Habit, on day: Day) throws -> CheckIn? {
        let request = CheckIn.fetchRequest()
        request.predicate = NSPredicate(format: "habit == %@ AND day == %@", habit, day.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func nextHabitSortOrder() throws -> Int32 {
        let request = Habit.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "sortOrder", ascending: false)]
        request.fetchLimit = 1
        return (try context.fetch(request).first?.sortOrder ?? -1) + 1
    }
}

private extension HabitRecord {
    init?(_ object: Habit) {
        guard let id = object.id, let modifiedAt = object.modifiedAt,
              let kind = HabitKind(rawValue: object.kind)
        else { return nil }
        self.init(
            id: id,
            emoji: object.emoji ?? "",
            name: object.name ?? "",
            kind: kind,
            isArchived: object.isArchived,
            sortOrder: Int(object.sortOrder),
            targets: object.targetSeries,
            modifiedAt: modifiedAt
        )
    }
}

private extension Habit {
    var targetObjects: [HabitTarget] {
        Array(targets as? Set<HabitTarget> ?? [])
    }

    /// The dated series earliest first. When a Day starts several records (two devices
    /// editing before sync), the latest-modified one stands, as the dedupe pass will settle.
    var targetSeries: [HabitTargetRecord] {
        let latestPerDay = Dictionary(
            targetObjects.compactMap { object in HabitTargetRecord(object).map { ($0.effectiveFrom, (object.modifiedAt ?? .distantPast, $0)) } },
            uniquingKeysWith: { $0.0 >= $1.0 ? $0 : $1 }
        )
        return latestPerDay.values.map(\.1).sorted { $0.effectiveFrom < $1.effectiveFrom }
    }
}

private extension HabitTargetRecord {
    init?(_ object: HabitTarget) {
        guard let raw = object.effectiveFrom, let day = Day(rawValue: raw),
              let period = HabitPeriod(rawValue: object.period)
        else { return nil }
        self.init(amount: object.amount, period: period, effectiveFrom: day)
    }
}

private extension CheckInRecord {
    init?(_ object: CheckIn) {
        guard let raw = object.day, let day = Day(rawValue: raw), let modifiedAt = object.modifiedAt else { return nil }
        self.init(day: day, amount: object.amount, modifiedAt: modifiedAt)
    }
}
