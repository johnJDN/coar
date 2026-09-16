import CoreData

/// The façade's Meals surface: Meals as groups of Food Items in fixed quantities, and the
/// Entries logged from them.
extension Store {

    // MARK: - Meals

    /// Creates a Meal with its lines in the given order.
    @discardableResult
    func createMeal(name: String, components: [MealComponentDraft]) throws -> MealRecord {
        let meal = Meal(context: context)
        meal.id = UUID()
        meal.isArchived = false
        try write(name: name, components: components, to: meal)
        return MealRecord(meal)!
    }

    /// Replaces the Meal's name and lines: drafts carrying an existing line's `id` update it
    /// in place, new ids insert, and lines left out are removed. Entries logged before keep
    /// their own copy of everything (ADR 0003).
    func updateMeal(_ id: MealRecord.ID, name: String, components: [MealComponentDraft]) throws {
        guard let meal = try fetchMeal(id) else { return }
        try write(name: name, components: components, to: meal)
    }

    /// Active Meals by name: what the "+" sheet's Meals segment lists.
    func meals() throws -> [MealRecord] {
        try fetchMeals(archived: false)
    }

    /// Archived Meals by name.
    func archivedMeals() throws -> [MealRecord] {
        try fetchMeals(archived: true)
    }

    func meal(_ id: MealRecord.ID) throws -> MealRecord? {
        try fetchMeal(id).flatMap(MealRecord.init)
    }

    /// Hides the Meal from the picker; its Entries stay (CONTEXT.md "Archived").
    func archiveMeal(_ id: MealRecord.ID) throws {
        try fetchMeal(id)?.isArchived = true
        try save()
    }

    func restoreMeal(_ id: MealRecord.ID) throws {
        try fetchMeal(id)?.isArchived = false
        try save()
    }

    // MARK: - Entries

    /// Logs that `quantity` of a Meal was eaten at `instant`: one Entry carrying the Meal's
    /// name, its summed macros for the quantity, and a copy of each line for one of the
    /// Meal (ADR 0003), on the local Day the instant falls on in `calendar` (ADR 0005).
    /// Keeps a reference to the Meal for re-logging only.
    @discardableResult
    func logEntry(
        meal mealID: MealRecord.ID,
        quantity: Double,
        at instant: Date,
        in calendar: Calendar = .current
    ) throws -> EntryRecord {
        guard let meal = try fetchMeal(mealID), let record = MealRecord(meal) else { throw NotFound(what: "Meal") }
        let entry = makeEntry(name: record.name, servingName: EntryRecord.mealServingName, quantity: quantity, macros: record.macros.scaled(by: quantity), at: instant, in: calendar)
        entry.meal = meal
        for (position, line) in record.components.enumerated() {
            let component = EntryComponent(context: context)
            component.name = line.name
            component.servingName = line.servingName
            component.quantity = line.quantity
            component.macros = line.macros
            component.sortOrder = Int32(position)
            component.entry = entry
        }
        try save()
        return EntryRecord(entry)!
    }

    // MARK: - Writes

    private func write(name: String, components drafts: [MealComponentDraft], to meal: Meal) throws {
        meal.name = name
        let existing = reconcile(meal.componentObjects, keeping: Set(drafts.map(\.id)), id: \.id)
        for (position, draft) in drafts.enumerated() {
            let component = existing[draft.id] ?? MealComponent(context: context)
            component.id = draft.id
            component.quantity = draft.quantity
            component.sortOrder = Int32(position)
            component.foodItem = try fetchFoodItem(draft.foodItemID)
            component.serving = draft.servingID.flatMap { servingID in component.foodItem?.servingObjects.first { $0.id == servingID } }
            component.meal = meal
        }
        try save()
    }

    // MARK: - Fetches

    private func fetchMeals(archived: Bool) throws -> [MealRecord] {
        let request = Meal.fetchRequest()
        request.predicate = NSPredicate(format: "isArchived == %@", NSNumber(value: archived))
        return try context.fetch(request).compactMap(MealRecord.init)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func fetchMeal(_ id: MealRecord.ID) throws -> Meal? {
        let request = Meal.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

private extension MealRecord {
    init?(_ object: Meal) {
        guard let id = object.id, let modifiedAt = object.modifiedAt else { return nil }
        self.init(
            id: id,
            name: object.name ?? "",
            isArchived: object.isArchived,
            components: object.componentRecords,
            modifiedAt: modifiedAt
        )
    }
}

private extension Meal {
    var componentObjects: [MealComponent] {
        Array(components as? Set<MealComponent> ?? [])
    }

    /// The lines in the user's order. A line whose Food Item is gone is dropped; one whose
    /// Serving is gone stays, carrying no macros.
    var componentRecords: [MealComponentRecord] {
        componentObjects
            .sorted(by: Store.bySortOrder)
            .compactMap { object in
                guard let id = object.id, let foodItem = object.foodItem, let foodItemID = foodItem.id else { return nil }
                return MealComponentRecord(
                    id: id,
                    foodItemID: foodItemID,
                    servingID: object.serving?.id,
                    name: foodItem.name ?? "",
                    servingName: object.serving?.name ?? "",
                    quantity: object.quantity,
                    servingMacros: object.serving?.macros ?? .zero
                )
            }
    }
}
