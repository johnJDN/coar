import XCTest
@testable import Coar

/// Seam 1: the store façade, with Apple Health faked. Home is one snapshot of today derived
/// through the façade: every card keeps its slot, and a missing Target, Body Weight, Workout,
/// or Health value shows its empty form (`—`, a bare `g` or `kcal`), never a 0
/// (DESIGN.md §1.5, `.scratch/data-model/issues/02`).
@MainActor
final class HomeSnapshotTests: XCTestCase {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    private let sep14 = Day(year: 2026, month: 9, day: 14)
    private let sep15 = Day(year: 2026, month: 9, day: 15)
    private let sep16 = Day(year: 2026, month: 9, day: 16)

    private func at(_ day: Day, _ hour: Int, _ minute: Int = 0) -> Date {
        Self.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day.start(in: Self.calendar))!
    }

    func test_withNothingRecordedAndHealthNotConnected_everySlotShowsItsEmptyForm_neverAZero() async throws {
        let store = Store.inMemory()
        let health = FakeHealthReader(calendar: Self.calendar)

        let snapshot = try await HomeSnapshot.load(store: store, health: health, healthStatus: .notRequested, unit: .pounds, today: sep16)

        XCTAssertEqual(snapshot.habits, .none)
        XCTAssertEqual(snapshot.macros.calories, "0")
        XCTAssertEqual(snapshot.macros.caloriesCaption, "kcal")
        XCTAssertNil(snapshot.macros.calorieProgress)
        XCTAssertEqual(snapshot.macros.bars.map(\.macro), [.protein, .fat, .carbs])
        XCTAssertEqual(snapshot.macros.bars.map(\.consumed), ["0", "0", "0"])
        XCTAssertEqual(snapshot.macros.bars.map(\.target), ["g", "g", "g"])
        XCTAssertEqual(snapshot.macros.bars.map(\.progress), [nil, nil, nil])
        XCTAssertFalse(snapshot.macros.hasTarget)
        XCTAssertEqual(snapshot.sleep, HomeTile(value: nil, caption: "Connect", connects: true))
        XCTAssertEqual(snapshot.steps, HomeTile(value: nil, caption: "Connect", connects: true))
        XCTAssertEqual(snapshot.bodyWeight, HomeTile(value: nil, caption: "lbs"))
        XCTAssertEqual(snapshot.training, HomeTile(value: "0", caption: "This week"))
    }

    func test_withADayOfRecords_everyCardReadsTodayInItsDisplayForm() async throws {
        let store = Store.inMemory()
        let health = FakeHealthReader(calendar: Self.calendar)

        let phone = try store.createHabit(emoji: "📵", name: "No phone on waking", kind: .yesNo, targetAmount: 1, period: .day, effectiveFrom: sep14)
        try store.createHabit(emoji: "📖", name: "Read", kind: .quantitative, targetAmount: 20, period: .day, effectiveFrom: sep14)
        try store.checkIn(phone.id, on: sep16, amount: 1)

        try store.setTarget(Macros(calories: 2_100, protein: 180, fat: 60, carbs: 210), effectiveFrom: sep14)
        let eggs = try store.createFoodItem(name: "Eggs", servings: [
            ServingDraft(name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0), isDefault: true),
        ])
        try store.logEntry(foodItem: eggs.id, serving: eggs.servings[0].id, quantity: 3, at: at(sep16, 8), in: Self.calendar)

        try store.logBodyWeight(kilograms: 84, on: sep14)
        try store.logBodyWeight(kilograms: 84.5, on: sep15)

        let push = try store.createPlan(name: "Push", exercises: [])
        let workout = try store.startWorkout(from: push.id, at: at(sep15, 18), in: Self.calendar)
        try store.finishWorkout(workout.id, at: at(sep15, 19))

        health.sleepSamples = [SleepSample(start: at(sep15, 23), end: at(sep16, 7), stage: .asleepCore)]
        health.stepsByDay = [sep16: 8_432]

        let snapshot = try await HomeSnapshot.load(store: store, health: health, healthStatus: .connected, unit: .pounds, today: sep16)

        XCTAssertEqual(snapshot.habits.toDo.map(\.name), ["Read"])
        XCTAssertEqual(snapshot.habits.done.map(\.name), ["No phone on waking"])
        XCTAssertEqual(snapshot.habits.summary, "1 of 2 done")

        XCTAssertEqual(snapshot.macros.calories, "1,890")
        XCTAssertEqual(snapshot.macros.caloriesCaption, "kcal left")
        XCTAssertEqual(snapshot.macros.calorieProgress, 0.1)
        XCTAssertEqual(snapshot.macros.bars.map(\.consumed), ["18", "15", "0"])
        XCTAssertEqual(snapshot.macros.bars.map(\.target), ["/180g", "/60g", "/210g"])
        XCTAssertEqual(snapshot.macros.bars.map(\.progress), [0.1, 0.25, 0])
        XCTAssertTrue(snapshot.macros.hasTarget)

        XCTAssertEqual(snapshot.sleep, HomeTile(value: "8h", caption: "Sleep"))
        XCTAssertEqual(snapshot.steps, HomeTile(value: "8,432", caption: "Steps"))
        // Trend Weight after two points: 84 kg moved a tenth of the way toward 84.5 kg.
        XCTAssertEqual(snapshot.bodyWeight, HomeTile(value: "185.3", caption: "lbs"))
        XCTAssertEqual(snapshot.training, HomeTile(value: "1", caption: "This week"))
    }

    func test_theHabitsCard_listsOnlyCheckInHabits_splitIntoToDoAndDone_eachInTheUsersOrder() async throws {
        let store = Store.inMemory()
        let phone = try store.createHabit(emoji: "📵", name: "No phone on waking", kind: .yesNo, targetAmount: 1, period: .day, effectiveFrom: sep14)
        try store.createHabit(emoji: "👟", name: "Steps", kind: .tracked, targetAmount: 8_000, period: .day, tracking: HabitTracking(metric: .steps, comparison: .atLeast), effectiveFrom: sep14)
        try store.createHabit(emoji: "📖", name: "Read", kind: .quantitative, targetAmount: 20, period: .day, effectiveFrom: sep14)
        let gym = try store.createHabit(emoji: "🏋️", name: "Gym", kind: .yesNo, targetAmount: 2, period: .week, effectiveFrom: sep14)
        let meditate = try store.createHabit(emoji: "🧘", name: "Meditate", kind: .yesNo, targetAmount: 1, period: .day, effectiveFrom: sep14)
        try store.checkIn(phone.id, on: sep16, amount: 1)
        try store.checkIn(meditate.id, on: sep16, amount: 1)
        // Gym's week (Monday Sep 14) is met before today, so it is done with no Check-in today.
        try store.checkIn(gym.id, on: sep14, amount: 1)
        try store.checkIn(gym.id, on: sep15, amount: 1)
        let health = FakeHealthReader(calendar: Self.calendar)
        health.stepsByDay = [sep16: 9_000]

        let snapshot = try await HomeSnapshot.load(store: store, health: health, healthStatus: .connected, unit: .pounds, today: sep16)

        XCTAssertEqual(snapshot.habits.toDo.map(\.name), ["Read"])
        XCTAssertEqual(snapshot.habits.done.map(\.name), ["No phone on waking", "Gym", "Meditate"])
        XCTAssertEqual(snapshot.habits.summary, "3 of 4 done")
    }

    func test_withOnlyTrackedHabits_theHabitsCardHasNoRows_andSaysThereIsNothingToCheckIn() async throws {
        let store = Store.inMemory()
        try store.createHabit(emoji: "👟", name: "Steps", kind: .tracked, targetAmount: 8_000, period: .day, tracking: HabitTracking(metric: .steps, comparison: .atLeast), effectiveFrom: sep14)

        let snapshot = try await HomeSnapshot.load(store: store, health: FakeHealthReader(calendar: Self.calendar), healthStatus: .connected, unit: .pounds, today: sep16)

        XCTAssertEqual(snapshot.habits, .onlyTracked)
    }

    func test_aSingleBodyWeight_showsTheRawValue() async throws {
        let store = Store.inMemory()
        try store.logBodyWeight(kilograms: 84, on: sep15)

        let snapshot = try await HomeSnapshot.load(store: store, health: FakeHealthReader(calendar: Self.calendar), healthStatus: .connected, unit: .kilograms, today: sep16)

        XCTAssertEqual(snapshot.bodyWeight, HomeTile(value: "84.0", caption: "kg"))
    }

    func test_training_countsDaysWithAWorkoutThisWeek_againstTheWeeklyWorkoutsHabit() async throws {
        let store = Store.inMemory()
        try store.createHabit(emoji: "🏋️", name: "Workout 3 days a week", kind: .tracked, targetAmount: 3, period: .week, tracking: HabitTracking(metric: .workouts, comparison: .atLeast), effectiveFrom: sep14)
        // Sunday Sep 13 is last week; two Workouts on Monday make one day.
        for (day, hour) in [(Day(year: 2026, month: 9, day: 13), 18), (sep14, 7), (sep14, 18), (sep15, 18)] {
            let workout = try store.startWorkout(from: nil, at: at(day, hour), in: Self.calendar)
            try store.finishWorkout(workout.id, at: at(day, hour, 45))
        }

        let snapshot = try await HomeSnapshot.load(store: store, health: FakeHealthReader(calendar: Self.calendar), healthStatus: .connected, unit: .pounds, today: sep16)

        XCTAssertEqual(snapshot.training, HomeTile(value: "2/3", caption: "This week"))
    }

    func test_overTheCalorieTarget_theRingIsFull_andShowsHowFarOver() async throws {
        let store = Store.inMemory()
        try store.setTarget(Macros(calories: 200, protein: 10, fat: 10, carbs: 10), effectiveFrom: sep14)
        let eggs = try store.createFoodItem(name: "Eggs", servings: [
            ServingDraft(name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0), isDefault: true),
        ])
        try store.logEntry(foodItem: eggs.id, serving: eggs.servings[0].id, quantity: 4, at: at(sep16, 8), in: Self.calendar)

        let snapshot = try await HomeSnapshot.load(store: store, health: FakeHealthReader(calendar: Self.calendar), healthStatus: .connected, unit: .pounds, today: sep16)

        XCTAssertEqual(snapshot.macros.calories, "80")
        XCTAssertEqual(snapshot.macros.caloriesCaption, "kcal over")
        XCTAssertEqual(snapshot.macros.calorieProgress, 1)
        XCTAssertEqual(snapshot.macros.bars.map(\.progress), [1, 1, 0])
    }

    func test_onceHealthHasBeenAsked_anEmptyTileNoLongerOffersToConnect() async throws {
        let snapshot = try await HomeSnapshot.load(store: Store.inMemory(), health: FakeHealthReader(calendar: Self.calendar), healthStatus: .connected, unit: .pounds, today: sep16)

        XCTAssertEqual(snapshot.sleep, HomeTile(value: nil, caption: "Sleep"))
        XCTAssertEqual(snapshot.steps, HomeTile(value: nil, caption: "Steps"))
    }
}
