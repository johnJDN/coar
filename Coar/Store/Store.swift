import CoreData
import os

/// The store façade (ADR 0002). Every app-facing read and write goes through here; view
/// controllers never touch a managed object context. Reads return value types, writes stamp
/// `modifiedAt`, and the same model backs the CloudKit-mirrored live store and the in-memory
/// store tests use.
@MainActor
final class Store {

    static let cloudKitContainerIdentifier = "iCloud.com.johnnguyen.coar"

    /// Loaded once per process: loading the same model twice makes Core Data warn that several
    /// entity descriptions claim each generated class.
    static let model: NSManagedObjectModel = {
        let url = Bundle(for: Store.self).url(forResource: "Coar", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: url)!
    }()

    private static let logger = Logger(category: "Store")

    /// For `Store+Sync` only, which runs the dedupe pass off the main queue.
    let container: NSPersistentContainer
    /// For the `Store+<Domain>` extensions only; nothing outside the façade may touch it.
    var context: NSManagedObjectContext { container.viewContext }

    /// The on-device store mirrored to the user's private CloudKit database.
    static func live() -> Store {
        let container = NSPersistentCloudKitContainer(name: "Coar", managedObjectModel: model)
        let description = container.persistentStoreDescriptions.first!
        description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: cloudKitContainerIdentifier
        )
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        return Store(container: container)
    }

    /// The same model over a transient in-memory store, with no CloudKit. One per test.
    static func inMemory() -> Store {
        let container = NSPersistentContainer(name: "Coar", managedObjectModel: model)
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [description]
        return Store(container: container)
    }

    private init(container: NSPersistentContainer) {
        self.container = container
        container.loadPersistentStores { description, error in
            if let error {
                Self.logger.error("Failed to load store \(description, privacy: .public): \(error, privacy: .public)")
                assertionFailure("Failed to load store: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Body Weight

    /// Logs the user's Body Weight for a Day. At most one per Day: logging again replaces it.
    func logBodyWeight(kilograms: Double, on day: Day) throws {
        let record = try fetchBodyWeight(on: day) ?? BodyWeight(context: context)
        record.day = day.rawValue
        record.kilograms = kilograms
        try save()
    }

    func bodyWeight(on day: Day) throws -> BodyWeightRecord? {
        try fetchBodyWeight(on: day).flatMap(BodyWeightRecord.init)
    }

    /// The Body Weight on the Day closest to `day`, looking both ways; the earlier one when
    /// two are equally close, nil when none is logged. What a Progress Photo's caption shows.
    func bodyWeight(nearest day: Day) throws -> BodyWeightRecord? {
        let before = try fetchBodyWeight(nearest: day, ascending: false)
        let after = try fetchBodyWeight(nearest: day, ascending: true)
        switch (before, after) {
        case (let before?, let after?):
            return before.day.distance(to: day) <= day.distance(to: after.day) ? before : after
        case (let only?, nil), (nil, let only?):
            return only
        case (nil, nil):
            return nil
        }
    }

    /// Every Body Weight in Day order, earliest first: the series the weight screen charts
    /// and Trend Weight smooths.
    func bodyWeights() throws -> [BodyWeightRecord] {
        let request = BodyWeight.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "day", ascending: true)]
        return try context.fetch(request).compactMap(BodyWeightRecord.init)
    }

    private func fetchBodyWeight(on day: Day) throws -> BodyWeight? {
        let request = BodyWeight.fetchRequest()
        request.predicate = NSPredicate(format: "day == %@", day.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// The latest Body Weight on or before `day` (descending), or the earliest on or after it
    /// (ascending). Duplicates a pre-dedupe sync can leave resolve by latest `modifiedAt`.
    private func fetchBodyWeight(nearest day: Day, ascending: Bool) throws -> BodyWeightRecord? {
        let request = BodyWeight.fetchRequest()
        request.predicate = NSPredicate(format: ascending ? "day >= %@" : "day <= %@", day.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(key: "day", ascending: ascending),
            NSSortDescriptor(key: "modifiedAt", ascending: false),
        ]
        request.fetchLimit = 1
        return try context.fetch(request).first.flatMap(BodyWeightRecord.init)
    }

    // MARK: - Target

    /// The Target in force on a Day: the entry with the latest effective-from Day that is on
    /// or before it. Nil when the series is empty or the Day precedes the first entry;
    /// callers render `—`, never 0 (ADR 0003; `.scratch/data-model/issues/02`).
    func target(inForceOn day: Day) throws -> TargetRecord? {
        let request = MacroTarget.fetchRequest()
        request.predicate = NSPredicate(format: "effectiveFrom <= %@", day.rawValue)
        request.sortDescriptors = [
            NSSortDescriptor(key: "effectiveFrom", ascending: false),
            NSSortDescriptor(key: "modifiedAt", ascending: false),
        ]
        request.fetchLimit = 1
        return try context.fetch(request).first.flatMap(TargetRecord.init)
    }

    /// Sets the Target in force from `day` on. Past Days keep the Target that applied then
    /// (ADR 0003). Setting the same values as are already in force on `day` writes nothing;
    /// setting again on a Day that already starts an entry replaces that entry, so a Day
    /// never starts two.
    func setTarget(_ macros: Macros, effectiveFrom day: Day = .today()) throws {
        guard try target(inForceOn: day)?.macros != macros else { return }
        let record = try fetchTarget(effectiveFrom: day) ?? MacroTarget(context: context)
        record.effectiveFrom = day.rawValue
        record.macros = macros
        try save()
    }

    private func fetchTarget(effectiveFrom day: Day) throws -> MacroTarget? {
        let request = MacroTarget.fetchRequest()
        request.predicate = NSPredicate(format: "effectiveFrom == %@", day.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    // MARK: - Writes

    /// Every write ends here: stamps `modifiedAt` on each inserted or updated object, then
    /// saves. The stamp is app-set so the sync dedupe rule can compare it across devices.
    /// For the `Store+<Domain>` extensions only.
    func save() throws {
        guard context.hasChanges else { return }
        let now = Date()
        for object in context.insertedObjects.union(context.updatedObjects) {
            (object as? ModifiedAtStamped)?.modifiedAt = now
        }
        try context.save()
    }
}

/// A Body Weight as read through the façade (CONTEXT.md "Body Weight").
struct BodyWeightRecord: Hashable {
    let day: Day
    let kilograms: Double
    let modifiedAt: Date
}

private extension BodyWeightRecord {
    init?(_ object: BodyWeight) {
        guard let raw = object.day, let day = Day(rawValue: raw), let modifiedAt = object.modifiedAt else { return nil }
        self.init(day: day, kilograms: object.kilograms, modifiedAt: modifiedAt)
    }
}

/// A Target as read through the façade (CONTEXT.md "Target"): the daily macro amounts in
/// force from `effectiveFrom` until a later entry takes over.
struct TargetRecord: Hashable {
    let macros: Macros
    let effectiveFrom: Day
    let modifiedAt: Date
}

private extension TargetRecord {
    init?(_ object: MacroTarget) {
        guard let raw = object.effectiveFrom, let day = Day(rawValue: raw), let modifiedAt = object.modifiedAt else { return nil }
        self.init(macros: object.macros, effectiveFrom: day, modifiedAt: modifiedAt)
    }
}

// MARK: - Macros

/// An entity holding the four Macro attributes, read and written together as a `Macros`.
protocol MacroAttributes: AnyObject {
    var calories: Double { get set }
    var protein: Double { get set }
    var fat: Double { get set }
    var carbs: Double { get set }
}

extension MacroAttributes {
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

extension MacroTarget: MacroAttributes {}
extension Serving: MacroAttributes {}
extension Entry: MacroAttributes {}
extension EntryComponent: MacroAttributes {}

// MARK: - sortOrder

/// An entity with an explicit `sortOrder` (ADR 0002: no ordered relationships). Ties, which
/// two devices can make, break by `modifiedAt` so every device lists the same order.
protocol SortOrdered: ModifiedAtStamped {
    var sortOrder: Int32 { get }
}

extension Store {
    static func bySortOrder<Object: SortOrdered>(_ lhs: Object, _ rhs: Object) -> Bool {
        (lhs.sortOrder, lhs.modifiedAt ?? .distantPast) < (rhs.sortOrder, rhs.modifiedAt ?? .distantPast)
    }
}

extension Serving: SortOrdered {}
extension MealComponent: SortOrdered {}
extension EntryComponent: SortOrdered {}
extension PlanExercise: SortOrdered {}
extension PlannedSet: SortOrdered {}
extension WorkoutExercise: SortOrdered {}
extension LoggedSet: SortOrdered {}

// MARK: - modifiedAt

/// Every entity carries an app-set `modifiedAt` (ADR 0002; `.scratch/data-model/issues/01`).
protocol ModifiedAtStamped: AnyObject {
    var modifiedAt: Date? { get set }
}

extension Habit: ModifiedAtStamped {}
extension HabitTarget: ModifiedAtStamped {}
extension CheckIn: ModifiedAtStamped {}
extension FoodItem: ModifiedAtStamped {}
extension Serving: ModifiedAtStamped {}
extension Meal: ModifiedAtStamped {}
extension MealComponent: ModifiedAtStamped {}
extension Entry: ModifiedAtStamped {}
extension EntryComponent: ModifiedAtStamped {}
extension MacroTarget: ModifiedAtStamped {}
extension Exercise: ModifiedAtStamped {}
extension Plan: ModifiedAtStamped {}
extension PlanExercise: ModifiedAtStamped {}
extension PlannedSet: ModifiedAtStamped {}
extension Workout: ModifiedAtStamped {}
extension WorkoutExercise: ModifiedAtStamped {}
extension LoggedSet: ModifiedAtStamped {}
extension BodyWeight: ModifiedAtStamped {}
extension ProgressPhoto: ModifiedAtStamped {}
