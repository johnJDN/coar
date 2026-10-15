import XCTest
@testable import Coar

/// History pages (`.scratch/health-pages/issues/03`): a range's points, grouped by Day, week,
/// or month; its average; and the usual band an overnight reading is drawn against.
final class MetricHistoryTests: XCTestCase {

    private let oct15 = Day(year: 2026, month: 10, day: 15)

    func test_monthRange_isOnePointADay_leavingGapsForDaysWithout() {
        let daily: [Day: Double] = [oct15: 7, oct15.advanced(by: -1): 8, oct15.advanced(by: -3): 6, oct15.advanced(by: -40): 9]

        let points = MetricHistory.points(daily, range: .month, today: oct15)

        XCTAssertEqual(points.map(\.value), [6, 8, 7], "the Day 40 back is outside the month; the missing Day is a gap")
    }

    func test_halfYearRange_averagesEachWeeksDaysWithData() {
        // Thursday Oct 15: its week began Monday Oct 12.
        let daily: [Day: Double] = [oct15: 10_000, oct15.advanced(by: -1): 6_000, oct15.advanced(by: -7): 8_000]

        let points = MetricHistory.points(daily, range: .halfYear, today: oct15)

        XCTAssertEqual(points.map(\.value), [8_000, 8_000])
        XCTAssertEqual(points.map(\.count), [1, 2])
        XCTAssertEqual(points.last?.date, Day(year: 2026, month: 10, day: 12).start())
    }

    func test_yearRange_averagesEachMonth() {
        let daily: [Day: Double] = [oct15: 50, Day(year: 2026, month: 10, day: 1): 54, Day(year: 2026, month: 9, day: 20): 51]

        let points = MetricHistory.points(daily, range: .year, today: oct15)

        XCTAssertEqual(points.map(\.value), [51, 52])
    }

    func test_average_isOverTheDaysWithData() {
        let daily: [Day: Double] = [oct15: 7, oct15.advanced(by: -2): 8, oct15.advanced(by: -10): 100]
        XCTAssertEqual(MetricHistory.average(daily, range: .week, today: oct15), 7.5)
        XCTAssertNil(MetricHistory.average([:], range: .week, today: oct15))
    }

    func test_usualBand_isTheLast30NightsGiveOrTakeOneStandardDeviation_onceThereAreFive() throws {
        var daily: [Day: Double] = [:]
        for (offset, value) in [48.0, 52, 48, 52].enumerated() { daily[oct15.advanced(by: -offset)] = value }
        XCTAssertNil(MetricHistory.usualBand(daily, today: oct15))

        daily[oct15.advanced(by: -4)] = 50
        daily[oct15.advanced(by: -40)] = 90 // too long ago to count
        let band = try XCTUnwrap(MetricHistory.usualBand(daily, today: oct15))

        XCTAssertEqual(band.lowerBound, 50 - 1.789, accuracy: 0.01)
        XCTAssertEqual(band.upperBound, 50 + 1.789, accuracy: 0.01)
    }
}
