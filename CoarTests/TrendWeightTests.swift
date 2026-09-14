import XCTest
@testable import Coar

/// Seam 2: pure rule functions. Trend Weight is the smoothed Body Weight that filters out
/// day-to-day water swings (CONTEXT.md "Trend Weight"); with fewer than 2 points there is
/// no trend and the screen shows `—`.
final class TrendWeightTests: XCTestCase {

    func test_trendWeightSeries_smoothsAFixedSeriesExponentially() {
        // Worked by hand with a 0.1 smoothing factor: each point moves a tenth of the way
        // from the previous trend toward the day's Body Weight.
        let trend = TrendWeight.series(of: [80.0, 82.0, 81.0, 83.0])

        XCTAssertEqual(trend.count, 4)
        XCTAssertEqual(trend[0], 80.0, accuracy: 0.001)
        XCTAssertEqual(trend[1], 80.2, accuracy: 0.001)
        XCTAssertEqual(trend[2], 80.28, accuracy: 0.001)
        XCTAssertEqual(trend[3], 80.552, accuracy: 0.001)
    }

    func test_trendWeight_withOnePoint_isNoTrend() {
        XCTAssertNil(TrendWeight.current(of: [84.2]))
        XCTAssertTrue(TrendWeight.series(of: [84.2]).isEmpty)
    }

    func test_trendWeight_withNoPoints_isNoTrend() {
        XCTAssertNil(TrendWeight.current(of: []))
    }

    func test_trendWeightCurrent_isTheLastPointOfTheSeries() {
        XCTAssertEqual(TrendWeight.current(of: [80.0, 82.0, 81.0, 83.0])!, 80.552, accuracy: 0.001)
    }

    func test_heroValue_isTrendWeightOnceThereIsOne_andTheRawValueBeforeThat() {
        XCTAssertEqual(TrendWeight.hero(of: [80.0, 82.0, 81.0, 83.0])!, 80.552, accuracy: 0.001)
        XCTAssertEqual(TrendWeight.hero(of: [84.2]), 84.2)
        XCTAssertNil(TrendWeight.hero(of: []))
    }
}
