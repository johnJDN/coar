import Foundation

/// The overnight readings the Sleep page shows beside a Night (`.scratch/health-pages/issues/02`).
/// Read live from Apple Health, never stored (ADR 0002).
enum Vital: CaseIterable, Hashable {
    case restingHeartRate
    /// The HRV Apple shows as Recovery HRV (RMSSD, iOS 27 and later).
    case recoveryHRV
    /// The HRV Apple has always recorded (SDNN).
    case hrv
    case respiratoryRate
    case bloodOxygen

    var title: String {
        switch self {
        case .restingHeartRate: return "Resting heart rate"
        case .recoveryHRV: return "Recovery HRV"
        case .hrv: return "HRV"
        case .respiratoryRate: return "Breathing rate"
        case .bloodOxygen: return "Blood oxygen"
        }
    }

    var systemImage: String {
        switch self {
        case .restingHeartRate: return "heart.fill"
        case .recoveryHRV, .hrv: return "waveform.path.ecg"
        case .respiratoryRate: return "lungs.fill"
        case .bloodOxygen: return "drop.fill"
        }
    }

    /// The value as the page shows it: "52 bpm", "38 ms", "14.5 /min", "96%".
    func text(_ value: Double) -> String {
        switch self {
        case .restingHeartRate: return "\(Int(value.rounded())) bpm"
        case .recoveryHRV, .hrv: return "\(Int(value.rounded())) ms"
        case .respiratoryRate: return "\(value.formatted(.number.precision(.fractionLength(1)))) /min"
        case .bloodOxygen: return "\(Int(value.rounded()))%"
        }
    }

    /// The bare number, for "usual 48".
    func number(_ value: Double) -> String {
        self == .respiratoryRate ? value.formatted(.number.precision(.fractionLength(1))) : "\(Int(value.rounded()))"
    }

    /// Whether a value is outside the usual range, on the side that matters: a higher resting
    /// heart rate or breathing rate, a lower HRV or blood oxygen. The margins are about what a
    /// normal night varies by.
    func isOutside(_ value: Double, usual: Double) -> Bool {
        switch self {
        case .restingHeartRate: return value - usual > 3
        case .recoveryHRV, .hrv: return value < usual * 0.8
        case .respiratoryRate: return value - usual > 1
        case .bloodOxygen: return usual - value > 2
        }
    }

    /// How an outside value reads in the summary: "higher", "lower".
    var outsideWord: String {
        switch self {
        case .restingHeartRate, .respiratoryRate: return "higher"
        case .recoveryHRV, .hrv, .bloodOxygen: return "lower"
        }
    }
}

/// One reading from Apple Health, in the unit the page shows (blood oxygen as a percentage).
struct VitalSample: Equatable {
    let vital: Vital
    let date: Date
    let value: Double
}

/// A value with its date, for a chart (VO2 max).
struct DatedValue: Equatable {
    let date: Date
    let value: Double
}

/// How the overnight readings are reduced (pure rules, values in, values out).
enum OvernightVitals {

    /// Nights before this one a usual needs.
    static let minimumNights = 5
    /// Nights a usual looks back over.
    static let usualNights = 30

    /// Each Night's value per vital: the average of the readings taken during its main sleep
    /// (`SleepNightDetail.fellAsleep` to `woke`). Resting heart rate is a daily value Apple
    /// works out, so it's the one dated on the wake Day.
    static func values(nights: [Day: SleepNightDetail], samples: [VitalSample], calendar: Calendar) -> [Day: [Vital: Double]] {
        var result: [Day: [Vital: Double]] = [:]
        for (day, night) in nights {
            let during = samples.filter { $0.vital != .restingHeartRate && $0.date >= night.fellAsleep && $0.date <= night.woke }
            for (vital, readings) in Dictionary(grouping: during, by: \.vital) {
                result[day, default: [:]][vital] = readings.map(\.value).reduce(0, +) / Double(readings.count)
            }
        }
        for sample in samples where sample.vital == .restingHeartRate {
            result[Day(sample.date, in: calendar), default: [:]][.restingHeartRate] = sample.value
        }
        return result
    }

