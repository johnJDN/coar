import XCTest
@testable import Coar

/// Your library wins (`.scratch/ai-food-logging/issues/04`): a line that means one of the
/// user's Food Items or Meals is logged through it, with its numbers. Seam 2 covers the exact
/// match, the handles the model sees, and resolving the model's pick; Seam 1 covers the Entry
/// a match logs.
@MainActor
final class FoodLibraryTests: XCTestCase {

    private let oneEgg = ServingDraft(name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0), grams: 50, isDefault: true)
    private let hundredGrams = ServingDraft(name: "100 g", macros: Macros(calories: 140, protein: 12, fat: 10, carbs: 1), grams: 100)

    private func catalogue() throws -> (Store, FoodItemRecord, MealRecord, FoodLibrary) {
        let store = Store.inMemory()
        let eggs = try store.createFoodItem(name: "Eggs", servings: [oneEgg, hundredGrams])
        let toast = try store.createFoodItem(name: "Toast", servings: [ServingDraft(name: "1 slice", macros: Macros(calories: 80, protein: 3, fat: 1, carbs: 15), isDefault: true)])
        let oats = try store.createMeal(name: "Overnight oats", components: [
            MealComponentDraft(foodItemID: toast.id, servingID: toast.servings[0].id, quantity: 2),
        ])
        let archived = try store.createFoodItem(name: "Bagel", servings: [oneEgg])
        try store.archiveFoodItem(archived.id)
        // In a set order: the catalogue itself lists the most recently used first.
        let library = FoodLibrary(foodItems: [eggs, toast, try XCTUnwrap(store.foodItem(archived.id))], meals: try store.meals())
        return (store, eggs, oats, library)
    }

    // MARK: Exact names

    func test_aLineThatIsAName_matchesItsDefaultServing_timesTheQuantity() throws {
        let (_, eggs, _, library) = try catalogue()

        let two = try XCTUnwrap(library.exactMatch("2 Eggs"))
        XCTAssertEqual(two.match, .foodItem(eggs.id, serving: eggs.servings[0].id))
        XCTAssertEqual(two.quantity, 2)
        XCTAssertEqual(two.unit, "1 egg")
        XCTAssertEqual(two.macros, Macros(calories: 140, protein: 12, fat: 10, carbs: 0))
        XCTAssertEqual(two.source, .food)

        XCTAssertEqual(library.exactMatch("egg")?.quantity, 1, "singular meets plural")
        XCTAssertEqual(library.exactMatch("½ eggs")?.quantity, 0.5)
        XCTAssertEqual(library.exactMatch("1/2 eggs")?.quantity, 0.5)
        XCTAssertEqual(library.exactMatch("1.5x eggs")?.quantity, 1.5)
        XCTAssertEqual(library.exactMatch("3 x eggs")?.quantity, 3)
        XCTAssertNil(library.exactMatch("eggs benedict"), "more than the name is the model's to judge")
        XCTAssertNil(library.exactMatch("bagel"), "archived foods don't match")
    }

    func test_aMealsName_matchesTheMeal() throws {
        let (_, _, oats, library) = try catalogue()
        let meal = try XCTUnwrap(library.exactMatch("overnight oats"))
        XCTAssertEqual(meal.match, .meal(oats.id))
        XCTAssertEqual(meal.macros.calories, 160)
        XCTAssertEqual(meal.source, .meal)
        XCTAssertEqual(meal.unit, EntryRecord.mealServingName)
    }

    func test_aMealThatCantBeLogged_isLeftToTheModel() throws {
        let (store, _, oats, _) = try catalogue()
        let toast = try XCTUnwrap(store.foodItems().first { $0.name == "Toast" })
        try store.updateFoodItem(toast.id, name: "Toast", servings: [ServingDraft(name: "2 slices", macros: Macros(calories: 160, protein: 6, fat: 2, carbs: 30), isDefault: true)])
        let library = FoodLibrary(foodItems: try store.foodItems(), meals: try store.meals())
        XCTAssertFalse(try XCTUnwrap(store.meal(oats.id)).isLoggable)
        XCTAssertNil(library.exactMatch("overnight oats"))
    }

    // MARK: Handles

    func test_theModelSeesHandles_notIds_andArchivedFoodsAreLeftOut() throws {
        let (_, _, _, library) = try catalogue()
        XCTAssertEqual(library.promptListing, """
        f1 Eggs: s1 "1 egg", s2 "100 g"
        f2 Toast: s1 "1 slice"
        m1 Overnight oats (meal)
        """)
        XCTAssertNil(FoodLibrary.empty.promptListing)
    }

    func test_theModelsPick_isResolvedToTheCataloguesNumbers() throws {
        let (_, eggs, oats, library) = try catalogue()

        let grams = try XCTUnwrap(library.resolve(food: "f1", serving: "s2", quantity: 2))
        XCTAssertEqual(grams.match, .foodItem(eggs.id, serving: eggs.servings[1].id))
        XCTAssertEqual(grams.macros.calories, 280)
        XCTAssertEqual(grams.grams, 200)

        XCTAssertEqual(library.resolve(food: "f1", serving: nil, quantity: 1)?.unit, "1 egg", "no serving: the default")
        XCTAssertEqual(library.resolve(food: "f1", serving: "s9", quantity: 1)?.unit, "1 egg", "an unknown serving: the default")
        XCTAssertEqual(library.resolve(food: "m1", serving: nil, quantity: 0)?.match, .meal(oats.id))
        XCTAssertEqual(library.resolve(food: "m1", serving: nil, quantity: 0)?.quantity, 1, "a nonsense quantity is one")
        XCTAssertNil(library.resolve(food: "f9", serving: nil, quantity: 1))
        XCTAssertNil(library.resolve(food: "x1", serving: nil, quantity: 1))
    }

    func test_aReplyWithAMatch_isReadAlongsideItsEstimate() throws {
        let reply = #"{"is_food":true,"name":"Eggs","quantity":2,"unit":"large egg","grams":100,"calories":143,"protein":12.6,"fat":9.5,"carbs":0.7,"needs_lookup":false,"assumption":"","match":{"food":"f1","serving":"s1","quantity":2}}"#
        let (estimate, match) = try Estimate.parse(reply: Data(reply.utf8), source: .estimated)
        XCTAssertEqual(estimate.name, "Eggs")
        XCTAssertEqual(match, Estimate.ModelMatch(food: "f1", serving: "s1", quantity: 2))
        let none = #"{"is_food":true,"name":"Banana","quantity":1,"unit":"medium banana","grams":118,"calories":105,"protein":1.3,"fat":0.4,"carbs":27,"needs_lookup":false,"assumption":"","match":null}"#
        XCTAssertNil(try Estimate.parse(reply: Data(none.utf8), source: .estimated).match)
    }

    func test_matches_areNotCached_becauseTheCatalogueCanChange() async throws {
        let (_, _, _, library) = try catalogue()
        let fake = FakeFoodEstimator()
        fake.replies["my usual"] = .success(try XCTUnwrap(library.resolve(food: "m1", serving: nil, quantity: 1)))
        let estimator = CachingFoodEstimator(wrapping: fake, url: nil)
        _ = try await estimator.estimate("my usual", library: library)
        _ = try await estimator.estimate("my usual", library: library)
        XCTAssertEqual(fake.sent.count, 2)
    }

    // MARK: Store

    func test_aMatchedLine_logsAnEntryLinkedToItsFood() throws {
        let (store, eggs, _, library) = try catalogue()
        let two = try XCTUnwrap(library.exactMatch("2 eggs"))
        guard case .foodItem(let id, let serving) = two.match else { return XCTFail() }

        let entry = try store.logEntry(foodItem: id, serving: serving, quantity: two.quantity, at: Date())

        XCTAssertEqual(entry.foodItemID, eggs.id)
        XCTAssertEqual(entry.macros, two.macros, "the Entry holds what the line showed")
    }
}
