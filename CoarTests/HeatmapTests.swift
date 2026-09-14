import XCTest
@testable import Coar

/// Seam 2: pure rule functions. The habit heatmap has 7 rows with Monday on top and one
/// column per Monday-to-Sunday week, ending with the current week (DESIGN.md §8, §11).
/// Yes/no cells are binary: done, or empty (a miss is never recorded, CONTEXT.md "Check-in");
/// quantitative cells fall into four buckets of amount ÷ the target in force.
final class HeatmapTests: XCTestCase {

    /// A Sunday, so the current week is complete.
    private let sunday13 = Day(year: 2026, month: 9, day: 13)
    /// A Thursday, so the current week still has days to come.
    private let thursday10 = Day(year: 2026, month: 9, day: 10)

    func test_grid_hasSevenRowsPerColumn_columnMajor() {
        let cells = Heatmap.cells(endingOn: sunday13, columns: 26, levels: [:])
        XCTAssertEqual(cells.count, 26 * 7)
    }

    func test_grid_startsOnTheMondayTwentyFiveWeeksBeforeTheCurrentWeek() {
        let cells = Heatmap.cells(endingOn: sunday13, columns: 26, levels: [:])
        XCTAssertEqual(cells.first?.day, Day(year: 2026, month: 3, day: 16))
    }

    func test_grid_lastColumnIsTheCurrentWeekMondayOnTop() {
        let cells = Heatmap.cells(endingOn: thursday10, columns: 2, levels: [:])
        let lastColumn = cells.suffix(7).map(\.day)
        XCTAssertEqual(lastColumn.first, Day(year: 2026, month: 9, day: 7))
        XCTAssertEqual(lastColumn.last, Day(year: 2026, month: 9, day: 13))
    }

    func test_daysAfterToday_areFuture_andDaysUpToTodayAreEmptyOrDone() {
        let levels: [Day: Heatmap.Level] = [Day(year: 2026, month: 9, day: 8): .done, Day(year: 2026, month: 9, day: 10): .half]
        let cells = Heatmap.cells(endingOn: thursday10, columns: 1, levels: levels)
        XCTAssertEqual(cells.map(\.level), [.empty, .done, .empty, .half, .future, .future, .future])
    }

    func test_levelsOutsideTheGrid_areIgnored() {
        let cells = Heatmap.cells(endingOn: sunday13, columns: 1, levels: [Day(year: 2026, month: 9, day: 1): .done])
        XCTAssertTrue(cells.allSatisfy { $0.level == .empty })
    }

    func test_weeks_areTheMondaysOfEachColumn() {
        XCTAssertEqual(
            Heatmap.weeks(endingOn: thursday10, columns: 3),
            [Day(year: 2026, month: 8, day: 24), Day(year: 2026, month: 8, day: 31), Day(year: 2026, month: 9, day: 7)]
        )
    }

    // MARK: Quantitative buckets

    func test_bucket_nothingLogged_isEmpty() {
        XCTAssertEqual(Heatmap.level(amount: 0, target: 20), .empty)
    }

    func test_bucket_upToAQuarter_isTheFirstBucket() {
        XCTAssertEqual(Heatmap.level(amount: 1, target: 20), .quarter)
        XCTAssertEqual(Heatmap.level(amount: 5, target: 20), .quarter)
    }

    func test_bucket_upToAHalf_isTheSecondBucket() {
        XCTAssertEqual(Heatmap.level(amount: 5.1, target: 20), .half)
        XCTAssertEqual(Heatmap.level(amount: 10, target: 20), .half)
    }

    func test_bucket_belowTheTarget_isTheThirdBucket() {
        XCTAssertEqual(Heatmap.level(amount: 10.1, target: 20), .mostly)
        XCTAssertEqual(Heatmap.level(amount: 15, target: 20), .mostly)
        XCTAssertEqual(Heatmap.level(amount: 19.9, target: 20), .mostly)
    }

    func test_bucket_targetReachedOrPassed_isDone() {
        XCTAssertEqual(Heatmap.level(amount: 20, target: 20), .done)
        XCTAssertEqual(Heatmap.level(amount: 45, target: 20), .done)
    }

    func test_bucket_withNoTargetInForce_isEmptyWhateverTheAmount() {
        XCTAssertEqual(Heatmap.level(amount: 12, target: nil), .empty)
    }
}
