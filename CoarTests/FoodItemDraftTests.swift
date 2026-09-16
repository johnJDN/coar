import XCTest
@testable import Coar

/// Seam 2: pure rule functions. The Food Item editor keeps exactly one default Serving as
/// Servings are added, edited, and removed (CONTEXT.md "Serving").
final class FoodItemDraftTests: XCTestCase {

    private let egg = ServingDraft(name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0), isDefault: true)
    private let hundred = ServingDraft(name: "100 g", macros: Macros(calories: 143, protein: 12.6, fat: 9.5, carbs: 0.7))

    func test_savingAServingAsDefault_takesTheFlagFromTheOthers() {
        var draft = FoodItemDraft(name: "Eggs", servings: [egg, hundred])
        var promoted = hundred
        promoted.isDefault = true

        draft.upsert(promoted)

        XCTAssertEqual(draft.servings.map(\.isDefault), [false, true])
    }

    func test_removingTheDefault_makesTheFirstRemainingServingTheDefault() {
        var draft = FoodItemDraft(name: "Eggs", servings: [egg, hundred])

        draft.remove(egg.id)

        XCTAssertEqual(draft.servings.map(\.name), ["100 g"])
        XCTAssertTrue(draft.servings[0].isDefault)
        XCTAssertTrue(draft.isComplete)
    }

    func test_aDraftWithoutAServingOrAName_isNotComplete() {
        var draft = FoodItemDraft(name: "Eggs")
        XCTAssertFalse(draft.isComplete)

        draft.upsert(hundred)
        XCTAssertTrue(draft.isComplete)
        XCTAssertTrue(draft.servings[0].isDefault)

        draft.name = "  "
        XCTAssertFalse(draft.isComplete)
    }

    func test_reorder_followsTheGivenIds() {
        var draft = FoodItemDraft(name: "Eggs", servings: [egg, hundred])

        draft.reorder([hundred.id, egg.id])

        XCTAssertEqual(draft.servings.map(\.name), ["100 g", "1 egg"])
        XCTAssertEqual(draft.servings.map(\.isDefault), [false, true])
    }
}
