import XCTest
@testable import Coar

@MainActor
final class RecentUseTests: XCTestCase {

    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func candidate(_ name: String, edited: TimeInterval?, logged: TimeInterval?) -> RecentUse.Candidate<String> {
        .init(value: name, name: name, modifiedAt: edited.map { t0 + $0 }, lastLoggedAt: logged.map { t0 + $0 })
    }

    func test_mostRecentlyUsedFirst_usingTheLaterOfEditAndLog() {
        let ordered = RecentUse.ordered([
            candidate("Eggs", edited: 10, logged: 50),
            candidate("Rice", edited: 60, logged: nil),
            candidate("Oats", edited: 5, logged: 20),
        ])
        XCTAssertEqual(ordered, ["Rice", "Eggs", "Oats"])
    }

    func test_undatedLast_andTiesByName() {
        let ordered = RecentUse.ordered([
            candidate("Zucchini", edited: nil, logged: nil),
            candidate("Banana", edited: 10, logged: nil),
            candidate("Apple", edited: 10, logged: nil),
        ])
        XCTAssertEqual(ordered, ["Apple", "Banana", "Zucchini"])
    }

    // MARK: Through the façade

    func test_loggingAFoodItem_movesItToTheTop() throws {
        let store = Store.inMemory()
        let serving = ServingDraft(name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0))
        let eggs = try store.createFoodItem(name: "Eggs", servings: [serving])
        _ = try store.createFoodItem(name: "Rice", servings: [ServingDraft(name: "1 cup", macros: Macros(calories: 200, protein: 4, fat: 0, carbs: 45))])
        XCTAssertEqual(try store.foodItems().map(\.name), ["Rice", "Eggs"], "newest first before anything is logged")

        let eggServing = try XCTUnwrap(try store.foodItem(eggs.id)?.defaultServing)
        try store.logEntry(foodItem: eggs.id, serving: eggServing.id, quantity: 2, at: Date())
        XCTAssertEqual(try store.foodItems().map(\.name), ["Eggs", "Rice"])
    }

    func test_archivedFoodItems_listByName() throws {
        let store = Store.inMemory()
        for name in ["Rice", "Apple"] {
            let item = try store.createFoodItem(name: name, servings: [ServingDraft(name: "1", macros: Macros(calories: 1, protein: 0, fat: 0, carbs: 0))])
            try store.archiveFoodItem(item.id)
        }
        XCTAssertEqual(try store.archivedFoodItems().map(\.name), ["Apple", "Rice"])
    }
}

@MainActor
final class RecentUseLoggedAtTests: XCTestCase {

    /// An Entry for late tonight, logged this morning, must not pin its food to the top once
    /// another food is logged afterwards.
    func test_orderFollowsWhenLogged_notTheTimeOfDayEaten() throws {
        let store = Store.inMemory()
        let serving = ServingDraft(name: "1", macros: Macros(calories: 100, protein: 0, fat: 0, carbs: 0))
        let chicken = try store.createFoodItem(name: "Chicken breast", servings: [serving])
        let rice = try store.createFoodItem(name: "Rice", servings: [serving])
        let lateTonight = Date().addingTimeInterval(12 * 3600)
        let earlier = Date().addingTimeInterval(-6 * 3600)

        try store.logEntry(foodItem: chicken.id, serving: try XCTUnwrap(chicken.defaultServing).id, quantity: 1, at: lateTonight)
        try store.logEntry(foodItem: rice.id, serving: try XCTUnwrap(rice.defaultServing).id, quantity: 1, at: earlier)

        XCTAssertEqual(try store.foodItems().map(\.name), ["Rice", "Chicken breast"])
    }
}
