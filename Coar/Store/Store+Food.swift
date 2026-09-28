import CoreData

/// The façade's Food surface: Food Items with their Servings, and Entries.
extension Store {

    /// A write that must return a record named something the store does not hold. Other
    /// writes on an unknown id do nothing, as the Habits surface does.
    struct NotFound: Error {
        let what: String
    }

    // MARK: - Food Items

    /// Creates a Food Item with its Servings in the given order. Exactly one Serving ends up
    /// the default: the first one flagged, else the first.
    @discardableResult
    func createFoodItem(name: String, servings: [ServingDraft]) throws -> FoodItemRecord {
        let item = FoodItem(context: context)
        item.id = UUID()
        item.isArchived = false
        try write(name: name, servings: servings, to: item)
        return FoodItemRecord(item)!
    }

    /// Replaces the Food Item's name and Servings: drafts carrying an existing Serving's `id`
    /// update it, new ids insert, and Servings left out are removed. Entries logged before
    /// keep their own copy of everything (ADR 0003).
    func updateFoodItem(_ id: FoodItemRecord.ID, name: String, servings: [ServingDraft]) throws {
        guard let item = try fetchFoodItem(id) else { return }
        try write(name: name, servings: servings, to: item)
    }

    /// Active Food Items, most recently used first: what the "+" sheet's Foods segment
    /// lists. Used means its latest Entry's time, or its own last edit when that is later,
    /// so a new or just-edited Food Item starts at the top.
    func foodItems() throws -> [FoodItemRecord] {
        try fetchFoodItems(archived: false)
    }

    /// Archived Food Items by name.
    func archivedFoodItems() throws -> [FoodItemRecord] {
        try fetchFoodItems(archived: true)
    }

    func foodItem(_ id: FoodItemRecord.ID) throws -> FoodItemRecord? {
        try fetchFoodItem(id).flatMap(FoodItemRecord.init)
    }

    /// Hides the Food Item from the picker; its Entries stay (CONTEXT.md "Archived").
    func archiveFoodItem(_ id: FoodItemRecord.ID) throws {
        try fetchFoodItem(id)?.isArchived = true
        try save()
    }

    func restoreFoodItem(_ id: FoodItemRecord.ID) throws {
        try fetchFoodItem(id)?.isArchived = false
        try save()
    }

