import XCTest
@testable import Coar

/// The line page (`.scratch/ai-food-logging/issues/05`): adjusting a line's quantity scales
/// it, typed macros make the numbers the user's own, a failed line gets numbers once typed,
/// and Save as food puts the food in the catalogue with the Entry linked, in one save.
@MainActor
final class DescribeLinePageTests: XCTestCase {

    private let slice = Estimate(
        name: "Pizza", quantity: 1, unit: "slice", grams: 110,
        macros: Macros(calories: 285, protein: 12, fat: 10, carbs: 36),
        source: .estimated, assumption: "Assumed cheese pizza."
    )

    private func filled(_ estimate: Estimate, text: String = "pizza slice") -> DescribeLine {
        DescribeLine(text: text, state: .filled(estimate))
    }

    // MARK: Adjusting

    func test_changingTheQuantity_scalesTheMacrosAndGrams_andKeepsTheSource() throws {
        var edit = DescribeLineEdit(filled(slice))
        edit.setQuantity(2)
        let two = try XCTUnwrap(edit.estimate)
        XCTAssertEqual(two.quantity, 2)
        XCTAssertEqual(two.macros, Macros(calories: 570, protein: 24, fat: 20, carbs: 72))
        XCTAssertEqual(two.grams, 220)
        XCTAssertEqual(two.source, .estimated)
        XCTAssertEqual(two.assumption, "Assumed cheese pizza.")

        edit.setQuantity(nil)
        XCTAssertNil(edit.estimate, "nothing addable while the quantity is cleared")
        edit.setQuantity(1)
        XCTAssertEqual(edit.estimate?.macros.calories, 285, "the macros waited for a quantity, then scaled from 2")
    }

    func test_typingAMacro_makesTheNumbersTyped() throws {
        var edit = DescribeLineEdit(filled(slice))
        edit.setMacro(.calories, 300)
        let typed = try XCTUnwrap(edit.estimate)
        XCTAssertEqual(typed.macros.calories, 300)
        XCTAssertEqual(typed.source, .typed)
        XCTAssertEqual(typed.assumption, "")
    }

    func test_aFailedLine_isAddableOnceItsMacrosAreTyped_emptyFieldsCountingAsZero() throws {
        var edit = DescribeLineEdit(DescribeLine(text: "grandma's lasagna", state: .failed("Not a food Coar knows.")))
        XCTAssertEqual(edit.name, "Grandma's lasagna")
        XCTAssertNil(edit.estimate)
        edit.setMacro(.calories, 600)
        let typed = try XCTUnwrap(edit.estimate)
        XCTAssertEqual(typed.macros, Macros(calories: 600, protein: 0, fat: 0, carbs: 0))
        XCTAssertEqual(typed.unit, "serving")
        XCTAssertEqual(typed.source, .typed)

        var draft = DescribeDraft()
        let id = try XCTUnwrap(draft.lines.first?.id)
        draft.edit(id, text: "grandma's lasagna")
        draft.setEstimate(id, typed)
        XCTAssertEqual(draft.filled.map(\.id), [id])
    }

    func test_aMatchedLine_keepsItsMatchForAQuantity_butNotForOwnNumbersOrAName() throws {
        let matched = Estimate(
            name: "Eggs", quantity: 1, unit: "1 egg", grams: 50, macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0),
            source: .food, assumption: "", match: .foodItem(UUID(), serving: UUID())
        )
        var edit = DescribeLineEdit(filled(matched, text: "egg"))
        XCTAssertFalse(edit.offersSaveAsFood, "already saved")
        edit.setQuantity(3)
        XCTAssertEqual(edit.estimate?.match, matched.match)
        XCTAssertEqual(edit.estimate?.source, .food)

        var renamed = edit
        renamed.name = "Duck eggs"
        XCTAssertNil(renamed.estimate?.match)
        XCTAssertEqual(renamed.estimate?.source, .typed)

        edit.setMacro(.protein, 20)
        XCTAssertNil(edit.estimate?.match)
    }

    // MARK: Save as food

    func test_theServingSaved_isOneOfTheUnit_or100gForAWeighedLine() {
        let saved = slice.servingToSave
        XCTAssertEqual(saved.serving.name, "slice")
        XCTAssertEqual(saved.serving.macros, slice.macros)
        XCTAssertEqual(saved.serving.grams, 110)
        XCTAssertEqual(saved.quantity, 1)

        var twoSlices = slice
        twoSlices.quantity = 2
        twoSlices.macros = slice.macros.scaled(by: 2)
        XCTAssertEqual(twoSlices.servingToSave.serving.macros, slice.macros, "per one slice")
        XCTAssertEqual(twoSlices.servingToSave.quantity, 2)

        let chicken = Estimate(
            name: "Chicken breast", quantity: 150, unit: "g", grams: 150,
            macros: Macros(calories: 248, protein: 46.5, fat: 5.4, carbs: 0), source: .estimated, assumption: ""
        )
        let weighed = chicken.servingToSave
        XCTAssertEqual(weighed.serving.name, "100 g")
        XCTAssertEqual(weighed.serving.grams, 100)
        XCTAssertEqual(weighed.serving.macros.calories, 248 / 1.5, accuracy: 0.001)
        XCTAssertEqual(weighed.quantity, 1.5)
    }

    func test_saveAsFood_createsTheFoodAndALinkedEntry_forWhatTheLineShowed() throws {
        let store = Store.inMemory()
        var twoSlices = slice
        twoSlices.quantity = 2
        twoSlices.macros = slice.macros.scaled(by: 2)
        let (serving, quantity) = twoSlices.servingToSave

        let entry = try store.logEntrySavingFood(name: "Pizza", serving: serving, quantity: quantity, at: Date())

        let food = try XCTUnwrap(store.foodItems().first)
        XCTAssertEqual(try store.foodItems().count, 1)
        XCTAssertEqual(food.name, "Pizza")
        XCTAssertEqual(food.servings.map(\.name), ["slice"])
        XCTAssertEqual(food.defaultServing?.macros, slice.macros)
        XCTAssertEqual(entry.foodItemID, food.id)
        XCTAssertEqual(entry.quantity, 2)
        XCTAssertEqual(entry.macros, twoSlices.macros)
    }

    func test_saveAsFood_isKeptWithTheDraft() throws {
        var draft = DescribeDraft()
        let id = try XCTUnwrap(draft.lines.first?.id)
        draft.setSaveAsFood(id, false)
        let data = try JSONEncoder().encode(draft)
        XCTAssertEqual(try JSONDecoder().decode(DescribeDraft.self, from: data).line(id)?.saveAsFood, false)

        let older = #"{"lines":[{"id":"\#(id.uuidString)","text":"toast","state":{"typing":{}}}]}"#
        XCTAssertEqual(try JSONDecoder().decode(DescribeDraft.self, from: Data(older.utf8)).line(id)?.saveAsFood, true, "a draft from before the flag reads with the default")
    }
}
