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

    /// The number a Body Weight surface shows as its hero: Trend Weight once there is one,
    /// the latest raw Body Weight before that, nil with nothing logged.
    static func hero(of kilograms: [Double]) -> Double? {
        current(of: kilograms) ?? kilograms.last
    }

    /// Weeks the rate looks back over.
    static let rateWeeks = 4
    /// The shortest span a rate is given for.
    static let minimumRateDays = 14

    /// Kilograms a week Trend Weight moved over about the last four weeks: from the trend at
    /// the last Body Weight on or before four weeks before the latest (or the first, when
    /// there is less) to the latest trend. Nil until the Body Weights span two weeks.
    static func weeklyRate(of records: [BodyWeightRecord]) -> Double? {
        let trend = series(of: records.map(\.kilograms))
        guard let latest = records.last, let current = trend.last else { return nil }
        let cutoff = latest.day.advanced(by: -7 * rateWeeks)
        let start = records.lastIndex { $0.day <= cutoff } ?? 0
        let days = records[start].day.distance(to: latest.day)
        guard days >= minimumRateDays else { return nil }
        return (current - trend[start]) / Double(days) * 7
    }

    /// Where Trend Weight stands against the Goal Weight, in kilograms.
    enum GoalProgress: Equatable {
        /// Within a quarter kilogram (about half a pound) of it.
        case reached
        /// Heading toward it: this many weeks at the current rate.
        case toward(weeks: Double)
        /// Heading away from it, or not moving (under 0.05 kg a week).
        case away
        case steady
        /// No rate yet.
        case unknown
    }

    static func progress(trend: Double, goal: Double, weeklyRate: Double?) -> GoalProgress {
        let remaining = goal - trend
        guard abs(remaining) >= 0.25 else { return .reached }
        guard let weeklyRate else { return .unknown }
        guard abs(weeklyRate) >= 0.05 else { return .steady }
        return (remaining > 0) == (weeklyRate > 0) ? .toward(weeks: remaining / weeklyRate) : .away
    }
}

