import SwiftUI
import UIKit

/// Something the history page charts (`.scratch/health-pages/issues/03`): a value per Day,
/// read live from Apple Health (ADR 0002) except nothing here is stored.
enum HistoryMetric: Hashable {
    case timeAsleep
    case sleepScore
    case steps
    case vital(Vital)
    case cardioFitness

    var title: String {
        switch self {
        case .timeAsleep: return "Time Asleep"
        case .sleepScore: return "Sleep Score"
        case .steps: return "Steps"
        case .vital(let vital): return vital.title
        case .cardioFitness: return "Cardio Fitness"
        }
    }

    /// Sleep's teal for everything on the Sleep page; Steps' amber for steps and VO2 max.
    var accent: Color {
        switch self {
        case .steps, .cardioFitness: return Color.accentAmber
        default: return Color.accentTeal
        }
    }

    /// Daily totals read as bars; readings as a line through their points.
    var isBars: Bool {
        switch self {
        case .timeAsleep, .sleepScore, .steps: return true
        case .vital, .cardioFitness: return false
        }
    }

    /// A value as the header and the scrub label show it.
    func text(_ value: Double) -> String {
        switch self {
        case .timeAsleep: return HealthText.duration(value * 3_600)
        case .sleepScore: return "\(Int(value.rounded()))"
        case .steps: return HealthText.steps(Int(value.rounded()))
        case .vital(let vital): return vital.text(value)
        case .cardioFitness: return "\(value.formatted(.number.precision(.fractionLength(1)))) VO2 max"
        }
    }

    func axisText(_ value: Double) -> String {
        switch self {
        case .timeAsleep: return HealthMetric.sleep.axisText(value)
        case .steps: return HealthMetric.steps.axisText(value)
        default: return value.formatted(.number.precision(.fractionLength(0)))
        }
    }

    /// Whether the chart shows the usual range as a band (the overnight readings).
    var showsUsualBand: Bool {
        if case .vital = self { return true }
        return false
    }
}

/// A chart's time window and how it groups Days: one point a Day for a week or a month, a
/// week's average for six months, a month's average for a year.
enum HistoryRange: Int, CaseIterable {
    case week, month, halfYear, year

    var title: String {
        switch self {
        case .week: return "W"
        case .month: return "M"
        case .halfYear: return "6M"
        case .year: return "Y"
        }
    }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .halfYear: return 182
        case .year: return 365
        }
    }

    var bucket: Calendar.Component {
        switch self {
        case .week, .month: return .day
        case .halfYear: return .weekOfYear
        case .year: return .month
        }
    }

    /// What a point is: "a day", "a week", "a month".
    var bucketNoun: String {
        switch self {
        case .week, .month: return "day"
        case .halfYear: return "week"
        case .year: return "month"
        }
    }
}

/// One point of a history chart: a Day's value, or the average of a week's or month's Days
/// that have one, dated at the bucket's first Day.
struct HistoryPoint: Hashable, Identifiable {
    let date: Date
    let value: Double
    /// Days with a value behind it.
    let count: Int
    var id: Date { date }
}

/// How a history page's points are made (pure rules, values in, values out).
enum MetricHistory {

    /// The Days a range covers, ending today.
    static func span(_ range: HistoryRange, today: Day, calendar: Calendar = .current) -> ClosedRange<Date> {
        let first = today.advanced(by: 1 - range.days)
        let start = bucketStart(first, range, calendar: calendar)
        return start...today.advanced(by: 1).start(in: calendar)
    }

    /// The points for a range, oldest first; buckets without a value are left out (a gap,
    /// not a zero).
    static func points(_ daily: [Day: Double], range: HistoryRange, today: Day, calendar: Calendar = .current) -> [HistoryPoint] {
        let first = today.advanced(by: 1 - range.days)
        let inRange = daily.filter { $0.key >= first && $0.key <= today }
        let grouped = Dictionary(grouping: inRange, by: { bucketStart($0.key, range, calendar: calendar) })
        return grouped.map { start, days in
            HistoryPoint(date: start, value: days.map(\.value).reduce(0, +) / Double(days.count), count: days.count)
        }
        .sorted { $0.date < $1.date }
    }

    /// The average a Day over a range, from the Days that have a value.
    static func average(_ daily: [Day: Double], range: HistoryRange, today: Day) -> Double? {
        let first = today.advanced(by: 1 - range.days)
        let values = daily.filter { $0.key >= first && $0.key <= today }.map(\.value)
        return values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    /// The user's usual range for an overnight reading: the last 30 Nights' average, give or
    /// take one standard deviation. Nil before there are 5.
    static func usualBand(_ daily: [Day: Double], today: Day) -> ClosedRange<Double>? {
        let recent = daily.filter { $0.key > today.advanced(by: -OvernightVitals.usualNights) && $0.key <= today }.map(\.value)
        guard recent.count >= OvernightVitals.minimumNights else { return nil }
        let mean = recent.reduce(0, +) / Double(recent.count)
        let spread = (recent.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(recent.count)).squareRoot()
        return (mean - spread)...(mean + spread)
    }

    private static func bucketStart(_ day: Day, _ range: HistoryRange, calendar: Calendar) -> Date {
        switch range.bucket {
        case .weekOfYear: return day.startOfWeek.start(in: calendar)
        case .month: return calendar.date(from: calendar.dateComponents([.year, .month], from: day.start(in: calendar)))!
        default: return day.start(in: calendar)
        }
    }

    /// A year of daily values for a metric, in its chart unit (hours of sleep, steps, the
    /// reading's own unit). Nights read: the year and the 14 before, for the Sleep Score's
    /// usual bedtime.
    @MainActor
    static func load(_ metric: HistoryMetric, dependencies: AppDependencies, today: Day) async throws -> [Day: Double] {
        let reader = dependencies.healthReader
        let year = (0..<HistoryRange.year.days).map { today.advanced(by: -$0) }
        switch metric {
        case .steps:
            return try await reader.steps(on: year).mapValues(Double.init)
        case .cardioFitness:
            let samples = try await reader.cardioFitness(from: year.last!.start(), to: Date())
            return Dictionary(grouping: samples, by: { Day($0.date) }).mapValues { $0.map(\.value).reduce(0, +) / Double($0.count) }
        case .timeAsleep, .sleepScore, .vital:
            let history = (0..<(HistoryRange.year.days + HealthDetailViewController.patternNights)).map { today.advanced(by: -$0) }
            let nights = try await reader.sleepNights(wakingOn: history)
            switch metric {
            case .timeAsleep:
                return nights.mapValues { $0.timeAsleep / 3_600 }
            case .sleepScore:
                let goal = (HealthTarget.current(for: .sleep, store: dependencies.store, today: today)?.amount ?? 8) * 3_600
                var scores: [Day: Double] = [:]
                for (day, night) in nights where day > today.advanced(by: -HistoryRange.year.days) {
                    let before = nights.filter { $0.key < day && $0.key >= day.advanced(by: -HealthDetailViewController.patternNights) }
                    let usual = SleepPattern.from(before, in: .current)?.bedtime
                    scores[day] = Double(SleepScore.score(night, wakingOn: day, goal: goal, usualBedtime: usual, calendar: .current).total)
                }
                return scores
            case .vital(let vital):
                let samples = try await reader.vitalSamples(from: SleepNight.window(wakingOn: history.last!, in: .current).lowerBound, to: Date())
                return OvernightVitals.values(nights: nights, samples: samples, calendar: .current).compactMapValues { $0[vital] }
            default:
                return [:]
            }
        }
    }
}
