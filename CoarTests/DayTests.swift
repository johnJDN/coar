import XCTest
@testable import Coar

/// Seam 2: pure rule functions. Day arithmetic is calendar arithmetic (ADR 0005): it must not
/// depend on the device's time zone, and it has to be right at the awkward edges.
final class DayTests: XCTestCase {

    func test_advanced_crossesLeapDayAndYearEnd() {
        XCTAssertEqual(Day(year: 2028, month: 2, day: 28).advanced(by: 1), Day(year: 2028, month: 2, day: 29))
        XCTAssertEqual(Day(year: 2027, month: 2, day: 28).advanced(by: 1), Day(year: 2027, month: 3, day: 1))
        XCTAssertEqual(Day(year: 2026, month: 12, day: 31).advanced(by: 1), Day(year: 2027, month: 1, day: 1))
        XCTAssertEqual(Day(year: 2027, month: 1, day: 1).advanced(by: -1), Day(year: 2026, month: 12, day: 31))
    }

    func test_weekday_isMondayOneThroughSundaySeven() {
        XCTAssertEqual(Day(year: 2026, month: 9, day: 14).weekday, 1)
        XCTAssertEqual(Day(year: 2026, month: 9, day: 13).weekday, 7)
    }

    func test_startOfWeek_isTheMondayOnOrBefore() {
        XCTAssertEqual(Day(year: 2026, month: 9, day: 13).startOfWeek, Day(year: 2026, month: 9, day: 7))
        XCTAssertEqual(Day(year: 2026, month: 9, day: 7).startOfWeek, Day(year: 2026, month: 9, day: 7))
        XCTAssertEqual(Day(year: 2026, month: 1, day: 3).startOfWeek, Day(year: 2025, month: 12, day: 29))
    }

    func test_daysInMonth_knowsLeapFebruary() {
        XCTAssertEqual(Day(year: 2028, month: 2, day: 1).daysInMonth, 29)
        XCTAssertEqual(Day(year: 2026, month: 2, day: 1).daysInMonth, 28)
        XCTAssertEqual(Day(year: 2026, month: 9, day: 1).daysInMonth, 30)
    }
}
