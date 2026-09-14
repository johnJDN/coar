import XCTest
@testable import Coar

/// Seam 2: pure rule functions. A Streak is the number of consecutive Periods, ending now,
/// in which a Habit met its target; the current Period counts once met and only breaks the
/// streak once it has ended unmet (CONTEXT.md "Streak"). Daily period here; ticket 05 adds
/// weeks.
final class StreakTests: XCTestCase {

    private let sep13 = Day(year: 2026, month: 9, day: 13)

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
}
