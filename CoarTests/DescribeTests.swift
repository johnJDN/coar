import XCTest
@testable import Coar

/// The Describe tab (`.scratch/ai-food-logging/`). Seam 2 covers reading a model's reply into
/// an Estimate, the checks that keep impossible numbers from being logged, and every change
/// the draft of typed lines goes through. Seam 1 covers the Entry that stands on its own.
@MainActor
final class DescribeTests: XCTestCase {

    private let eggs = Estimate(
        name: "Eggs", quantity: 2, unit: "large egg", grams: 100,
        macros: Macros(calories: 143, protein: 12.6, fat: 9.5, carbs: 0.7),
        source: .estimated, assumption: "Assumed boiled."
    )

    // MARK: Reading a reply

    func test_aReply_becomesAnEstimateForTheWholePortion() throws {
        let reply = #"{"is_food":true,"name":"Eggs","quantity":2,"unit":"large egg","grams":100,"calories":143,"protein":12.6,"fat":9.5,"carbs":0.7,"needs_lookup":false,"assumption":"Assumed boiled."}"#
        let estimate = try Estimate(reply: Data(reply.utf8), source: .estimated)
        XCTAssertEqual(estimate, eggs)
        XCTAssertEqual(estimate.portion, "2 × large egg")
    }

    func test_aReply_withNoUnitOrGrams_countsAServing() throws {
        let reply = #"{"is_food":true,"name":"Pizza","quantity":1,"unit":" ","grams":null,"calories":285,"protein":12,"fat":10,"carbs":36,"needs_lookup":false,"assumption":""}"#
        let estimate = try Estimate(reply: Data(reply.utf8), source: .estimated)
        XCTAssertEqual(estimate.unit, "serving")
        XCTAssertNil(estimate.grams)
    }

    func test_notFood_andNotJSON_areTheirOwnErrors() {
        let notFood = #"{"is_food":false,"name":"None","quantity":0,"unit":"","grams":0,"calories":0,"protein":0,"fat":0,"carbs":0,"needs_lookup":false,"assumption":""}"#
        XCTAssertThrowsError(try Estimate(reply: Data(notFood.utf8), source: .estimated)) { XCTAssertEqual($0 as? Estimate.ReplyError, .notFood) }
        XCTAssertThrowsError(try Estimate(reply: Data("Sure! Here's".utf8), source: .estimated)) { XCTAssertEqual($0 as? Estimate.ReplyError, .unreadable) }
    }

    // MARK: Checks

    func test_impossibleNumbers_areNeverLoggable() {
        var estimate = eggs
        XCTAssertNil(estimate.impossibility)
        estimate.macros.fat = -1
        XCTAssertNotNil(estimate.impossibility)
        estimate = eggs
        estimate.macros.calories = 5_001
        XCTAssertNotNil(estimate.impossibility)
        estimate = eggs
        estimate.grams = 3_001
        XCTAssertNotNil(estimate.impossibility)
        estimate = eggs
        estimate.quantity = 0
        XCTAssertNotNil(estimate.impossibility)
        estimate = eggs
        estimate.macros.protein = .nan
        XCTAssertNotNil(estimate.impossibility)
    }

    func test_caloriesDisagreeing_withTheMacros_isFlagged() {
        XCTAssertFalse(eggs.caloriesDisagree, "143 vs 4×12.6 + 4×0.7 + 9×9.5 = 147")
        var small = eggs
        small.macros = Macros(calories: 60, protein: 0, fat: 0, carbs: 0)
        XCTAssertTrue(small.caloriesDisagree, "60 kcal from nothing is off by more than 40")
        small.macros = Macros(calories: 30, protein: 0, fat: 0, carbs: 0)
        XCTAssertFalse(small.caloriesDisagree, "within 40 kcal is fine at any share")
        var big = eggs
        big.macros = Macros(calories: 1_000, protein: 50, fat: 40, carbs: 100)
        XCTAssertFalse(big.caloriesDisagree, "1,000 vs 960 is within 20%")
        big.macros.calories = 1_300
        XCTAssertTrue(big.caloriesDisagree, "1,300 vs 960 isn't")
    }

    // MARK: The draft

    func test_aTypedLine_isSentOnce_andFilledByItsReply() throws {
        var draft = DescribeDraft()
        let id = try XCTUnwrap(draft.lines.first?.id)
        draft.edit(id, text: "2 eggs ")
        XCTAssertEqual(draft.unsent, [id])

        let sent = try XCTUnwrap(draft.begin(id))
        XCTAssertEqual(sent, "2 eggs")
        XCTAssertNil(draft.begin(id), "already checking")
        XCTAssertTrue(draft.finish(id, sentText: sent, result: .success(eggs)))

        XCTAssertEqual(draft.line(id)?.estimate, eggs)
        XCTAssertNil(draft.begin(id), "already filled for this text")
        XCTAssertEqual(draft.filled.map(\.id), [id])
        XCTAssertEqual(draft.filledTotal, eggs.macros)
    }

