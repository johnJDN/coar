import XCTest
@testable import Coar

/// Seam 2: pure rule functions. The habit heatmap has 7 rows with Monday on top and one
/// column per Monday-to-Sunday week, ending with the current week (DESIGN.md §8, §11).
/// Yes/no cells are binary: done, or empty (a miss is never recorded, CONTEXT.md "Check-in").
final class HeatmapTests: XCTestCase {

    /// A Sunday, so the current week is complete.
    private let sunday13 = Day(year: 2026, month: 9, day: 13)
    /// A Thursday, so the current week still has days to come.
    private let thursday10 = Day(year: 2026, month: 9, day: 10)

    func test_grid_hasSevenRowsPerColumn_columnMajor() {
        let cells = Heatmap.cells(endingOn: sunday13, columns: 26, met: [])
        XCTAssertEqual(cells.count, 26 * 7)
    }

    func test_grid_startsOnTheMondayTwentyFiveWeeksBeforeTheCurrentWeek() {
        let cells = Heatmap.cells(endingOn: sunday13, columns: 26, met: [])
        XCTAssertEqual(cells.first?.day, Day(year: 2026, month: 3, day: 16))
    }

    func test_grid_lastColumnIsTheCurrentWeekMondayOnTop() {
        let cells = Heatmap.cells(endingOn: thursday10, columns: 2, met: [])
        let lastColumn = cells.suffix(7).map(\.day)
        XCTAssertEqual(lastColumn.first, Day(year: 2026, month: 9, day: 7))
        XCTAssertEqual(lastColumn.last, Day(year: 2026, month: 9, day: 13))
    }

    func test_daysAfterToday_areFuture_andDaysUpToTodayAreEmptyOrDone() {
        let met: Set<Day> = [Day(year: 2026, month: 9, day: 8), Day(year: 2026, month: 9, day: 10)]
        let cells = Heatmap.cells(endingOn: thursday10, columns: 1, met: met)
        XCTAssertEqual(cells.map(\.level), [.empty, .done, .empty, .done, .future, .future, .future])
    }

    func test_metDaysOutsideTheGrid_areIgnored() {
        let cells = Heatmap.cells(endingOn: sunday13, columns: 1, met: [Day(year: 2026, month: 9, day: 1)])
        XCTAssertTrue(cells.allSatisfy { $0.level == .empty })
    }
}
