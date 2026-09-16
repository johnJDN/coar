import XCTest
@testable import Coar

/// Seam 2: pure rule functions. The Entry detail edits the snapshotted macros directly
/// (ADR 0003); changing the quantity keeps the macros per one the same, so "I had 3, not 2"
/// scales what was eaten without retyping four numbers.
final class EntryDraftTests: XCTestCase {

    private let noon = Date(timeIntervalSince1970: 1_789_300_000)

    private func entry(quantity: Double, macros: Macros) -> EntryRecord {
        EntryRecord(
            id: UUID(), loggedAt: noon, day: Day(year: 2026, month: 9, day: 13), name: "Eggs", servingName: "1 egg",
            quantity: quantity, macros: macros, foodItemID: nil, modifiedAt: noon
        )
    }

    func test_changingTheQuantity_scalesTheMacrosToKeepThePerOneValues() {
        var draft = EntryDraft(entry(quantity: 2, macros: Macros(calories: 140, protein: 12, fat: 10, carbs: 0)))

        draft.setQuantity(3)

        XCTAssertEqual(draft.quantity, 3)
        XCTAssertEqual(draft.macros, Macros(calories: 210, protein: 18, fat: 15, carbs: 0))
    }

    func test_clearingTheQuantity_keepsTheMacrosAndMakesTheDraftUnsaveable() {
        var draft = EntryDraft(entry(quantity: 2, macros: Macros(calories: 140, protein: 12, fat: 10, carbs: 0)))

        draft.setQuantity(nil)

        XCTAssertNil(draft.quantity)
        XCTAssertEqual(draft.macros, Macros(calories: 140, protein: 12, fat: 10, carbs: 0))
        XCTAssertFalse(draft.isSaveable)

        draft.setQuantity(1)

        XCTAssertEqual(draft.macros, Macros(calories: 70, protein: 6, fat: 5, carbs: 0))
        XCTAssertTrue(draft.isSaveable)
    }

    func test_editedMacros_standAsTyped_andAnEmptyFieldReadsAsZero() {
        var draft = EntryDraft(entry(quantity: 1, macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0)))

        draft.typedMacros[.calories] = 78
        draft.typedMacros[.fat] = nil

        XCTAssertEqual(draft.macros, Macros(calories: 78, protein: 6, fat: 0, carbs: 0))
        XCTAssertTrue(draft.isSaveable)
    }

    func test_aNegativeMacro_makesTheDraftUnsaveable() {
        var draft = EntryDraft(entry(quantity: 1, macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0)))

        draft.typedMacros[.protein] = -1

        XCTAssertNil(draft.macros)
        XCTAssertFalse(draft.isSaveable)
    }

    // MARK: Text

    func test_amounts_readWholeWhenWhole_andToOneDecimalOtherwise() {
        XCTAssertEqual(FoodText.amount(70), "70")
        XCTAssertEqual(FoodText.amount(1.5), "1.5")
        XCTAssertEqual(FoodText.amount(93.333), "93.3")
        XCTAssertEqual(FoodText.quantity(2, of: "1 egg"), "2 × 1 egg")
        XCTAssertEqual(FoodText.calories(Macros(calories: 140.4, protein: 0, fat: 0, carbs: 0)), "140 kcal")
    }
}
