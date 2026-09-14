import XCTest
@testable import Coar

/// Seam 2: pure rule functions. A Streak is the number of consecutive Periods, ending now,
/// in which a Habit met its target; the current Period counts once met and only breaks the
/// streak once it has ended unmet (CONTEXT.md "Streak"). Counted in Days for a daily Habit
/// and in Monday-to-Sunday weeks for a weekly one.
final class StreakTests: XCTestCase {

    private let sep13 = Day(year: 2026, month: 9, day: 13)
    /// A Thursday: the current week still has days to come.
    private let thursday10 = Day(year: 2026, month: 9, day: 10)

    private func days(_ numbers: Int...) -> Set<Day> {
        Set(numbers.map { Day(year: 2026, month: 9, day: $0) })
    }

    func test_streak_countsConsecutiveMetDaysEndingToday() {
        XCTAssertEqual(Streak.days(met: days(11, 12, 13), today: sep13), 3)
    }

    func test_streak_todayMetCountsOnce() {
        XCTAssertEqual(Streak.days(met: days(13), today: sep13), 1)
    }

    func test_streak_todayUnmetDoesNotBreakYesterdaysRun() {
        XCTAssertEqual(Streak.days(met: days(10, 11, 12), today: sep13), 3)
    }

    func test_streak_isZeroWhenNeitherTodayNorYesterdayIsMet() {
        XCTAssertEqual(Streak.days(met: days(9, 10, 11), today: sep13), 0)
    }

    func test_streak_aGapResetsTheCount() {
        XCTAssertEqual(Streak.days(met: days(8, 9, 11, 12, 13), today: sep13), 3)
    }

    func test_streak_withNoCheckIns_isZero() {
        XCTAssertEqual(Streak.days(met: [], today: sep13), 0)
    }

    func test_streak_crossesAMonthBoundary() {
        let met: Set<Day> = [
            Day(year: 2026, month: 8, day: 30), Day(year: 2026, month: 8, day: 31),
            Day(year: 2026, month: 9, day: 1),
        ]
        XCTAssertEqual(Streak.days(met: met, today: Day(year: 2026, month: 9, day: 1)), 3)
    }

    func test_streak_ignoresDaysAfterToday() {
        XCTAssertEqual(Streak.days(met: days(12, 13, 14, 15), today: sep13), 2)
    }

    // MARK: Weeks

    private let aug17 = Day(year: 2026, month: 8, day: 17)
    private let aug24 = Day(year: 2026, month: 8, day: 24)
    private let aug31 = Day(year: 2026, month: 8, day: 31)
    private let sep7 = Day(year: 2026, month: 9, day: 7)

    func test_weeklyStreak_countsConsecutiveMetWeeksEndingWithTheCurrentOne() {
        XCTAssertEqual(Streak.weeks(met: [aug24, aug31, sep7], today: thursday10), 3)
    }

    func test_weeklyStreak_currentWeekMetMidweekCountsAlready() {
        XCTAssertEqual(Streak.weeks(met: [sep7], today: thursday10), 1)
    }

    func test_weeklyStreak_currentWeekStillPendingDoesNotBreakLastWeeksRun() {
        XCTAssertEqual(Streak.weeks(met: [aug24, aug31], today: thursday10), 2)
    }

    func test_weeklyStreak_breaksOnceAWeekHasEndedUnmet() {
        XCTAssertEqual(Streak.weeks(met: [aug17, aug24], today: thursday10), 0)
    }

    func test_weeklyStreak_aGapResetsTheCount() {
        XCTAssertEqual(Streak.weeks(met: [Day(year: 2026, month: 8, day: 10), aug24, aug31, sep7], today: thursday10), 3)
    }

    func test_weeklyStreak_onASundayTheCurrentWeekStillCounts() {
        XCTAssertEqual(Streak.weeks(met: [aug31, sep7], today: sep13), 2)
    }
}