    struct Reading: Equatable {
        let value: Double
        /// The average of up to 30 earlier nights, once there are 5.
        let usual: Double?
        var isOutside: Bool
    }

    /// A Night's readings against its usual: the average of the nights before it.
    static func readings(on day: Day, values: [Day: [Vital: Double]]) -> [Vital: Reading] {
        guard let tonight = values[day] else { return [:] }
        let earlier = values.keys.filter { $0 < day }.sorted(by: >)
        var result: [Vital: Reading] = [:]
        for (vital, value) in tonight {
            let history = earlier.compactMap { values[$0]?[vital] }.prefix(usualNights)
            let usual = history.count >= minimumNights ? history.reduce(0, +) / Double(history.count) : nil
            result[vital] = Reading(value: value, usual: usual, isOutside: usual.map { vital.isOutside(value, usual: $0) } ?? false)
        }
        return result
    }

    /// One line for the card: all usual, what's off, or still learning.
    static func summary(_ readings: [Vital: Reading]) -> String {
        guard !readings.isEmpty else { return "No overnight readings for this night." }
        guard readings.values.contains(where: { $0.usual != nil }) else {
            return "Learning your usual: it needs \(minimumNights) nights of readings."
        }
        let outside = Vital.allCases.filter { readings[$0]?.isOutside == true }
        guard !outside.isEmpty else { return "All in your usual range." }
        let parts = outside.map { "\($0.title.lowercased().replacingOccurrences(of: "hrv", with: "HRV")) \($0.outsideWord)" }
        let list = parts.count == 1 ? parts[0] : parts.dropLast().joined(separator: ", ") + " and " + parts.last!
        let first = list.prefix(1).uppercased() + list.dropFirst()
        return outside.count >= 2
            ? "\(first) than usual. Together that often means you're not recovered: a hard day, alcohol, or getting sick."
            : "\(first) than usual."
    }
}

/// Coar's Sleep Score for a Night, out of 100 (CONTEXT.md "Sleep Score"), from the same three
/// things Apple's uses: how long you slept (50), how close to your usual time you fell
/// asleep (30), and how little you woke (20). Not Apple's number, which apps can't read.
struct SleepScore: Equatable {
    let duration: Int
    let bedtime: Int
    let interruptions: Int

    var total: Int { duration + bedtime + interruptions }

    var label: String {
        switch total {
        case 90...: return "Excellent"
        case 75..<90: return "Good"
        case 60..<75: return "OK"
        case 40..<60: return "Low"
        default: return "Very low"
        }
    }

    /// The bedtime used when there's no usual one yet: 11:30 PM, in minutes after 6 PM.
    static let defaultBedtime = 330.0

    /// - Parameters:
    ///   - goal: the sleep wanted, from the Sleep habit's target (8 hours without one).
    ///   - usualBedtime: minutes after 6 PM (`SleepPattern.bedtime`), nil before there is one.
    static func score(_ night: SleepNightDetail, wakingOn day: Day, goal: TimeInterval, usualBedtime: Double?, calendar: Calendar) -> SleepScore {
        let share = min(1, max(0, night.timeAsleep / max(goal, 1)))
        let duration = Int((50 * pow(share, 1.5)).rounded())

        let start = SleepNight.window(wakingOn: day, in: calendar).lowerBound
        let minutes = night.fellAsleep.timeIntervalSince(start) / 60
        let off = abs(minutes - (usualBedtime ?? defaultBedtime))
        let bedtime = Int((30 * min(1, max(0, (150 - off) / 120))).rounded())

        let awakeMinutes = night.awakeTime / 60
        let lost = 3 * Double(max(0, night.interruptions - 1)) + max(0, awakeMinutes - 10) / 2
        let interruptions = Int(max(0, 20 - lost).rounded())

        return SleepScore(duration: duration, bedtime: bedtime, interruptions: interruptions)
    }
}
