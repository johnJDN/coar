import XCTest
@testable import Coar

/// Seam 1: the store façade. A Target is a dated series (ADR 0003); a Day is judged against
/// the Target in force on that Day, and "none in force" is nil, never 0
/// (`.scratch/data-model/issues/02`).
@MainActor
final class TargetTests: XCTestCase {

    private let cut = Macros(calories: 2_100, protein: 180, fat: 60, carbs: 210)
    private let bulk = Macros(calories: 2_900, protein: 190, fat: 85, carbs: 340)

    private let sep10 = Day(year: 2026, month: 9, day: 10)
    private let sep11 = Day(year: 2026, month: 9, day: 11)
    private let sep12 = Day(year: 2026, month: 9, day: 12)
    private let sep13 = Day(year: 2026, month: 9, day: 13)

    func test_targetInForce_withNoTargets_isNil() throws {
        let store = Store.inMemory()

        XCTAssertNil(try store.target(inForceOn: sep13))
    }

    func test_targetInForce_onDayBeforeFirstEffectiveFrom_isNil() throws {
        let store = Store.inMemory()
        try store.setTarget(cut, effectiveFrom: sep11)

        XCTAssertNil(try store.target(inForceOn: sep10))
    }

    func test_targetInForce_onItsEffectiveFromDay_isThatTarget() throws {
        let store = Store.inMemory()
        try store.setTarget(cut, effectiveFrom: sep11)

        XCTAssertEqual(try store.target(inForceOn: sep11)?.macros, cut)
    }

    func test_targetInForce_onDaysAroundALaterTarget_isWhicheverAppliedThen() throws {
        let store = Store.inMemory()
        try store.setTarget(cut, effectiveFrom: sep11)
        try store.setTarget(bulk, effectiveFrom: sep13)

        XCTAssertEqual(try store.target(inForceOn: sep12)?.macros, cut)
        XCTAssertEqual(try store.target(inForceOn: sep13)?.macros, bulk)
        XCTAssertEqual(try store.target(inForceOn: Day(year: 2026, month: 12, day: 25))?.macros, bulk)
    }

    func test_settingTargetToday_leavesYesterdaysLookupUnchanged() throws {
        let store = Store.inMemory()
        try store.setTarget(cut, effectiveFrom: sep10)

        try store.setTarget(bulk, effectiveFrom: sep13)

        XCTAssertEqual(try store.target(inForceOn: sep12)?.macros, cut)
        XCTAssertEqual(try store.target(inForceOn: sep13)?.macros, bulk)
    }

    func test_settingUnchangedTarget_createsNothing() throws {
        let store = Store.inMemory()
        try store.setTarget(cut, effectiveFrom: sep10)

        try store.setTarget(cut, effectiveFrom: sep13)

        XCTAssertEqual(try store.target(inForceOn: sep13)?.effectiveFrom, sep10)
    }

    func test_settingTargetTwiceOnOneDay_replacesThatDaysEntry() throws {
        let store = Store.inMemory()
        try store.setTarget(cut, effectiveFrom: sep10)
        try store.setTarget(bulk, effectiveFrom: sep13)

        let corrected = Macros(calories: 2_800, protein: 190, fat: 80, carbs: 330)
        try store.setTarget(corrected, effectiveFrom: sep13)

        XCTAssertEqual(try store.target(inForceOn: sep13)?.macros, corrected)
        XCTAssertEqual(try store.target(inForceOn: sep12)?.macros, cut)
    }

    // MARK: The Food summary row

    func test_aDayBeforeTheFirstTarget_hasNoTarget_andTheSummaryRowRendersItsEmptyForm() throws {
        let store = Store.inMemory()
        try store.setTarget(cut, effectiveFrom: sep11)
        let eggs = try store.createFoodItem(name: "Eggs", servings: [ServingDraft(name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0))])
        try store.logEntry(foodItem: eggs.id, serving: eggs.servings[0].id, quantity: 2, at: sep10.start().addingTimeInterval(8 * 3600))
        try store.logEntry(foodItem: eggs.id, serving: eggs.servings[0].id, quantity: 1, at: sep10.start().addingTimeInterval(13 * 3600))

        XCTAssertNil(try store.target(inForceOn: sep10))
        let before = MacroSummary(
            consumed: Macros.sum(try store.entries(on: sep10).map(\.macros)),
            target: try store.target(inForceOn: sep10)?.macros
        )
        XCTAssertEqual(before.bars[0].consumed, "210")
        XCTAssertEqual(before.bars.map(\.target), ["—", "—", "—", "—"])
        XCTAssertEqual(before.bars.map(\.fraction), [nil, nil, nil, nil])

        let after = MacroSummary(
            consumed: Macros.sum(try store.entries(on: sep11).map(\.macros)),
            target: try store.target(inForceOn: sep11)?.macros
        )
        XCTAssertEqual(after.bars[0].consumed, "0")
        XCTAssertEqual(after.bars[0].target, "2,100")
        XCTAssertEqual(after.bars[0].fraction, 0)
    }
}
