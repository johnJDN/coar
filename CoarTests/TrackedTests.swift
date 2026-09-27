import XCTest
@testable import Coar

/// A tracked Habit (CONTEXT.md "Tracked habit") is judged from data Coar already has.
/// Seam 2 covers the rules: a week's average uses only the Days with data, a daily food
/// goal misses a Day with nothing logged, macros are judged as a share of the Target in
/// force that Day, and a day-count metric counts Days. Seam 1 covers the Habit's storage.
@MainActor
final class TrackedTests: XCTestCase {

    private let monday7 = Day(year: 2026, month: 9, day: 7)
    private var tuesday8: Day { monday7.advanced(by: 1) }
    private var wednesday9: Day { monday7.advanced(by: 2) }
    private var thursday10: Day { monday7.advanced(by: 3) }
    private var sunday13: Day { monday7.advanced(by: 6) }

    private func habit(_ metric: TrackedMetric, _ comparison: HabitComparison, amount: Double, period: HabitPeriod) -> HabitRecord {
        HabitRecord(
            id: UUID(), emoji: metric.emoji, name: metric.title, kind: .tracked, isArchived: false, sortOrder: 0,
            targets: [HabitTargetRecord(amount: amount, period: period, effectiveFrom: monday7.advanced(by: -28))],
            tracking: HabitTracking(metric: metric, comparison: comparison), modifiedAt: Date()
        )
    }

    // MARK: Rules

    func test_weeklySleepAverage_usesOnlyNightsWithData() {
        let sleep = habit(.sleep, .atLeast, amount: 7, period: .week)
        let nights: [Day: Double] = [monday7: 6.5, tuesday8: 7.5, thursday10: 7.25]

        let card = HabitCardModel(habit: sleep, checkIns: [], trackedValues: nights, today: sunday13)

        XCTAssertTrue(card.isDoneToday)
        XCTAssertEqual(card.streak, 1)
        XCTAssertEqual(card.trackedText, "7.1h")
        XCTAssertEqual(card.weekCaption, "7.1h average this week")
    }

    func test_weeklySleepAverage_belowTheGoal_isNotMet() {
        let sleep = habit(.sleep, .atLeast, amount: 7, period: .week)
        let card = HabitCardModel(habit: sleep, checkIns: [], trackedValues: [monday7: 6, tuesday8: 7], today: tuesday8)
        XCTAssertFalse(card.isDoneToday)
        XCTAssertEqual(card.streak, 0)
    }

    func test_caloriesAtMost110Percent_followTheTargetInForce_andAnUnloggedDayIsAMiss() {
        let targets = [
            TargetRecord(macros: Macros(calories: 2_000, protein: 180, fat: 60, carbs: 200), effectiveFrom: monday7, modifiedAt: Date()),
            TargetRecord(macros: Macros(calories: 2_200, protein: 180, fat: 60, carbs: 200), effectiveFrom: wednesday9, modifiedAt: Date()),
        ]
        let totals: [Day: Macros] = [
            monday7: Macros(calories: 2_150, protein: 170, fat: 60, carbs: 200),
            tuesday8: Macros(calories: 2_300, protein: 150, fat: 60, carbs: 200),
            wednesday9: Macros(calories: 2_300, protein: 175, fat: 60, carbs: 200),
        ]
        let values = TrackedValues.percentages(of: .calories, totals: totals, targets: targets)
        XCTAssertEqual(values[monday7] ?? 0, 107.5, accuracy: 0.01)
        XCTAssertEqual(values[tuesday8] ?? 0, 115, accuracy: 0.01)
        XCTAssertEqual(values[wednesday9] ?? 0, 104.5, accuracy: 0.1)

        let cut = habit(.calories, .atMost, amount: 110, period: .day)
        let wednesday = HabitCardModel(habit: cut, checkIns: [], trackedValues: values, today: wednesday9)
        XCTAssertTrue(wednesday.isDoneToday)
        XCTAssertEqual(wednesday.streak, 1)
        XCTAssertEqual(wednesday.trackedText, "105%")

        let thursday = HabitCardModel(habit: cut, checkIns: [], trackedValues: values, today: thursday10)
        XCTAssertFalse(thursday.isDoneToday)
        XCTAssertEqual(thursday.trackedText, "—")
        XCTAssertEqual(thursday.streak, 1, "an unlogged today is pending, not yet a miss")
        XCTAssertEqual(HabitCardModel(habit: cut, checkIns: [], trackedValues: values, today: thursday10.advanced(by: 1)).streak, 0)
    }

    func test_proteinAtLeast90Percent_isMetPerDay() {
        let protein = habit(.protein, .atLeast, amount: 90, period: .day)
        let values: [Day: Double] = [monday7: 95, tuesday8: 85, wednesday9: 91]
        let card = HabitCardModel(habit: protein, checkIns: [], trackedValues: values, today: wednesday9)
        XCTAssertTrue(card.isDoneToday)
        XCTAssertEqual(card.streak, 1)
    }

    func test_workoutDays_countTowardAWeeklyGoal() {
        let workouts = habit(.workouts, .atLeast, amount: 3, period: .week)
        let two = HabitCardModel(habit: workouts, checkIns: [], trackedValues: [monday7: 1, wednesday9: 1], today: thursday10)
        XCTAssertFalse(two.isDoneToday)
        XCTAssertEqual(two.trackedText, "2/3")
        XCTAssertEqual(two.weekCaption, "2 of 3 days this week")

        let three = HabitCardModel(habit: workouts, checkIns: [], trackedValues: [monday7: 1, wednesday9: 1, thursday10: 1], today: thursday10)
        XCTAssertTrue(three.isDoneToday)
        XCTAssertNil(three.editableFrom, "a tracked Habit has no Days to edit")
    }

    func test_goalValidation_followsTheMetric() {
        var draft = HabitTargetDraft(kind: .tracked, period: .week, typedAmount: 3)
        draft.metric = .workouts
        XCTAssertEqual(draft.amount, 3)
        draft.typedAmount = 8
        XCTAssertNil(draft.amount)
        draft.period = .day
        XCTAssertFalse(draft.needsAmount)
        XCTAssertEqual(draft.amount, 1)
        draft.metric = .sleep
        draft.typedAmount = 7.5
        XCTAssertEqual(draft.amount, 7.5)
        draft.typedAmount = 25
        XCTAssertNil(draft.amount)
    }

    func test_aNewHabitFromTheTrackedTab_startsAtTheMetricsUsualGoal() {
        let draft = HabitForm.Draft(kind: .tracked)
        XCTAssertEqual(draft.target.kind, .tracked)
        XCTAssertEqual(draft.target.tracking, HabitTracking(metric: .sleep, comparison: .atLeast))
        XCTAssertEqual(draft.target.period, .week)
        XCTAssertEqual(draft.target.amount, 7)
        XCTAssertEqual(draft.resolvedName, "Sleep 7h")
        XCTAssertTrue(draft.isComplete, "Save is ready without typing anything")
    }

    // MARK: Store

    func test_trackedHabit_keepsItsMetricAndDirection() throws {
        let store = Store.inMemory()
        let created = try store.createHabit(
            emoji: "🔥", name: "Calories under 110%", kind: .tracked, targetAmount: 110, period: .day,
            tracking: HabitTracking(metric: .calories, comparison: .atMost)
        )

        let read = try XCTUnwrap(store.habit(created.id))
        XCTAssertEqual(read.tracking, HabitTracking(metric: .calories, comparison: .atMost))
        XCTAssertNil(try store.createHabit(emoji: "📵", name: "Phone", kind: .yesNo, targetAmount: 1, period: .day).tracking)
    }
}
