import CoreData
import XCTest
@testable import Coar

/// Seam 1: the store façade. Two devices syncing offline can create rows CloudKit cannot
/// prevent; the dedupe pass makes both converge on the latest `modifiedAt`, with the Active
/// Workout as the sole exception (`.scratch/data-model/issues/01`). Duplicates are planted
/// straight into the context, which is what a CloudKit import does: rows land without
/// passing through the façade.
@MainActor
final class SyncDedupeTests: XCTestCase {

    private let day = Day(year: 2026, month: 9, day: 10)
    private let earlier = Date(timeIntervalSince1970: 1_800_000_000)
    private var later: Date { earlier.addingTimeInterval(60) }

    // MARK: Check-ins

    func test_twoCheckInsOnOneDay_keepTheLatestModifiedEvenWhenItsAmountIsSmaller() async throws {
        let store = Store.inMemory()
        let habit = try store.createHabit(emoji: "💧", name: "Water", kind: .quantitative, targetAmount: 8, period: .day, effectiveFrom: day)
        try store.checkIn(habit.id, on: Day(year: 2026, month: 9, day: 9), amount: 5)
        try plantCheckIn(in: store, habit: habit.id, on: day, amount: 3, modifiedAt: earlier)
        try plantCheckIn(in: store, habit: habit.id, on: day, amount: 1, modifiedAt: later)

        let report = try await store.runDedupePass()

        XCTAssertEqual(report, DedupePass.Report(checkInsDeleted: 1))
        XCTAssertEqual(try store.checkIn(habit.id, on: day)?.amount, 1)
        XCTAssertEqual(try store.checkIns(for: habit.id).map(\.amount), [5, 1])
        let secondRun = try await store.runDedupePass()
        XCTAssertTrue(secondRun.isEmpty, "a second run finds nothing to do")
    }

    func test_checkInsOfDifferentHabitsOnOneDay_areNotDuplicates() async throws {
        let store = Store.inMemory()
        let water = try store.createHabit(emoji: "💧", name: "Water", kind: .quantitative, targetAmount: 8, period: .day, effectiveFrom: day)
        let read = try store.createHabit(emoji: "📖", name: "Read", kind: .yesNo, targetAmount: 1, period: .day, effectiveFrom: day)
        try plantCheckIn(in: store, habit: water.id, on: day, amount: 3, modifiedAt: earlier)
        try plantCheckIn(in: store, habit: read.id, on: day, amount: 1, modifiedAt: later)

        let report = try await store.runDedupePass()

        XCTAssertTrue(report.isEmpty)
        XCTAssertEqual(try store.checkIn(water.id, on: day)?.amount, 3)
        XCTAssertEqual(try store.checkIn(read.id, on: day)?.amount, 1)
    }

    // MARK: Body Weight

    func test_twoBodyWeightsOnOneDay_keepTheLatestModified() async throws {
        let store = Store.inMemory()
        try store.logBodyWeight(kilograms: 83, on: Day(year: 2026, month: 9, day: 9))
        try plantBodyWeight(in: store, on: day, kilograms: 84.5, modifiedAt: later)
        try plantBodyWeight(in: store, on: day, kilograms: 84.0, modifiedAt: earlier)

        let report = try await store.runDedupePass()

        XCTAssertEqual(report, DedupePass.Report(bodyWeightsDeleted: 1))
        XCTAssertEqual(try store.bodyWeights().map(\.kilograms), [83, 84.5])
        let secondRun = try await store.runDedupePass()
        XCTAssertTrue(secondRun.isEmpty, "a second run finds nothing to do")
    }

    // MARK: Default Serving

    func test_twoDefaultServings_keepTheLatestModifiedAsDefaultAndTheOtherServing() async throws {
        let store = Store.inMemory()
        let cup = ServingDraft(name: "Cup", macros: Macros(calories: 100, protein: 5, fat: 2, carbs: 15), grams: 240, isDefault: true)
        let bowl = ServingDraft(name: "Bowl", macros: Macros(calories: 200, protein: 10, fat: 4, carbs: 30), grams: 480, isDefault: false)
        let item = try store.createFoodItem(name: "Oats", servings: [cup, bowl])
        try plantDefaultFlag(in: store, serving: cup.id, modifiedAt: earlier)
        try plantDefaultFlag(in: store, serving: bowl.id, modifiedAt: later)

        let report = try await store.runDedupePass()

        XCTAssertEqual(report, DedupePass.Report(servingDefaultsCleared: 1))
        let servings = try XCTUnwrap(store.foodItem(item.id)).servings
        XCTAssertEqual(servings.map(\.name), ["Cup", "Bowl"])
        XCTAssertEqual(servings.map(\.isDefault), [false, true])
        let secondRun = try await store.runDedupePass()
        XCTAssertTrue(secondRun.isEmpty, "a second run finds nothing to do")
    }

