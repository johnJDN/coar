import XCTest
@testable import Coar

/// Seam 1: the store façade. A Food Item has one or more Servings with one default; an
/// Entry snapshots what was eaten (ADR 0003) and stores an instant plus the local Day it was
/// logged into (ADR 0005); an archived Food Item leaves the picker while its Entries stay
/// (CONTEXT.md "Food Item", "Serving", "Entry", "Archived").
@MainActor
final class FoodTests: XCTestCase {

    private let sep13 = Day(year: 2026, month: 9, day: 13)

    private let oneEgg = ServingDraft(name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0), grams: 50, isDefault: true)
    private let hundredGrams = ServingDraft(name: "100 g", macros: Macros(calories: 140, protein: 12, fat: 10, carbs: 1), grams: 100)

    private func makeEggs(_ store: Store) throws -> FoodItemRecord {
        try store.createFoodItem(name: "Eggs", servings: [oneEgg, hundredGrams])
    }

    // MARK: Food Items and Servings

    func test_newFoodItem_readsBackWithItsServingsInOrderAndTheDefaultMarked() throws {
        let store = Store.inMemory()

        let eggs = try makeEggs(store)

        let read = try XCTUnwrap(store.foodItem(eggs.id))
        XCTAssertEqual(read.name, "Eggs")
        XCTAssertFalse(read.isArchived)
        XCTAssertEqual(read.servings.map(\.name), ["1 egg", "100 g"])
        XCTAssertEqual(read.servings.map(\.grams), [50, 100])
        XCTAssertEqual(read.servings.first?.macros, Macros(calories: 70, protein: 6, fat: 5, carbs: 0))
        XCTAssertEqual(read.defaultServing?.name, "1 egg")
        XCTAssertEqual(try store.foodItems().map(\.name), ["Eggs"])
    }

    func test_updatingAFoodItem_keepsServingsByIdInTheNewOrder_dropsTheOnesLeftOut_andMovesTheDefault() throws {
        let store = Store.inMemory()
        let eggs = try makeEggs(store)
        let hundred = try XCTUnwrap(eggs.servings.last)
        var moved = ServingDraft(hundred)
        moved.macros.calories = 143
        moved.isDefault = true
        let large = ServingDraft(name: "1 large egg", macros: Macros(calories: 78, protein: 6, fat: 5, carbs: 1), grams: 56)

        try store.updateFoodItem(eggs.id, name: "Eggs (large)", servings: [moved, large])

        let read = try XCTUnwrap(store.foodItem(eggs.id))
        XCTAssertEqual(read.name, "Eggs (large)")
        XCTAssertEqual(read.servings.map(\.name), ["100 g", "1 large egg"])
        XCTAssertEqual(read.servings.first?.id, hundred.id)
        XCTAssertEqual(read.servings.first?.macros.calories, 143)
        XCTAssertEqual(read.defaultServing?.id, hundred.id)
        XCTAssertEqual(read.servings.filter(\.isDefault).count, 1)
    }

    func test_aFoodItemWithNoServingFlagged_makesTheFirstTheDefault() throws {
        let store = Store.inMemory()

        let rice = try store.createFoodItem(name: "Rice", servings: [
            ServingDraft(name: "1 cup", macros: Macros(calories: 206, protein: 4, fat: 0, carbs: 45)),
            ServingDraft(name: "100 g", macros: Macros(calories: 130, protein: 3, fat: 0, carbs: 28), grams: 100),
        ])

        XCTAssertEqual(try XCTUnwrap(store.foodItem(rice.id)).defaultServing?.name, "1 cup")
    }

    func test_foodItems_listByNameRegardlessOfCase() throws {
        let store = Store.inMemory()
        try store.createFoodItem(name: "rice", servings: [oneEgg])
        try store.createFoodItem(name: "Chicken breast", servings: [oneEgg])
        try store.createFoodItem(name: "Eggs", servings: [oneEgg])

        XCTAssertEqual(try store.foodItems().map(\.name), ["Chicken breast", "Eggs", "rice"])
    }

    // MARK: Entries snapshot their source (ADR 0003)

    func test_loggedEntry_carriesTheNameServingNameQuantityAndScaledMacros() throws {
        let store = Store.inMemory()
        let eggs = try makeEggs(store)
        let serving = try XCTUnwrap(eggs.defaultServing)
        let instant = Date(timeIntervalSince1970: 1_789_300_000) // 2026-09-13 in every zone near the user

        let entry = try store.logEntry(foodItem: eggs.id, serving: serving.id, quantity: 3, at: instant)

        XCTAssertEqual(entry.name, "Eggs")
        XCTAssertEqual(entry.servingName, "1 egg")
        XCTAssertEqual(entry.quantity, 3)
        XCTAssertEqual(entry.macros, Macros(calories: 210, protein: 18, fat: 15, carbs: 0))
        XCTAssertEqual(entry.loggedAt, instant)
        XCTAssertEqual(entry.foodItemID, eggs.id)
        XCTAssertEqual(try store.entry(entry.id), entry)
    }

    func test_editingAServingsMacros_leavesPriorEntriesUnchanged() throws {
        let store = Store.inMemory()
        let eggs = try makeEggs(store)
        let serving = try XCTUnwrap(eggs.defaultServing)
        let entry = try store.logEntry(foodItem: eggs.id, serving: serving.id, quantity: 2, at: sep13.start())

        var corrected = ServingDraft(serving)
        corrected.name = "1 medium egg"
        corrected.macros = Macros(calories: 78, protein: 7, fat: 6, carbs: 1)
        try store.updateFoodItem(eggs.id, name: "Free-range eggs", servings: [corrected])

        let read = try XCTUnwrap(store.entry(entry.id))
        XCTAssertEqual(read.name, "Eggs")
        XCTAssertEqual(read.servingName, "1 egg")
        XCTAssertEqual(read.macros, Macros(calories: 140, protein: 12, fat: 10, carbs: 0))
    }

    func test_removingTheServingAnEntryCameFrom_leavesTheEntryIntact() throws {
        let store = Store.inMemory()
        let eggs = try makeEggs(store)
        let serving = try XCTUnwrap(eggs.defaultServing)
        let entry = try store.logEntry(foodItem: eggs.id, serving: serving.id, quantity: 1, at: sep13.start())

        try store.updateFoodItem(eggs.id, name: "Eggs", servings: [ServingDraft(try XCTUnwrap(eggs.servings.last))])

        XCTAssertEqual(try store.entry(entry.id)?.servingName, "1 egg")
        XCTAssertEqual(try store.entries(on: sep13).map(\.id), [entry.id])
    }

    // MARK: Entries store the local Day at write time (ADR 0005)

    func test_entryDay_isTheLocalDayWhenLogged_notTheDayTheInstantFallsOnElsewhere() throws {
        let store = Store.inMemory()
        let eggs = try makeEggs(store)
        let serving = try XCTUnwrap(eggs.defaultServing)
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        // 23:30 on 13 September in Los Angeles is already 15:30 on the 14th in Tokyo.
        let lateSnack = losAngeles.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 23, minute: 30))!
        XCTAssertEqual(Day(lateSnack, in: tokyo), Day(year: 2026, month: 9, day: 14))

        let atHome = try store.logEntry(foodItem: eggs.id, serving: serving.id, quantity: 1, at: lateSnack, in: losAngeles)
        let inTokyo = try store.logEntry(foodItem: eggs.id, serving: serving.id, quantity: 1, at: lateSnack, in: tokyo)

        XCTAssertEqual(atHome.day, sep13)
        XCTAssertEqual(inTokyo.day, Day(year: 2026, month: 9, day: 14))
        XCTAssertEqual(try store.entries(on: sep13).map(\.id), [atHome.id])
        XCTAssertEqual(try store.entries(on: Day(year: 2026, month: 9, day: 14)).map(\.id), [inTokyo.id])
        XCTAssertEqual(atHome.loggedAt, lateSnack)
    }

    func test_entriesOnADay_comeBackEarliestFirst_andOnlyForThatDay() throws {
        let store = Store.inMemory()
        let eggs = try makeEggs(store)
        let serving = try XCTUnwrap(eggs.defaultServing)
        let lunch = try store.logEntry(foodItem: eggs.id, serving: serving.id, quantity: 1, at: sep13.start().addingTimeInterval(13 * 3600))
        let breakfast = try store.logEntry(foodItem: eggs.id, serving: serving.id, quantity: 1, at: sep13.start().addingTimeInterval(8 * 3600))
        try store.logEntry(foodItem: eggs.id, serving: serving.id, quantity: 1, at: sep13.advanced(by: 1).start().addingTimeInterval(8 * 3600))

        XCTAssertEqual(try store.entries(on: sep13).map(\.id), [breakfast.id, lunch.id])
    }

    // MARK: Editing and deleting an Entry

    func test_updatingAnEntry_changesItsInstantQuantityAndMacros_andKeepsItsDay() throws {
        let store = Store.inMemory()
        let eggs = try makeEggs(store)
        let serving = try XCTUnwrap(eggs.defaultServing)
        let entry = try store.logEntry(foodItem: eggs.id, serving: serving.id, quantity: 1, at: sep13.start().addingTimeInterval(8 * 3600))
        let later = sep13.start().addingTimeInterval(9 * 3600)

        try store.updateEntry(entry.id, loggedAt: later, quantity: 2, macros: Macros(calories: 150, protein: 12, fat: 10, carbs: 1))

        let read = try XCTUnwrap(store.entry(entry.id))
        XCTAssertEqual(read.loggedAt, later)
        XCTAssertEqual(read.quantity, 2)
        XCTAssertEqual(read.macros, Macros(calories: 150, protein: 12, fat: 10, carbs: 1))
        XCTAssertEqual(read.day, sep13)
        XCTAssertEqual(read.name, "Eggs")
        XCTAssertEqual(try XCTUnwrap(store.foodItem(eggs.id)).defaultServing?.macros.calories, 70)
    }

    func test_deletingAnEntry_removesOnlyThatEntry() throws {
        let store = Store.inMemory()
        let eggs = try makeEggs(store)
        let serving = try XCTUnwrap(eggs.defaultServing)
        let first = try store.logEntry(foodItem: eggs.id, serving: serving.id, quantity: 1, at: sep13.start().addingTimeInterval(8 * 3600))
        let second = try store.logEntry(foodItem: eggs.id, serving: serving.id, quantity: 1, at: sep13.start().addingTimeInterval(9 * 3600))

        try store.deleteEntry(first.id)

        XCTAssertNil(try store.entry(first.id))
        XCTAssertEqual(try store.entries(on: sep13).map(\.id), [second.id])
        XCTAssertNotNil(try store.foodItem(eggs.id))
    }

    // MARK: Archive

    func test_archivedFoodItem_isAbsentFromThePickerQuery_whileItsEntriesStay_andRestores() throws {
        let store = Store.inMemory()
        let eggs = try makeEggs(store)
        let rice = try store.createFoodItem(name: "Rice", servings: [oneEgg])
        let serving = try XCTUnwrap(eggs.defaultServing)
        let entry = try store.logEntry(foodItem: eggs.id, serving: serving.id, quantity: 1, at: sep13.start())

        try store.archiveFoodItem(eggs.id)

        XCTAssertEqual(try store.foodItems().map(\.id), [rice.id])
        XCTAssertEqual(try store.archivedFoodItems().map(\.id), [eggs.id])
        XCTAssertEqual(try store.entries(on: sep13).map(\.id), [entry.id])
        XCTAssertEqual(try store.entry(entry.id)?.foodItemID, eggs.id)

        try store.restoreFoodItem(eggs.id)

        XCTAssertEqual(try store.foodItems().map(\.id), [eggs.id, rice.id])
        XCTAssertEqual(try store.archivedFoodItems(), [])
    }
}
