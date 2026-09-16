import XCTest
@testable import Coar

/// Seam 2: pure rule functions. The Food tab's summary row shows consumed / target per
/// macro with a thin bar against the Target in force on the Day; with no Target the slot
/// reads `—` and the bar has no fill, never 0 % (`.scratch/data-model/issues/02`).
final class MacroSummaryTests: XCTestCase {

    private let eaten = Macros(calories: 1_240, protein: 137.5, fat: 41, carbs: 150)
    private let cut = Macros(calories: 2_100, protein: 180, fat: 60, carbs: 210)

    func test_withATarget_eachBarReadsConsumedOverTarget_andFillsByTheShare() {
        let summary = MacroSummary(consumed: eaten, target: cut)

        XCTAssertEqual(summary.bars.map(\.macro), [.calories, .protein, .fat, .carbs])
        XCTAssertEqual(summary.bars.map(\.consumed), ["1,240", "138", "41", "150"])
        XCTAssertEqual(summary.bars.map(\.target), ["2,100", "180", "60", "210"])
        XCTAssertEqual(try XCTUnwrap(summary.bars[0].fraction), 1_240 / 2_100, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(summary.bars[2].fraction), 41 / 60, accuracy: 0.0001)
    }

    func test_overTheTarget_theBarIsFull() {
        let summary = MacroSummary(consumed: Macros(calories: 2_500, protein: 0, fat: 0, carbs: 0), target: cut)

        XCTAssertEqual(summary.bars[0].fraction, 1)
        XCTAssertEqual(summary.bars[1].fraction, 0)
    }

    func test_withNoTarget_theTargetSlotIsADash_andTheBarHasNoFill() {
        let summary = MacroSummary(consumed: eaten, target: nil)

        XCTAssertEqual(summary.bars.map(\.consumed), ["1,240", "138", "41", "150"])
        XCTAssertEqual(summary.bars.map(\.target), ["—", "—", "—", "—"])
        XCTAssertEqual(summary.bars.map(\.fraction), [nil, nil, nil, nil])
    }

    func test_aZeroTarget_countsAsNoTargetForThatBar() {
        let summary = MacroSummary(consumed: eaten, target: Macros(calories: 2_100, protein: 0, fat: 60, carbs: 210))

        XCTAssertEqual(summary.bars[1].target, "—")
        XCTAssertNil(summary.bars[1].fraction)
        XCTAssertNotNil(summary.bars[0].fraction)
    }

    // MARK: A Meal's macros

    func test_aMealsMacros_areItsLinesSummed_andScaleByTheMultiplier() {
        let meal = MealRecord(id: UUID(), name: "Egg bowl", isArchived: false, components: [
            MealComponentRecord(id: UUID(), foodItemID: UUID(), servingID: UUID(), name: "Eggs", servingName: "1 egg", quantity: 2, servingMacros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0)),
            MealComponentRecord(id: UUID(), foodItemID: UUID(), servingID: UUID(), name: "Rice", servingName: "1 cup", quantity: 1, servingMacros: Macros(calories: 200, protein: 4, fat: 0, carbs: 44)),
        ], modifiedAt: Date())

        XCTAssertEqual(meal.macros, Macros(calories: 340, protein: 16, fat: 10, carbs: 44))
        XCTAssertEqual(meal.macros.scaled(by: 0.5), Macros(calories: 170, protein: 8, fat: 5, carbs: 22))
        XCTAssertEqual(MealRecord(id: UUID(), name: "Nothing", isArchived: false, components: [], modifiedAt: Date()).macros, .zero)
    }
}