    // MARK: Active Workout

    func test_twoActiveWorkouts_theLaterStaysActiveAndTheOlderIsFinishedWhenItHasACompletedSet() async throws {
        let store = Store.inMemory()
        let bench = try store.createExercise(name: "Bench press", muscleGroup: .chest, equipment: "Barbell")
        let older = try store.startWorkout(from: nil, at: earlier)
        try store.addExercise(bench.id, to: older.id)
        let row = try XCTUnwrap(store.workout(older.id)?.exercises.first)
        try store.addLoggedSet(to: row.id)
        try store.addLoggedSet(to: row.id)
        let sets = try XCTUnwrap(store.workout(older.id)?.exercises.first?.sets)
        try store.updateLoggedSet(sets[0].id, kilograms: 100, reps: 5, isCompleted: true)
        let newer = try plantActiveWorkout(in: store, startedAt: later)
        let changed = expectation(forNotification: Store.activeWorkoutDidChange, object: store)

        let report = try await store.runDedupePass()

        XCTAssertEqual(report, DedupePass.Report(workoutsFinished: 1))
        await fulfillment(of: [changed], timeout: 1)
        XCTAssertEqual(try store.activeWorkout()?.id, newer)
        let finished = try XCTUnwrap(store.workout(older.id))
        XCTAssertEqual(finished.finishedAt, later)
        XCTAssertEqual(finished.exercises.first?.sets.map(\.isCompleted), [true])
        let secondRun = try await store.runDedupePass()
        XCTAssertTrue(secondRun.isEmpty, "a second run finds nothing to do")
    }

    func test_twoActiveWorkouts_theOlderIsDeletedWhenNoSetWasCompleted() async throws {
        let store = Store.inMemory()
        let bench = try store.createExercise(name: "Bench press", muscleGroup: .chest, equipment: "Barbell")
        let push = try store.createPlan(name: "Push", exercises: [
            PlanExerciseDraft(exerciseID: bench.id, supersetGroup: nil, sets: [PlannedSetDraft(targetKilograms: 100, reps: RepRange(5))]),
        ])
        let older = try store.startWorkout(from: push.id, at: earlier)
        XCTAssertEqual(older.exercises.first?.sets.count, 1, "a Plan start pre-fills uncompleted sets")
        let newer = try plantActiveWorkout(in: store, startedAt: later)

        let report = try await store.runDedupePass()

        XCTAssertEqual(report, DedupePass.Report(workoutsDeleted: 1))
        XCTAssertEqual(try store.activeWorkout()?.id, newer)
        XCTAssertNil(try store.workout(older.id))
        XCTAssertEqual(try store.workouts(on: Day(later, in: .current)).map(\.id), [newer])
        let secondRun = try await store.runDedupePass()
        XCTAssertTrue(secondRun.isEmpty, "a second run finds nothing to do")
    }

    func test_oneActiveWorkout_isLeftAlone() async throws {
        let store = Store.inMemory()
        let active = try store.startWorkout(from: nil, at: earlier)

        let report = try await store.runDedupePass()

        XCTAssertTrue(report.isEmpty)
        XCTAssertEqual(try store.activeWorkout()?.id, active.id)
    }

    // MARK: - Planting duplicates

    private func plantCheckIn(in store: Store, habit id: HabitRecord.ID, on day: Day, amount: Double, modifiedAt: Date) throws {
        let context = store.context
        let request = Habit.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let habit = try XCTUnwrap(context.fetch(request).first)
        let checkIn = CheckIn(context: context)
        checkIn.habit = habit
        checkIn.day = day.rawValue
        checkIn.amount = amount
        checkIn.modifiedAt = modifiedAt
        try context.save()
    }

    private func plantBodyWeight(in store: Store, on day: Day, kilograms: Double, modifiedAt: Date) throws {
        let record = BodyWeight(context: store.context)
        record.day = day.rawValue
        record.kilograms = kilograms
        record.modifiedAt = modifiedAt
        try store.context.save()
    }

    private func plantDefaultFlag(in store: Store, serving id: UUID, modifiedAt: Date) throws {
        let request = Serving.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        let serving = try XCTUnwrap(store.context.fetch(request).first)
        serving.isDefault = true
        serving.modifiedAt = modifiedAt
        try store.context.save()
    }

    /// A second Active Workout, as another device's start arrives through sync.
    private func plantActiveWorkout(in store: Store, startedAt: Date) throws -> WorkoutRecord.ID {
        let workout = Workout(context: store.context)
        workout.id = UUID()
        workout.startedAt = startedAt
        workout.day = Day(startedAt, in: .current).rawValue
        workout.modifiedAt = startedAt
        try store.context.save()
        return workout.id!
    }
}
