import XCTest
@testable import Coar

/// Deleting an Entry from the timeline, and Undo (`.scratch/quick-delete/`): the Entry comes
/// back exactly as it was, linked again to what it came from. Seam 1: the façade, in memory.
@MainActor
final class DeleteEntryTests: XCTestCase {

    private let eggs = Macros(calories: 140, protein: 12, fat: 10, carbs: 0)

    func test_aDeletedEntry_comesBackAsItWas() throws {
        let store = Store.inMemory()
        let entry = try store.logEntry(name: "Quest bar", servingName: "bar", quantity: 2, macros: Macros(calories: 380, protein: 42, fat: 18, carbs: 44), at: Date())

        try store.deleteEntry(entry.id)
        XCTAssertEqual(try store.entries(on: entry.day), [])

        let restored = try store.restoreEntry(entry)
        XCTAssertEqual(restored.id, entry.id)
        XCTAssertEqual(try store.entries(on: entry.day).map(\.id), [entry.id])
        let back = try XCTUnwrap(store.entry(entry.id))
        XCTAssertEqual(back.name, "Quest bar")
        XCTAssertEqual(back.servingName, "bar")
        XCTAssertEqual(back.quantity, 2)
        XCTAssertEqual(back.macros, entry.macros)
        XCTAssertEqual(back.loggedAt, entry.loggedAt)
        XCTAssertEqual(back.day, entry.day)
    }

    func test_aFoodItemEntry_isLinkedAgain_andOneWhoseFoodIsGoneStandsAlone() throws {
        let store = Store.inMemory()
        let food = try store.createFoodItem(name: "Eggs", servings: [ServingDraft(name: "1 egg", macros: eggs, isDefault: true)])
        let entry = try store.logEntry(foodItem: food.id, serving: food.servings[0].id, quantity: 2, at: Date())

        try store.deleteEntry(entry.id)
        try store.restoreEntry(entry)
        XCTAssertEqual(try store.entry(entry.id)?.foodItemID, food.id)

        try store.deleteEntry(entry.id)
        try store.archiveFoodItem(food.id)
        try store.restoreEntry(entry)
        XCTAssertEqual(try store.entry(entry.id)?.foodItemID, food.id, "archived foods still link")
    }

    func test_aMealEntry_comesBackWithItsBreakdown() throws {
        let store = Store.inMemory()
        let food = try store.createFoodItem(name: "Eggs", servings: [ServingDraft(name: "1 egg", macros: eggs, isDefault: true)])
        let meal = try store.createMeal(name: "Breakfast", components: [MealComponentDraft(foodItemID: food.id, servingID: food.servings[0].id, quantity: 2)])
        let entry = try store.logEntry(meal: meal.id, quantity: 1, at: Date())
        XCTAssertEqual(entry.components.count, 1)

        try store.deleteEntry(entry.id)
        try store.restoreEntry(entry)

        let back = try XCTUnwrap(store.entry(entry.id))
        XCTAssertEqual(back.mealID, meal.id)
        XCTAssertEqual(back.components, entry.components)
        XCTAssertEqual(back.macros, entry.macros)
    }

    func test_restoringAnEntryThatIsAlreadyBack_doesNothing() throws {
        let store = Store.inMemory()
        let entry = try store.logEntry(name: "Toast", servingName: "slice", quantity: 1, macros: eggs, at: Date())
        try store.restoreEntry(entry)
        XCTAssertEqual(try store.entries(on: entry.day).count, 1)
    }
}