    /// The Meals (archived ones included) with a line of this Food Item, by name: what
    /// deleting it would change.
    func mealNames(using id: FoodItemRecord.ID) throws -> [String] {
        guard let item = try fetchFoodItem(id) else { return [] }
        return Set(item.mealComponentObjects.compactMap { $0.meal?.name }).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Deletes a Food Item for good, with its Servings. Its lines leave every Meal that used
    /// it, which would otherwise drop them silently and read lighter than it is. Entries
    /// logged from it keep their own copy (ADR 0003).
    func deleteFoodItemPermanently(_ id: FoodItemRecord.ID) throws {
        guard let item = try fetchFoodItem(id) else { return }
        item.mealComponentObjects.forEach(context.delete)
        context.delete(item)
        try save()
    }

    // MARK: - Entries

    /// Logs that `quantity` of one Serving of a Food Item was eaten at `instant`. The Entry
    /// takes its own copy of the name, Serving name, and the macros for the whole quantity
    /// (ADR 0003), and stores the local Day the instant falls on in `calendar` at write
    /// time (ADR 0005). Keeps a reference to the Food Item for re-logging only.
    @discardableResult
    func logEntry(
        foodItem foodItemID: FoodItemRecord.ID,
        serving servingID: ServingRecord.ID,
        quantity: Double,
        at instant: Date,
        in calendar: Calendar = .current
    ) throws -> EntryRecord {
        guard let item = try fetchFoodItem(foodItemID), let record = FoodItemRecord(item) else { throw NotFound(what: "Food Item") }
        guard let serving = record.serving(servingID) else { throw NotFound(what: "Serving") }
        let entry = makeEntry(name: record.name, servingName: serving.name, quantity: quantity, macros: serving.macros.scaled(by: quantity), at: instant, in: calendar)
        entry.foodItem = item
        try save()
        return EntryRecord(entry)!
    }

    /// Logs a food that is not in the catalogue: an Entry standing on its own name, Serving
    /// name, quantity, and macros for the whole quantity (CONTEXT.md "Entry"), with no Food
    /// Item or Meal behind it. What the Describe tab logs.
    @discardableResult
    func logEntry(
        name: String,
        servingName: String,
        quantity: Double,
        macros: Macros,
        at instant: Date,
        in calendar: Calendar = .current
    ) throws -> EntryRecord {
        let entry = makeEntry(name: name, servingName: servingName, quantity: quantity, macros: macros, at: instant, in: calendar)
        try save()
        return EntryRecord(entry)!
    }

    /// A new Entry with its snapshot filled in (ADR 0003) and its Day fixed (ADR 0005); the
    /// caller sets the reference and saves. For the `Store+<Domain>` extensions only.
    func makeEntry(name: String, servingName: String, quantity: Double, macros: Macros, at instant: Date, in calendar: Calendar) -> Entry {
        let entry = Entry(context: context)
        entry.id = UUID()
        entry.loggedAt = instant
        entry.day = Day(instant, in: calendar).rawValue
        entry.name = name
        entry.servingName = servingName
        entry.quantity = quantity
        entry.macros = macros
        return entry
    }

    /// Each Day's summed macros in the range, for the Days with at least one Entry: what a
    /// tracked Habit judges food by (a Day with none has nothing logged).
    func dailyTotals(from start: Day, to end: Day) throws -> [Day: Macros] {
        let request = Entry.fetchRequest()
        request.predicate = NSPredicate(format: "day >= %@ AND day <= %@", start.rawValue, end.rawValue)
        return try context.fetch(request).compactMap(EntryRecord.init).reduce(into: [:]) { totals, entry in
            totals[entry.day] = Macros.sum([totals[entry.day] ?? .zero, entry.macros])
        }
    }

    /// The Day's Entries, earliest first.
    func entries(on day: Day) throws -> [EntryRecord] {
        let request = Entry.fetchRequest()
        request.predicate = NSPredicate(format: "day == %@", day.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(key: "loggedAt", ascending: true),
            NSSortDescriptor(key: "modifiedAt", ascending: true),
        ]
        return try context.fetch(request).compactMap(EntryRecord.init)
    }

    func entry(_ id: EntryRecord.ID) throws -> EntryRecord? {
        try fetchEntry(id).flatMap(EntryRecord.init)
    }

    /// Corrects the past on the past (ADR 0003): the instant, the quantity, and the
    /// snapshotted macros. The Entry keeps the Day it was logged into (ADR 0005).
    func updateEntry(_ id: EntryRecord.ID, loggedAt: Date, quantity: Double, macros: Macros) throws {
        guard let entry = try fetchEntry(id) else { return }
        entry.loggedAt = loggedAt
        entry.quantity = quantity
        entry.macros = macros
        try save()
    }

    /// Removes the Entry and nothing else: the Food Item it came from is untouched.
    func deleteEntry(_ id: EntryRecord.ID) throws {
        guard let entry = try fetchEntry(id) else { return }
        context.delete(entry)
        try save()
    }

    // MARK: - Writes

    private func write(name: String, servings drafts: [ServingDraft], to item: FoodItem) throws {
        item.name = name
        let existing = reconcile(item.servingObjects, keeping: Set(drafts.map(\.id)), id: \.id)
        let defaultID = drafts.first { $0.isDefault }?.id ?? drafts.first?.id
        for (position, draft) in drafts.enumerated() {
            let serving = existing[draft.id] ?? Serving(context: context)
            serving.id = draft.id
            serving.name = draft.name
            serving.macros = draft.macros
            serving.grams = draft.grams.map { NSNumber(value: $0) }
            serving.isDefault = draft.id == defaultID
            serving.sortOrder = Int32(position)
            serving.foodItem = item
        }
        try save()
    }

    /// Syncs a parent's child objects with the drafts about to be written: a child without
    /// an id, or one whose id `kept` leaves out, is deleted; should an id be held twice (two
    /// devices editing before sync), the latest-modified one is kept. Returns the survivors
    /// by id, for the drafts to update in place. For the `Store+<Domain>` extensions only.
    func reconcile<Child: NSManagedObject & ModifiedAtStamped>(_ children: [Child], keeping kept: Set<UUID>, id: KeyPath<Child, UUID?>) -> [UUID: Child] {
        var existing: [UUID: Child] = [:]
        for object in children {
            guard let objectID = object[keyPath: id], kept.contains(objectID) else { context.delete(object); continue }
            if let other = existing[objectID] {
                let keep = (object.modifiedAt ?? .distantPast) >= (other.modifiedAt ?? .distantPast) ? object : other
                context.delete(keep === object ? other : object)
                existing[objectID] = keep
            } else {
                existing[objectID] = object
            }
        }
        return existing
    }

    // MARK: - Fetches

    private func fetchFoodItems(archived: Bool) throws -> [FoodItemRecord] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == %@", NSNumber(value: archived))
        let items = try context.fetch(request)
        guard !archived else {
            return items.compactMap(FoodItemRecord.init).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        return RecentUse.ordered(items.map { item in
            RecentUse.Candidate(
                value: item,
                name: item.name ?? "",
                modifiedAt: item.modifiedAt,
                lastLoggedAt: (item.entries as? Set<Entry>)?.compactMap(\.modifiedAt).max()
            )
        }).compactMap(FoodItemRecord.init)
    }

    /// For the `Store+<Domain>` extensions only.
    func fetchFoodItem(_ id: FoodItemRecord.ID) throws -> FoodItem? {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func fetchEntry(_ id: EntryRecord.ID) throws -> Entry? {
        let request = Entry.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

private extension FoodItemRecord {
    init?(_ object: FoodItem) {
        guard let id = object.id, let modifiedAt = object.modifiedAt else { return nil }
        self.init(
            id: id,
            name: object.name ?? "",
            isArchived: object.isArchived,
            servings: object.servingRecords,
            modifiedAt: modifiedAt
        )
    }
}

extension FoodItem {
    /// For the `Store+<Domain>` extensions only.
    var servingObjects: [Serving] {
        Array(servings as? Set<Serving> ?? [])
    }

    /// The Servings in the user's order. Should two carry the default flag (two devices
    /// editing before sync), the latest-modified one stands, as the dedupe pass will settle.
    var servingRecords: [ServingRecord] {
        let ordered = servingObjects.sorted(by: Store.bySortOrder)
        let standingDefault = ordered.filter(\.isDefault).max { ($0.modifiedAt ?? .distantPast) < ($1.modifiedAt ?? .distantPast) }
        return ordered.compactMap { object in
            guard let id = object.id else { return nil }
            return ServingRecord(
                id: id,
                name: object.name ?? "",
                macros: object.macros,
                grams: object.grams?.doubleValue,
                isDefault: object === standingDefault
            )
        }
    }
}

private extension Entry {
    /// The breakdown in the order it was logged.
    var componentRecords: [EntryComponentRecord] {
        (components as? Set<EntryComponent> ?? [])
            .sorted(by: Store.bySortOrder)
            .map { EntryComponentRecord(name: $0.name ?? "", servingName: $0.servingName ?? "", quantity: $0.quantity, macros: $0.macros) }
    }
}

extension EntryRecord {
    init?(_ object: Entry) {
        guard let id = object.id, let loggedAt = object.loggedAt, let raw = object.day, let day = Day(rawValue: raw),
              let modifiedAt = object.modifiedAt
        else { return nil }
        self.init(
            id: id,
            loggedAt: loggedAt,
            day: day,
            name: object.name ?? "",
            servingName: object.servingName ?? "",
            quantity: object.quantity,
            macros: object.macros,
            foodItemID: object.foodItem?.id,
            mealID: object.meal?.id,
            components: object.componentRecords,
            modifiedAt: modifiedAt
        )
    }
}

private extension FoodItem {
    var mealComponentObjects: [MealComponent] {
        Array(mealComponents as? Set<MealComponent> ?? [])
    }
}