    func test_editingALine_clearsItsEstimate_andAStaleReplyIsDropped() throws {
        var draft = DescribeDraft()
        let id = try XCTUnwrap(draft.lines.first?.id)
        draft.edit(id, text: "2 eggs")
        let sent = try XCTUnwrap(draft.begin(id))
        draft.edit(id, text: "3 eggs")
        XCTAssertEqual(draft.line(id)?.state, .typing)

        XCTAssertFalse(draft.finish(id, sentText: sent, result: .success(eggs)), "the reply is for text no longer there")
        XCTAssertEqual(draft.line(id)?.state, .typing)

        draft.edit(id, text: "3 eggs ")
        XCTAssertEqual(draft.line(id)?.state, .typing, "trailing space alone is no new meaning, and the line is still unsent")
        _ = draft.begin(id)
        draft.finish(id, sentText: "3 eggs", result: .success(eggs))
        draft.edit(id, text: "3 eggs  ")
        XCTAssertEqual(draft.line(id)?.estimate, eggs, "spacing doesn't clear a filled line")
    }

    func test_failures_landWhereTheScreenShowsThem() throws {
        var draft = DescribeDraft()
        let id = try XCTUnwrap(draft.lines.first?.id)
        func attempt(_ error: Error) -> DescribeLine.State? {
            draft.edit(id, text: "x")
            draft.edit(id, text: "toast")
            let sent = draft.begin(id)!
            draft.finish(id, sentText: sent, result: .failure(error))
            return draft.line(id)?.state
        }
        XCTAssertEqual(attempt(OpenRouterError.offline), .waiting)
        XCTAssertEqual(draft.unsent, [id], "a waiting line goes again")
        XCTAssertEqual(attempt(OpenRouterError.keyRejected), .typing, "a key problem is the tab's, not the line's")
        XCTAssertEqual(attempt(OpenRouterError.failed("OpenRouter: Upstream error")), .failed("OpenRouter: Upstream error"))
        XCTAssertEqual(attempt(Estimate.ReplyError.notFood), .failed("Not a food Coar knows. Check the spelling, or say more."))
        XCTAssertEqual(attempt(URLError(.notConnectedToInternet)), .waiting)

        var huge = eggs
        huge.macros.calories = 9_000
        draft.edit(id, text: "huge")
        draft.finish(id, sentText: draft.begin(id)!, result: .success(huge))
        guard case .failed = draft.line(id)?.state else { return XCTFail("impossible numbers fail the line") }
        XCTAssertTrue(draft.filled.isEmpty)
    }

    func test_returnAddsALineBelow_andBackspaceOnAnEmptyLineRemovesIt_butNeverTheLast() throws {
        var draft = DescribeDraft()
        let first = try XCTUnwrap(draft.lines.first?.id)
        let third = draft.insertLine(after: first)
        let second = draft.insertLine(after: first)
        XCTAssertEqual(draft.lines.map(\.id), [first, second, third])

        XCTAssertEqual(draft.removeLine(second), first)
        XCTAssertEqual(draft.removeLine(first), third, "removing the first focuses the one that took its place")
        draft.edit(third, text: "toast")
        XCTAssertEqual(draft.removeLine(third), third)
        XCTAssertEqual(draft.lines.count, 1)
        XCTAssertEqual(draft.lines.first?.text, "", "the last line is emptied, not removed")
    }

    func test_removingLoggedLines_keepsTheOthers_andAlwaysOneLine() throws {
        var draft = DescribeDraft()
        let logged = try XCTUnwrap(draft.lines.first?.id)
        let failed = draft.insertLine(after: logged)
        draft.remove([logged])
        XCTAssertEqual(draft.lines.map(\.id), [failed])
        draft.remove([failed])
        XCTAssertEqual(draft.lines.count, 1)
    }

    // MARK: Store

    func test_anEntryWithNothingBehindIt_countsTowardItsDay() throws {
        let store = Store.inMemory()
        let noon = Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!

        let entry = try store.logEntry(name: "Eggs", servingName: "large egg", quantity: 2, macros: eggs.macros, at: noon)

        let read = try XCTUnwrap(store.entries(on: .today()).first)
        XCTAssertEqual(read, entry)
        XCTAssertEqual(read.name, "Eggs")
        XCTAssertEqual(read.servingName, "large egg")
        XCTAssertEqual(read.quantity, 2)
        XCTAssertNil(read.foodItemID)
        XCTAssertNil(read.mealID)
        XCTAssertEqual(try store.dailyTotals(from: .today(), to: .today())[.today()], eggs.macros)
    }
}
