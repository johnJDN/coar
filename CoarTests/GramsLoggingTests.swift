import XCTest
@testable import Coar

/// Logging by weight and by fraction (`.scratch/food-logging/issues/01`): amounts typed as
/// fractions, the servings | g switch, "45g granola" against a saved label food, and the
/// Foods log sheet's grams.
@MainActor
final class GramsLoggingTests: XCTestCase {

    private let noon = Date(timeIntervalSince1970: 1_789_300_000)
    private let granolaServing = ServingDraft(name: "serving (55 g)", macros: Macros(calories: 240, protein: 5, fat: 9, carbs: 36), grams: 55, isDefault: true, extras: Extras(fiber: 4, sodium: 120))

    func test_amounts_takeFractions() {
        XCTAssertEqual(FoodText.parseAmount("1/3")!, 1.0 / 3, accuracy: 0.0001)
        XCTAssertEqual(FoodText.parseAmount("1 1/2"), 1.5)
        XCTAssertEqual(FoodText.parseAmount("½"), 0.5)
        XCTAssertEqual(FoodText.parseAmount("1½"), 1.5)
        XCTAssertEqual(FoodText.parseAmount(" 2.25 "), 2.25)
        XCTAssertNil(FoodText.parseAmount("a bit"))
    }

    func test_aLabelLine_switchesToGramsAndBack_keepingItsMacros() throws {
        let estimate = Estimate(name: "Maple pecan granola", quantity: 1, unit: "serving (55 g)", grams: 55,
                                macros: Macros(calories: 240, protein: 5, fat: 9, carbs: 36), source: .label, assumption: "")
        var edit = DescribeLineEdit(DescribeLine(text: "x", state: .filled(estimate)))

        XCTAssertTrue(edit.offersGrams)
        edit.setInGrams(true)
        XCTAssertEqual(edit.quantity, 55)
        XCTAssertTrue(edit.isInGrams)
        edit.setQuantity(45)
        XCTAssertEqual(edit.estimate?.macros.calories ?? 0, 196.4, accuracy: 0.1)

        edit.setInGrams(false)
        XCTAssertEqual(edit.unit, "serving (55 g)")
        XCTAssertEqual(edit.quantity ?? 0, 0.82, accuracy: 0.01)
        XCTAssertEqual(edit.estimate?.macros.calories ?? 0, 196.4, accuracy: 0.5, "back in servings, the same food")
    }

    func test_aLineWithoutAWeight_offersNoGrams() {
        let estimate = Estimate(name: "Pho", quantity: 1, unit: "bowl", grams: nil, macros: Macros(calories: 500, protein: 30, fat: 12, carbs: 60), source: .estimated, assumption: "")
        XCTAssertFalse(DescribeLineEdit(DescribeLine(text: "x", state: .filled(estimate))).offersGrams)
    }

    func test_typedGrams_ofASavedFood_areWorkedOutFromItsLabel() throws {
        let store = Store.inMemory()
        let granola = try store.createFoodItem(name: "Granola", servings: [granolaServing])
        let library = FoodLibrary(foodItems: [granola], meals: [])

        for line in ["45g granola", "45 g granola", "45 grams of granola", "granola 45g", "Granola, 45 grams"] {
            let match = try XCTUnwrap(library.exactMatch(line), line)
            XCTAssertEqual(match.quantity, 45, line)
            XCTAssertEqual(match.unit, "g", line)
            XCTAssertEqual(match.macros.calories, 240 * 45 / 55, accuracy: 0.01, line)
            XCTAssertEqual(match.extras.fiber ?? 0, 4 * 45 / 55, accuracy: 0.01, line)
        }
        XCTAssertNil(library.weightMatch("45g oats"), "not a saved food")
        XCTAssertEqual(library.exactMatch("2 granola")?.quantity, 2, "a count still means servings")
    }

    func test_aGramsLine_logsInGrams_linkedToTheFood() throws {
        let store = Store.inMemory()
        let granola = try store.createFoodItem(name: "Granola", servings: [granolaServing])
        let estimate = try XCTUnwrap(FoodLibrary(foodItems: [granola], meals: []).exactMatch("45g granola"))

        try store.logDescribed(estimate, typed: "45g granola", savingAsFood: true, at: noon)

        let entry = try XCTUnwrap(store.entries(on: Day(noon)).first)
        XCTAssertEqual(entry.servingName, "g")
        XCTAssertEqual(entry.quantity, 45)
        XCTAssertEqual(entry.macros.calories, 240 * 45 / 55, accuracy: 0.01)
        XCTAssertEqual(entry.foodItemID, granola.id)
    }

    func test_theFoodsLogSheet_logsGramsOfAServing() throws {
        let store = Store.inMemory()
        let granola = try store.createFoodItem(name: "Granola", servings: [granolaServing])
        let serving = try XCTUnwrap(granola.defaultServing)

        XCTAssertEqual(LogFoodItemForm.servings(45, of: serving, inGrams: true), 45.0 / 55)
        XCTAssertEqual(LogFoodItemForm.servings(2, of: serving, inGrams: false), 2)
        let entry = try store.logEntry(foodItem: granola.id, serving: serving.id, quantity: 45, grams: 45, at: noon)

        XCTAssertEqual(FoodText.portion(entry.quantity, of: entry.servingName), "45 g")
        XCTAssertEqual(entry.extras.sodium ?? 0, 120 * 45 / 55, accuracy: 0.01)
    }

    func test_theListing_showsAServingsWeight_unlessItsNameDoes() throws {
        let store = Store.inMemory()
        let pho = try store.createFoodItem(name: "Pho", servings: [ServingDraft(name: "bowl", macros: Macros(calories: 500, protein: 30, fat: 12, carbs: 60), grams: 650, isDefault: true)])
        let granola = try store.createFoodItem(name: "Granola", servings: [granolaServing])
        let listing = try XCTUnwrap(FoodLibrary(foodItems: [pho, granola], meals: []).promptListing)
        XCTAssertTrue(listing.contains(#"s1 "bowl" (650 g)"#), listing)
        XCTAssertTrue(listing.contains(#"s1 "serving (55 g)""#) && !listing.contains("(55 g) (55 g)"), listing)
    }
}
