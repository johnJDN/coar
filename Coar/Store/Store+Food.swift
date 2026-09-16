import CoreData

/// The façade's Food surface: Food Items with their Servings, and Entries.
extension Store {

    /// A write named something the store does not hold.
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
        guard let item = try fetchFoodItem(id) else { throw NotFound(what: "Food Item") }
        try write(name: name, servings: servings, to: item)
    }

    /// Active Food Items by name: what the "+" sheet's Foods segment lists.
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
        guard let serving = record.servings.first(where: { $0.id == servingID }) else { throw NotFound(what: "Serving") }
        let entry = Entry(context: context)
        entry.id = UUID()
        entry.loggedAt = instant
        entry.day = Day(instant, in: calendar).rawValue
        entry.name = record.name
        entry.servingName = serving.name
        entry.quantity = quantity
        entry.macros = serving.macros.scaled(by: quantity)
        entry.foodItem = item
        try save()
        return EntryRecord(entry)!
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
        guard let entry = try fetchEntry(id) else { throw NotFound(what: "Entry") }
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
        let kept = Set(drafts.map(\.id))
        var existing: [ServingRecord.ID: Serving] = [:]
        for object in item.servingObjects {
            // A Serving without an id, or one the drafts leave out, is gone; should an id be
            // held twice (two devices editing before sync), the latest-modified one is kept.
            guard let id = object.id, kept.contains(id) else { context.delete(object); continue }
            if let other = existing[id] {
                let keep = (object.modifiedAt ?? .distantPast) >= (other.modifiedAt ?? .distantPast) ? object : other
                context.delete(keep === object ? other : object)
                existing[id] = keep
            } else {
                existing[id] = object
            }
        }
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

    // MARK: - Fetches

    private func fetchFoodItems(archived: Bool) throws -> [FoodItemRecord] {
        let request = FoodItem.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == %@", NSNumber(value: archived))
        return try context.fetch(request).compactMap(FoodItemRecord.init)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func fetchFoodItem(_ id: FoodItemRecord.ID) throws -> FoodItem? {
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

private extension FoodItem {
    var servingObjects: [Serving] {
        Array(servings as? Set<Serving> ?? [])
    }

    /// The Servings in the user's order. Should two carry the default flag (two devices
    /// editing before sync), the latest-modified one stands, as the dedupe pass will settle.
    var servingRecords: [ServingRecord] {
        let ordered = servingObjects.sorted {
            ($0.sortOrder, $0.modifiedAt ?? .distantPast) < ($1.sortOrder, $1.modifiedAt ?? .distantPast)
        }
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

private extension Serving {
    var macros: Macros {
        get { Macros(calories: calories, protein: protein, fat: fat, carbs: carbs) }
        set {
            calories = newValue.calories
            protein = newValue.protein
            fat = newValue.fat
            carbs = newValue.carbs
        }
    }
}

private extension EntryRecord {
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
            modifiedAt: modifiedAt
        )
    }
}

private extension Entry {
    var macros: Macros {
        get { Macros(calories: calories, protein: protein, fat: fat, carbs: carbs) }
        set {
            calories = newValue.calories
            protein = newValue.protein
            fat = newValue.fat
            carbs = newValue.carbs
        }
    }
}
