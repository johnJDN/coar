import XCTest
@testable import Coar

/// Seam 2, through the HealthKit fake: a night belongs to the Day the user woke, and time
/// asleep sums the asleep stages and excludes awake and in-bed, so Coar matches the Health
/// app (spec stories 77 and 79).
final class HealthReaderTests: XCTestCase {

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

    private func sample(_ stage: SleepSample.Stage, from start: Date, to end: Date) -> SleepSample {
        SleepSample(start: start, end: end, stage: stage)
    }

    func test_nightAcrossMidnight_belongsToTheDayTheUserWoke() async throws {
        let health = FakeHealthReader(calendar: Self.calendar)
        health.sleepSamples = [sample(.asleepUnspecified, from: at(sep12, 23), to: at(sep13, 7))]

        let asleep = try await health.timeAsleep(wakingOn: [sep12, sep13])

        XCTAssertEqual(asleep, [sep13: 8 * 3_600.0])
    }

    func test_timeAsleep_sumsTheAsleepStages_andExcludesAwakeAndInBed() async throws {
        let health = FakeHealthReader(calendar: Self.calendar)
        health.sleepSamples = [
            sample(.inBed, from: at(sep12, 22, 30), to: at(sep13, 7)),
            sample(.asleepCore, from: at(sep12, 23), to: at(sep13, 1)),
            sample(.asleepDeep, from: at(sep13, 1), to: at(sep13, 2)),
            sample(.awake, from: at(sep13, 2), to: at(sep13, 2, 20)),
            sample(.asleepREM, from: at(sep13, 2, 20), to: at(sep13, 3, 50)),
            sample(.asleepUnspecified, from: at(sep13, 3, 50), to: at(sep13, 4, 20)),
        ]

        let asleep = try await health.timeAsleep(wakingOn: [sep13])

        // 2h core + 1h deep + 1h30 REM + 30m unspecified; the 20m awake and 8h30 in bed do not count.
        XCTAssertEqual(asleep, [sep13: 5 * 3_600.0])
    }

    func test_napTheSameAfternoon_countsTowardThatWakeDay() async throws {
        let health = FakeHealthReader(calendar: Self.calendar)
        health.sleepSamples = [
            sample(.asleepUnspecified, from: at(sep12, 23), to: at(sep13, 7)),
            sample(.asleepUnspecified, from: at(sep13, 14), to: at(sep13, 15)),
        ]

        let asleep = try await health.timeAsleep(wakingOn: [sep13])

        XCTAssertEqual(asleep, [sep13: 9 * 3_600.0])
    }

    func test_dozeAfterSixInTheEvening_countsTowardTheNextWakeDay() async throws {
        // The Health app's sleep day runs 6 PM to 6 PM: an early evening doze is the start of
        // the coming night, not part of the day that ended.
        let health = FakeHealthReader(calendar: Self.calendar)
        health.sleepSamples = [
            sample(.asleepUnspecified, from: at(sep12, 23), to: at(sep13, 7)),
            sample(.asleepUnspecified, from: at(sep13, 19), to: at(sep13, 20)),
        ]

        let asleep = try await health.timeAsleep(wakingOn: [sep13, sep13.advanced(by: 1)])

        XCTAssertEqual(asleep, [sep13: 8 * 3_600.0, sep13.advanced(by: 1): 3_600.0])
    }

    func test_twoSourcesRecordingTheSameHours_countOnce() async throws {
        // A watch writing stages and a sleep app writing one unspecified span overlap; the
        // hour asleep is still one hour.
        let health = FakeHealthReader(calendar: Self.calendar)
        health.sleepSamples = [
            sample(.asleepUnspecified, from: at(sep12, 23), to: at(sep13, 7)),
            sample(.asleepCore, from: at(sep12, 23), to: at(sep13, 3)),
            sample(.asleepDeep, from: at(sep13, 3), to: at(sep13, 7, 30)),
        ]

        let asleep = try await health.timeAsleep(wakingOn: [sep13])

        XCTAssertEqual(asleep, [sep13: 8.5 * 3_600.0])
    }

    func test_sleepStraddlingSixInTheEvening_isSplitBetweenTheTwoWakeDays() async throws {
        let health = FakeHealthReader(calendar: Self.calendar)
        health.sleepSamples = [sample(.asleepUnspecified, from: at(sep13, 17, 30), to: at(sep13, 18, 30))]

        let asleep = try await health.timeAsleep(wakingOn: [sep13, sep13.advanced(by: 1)])

        XCTAssertEqual(asleep, [sep13: 1_800.0, sep13.advanced(by: 1): 1_800.0])
    }

    func test_timeAsleepForOneWakeDay_isNilWithoutAnAsleepSample_evenWhenInBed() async throws {
        let health = FakeHealthReader(calendar: Self.calendar)
        health.sleepSamples = [sample(.inBed, from: at(sep12, 23), to: at(sep13, 7))]

        let asleep = try await health.timeAsleep(wakingOn: sep13)

        XCTAssertNil(asleep)
    }

    func test_stepsForADay_andForASeries_comeBackOnlyForDaysThatHaveAny() async throws {
        let health = FakeHealthReader(calendar: Self.calendar)
        health.stepsByDay = [sep13: 8_432]

        let today = try await health.steps(on: sep13)
        let series = try await health.steps(on: [sep12, sep13])

        XCTAssertEqual(today, 8_432)
        XCTAssertEqual(series, [sep13: 8_432])
    }
}

/// The text a sleep or steps value is shown as.
final class HealthTextTests: XCTestCase {

    func test_timeAsleep_readsAsHoursAndMinutes() {
        XCTAssertEqual(HealthText.duration(7 * 3_600 + 32 * 60), "7h 32m")
        XCTAssertEqual(HealthText.duration(8 * 3_600), "8h")
        XCTAssertEqual(HealthText.duration(45 * 60), "45m")
        XCTAssertEqual(HealthText.duration(0), "0m")
    }

    func test_timeAsleep_roundsToTheNearestMinute() {
        XCTAssertEqual(HealthText.duration(7 * 3_600 + 59 * 60 + 40), "8h")
    }

    func test_steps_readsAsAGroupedWholeNumber() {
        XCTAssertEqual(HealthText.steps(8_432), "8,432")
        XCTAssertEqual(HealthText.steps(0), "0")
    }
}
