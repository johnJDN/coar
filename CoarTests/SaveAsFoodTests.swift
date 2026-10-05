import XCTest
@testable import Coar

/// Save as food (spec story 16): on by default for a Describe line that isn't already one of
/// the user's foods, never a second Food Item with the same name, and available afterwards on
/// a logged Entry's page (2026-10-04). Seam 1: the store façade, in memory.
@MainActor
final class SaveAsFoodTests: XCTestCase {

    private let kind = Estimate(
        name: "KIND Protein MAX Raspberry Cocoa Crisp", quantity: 1, unit: "bar", grams: 62,
        macros: Macros(calories: 240, protein: 20, fat: 13, carbs: 24), source: .lookedUp, assumption: ""
    )

    private func line(_ estimate: Estimate) -> DescribeLine {
        DescribeLine(text: "kind raspberry", state: .filled(estimate))
    }

    // MARK: Describe

    func test_aNewLine_savesToFoodsByDefault_andOffersTheToggle_unlessItIsAlreadyTheUsers() {
        XCTAssertTrue(DescribeLine().saveAsFood)
        XCTAssertTrue(DescribeLineCell.offersSaveAsFood(line(kind)))
        XCTAssertFalse(DescribeLineCell.offersSaveAsFood(DescribeLine(text: "kind", state: .checking)))
        var matched = kind
        matched.match = .foodItem(UUID(), serving: UUID())
        XCTAssertFalse(DescribeLineCell.offersSaveAsFood(line(matched)))
    }

    func test_aLineSavedAsFood_isSavedOnce_evenWhenTypedAgainWithOtherCasing() throws {
        let store = Store.inMemory()
        try store.logDescribed(kind, typed: "kind raspberry", savingAsFood: true, at: Date())
        var shouted = kind
        shouted.name = "kind protein max raspberry cocoa crisp "
        try store.logDescribed(shouted, typed: "kind raspberry", savingAsFood: true, at: Date())

        XCTAssertEqual(try store.foodItems().map(\.name), ["KIND Protein MAX Raspberry Cocoa Crisp"])
        let entries = try store.entries(on: .today())
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries.filter { $0.foodItemID != nil }.count, 1, "the second logs on its own")
    }

    func test_aLineWithSaveTurnedOff_logsOnItsOwn() throws {
        let store = Store.inMemory()
        try store.logDescribed(kind, typed: "kind raspberry", savingAsFood: false, at: Date())
        XCTAssertEqual(try store.foodItems(), [])
        XCTAssertEqual(try store.entries(on: .today()).map(\.name), ["KIND Protein MAX Raspberry Cocoa Crisp"])
    }

    // MARK: A logged Entry

    func test_aLoggedEntry_isSavedAsAFood_andLinkedToIt() throws {
        let store = Store.inMemory()
        let entry = try store.logEntry(name: "Quest bar", servingName: "bar", quantity: 2, macros: Macros(calories: 380, protein: 42, fat: 18, carbs: 44), at: Date())

        let food = try XCTUnwrap(store.saveEntryAsFood(entry.id))

        XCTAssertEqual(food.name, "Quest bar")
        XCTAssertEqual(food.servings.map(\.name), ["bar"])
        XCTAssertEqual(food.defaultServing?.macros, Macros(calories: 190, protein: 21, fat: 9, carbs: 22), "one bar, not the two logged")
        XCTAssertEqual(try store.entry(entry.id)?.foodItemID, food.id)
        XCTAssertNil(try store.saveEntryAsFood(entry.id), "already from a food")
    }

    func test_anEntryInGrams_savesA100gServing() throws {
        let store = Store.inMemory()
        let entry = try store.logEntry(name: "Chicken breast", servingName: "g", quantity: 150, macros: Macros(calories: 248, protein: 46.5, fat: 5.4, carbs: 0), at: Date())
        let food = try XCTUnwrap(store.saveEntryAsFood(entry.id))
        XCTAssertEqual(food.defaultServing?.name, "100 g")
        XCTAssertEqual(try XCTUnwrap(food.defaultServing?.macros.calories), 248 / 1.5, accuracy: 0.001)
    }

    func test_anEntryWhoseNameIsAlreadyInFoods_isNotSavedAgain() throws {
        let store = Store.inMemory()
        try store.createFoodItem(name: "Quest bar", servings: [ServingDraft(name: "bar", macros: Macros(calories: 190, protein: 21, fat: 9, carbs: 22), isDefault: true)])
        let entry = try store.logEntry(name: "quest BAR", servingName: "bar", quantity: 1, macros: Macros(calories: 190, protein: 21, fat: 9, carbs: 22), at: Date())
        XCTAssertNil(try store.saveEntryAsFood(entry.id))
        XCTAssertEqual(try store.foodItems().count, 1)
    }
}
