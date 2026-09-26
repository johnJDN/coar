import XCTest
@testable import Coar

/// Seam 1: the store façade. Deleting an archived Food Item, Meal, Exercise, or Plan for
/// good leaves history as it was (ADR 0003) and leaves nothing behind that would quietly
/// read wrong: a Meal without the line, a Plan without the row, a Workout without its title.
@MainActor
final class DeletePermanentlyTests: XCTestCase {

    private let noon = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 12))!

    // MARK: Food

    func test_deletingAFoodItem_removesItsLinesFromMeals_andKeepsItsEntries() throws {
        let store = Store.inMemory()
        let eggs = try store.createFoodItem(name: "Eggs", servings: [ServingDraft(name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0), isDefault: true)])
        let rice = try store.createFoodItem(name: "Rice", servings: [ServingDraft(name: "1 cup", macros: Macros(calories: 200, protein: 4, fat: 0, carbs: 44), isDefault: true)])
        let bowl = try store.createMeal(name: "Egg bowl", components: [
            MealComponentDraft(foodItemID: eggs.id, servingID: eggs.servings[0].id, quantity: 2),
            MealComponentDraft(foodItemID: rice.id, servingID: rice.servings[0].id, quantity: 1),
        ])
        try store.createMeal(name: "Plain rice", components: [
            MealComponentDraft(foodItemID: rice.id, servingID: rice.servings[0].id, quantity: 1),
        ])
        let entry = try store.logEntry(foodItem: eggs.id, serving: eggs.servings[0].id, quantity: 3, at: noon)
        try store.archiveFoodItem(eggs.id)

        XCTAssertEqual(try store.mealNames(using: eggs.id), ["Egg bowl"])
        try store.deleteFoodItemPermanently(eggs.id)

        XCTAssertNil(try store.foodItem(eggs.id))
        XCTAssertEqual(try store.archivedFoodItems(), [])
        let meal = try XCTUnwrap(store.meal(bowl.id))
        XCTAssertEqual(meal.components.map(\.name), ["Rice"])
        XCTAssertTrue(meal.isLoggable)
        let kept = try XCTUnwrap(store.entries(on: Day(noon)).first { $0.id == entry.id })
        XCTAssertEqual(kept.name, "Eggs")
        XCTAssertEqual(kept.macros, Macros(calories: 210, protein: 18, fat: 15, carbs: 0))
    }

    func test_deletingAMeal_keepsItsEntries() throws {
        let store = Store.inMemory()
        let rice = try store.createFoodItem(name: "Rice", servings: [ServingDraft(name: "1 cup", macros: Macros(calories: 200, protein: 4, fat: 0, carbs: 44), isDefault: true)])
        let meal = try store.createMeal(name: "Plain rice", components: [
            MealComponentDraft(foodItemID: rice.id, servingID: rice.servings[0].id, quantity: 1),
        ])
        let entry = try store.logEntry(meal: meal.id, quantity: 2, at: noon)
        try store.archiveMeal(meal.id)

        try store.deleteMealPermanently(meal.id)

        XCTAssertNil(try store.meal(meal.id))
        XCTAssertEqual(try store.archivedMeals(), [])
        XCTAssertNotNil(try store.foodItem(rice.id))
        let kept = try XCTUnwrap(store.entries(on: Day(noon)).first { $0.id == entry.id })
        XCTAssertEqual(kept.name, "Plain rice")
        XCTAssertEqual(kept.macros.calories, 400)
    }

    // MARK: Train

    func test_deletingAnExercise_removesItsRowsFromPlans_keepingTheRestOfASuperset() throws {
        let store = Store.inMemory()
        let bench = try store.createExercise(name: "Bench press", muscleGroup: .chest)
        let row = try store.createExercise(name: "Cable row", muscleGroup: .back)
        let fly = try store.createExercise(name: "Cable fly", muscleGroup: .chest)
        let squat = try store.createExercise(name: "Back squat", muscleGroup: .quads)
        let sets = [PlannedSetDraft(targetKilograms: 50, reps: RepRange(8))]
        let plan = try store.createPlan(name: "Push", exercises: [
            PlanExerciseDraft(exerciseID: bench.id, supersetGroup: 1, sets: sets),
            PlanExerciseDraft(exerciseID: row.id, supersetGroup: 1, sets: sets),
            PlanExerciseDraft(exerciseID: squat.id, supersetGroup: nil, sets: sets),
            PlanExerciseDraft(exerciseID: fly.id, supersetGroup: 2, sets: sets),
            PlanExerciseDraft(exerciseID: row.id, supersetGroup: 2, sets: sets),
        ])
        let workout = try store.startWorkout(from: plan.id, at: noon)
        try store.finishWorkout(workout.id, at: noon.addingTimeInterval(3_600))
        try store.archiveExercise(row.id)

        XCTAssertEqual(try store.planNames(using: row.id), ["Push"])
        try store.deleteExercisePermanently(row.id)

        XCTAssertNil(try store.exercise(row.id))
        let left = try XCTUnwrap(store.plan(plan.id)).exercises
        XCTAssertEqual(left.map(\.exercise.name), ["Bench press", "Back squat", "Cable fly"])
        XCTAssertEqual(left.map(\.supersetGroup), [nil, nil, nil])
        let history = try XCTUnwrap(store.workout(workout.id))
        XCTAssertEqual(history.exercises.map(\.name), ["Bench press", "Cable row", "Back squat", "Cable fly", "Cable row"])
    }

    func test_deletingAPlan_keepsItsWorkouts_underItsLastName() throws {
        let store = Store.inMemory()
        let bench = try store.createExercise(name: "Bench press", muscleGroup: .chest)
        let plan = try store.createPlan(name: "Push", exercises: [
            PlanExerciseDraft(exerciseID: bench.id, supersetGroup: nil, sets: [PlannedSetDraft(targetKilograms: 100, reps: RepRange(5))]),
        ])
        let workout = try store.startWorkout(from: plan.id, at: noon)
        try store.finishWorkout(workout.id, at: noon.addingTimeInterval(3_600))
        try store.archivePlan(plan.id)

        try store.deletePlanPermanently(plan.id)

        XCTAssertNil(try store.plan(plan.id))
        XCTAssertEqual(try store.archivedPlans(), [])
        XCTAssertNotNil(try store.exercise(bench.id))
        let history = try XCTUnwrap(store.workout(workout.id))
        XCTAssertEqual(history.title, "Push")
        XCTAssertNil(history.planID)
        XCTAssertEqual(history.exercises.map(\.name), ["Bench press"])
    }
}
