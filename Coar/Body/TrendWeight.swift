import Foundation

/// Trend Weight (CONTEXT.md): the smoothed Body Weight that filters out day-to-day water
/// swings. An exponential moving average over the logged series in Day order, in the style
/// of MacroFactor and the Hacker's Diet: each point moves a tenth of the way from the
/// previous trend toward that Day's Body Weight. Gaps between logged Days are not weighted.
/// A pure rule function: values in, values out.
enum TrendWeight {

    /// How far the trend moves toward each new point.
    static let smoothing = 0.1

    /// One trend value per input point, aligned by index. Empty with fewer than 2 points:
    /// a single Body Weight has no trend, and the screen shows `—` for it.
    static func series(of kilograms: [Double]) -> [Double] {
        guard kilograms.count >= 2 else { return [] }
        var trend: [Double] = []
        trend.reserveCapacity(kilograms.count)
        var current = kilograms[0]
        trend.append(current)
        for point in kilograms.dropFirst() {
            current += smoothing * (point - current)
            trend.append(current)
        }
        return trend
    }

    /// The latest Trend Weight, the hero number on the weight screen; nil with fewer than
    /// 2 points.
    static func current(of kilograms: [Double]) -> Double? {
        series(of: kilograms).last
    }
}
