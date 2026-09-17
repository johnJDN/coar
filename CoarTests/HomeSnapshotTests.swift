import XCTest
@testable import Coar

/// Seam 1: the store façade, with Apple Health faked. Home is one snapshot of today derived
/// through the façade: every card keeps its slot, and a missing Target, Body Weight, Workout,
/// or Health value shows its empty form (`—`, `— target`, `No data`), never a 0
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

        XCTAssertEqual(snapshot.habits.rows, [])
        XCTAssertNil(snapshot.habits.hero)
        XCTAssertEqual(snapshot.macros.rows.map(\.macro), [.calories, .protein, .fat, .carbs])
        XCTAssertEqual(snapshot.macros.rows.map(\.consumed), ["0", "0", "0", "0"])
        XCTAssertEqual(snapshot.macros.rows.map(\.targetCaption), ["— target", "— target", "— target", "— target"])
        XCTAssertEqual(snapshot.macros.rows.map(\.dots), [nil, nil, nil, nil])
        XCTAssertFalse(snapshot.macros.hasTarget)
        XCTAssertEqual(snapshot.sleep, HomeSquare(value: nil, caption: "Tap to connect Apple Health", connects: true))
        XCTAssertEqual(snapshot.steps, HomeSquare(value: nil, caption: "Tap to connect Apple Health", connects: true))
        XCTAssertEqual(snapshot.bodyWeight, HomeSquare(value: nil, caption: "No Body Weight yet"))
        XCTAssertEqual(snapshot.lastWorkout, HomeSquare(value: nil, caption: "No workouts yet"))
        XCTAssertNil(snapshot.lastWorkoutID)
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

        XCTAssertEqual(snapshot.habits.rows.map(\.name), ["No phone on waking", "Read"])
        XCTAssertEqual(snapshot.habits.rows.map(\.isDoneToday), [true, false])
        XCTAssertEqual(snapshot.habits.hero, "1")
        XCTAssertEqual(snapshot.habits.caption, "of 2 done today")

        XCTAssertEqual(snapshot.macros.rows.map(\.consumed), ["210", "18", "15", "0"])
        XCTAssertEqual(snapshot.macros.rows.map(\.targetCaption), ["of 2,100 kcal", "of 180 g", "of 60 g", "of 210 g"])
        XCTAssertEqual(snapshot.macros.rows.map { $0.dots?.filled }, [4, 4, 3, 0])
        XCTAssertTrue(snapshot.macros.hasTarget)

        XCTAssertEqual(snapshot.sleep, HomeSquare(value: "8h", caption: "Last night"))
        XCTAssertEqual(snapshot.steps, HomeSquare(value: "8,432", caption: "Today"))
        // Trend Weight after two points: 84 kg moved a tenth of the way toward 84.5 kg.
        XCTAssertEqual(snapshot.bodyWeight, HomeSquare(value: "185.3 lbs", caption: "Trend Weight"))
        XCTAssertEqual(snapshot.lastWorkout, HomeSquare(value: "Yesterday", caption: "Push"))
        XCTAssertEqual(snapshot.lastWorkoutID, workout.id)
    }

    func test_aSingleBodyWeight_showsTheRawValue_withTheTrendAsADash() async throws {
        let store = Store.inMemory()
        try store.logBodyWeight(kilograms: 84, on: sep15)

        let snapshot = try await HomeSnapshot.load(store: store, health: FakeHealthReader(calendar: Self.calendar), healthStatus: .connected, unit: .kilograms, today: sep16)

        XCTAssertEqual(snapshot.bodyWeight, HomeSquare(value: "84.0 kg", caption: "Sep 15 · Trend —"))
    }

    func test_anEmptyWorkoutWithNoPlan_isCaptionedWorkout_andTheDayReadsRelativeToToday() async throws {
        let store = Store.inMemory()
        let workout = try store.startWorkout(from: nil, at: at(sep14, 18), in: Self.calendar)
        try store.finishWorkout(workout.id, at: at(sep14, 19))

        let snapshot = try await HomeSnapshot.load(store: store, health: FakeHealthReader(calendar: Self.calendar), healthStatus: .connected, unit: .pounds, today: sep16)

        XCTAssertEqual(snapshot.lastWorkout, HomeSquare(value: "2 days ago", caption: "Workout"))
    }

    func test_onceHealthHasBeenAsked_anEmptySquareNoLongerOffersToConnect() async throws {
        let snapshot = try await HomeSnapshot.load(store: Store.inMemory(), health: FakeHealthReader(calendar: Self.calendar), healthStatus: .connected, unit: .pounds, today: sep16)

        XCTAssertEqual(snapshot.sleep, HomeSquare(value: nil, caption: "Last night"))
        XCTAssertEqual(snapshot.steps, HomeSquare(value: nil, caption: "Today"))
    }
}
