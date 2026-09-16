import XCTest
@testable import Coar

/// Seam 1: the store façade. A Meal is a named group of Food Items in fixed quantities
/// (CONTEXT.md "Meal"), read live from the Servings it points at; logging it makes one Entry
/// that snapshots the Meal's name, its summed macros × the multiplier, and its component
/// breakdown, so editing the Meal or its Food Items later never changes what was eaten
/// (ADR 0003).
@MainActor
final class MealTests: XCTestCase {

    private let sep13 = Day(year: 2026, month: 9, day: 13)

    private struct Pantry {
        let eggs: FoodItemRecord
        let rice: FoodItemRecord
        var oneEgg: ServingRecord { eggs.servings[0] }
        var hundredGramsEgg: ServingRecord { eggs.servings[1] }
        var cupOfRice: ServingRecord { rice.servings[0] }
    }

    private func stock(_ store: Store) throws -> Pantry {
        Pantry(
            eggs: try store.createFoodItem(name: "Eggs", servings: [
                ServingDraft(name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0), grams: 50, isDefault: true),
                ServingDraft(name: "100 g", macros: Macros(calories: 140, protein: 12, fat: 10, carbs: 1), grams: 100),
            ]),
            rice: try store.createFoodItem(name: "Rice", servings: [
                ServingDraft(name: "1 cup", macros: Macros(calories: 200, protein: 4, fat: 0, carbs: 44)),
            ])
        )
    }

    /// 2 eggs and a cup of rice: 340 kcal, 16 g protein, 10 g fat, 44 g carbs.
    private func makeBreakfast(_ store: Store, _ pantry: Pantry) throws -> MealRecord {
        try store.createMeal(name: "Egg bowl", components: [
            MealComponentDraft(foodItemID: pantry.eggs.id, servingID: pantry.oneEgg.id, quantity: 2),
            MealComponentDraft(foodItemID: pantry.rice.id, servingID: pantry.cupOfRice.id, quantity: 1),
        ])
    }

    // MARK: Meals

    func test_newMeal_readsBackWithItsLinesInOrder_namedFromTheirFoodItems_andSummedMacros() throws {
        let store = Store.inMemory()
        let pantry = try stock(store)

        let bowl = try makeBreakfast(store, pantry)

        let read = try XCTUnwrap(store.meal(bowl.id))
        XCTAssertEqual(read.name, "Egg bowl")
        XCTAssertFalse(read.isArchived)
        XCTAssertEqual(read.components.map(\.name), ["Eggs", "Rice"])
        XCTAssertEqual(read.components.map(\.servingName), ["1 egg", "1 cup"])
        XCTAssertEqual(read.components.map(\.quantity), [2, 1])
        XCTAssertEqual(read.components.map(\.foodItemID), [pantry.eggs.id, pantry.rice.id])
        XCTAssertEqual(read.components.map(\.servingID), [pantry.oneEgg.id, pantry.cupOfRice.id])
        XCTAssertEqual(read.macros, Macros(calories: 340, protein: 16, fat: 10, carbs: 44))
        XCTAssertEqual(try store.meals().map(\.name), ["Egg bowl"])
    }

    func test_updatingAMeal_keepsLinesByIdInTheNewOrder_andDropsTheOnesLeftOut() throws {
        let store = Store.inMemory()
        let pantry = try stock(store)
        let bowl = try makeBreakfast(store, pantry)
        let eggLine = try XCTUnwrap(bowl.components.first)
        let moreEggs = MealComponentDraft(id: eggLine.id, foodItemID: pantry.eggs.id, servingID: pantry.hundredGramsEgg.id, quantity: 1.5)
        let toast = try store.createFoodItem(name: "Toast", servings: [ServingDraft(name: "1 slice", macros: Macros(calories: 80, protein: 3, fat: 1, carbs: 15))])
        let toastLine = MealComponentDraft(foodItemID: toast.id, servingID: toast.servings[0].id, quantity: 2)

        try store.updateMeal(bowl.id, name: "Egg plate", components: [toastLine, moreEggs])

        let read = try XCTUnwrap(store.meal(bowl.id))
        XCTAssertEqual(read.name, "Egg plate")
        XCTAssertEqual(read.components.map(\.id), [toastLine.id, eggLine.id])
        XCTAssertEqual(read.components.map(\.servingName), ["1 slice", "100 g"])
        XCTAssertEqual(read.components.map(\.quantity), [2, 1.5])
        XCTAssertEqual(read.macros, Macros(calories: 370, protein: 24, fat: 17, carbs: 31.5))
    }

    func test_editingAFoodItemsServing_changesWhatTheMealSumsNow() throws {
        let store = Store.inMemory()
        let pantry = try stock(store)
        let bowl = try makeBreakfast(store, pantry)

        var bigger = ServingDraft(pantry.oneEgg)
        bigger.macros.calories = 80
        try store.updateFoodItem(pantry.eggs.id, name: "Eggs", servings: [bigger, ServingDraft(pantry.hundredGramsEgg)])

        XCTAssertEqual(try store.meal(bowl.id)?.macros.calories, 360)
    }

    func test_removingTheServingALineUses_leavesTheLineWithNoMacros() throws {
        let store = Store.inMemory()
        let pantry = try stock(store)
        let bowl = try makeBreakfast(store, pantry)

        try store.updateFoodItem(pantry.eggs.id, name: "Eggs", servings: [ServingDraft(pantry.hundredGramsEgg)])

        let read = try XCTUnwrap(store.meal(bowl.id))
        XCTAssertEqual(read.components.map(\.name), ["Eggs", "Rice"])
        XCTAssertNil(read.components[0].servingID)
        XCTAssertEqual(read.macros, Macros(calories: 200, protein: 4, fat: 0, carbs: 44))
    }

    // MARK: Logging a Meal snapshots it (ADR 0003)

    func test_loggingAMeal_makesOneEntryWithItsName_summedMacrosTimesTheMultiplier_andTheBreakdown() throws {
        let store = Store.inMemory()
        let pantry = try stock(store)
        let bowl = try makeBreakfast(store, pantry)
        let instant = sep13.start().addingTimeInterval(8 * 3600)

        let entry = try store.logEntry(meal: bowl.id, quantity: 0.5, at: instant)

        XCTAssertEqual(entry.name, "Egg bowl")
        XCTAssertEqual(entry.quantity, 0.5)
        XCTAssertEqual(entry.macros, Macros(calories: 170, protein: 8, fat: 5, carbs: 22))
        XCTAssertEqual(entry.loggedAt, instant)
        XCTAssertEqual(entry.day, sep13)
        XCTAssertEqual(entry.mealID, bowl.id)
        XCTAssertNil(entry.foodItemID)
        XCTAssertEqual(entry.components, [
            EntryComponentRecord(name: "Eggs", servingName: "1 egg", quantity: 2, macros: Macros(calories: 140, protein: 12, fat: 10, carbs: 0)),
            EntryComponentRecord(name: "Rice", servingName: "1 cup", quantity: 1, macros: Macros(calories: 200, protein: 4, fat: 0, carbs: 44)),
        ])
        XCTAssertEqual(try store.entries(on: sep13).map(\.id), [entry.id])
        XCTAssertEqual(try store.entry(entry.id), entry)
    }

    func test_mealEntry_keepsItsSnapshot_whenTheMealOrItsFoodItemsChange() throws {
        let store = Store.inMemory()
        let pantry = try stock(store)
        let bowl = try makeBreakfast(store, pantry)
        let entry = try store.logEntry(meal: bowl.id, quantity: 1, at: sep13.start())

        try store.updateMeal(bowl.id, name: "Rice bowl", components: [
            MealComponentDraft(foodItemID: pantry.rice.id, servingID: pantry.cupOfRice.id, quantity: 3),
        ])
        try store.updateFoodItem(pantry.rice.id, name: "Brown rice", servings: [
            ServingDraft(id: pantry.cupOfRice.id, name: "1 bowl", macros: Macros(calories: 250, protein: 5, fat: 2, carbs: 50)),
        ])

        let read = try XCTUnwrap(store.entry(entry.id))
        XCTAssertEqual(read.name, "Egg bowl")
        XCTAssertEqual(read.macros, Macros(calories: 340, protein: 16, fat: 10, carbs: 44))
        XCTAssertEqual(read.components.map(\.name), ["Eggs", "Rice"])
        XCTAssertEqual(read.components.map(\.servingName), ["1 egg", "1 cup"])
        XCTAssertEqual(read.components.last?.macros.calories, 200)
    }

    func test_editingAMealEntry_neverTouchesTheMeal() throws {
        let store = Store.inMemory()
        let pantry = try stock(store)
        let bowl = try makeBreakfast(store, pantry)
        let entry = try store.logEntry(meal: bowl.id, quantity: 1, at: sep13.start())

        try store.updateEntry(entry.id, loggedAt: sep13.start(), quantity: 2, macros: Macros(calories: 700, protein: 30, fat: 20, carbs: 90))

        XCTAssertEqual(try store.entry(entry.id)?.quantity, 2)
        XCTAssertEqual(try store.entry(entry.id)?.components.map(\.quantity), [2, 1])
        let meal = try XCTUnwrap(store.meal(bowl.id))
        XCTAssertEqual(meal.macros, Macros(calories: 340, protein: 16, fat: 10, carbs: 44))
        XCTAssertEqual(meal.components.map(\.quantity), [2, 1])
    }

    func test_deletingAMealEntry_leavesTheMeal() throws {
        let store = Store.inMemory()
        let pantry = try stock(store)
        let bowl = try makeBreakfast(store, pantry)
        let entry = try store.logEntry(meal: bowl.id, quantity: 1, at: sep13.start())

        try store.deleteEntry(entry.id)

        XCTAssertNil(try store.entry(entry.id))
        XCTAssertEqual(try store.meal(bowl.id)?.components.count, 2)
    }

    // MARK: Archive

    func test_archivedMeal_leavesThePickerQuery_whileItsEntriesStay_andRestores() throws {
        let store = Store.inMemory()
        let pantry = try stock(store)
        let bowl = try makeBreakfast(store, pantry)
        let entry = try store.logEntry(meal: bowl.id, quantity: 1, at: sep13.start())

        try store.archiveMeal(bowl.id)

        XCTAssertEqual(try store.meals(), [])
        XCTAssertEqual(try store.archivedMeals().map(\.id), [bowl.id])
        XCTAssertEqual(try store.entries(on: sep13).map(\.id), [entry.id])
        XCTAssertEqual(try store.entry(entry.id)?.mealID, bowl.id)

        try store.restoreMeal(bowl.id)

        XCTAssertEqual(try store.meals().map(\.id), [bowl.id])
    }

    func test_meals_listByNameRegardlessOfCase() throws {
        let store = Store.inMemory()
        let pantry = try stock(store)
        let line = MealComponentDraft(foodItemID: pantry.eggs.id, servingID: pantry.oneEgg.id, quantity: 1)
        try store.createMeal(name: "omelette", components: [line])
        try store.createMeal(name: "Breakfast", components: [line])

        XCTAssertEqual(try store.meals().map(\.name), ["Breakfast", "omelette"])
    }
}
