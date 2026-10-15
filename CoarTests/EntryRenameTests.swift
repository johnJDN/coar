import XCTest
@testable import Coar

/// A logged Entry's name and unit can be corrected on its page (ADR 0003: the past is
/// corrected on the past). A weight unit converts the same portion; any other unit leaves the
/// macros for the old one and says so until a macro is typed.
@MainActor
final class EntryRenameTests: XCTestCase {

    private let noon = Date(timeIntervalSince1970: 1_789_300_000)

    private func entry(name: String = "Pho", servingName: String, quantity: Double, calories: Double = 500, components: [EntryComponentRecord] = []) -> EntryRecord {
        EntryRecord(
            id: UUID(), loggedAt: noon, day: Day(year: 2026, month: 9, day: 13), name: name, servingName: servingName,
            quantity: quantity, macros: Macros(calories: calories, protein: 30, fat: 10, carbs: 60), foodItemID: nil, mealID: nil,
            components: components, modifiedAt: noon
        )
    }

    func test_renaming_isSaveable_andAnEmptyNameIsNot() {
        var draft = EntryDraft(entry(servingName: "bowl", quantity: 1))

        draft.name = "  Beef pho "
        XCTAssertEqual(draft.trimmedName, "Beef pho")
        XCTAssertTrue(draft.isSaveable)

        draft.name = " "
        XCTAssertNil(draft.trimmedName)
        XCTAssertFalse(draft.isSaveable)
    }

    func test_aCountedWeightUnit_convertsToGrams_withTheSameMacros() {
        var draft = EntryDraft(entry(name: "Rice", servingName: "100 g", quantity: 1.5, calories: 195))

        draft.setUnit("g")

        XCTAssertEqual(draft.quantity, 150)
        XCTAssertEqual(draft.servingName, "g")
        XCTAssertEqual(draft.macros?.calories, 195)
        XCTAssertFalse(draft.unitNeedsNumbers)

        draft.setQuantity(300)
        XCTAssertEqual(draft.macros?.calories, 390)
    }

    func test_gramsToOunces_convertsThroughPartialTyping() {
        var draft = EntryDraft(entry(name: "Chicken", servingName: "g", quantity: 170, calories: 280))

        draft.setUnit("o")
        XCTAssertTrue(draft.unitNeedsNumbers)
        draft.setUnit("oz")

        XCTAssertEqual(draft.quantity, 6)
        XCTAssertEqual(draft.macros?.calories, 280)
        XCTAssertFalse(draft.unitNeedsNumbers)
    }

    func test_aUnitWithNoKnownWeight_keepsTheMacros_andSaysSo_untilAMacroIsTyped() {
        var draft = EntryDraft(entry(servingName: "serving", quantity: 1))

        draft.setUnit("bowl")

        XCTAssertTrue(draft.unitNeedsNumbers)
        XCTAssertEqual(draft.numbersPortion, "1 serving")
        XCTAssertEqual(draft.macros?.calories, 500)
        XCTAssertTrue(draft.isSaveable, "a relabel saves; the page says the macros are unchanged")

        draft.setMacro(.calories, 650)
        XCTAssertFalse(draft.unitNeedsNumbers)
        XCTAssertEqual(draft.servingName, "bowl")
    }

    func test_anEmptyUnit_isNotSaveable() {
        var draft = EntryDraft(entry(servingName: "bowl", quantity: 1))

        draft.setUnit(" ")

        XCTAssertNil(draft.servingName)
        XCTAssertFalse(draft.isSaveable)
    }

    func test_aMealEntry_keepsItsUnit() {
        let line = EntryComponentRecord(name: "Rice", servingName: "g", quantity: 150, macros: .zero)
        XCTAssertTrue(EntryDraft(entry(name: "Lunch", servingName: EntryRecord.mealServingName, quantity: 1, components: [line])).isMeal)
        XCTAssertFalse(EntryDraft(entry(servingName: "bowl", quantity: 1)).isMeal)
    }

    func test_gramsInOne_readsTheWeightAUnitSays() {
        XCTAssertEqual(PortionUnit.grams(inOne: "oz"), 28.3495)
        XCTAssertEqual(PortionUnit.grams(inOne: "100 g"), 100)
        XCTAssertEqual(PortionUnit.grams(inOne: "serving (28 g)"), 28)
        XCTAssertNil(PortionUnit.grams(inOne: "bowl"))
        XCTAssertNil(PortionUnit.grams(inOne: "2 slices"))
    }

    func test_updatingAnEntry_withANameAndUnit_savesThem_andKeepsItsFoodLink() throws {
        let store = Store.inMemory()
        let eggs = try store.createFoodItem(name: "Eggs", servings: [ServingDraft(name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0), isDefault: true)])
        let serving = try XCTUnwrap(eggs.defaultServing)
        let logged = try store.logEntry(foodItem: eggs.id, serving: serving.id, quantity: 2, at: noon)

        try store.updateEntry(logged.id, loggedAt: noon, quantity: 2, macros: logged.macros, name: "Scrambled eggs", servingName: "large egg")

        let read = try XCTUnwrap(store.entry(logged.id))
        XCTAssertEqual(read.name, "Scrambled eggs")
        XCTAssertEqual(read.servingName, "large egg")
        XCTAssertEqual(read.foodItemID, eggs.id)
        XCTAssertEqual(try XCTUnwrap(store.foodItem(eggs.id)).name, "Eggs")
    }
}
