import CoreData

/// The façade's Habits surface: Habits, their dated targets, and Check-ins.
extension Store {

    // MARK: - Habits

    /// Creates a Habit at the end of the list with its first target in force from
    /// `effectiveFrom`. A checklist Habit gets its Items, blank names left out.
    @discardableResult
    func createHabit(
        emoji: String,
        name: String,
        kind: HabitKind,
        targetAmount: Double,
        period: HabitPeriod,
        items: [HabitItemDraft] = [],
        tracking: HabitTracking? = nil,
        effectiveFrom: Day = .today()
    ) throws -> HabitRecord {
        let habit = Habit(context: context)
        habit.id = UUID()
        habit.emoji = emoji
        habit.name = name
        habit.kind = kind.rawValue
        habit.metric = kind == .tracked ? tracking?.metric.rawValue ?? 0 : 0
        habit.comparison = tracking?.comparison.rawValue ?? 0
        habit.isArchived = false
        habit.sortOrder = try nextHabitSortOrder()

        let target = HabitTarget(context: context)
        target.amount = targetAmount
        target.period = period.rawValue
        target.effectiveFrom = effectiveFrom.rawValue
        target.habit = habit
        if kind == .checklist {
            writeItems(items, to: habit)
        }
        try save()
        return HabitRecord(habit)!
    }

    /// Replaces a checklist Habit's Items: drafts carrying an existing Item's `id` rename and
    /// reorder it, new ids add one, and Items left out are marked removed rather than
    /// deleted, so past Check-ins still name them. When the count changes, the goal follows
    /// (`Checklist.goal`) as a new dated target from `effectiveFrom`. An empty list is not
    /// written: a checklist always has an Item.
    func setHabitItems(_ id: HabitRecord.ID, items drafts: [HabitItemDraft], effectiveFrom: Day = .today()) throws {
        guard let habit = try fetchHabit(id), let record = HabitRecord(habit) else { return }
        let kept = drafts.filter { !$0.trimmedName.isEmpty }
        guard !kept.isEmpty else { return }
        writeItems(kept, to: habit)
        if let inForce = record.target(inForceOn: effectiveFrom),
           let goal = Checklist.goal(current: inForce.amount, oldCount: record.items.count, newCount: kept.count) {
            try save()
            try setHabitTarget(id, amount: goal, period: inForce.period, effectiveFrom: effectiveFrom)
        } else {
            try save()
        }
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

    /// A yes/no Habit's Check-in as a toggle: done writes the Day's Check-in (amount 1), not
    /// done deletes it. There is no recorded miss (DESIGN.md §7 `CheckToggle`).
    func setCheckedIn(_ id: HabitRecord.ID, on day: Day, done: Bool) throws {
        if done {
            try checkIn(id, on: day, amount: 1)
        } else {
            try removeCheckIn(id, on: day)
        }
    }

    /// Ticks or unticks one Item of a checklist Habit. A tick lands on `day`. On a weekly
    /// list an Item counts once a week, so ticking one already ticked this week writes
    /// nothing, and unticking clears it from every Day of the week. A Day left with no Items
    /// loses its Check-in; its amount is always its count of Items.
    func setChecklistItem(_ id: HabitRecord.ID, item: HabitItemRecord.ID, on day: Day, ticked: Bool) throws {
        guard let habit = try fetchHabit(id), let record = HabitRecord(habit) else { return }
        let period = record.target(inForceOn: day)?.period ?? .day
        let days = period == .week ? (0..<7).map { day.startOfWeek.advanced(by: $0) } : [day]
        let checkIns = try days.compactMap { try fetchCheckIn(habit: habit, on: $0) }
        if ticked {
            guard !checkIns.contains(where: { $0.itemIDSet.contains(item) }) else { return }
            let checkIn = try fetchCheckIn(habit: habit, on: day) ?? CheckIn(context: context)
            checkIn.habit = habit
            checkIn.day = day.rawValue
            checkIn.itemIDSet = checkIn.itemIDSet.union([item])
        } else {
            for checkIn in checkIns where checkIn.itemIDSet.contains(item) {
                checkIn.itemIDSet = checkIn.itemIDSet.subtracting([item])
                if checkIn.itemIDSet.isEmpty { context.delete(checkIn) }
            }
        }
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

    private func writeItems(_ drafts: [HabitItemDraft], to habit: Habit) {
        let existing = Dictionary(habit.itemObjects.compactMap { item in item.id.map { ($0, item) } }, uniquingKeysWith: { first, _ in first })
        let keptIDs = Set(drafts.map(\.id))
        for item in habit.itemObjects where !keptIDs.contains(item.id ?? UUID()) {
            item.isRemoved = true
        }
        for (position, draft) in drafts.filter({ !$0.trimmedName.isEmpty }).enumerated() {
            let item = existing[draft.id] ?? HabitItem(context: context)
            item.id = draft.id
            item.name = draft.trimmedName
            item.sortOrder = Int32(position)
            item.isRemoved = false
            item.habit = habit
        }
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
            items: object.itemObjects
                .filter { !$0.isRemoved }
                .sorted(by: Store.bySortOrder)
                .compactMap { item in item.id.map { HabitItemRecord(id: $0, name: item.name ?? "") } },
            tracking: TrackedMetric(rawValue: object.metric).map {
                HabitTracking(metric: $0, comparison: HabitComparison(rawValue: object.comparison) ?? .atLeast)
            },
            modifiedAt: modifiedAt
        )
    }
}

private extension Habit {
    var targetObjects: [HabitTarget] {
        Array(targets as? Set<HabitTarget> ?? [])
    }

    var itemObjects: [HabitItem] {
        Array(items as? Set<HabitItem> ?? [])
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
        self.init(day: day, amount: object.amount, modifiedAt: modifiedAt, itemIDs: object.itemIDSet)
    }
}

extension CheckIn {
    /// The Items ticked this Day, stored as comma-joined UUIDs (additive, ADR 0002). Setting
    /// it keeps `amount` as the count, so the Day reads the same to every kind-blind rule.
    var itemIDSet: Set<UUID> {
        get { Set((itemIDs ?? "").split(separator: ",").compactMap { UUID(uuidString: String($0)) }) }
        set {
            itemIDs = newValue.isEmpty ? nil : newValue.map(\.uuidString).sorted().joined(separator: ",")
            amount = Double(newValue.count)
        }
    }
}
