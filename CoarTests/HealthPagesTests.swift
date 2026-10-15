import XCTest
@testable import Coar

/// The Sleep and Steps pages' rules (`.scratch/health-pages/`): a Night's bedtime, wake time
/// and stages; the usual times across midnight; a week against the one before; how often a
/// target was met; and where the target comes from.
@MainActor
final class HealthPagesTests: XCTestCase {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    private let sep12 = Day(year: 2026, month: 9, day: 12)
    private let sep13 = Day(year: 2026, month: 9, day: 13)

    private func at(_ day: Day, _ hour: Int, _ minute: Int = 0) -> Date {
        Self.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day.start(in: Self.calendar))!
    }

    private func sample(_ stage: SleepSample.Stage, _ start: Date, _ end: Date) -> SleepSample {
        SleepSample(start: start, end: end, stage: stage)
    }

    // MARK: A Night

    func test_night_bedtimeAndWakeAreTheMainSleeps_andANapDoesNotMoveThem() throws {
        let samples = [
            sample(.asleepCore, at(sep12, 23, 30), at(sep13, 3)),
            sample(.awake, at(sep13, 3), at(sep13, 3, 20)),
            sample(.asleepDeep, at(sep13, 3, 20), at(sep13, 4)),
            sample(.asleepREM, at(sep13, 4), at(sep13, 7)),
            sample(.asleepCore, at(sep13, 14), at(sep13, 14, 40)),
        ]

        let night = try XCTUnwrap(SleepNight.detail(wakingOn: sep13, from: samples, in: Self.calendar))

        XCTAssertEqual(night.fellAsleep, at(sep12, 23, 30))
        XCTAssertEqual(night.woke, at(sep13, 7))
        XCTAssertEqual(night.timeAsleep, (3.5 + 0.67 + 3 + 0.67) * 3_600, accuracy: 60, "the nap still counts toward Time Asleep")
        XCTAssertEqual(night.stages[.deep], 40 * 60)
        XCTAssertEqual(night.stages[.rem], 3 * 3_600)
        XCTAssertEqual(night.stages[.core], (3.5 * 60 + 40) * 60)
        XCTAssertEqual(night.stages[.awake], 20 * 60)
    }

    func test_night_withoutRecordedStages_hasNone() throws {
        let samples = [sample(.inBed, at(sep12, 22), at(sep13, 7)), sample(.asleepUnspecified, at(sep12, 23), at(sep13, 6, 30))]

        let night = try XCTUnwrap(SleepNight.detail(wakingOn: sep13, from: samples, in: Self.calendar))

        XCTAssertTrue(night.stages.isEmpty)
        XCTAssertEqual(night.timeAsleep, 7.5 * 3_600)
    }

    func test_night_withNothingAsleep_isNil() {
        XCTAssertNil(SleepNight.detail(wakingOn: sep13, from: [sample(.inBed, at(sep12, 22), at(sep13, 7))], in: Self.calendar))
    }

    // MARK: Usual times

    func test_pattern_averagesBedtimesAcrossMidnight() throws {
        let nights: [Day: SleepNightDetail] = [
            sep12: SleepNightDetail(timeAsleep: 0, fellAsleep: at(sep12.advanced(by: -1), 23, 30), woke: at(sep12, 7), stages: [:]),
            sep13: SleepNightDetail(timeAsleep: 0, fellAsleep: at(sep13, 0, 30), woke: at(sep13, 7, 20), stages: [:]),
            sep13.advanced(by: 1): SleepNightDetail(timeAsleep: 0, fellAsleep: at(sep13, 23, 45), woke: at(sep13.advanced(by: 1), 6, 40), stages: [:]),
        ]

        let pattern = try XCTUnwrap(SleepPattern.from(nights, in: Self.calendar))

        // 23:30, 00:30, 23:45 average to 23:55, not to the middle of the day.
        XCTAssertEqual(pattern.bedtime, 5 * 60 + 55, accuracy: 0.1)
        XCTAssertEqual(pattern.bedtimeSpread, (25 + 35 + 10) / 3, accuracy: 0.1)
        XCTAssertEqual(pattern.wake, 13 * 60, accuracy: 0.1)
        XCTAssertEqual(pattern.nights, 3)
    }

    func test_pattern_needsThreeNights() {
        let one: [Day: SleepNightDetail] = [sep13: SleepNightDetail(timeAsleep: 0, fellAsleep: at(sep12, 23), woke: at(sep13, 7), stages: [:])]
        XCTAssertNil(SleepPattern.from(one, in: Self.calendar))
    }

    func test_spreadText_roundsToFiveMinutes() {
        XCTAssertEqual(SleepPattern.spreadText(23.3), "± 25 min")
        XCTAssertEqual(SleepPattern.spreadText(1), "± 5 min")
        XCTAssertEqual(SleepPattern.spreadText(72), "± 1h 10m")
    }

    // MARK: Week and target

    func test_week_comparesTheSevenDaysEndingYesterday_withTheSevenBefore() throws {
        var values: [Day: Double] = [sep13: 99_999]
        for offset in 1...7 { values[sep13.advanced(by: -offset)] = 8_000 }
        for offset in 8...14 where offset != 10 { values[sep13.advanced(by: -offset)] = 10_000 }

        let week = try XCTUnwrap(HealthSummary.week(values, today: sep13))

        XCTAssertEqual(week.recent, 8_000, "today isn't over, so it's left out")
        XCTAssertEqual(week.previous, 10_000, "a Day without data isn't a zero")
        XCTAssertEqual(HealthSummary.changeText(from: 10_000, to: 8_000), "down 20% on the week before")
        XCTAssertEqual(HealthSummary.changeText(from: 10_000, to: 10_100), "about the same as the week before")
    }

    func test_target_countsDaysMet_andTheRunEndingNow() {
        let days = (0..<7).map { sep13.advanced(by: -$0) }
        let values: [Day: Double] = [
            sep13: 6_000, // today, not there yet: the run counts from yesterday
            sep13.advanced(by: -1): 10_500,
            sep13.advanced(by: -2): 12_000,
            sep13.advanced(by: -3): 4_000,
            sep13.advanced(by: -4): 11_000,
        ]

        let record = HealthSummary.target(10_000, values: values, days: days, today: sep13)

        XCTAssertEqual(record, HealthSummary.TargetRecord(met: 3, judged: 5, inARow: 2))
    }

    func test_target_comesFromTheTrackedHabitForThatMetric() throws {
        let store = Store.inMemory()
        _ = try store.createHabit(emoji: "😴", name: "Sleep under 9h", kind: .tracked, targetAmount: 9, period: .day, tracking: HabitTracking(metric: .sleep, comparison: .atMost))
        XCTAssertNil(HealthTarget.current(for: .sleep, store: store, today: .today()), "an at-most Habit isn't a target to reach")

        _ = try store.createHabit(emoji: "👟", name: "Steps 10k", kind: .tracked, targetAmount: 10_000, period: .day, tracking: HabitTracking(metric: .steps, comparison: .atLeast))

        XCTAssertEqual(HealthTarget.current(for: .steps, store: store, today: .today()), HealthTarget(amount: 10_000, habitName: "Steps 10k"))
        XCTAssertNil(HealthTarget.current(for: .sleep, store: store, today: .today()))
    }

    func test_setATarget_startsATrackedHabitForThePagesMetric() {
        let draft = HabitForm.Draft(kind: .tracked, metric: .steps)
        XCTAssertEqual(draft.target.metric, .steps)
        XCTAssertEqual(draft.target.typedAmount, TrackedMetric.steps.defaults.amount)
    }
}
