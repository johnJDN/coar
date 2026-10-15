import Foundation

/// The sleep rule (spec story 77): a night belongs to the Day the user woke, and its value
/// is the time asleep, which sums the asleep stages and excludes awake and in-bed, matching
/// the Health app. The Health app's sleep day runs 6 PM to 6 PM, so an afternoon nap counts
/// toward the Day it was taken and an early-evening doze toward the next.
enum SleepNight {

    /// The hour a sleep day turns over: 6 PM.
    static let boundaryHour = 18

    /// The span of the night that ends on `day`: 6 PM the evening before to 6 PM that Day.
    static func window(wakingOn day: Day, in calendar: Calendar) -> Range<Date> {
        let start = calendar.date(bySettingHour: boundaryHour, minute: 0, second: 0, of: day.advanced(by: -1).start(in: calendar))!
        let end = calendar.date(bySettingHour: boundaryHour, minute: 0, second: 0, of: day.start(in: calendar))!
        return start..<end
    }

    /// Time Asleep per wake Day, for the Days whose Night has an asleep sample. The one
    /// reduction the live reader and the test fake share.
    static func timeAsleep(wakingOn days: [Day], from samples: [SleepSample], in calendar: Calendar) -> [Day: TimeInterval] {
        var result: [Day: TimeInterval] = [:]
        for day in days {
            result[day] = timeAsleep(wakingOn: day, from: samples, in: calendar)
        }
        return result
    }

    /// Seconds asleep in the Night that ended on `day`; nil when no asleep sample belongs
    /// to it. A sample that straddles the window's edge counts only for the part inside, and
    /// hours two sources both recorded (a watch's stages under a sleep app's one span) count
    /// once.
    static func timeAsleep(wakingOn day: Day, from samples: [SleepSample], in calendar: Calendar) -> TimeInterval? {
        let window = window(wakingOn: day, in: calendar)
        let spans = samples
            .filter(\.stage.isAsleep)
            .compactMap { sample -> Range<Date>? in
                let start = max(sample.start, window.lowerBound)
                let end = min(sample.end, window.upperBound)
                return start < end ? start..<end : nil
            }
        guard !spans.isEmpty else { return nil }
        return merged(spans).reduce(0) { $0 + $1.upperBound.timeIntervalSince($1.lowerBound) }
    }

    /// A Night's detail per wake Day, for the Days whose Night has an asleep sample.
    static func details(wakingOn days: [Day], from samples: [SleepSample], in calendar: Calendar) -> [Day: SleepNightDetail] {
        var result: [Day: SleepNightDetail] = [:]
        for day in days {
            result[day] = detail(wakingOn: day, from: samples, in: calendar)
        }
        return result
    }

    /// The Night that ended on `day` as its page shows it; nil when no asleep sample belongs
    /// to it. Time Asleep is the same as `timeAsleep`. Bedtime and wake time are those of the
    /// main sleep: asleep spans less than an hour apart are one sleep, and the longest wins,
    /// so an afternoon nap in the same window doesn't move them. Stages come only from a
    /// source that records them (an Apple Watch: core, deep, REM); awake counts between
    /// bedtime and wake time.
    static func detail(wakingOn day: Day, from samples: [SleepSample], in calendar: Calendar) -> SleepNightDetail? {
        let window = window(wakingOn: day, in: calendar)
        let asleep = merged(clipped(samples.filter(\.stage.isAsleep), to: window))
        guard !asleep.isEmpty else { return nil }

        var sleeps: [Range<Date>] = []
        for span in asleep {
            if let last = sleeps.last, span.lowerBound.timeIntervalSince(last.upperBound) < 3_600 {
                sleeps[sleeps.count - 1] = last.lowerBound..<span.upperBound
            } else {
                sleeps.append(span)
            }
        }
        let main = sleeps.max { duration(of: [$0]) < duration(of: [$1]) }!

        var stages: [SleepStage: TimeInterval] = [:]
        let staged: [(SleepStage, SleepSample.Stage)] = [(.core, .asleepCore), (.deep, .asleepDeep), (.rem, .asleepREM)]
        for (stage, recorded) in staged {
            let total = duration(of: merged(clipped(samples.filter { $0.stage == recorded }, to: window)))
            if total > 0 { stages[stage] = total }
        }
        if !stages.isEmpty {
            stages[.awake] = duration(of: merged(clipped(samples.filter { $0.stage == .awake }, to: main)))
        }
        // Waking inside the main sleep: the gaps between its asleep spans, those of 2 minutes
        // or more counted as interruptions.
        let inside = asleep.filter { main.contains($0.lowerBound) }
        let gaps = zip(inside, inside.dropFirst()).map { $1.lowerBound.timeIntervalSince($0.upperBound) }
        return SleepNightDetail(
            timeAsleep: duration(of: asleep), fellAsleep: main.lowerBound, woke: main.upperBound, stages: stages,
            interruptions: gaps.filter { $0 >= 120 }.count, awakeTime: gaps.reduce(0, +)
        )
    }

    private static func clipped(_ samples: [SleepSample], to window: Range<Date>) -> [Range<Date>] {
        samples.compactMap { sample in
            let start = max(sample.start, window.lowerBound)
            let end = min(sample.end, window.upperBound)
            return start < end ? start..<end : nil
        }
    }

    private static func duration(of spans: [Range<Date>]) -> TimeInterval {
        spans.reduce(0) { $0 + $1.upperBound.timeIntervalSince($1.lowerBound) }
    }

    /// The spans with every overlap folded into one, so no instant is counted twice.
    private static func merged(_ spans: [Range<Date>]) -> [Range<Date>] {
        var merged: [Range<Date>] = []
        for span in spans.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            if let last = merged.last, span.lowerBound <= last.upperBound {
                merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, span.upperBound)
            } else {
                merged.append(span)
            }
        }
        return merged
    }
}

/// The stages a Night's page shows, in the Health app's order.
enum SleepStage: CaseIterable, Hashable {
    case awake, rem, core, deep

    var title: String {
        switch self {
        case .awake: return "Awake"
        case .rem: return "REM"
        case .core: return "Core"
        case .deep: return "Deep"
        }
    }
}

/// One Night as its page shows it: Time Asleep, when the main sleep began and ended, seconds
/// per stage when a source recorded stages (empty otherwise), and how often and how long the
/// user woke during the main sleep.
struct SleepNightDetail: Equatable {
    let timeAsleep: TimeInterval
    let fellAsleep: Date
    let woke: Date
    let stages: [SleepStage: TimeInterval]
    var interruptions = 0
    var awakeTime: TimeInterval = 0
}

/// When the user usually falls asleep and wakes (a pure rule): the average of recent Nights'
/// bedtimes and wake times, and how far a typical Night strays from it (the mean absolute
/// difference). Times are measured from each Night's 6 PM start, so 11:30 PM and 12:30 AM
/// average to midnight, not to noon.
struct SleepPattern: Equatable {
    /// Minutes after 6 PM.
    let bedtime: Double
    let bedtimeSpread: Double
    /// Minutes after 6 PM the evening before.
    let wake: Double
    let wakeSpread: Double
    let nights: Int

    /// Nights it needs before it says anything.
    static let minimumNights = 3

    /// From the Nights waking on the given Days; nil with fewer than `minimumNights`.
    static func from(_ details: [Day: SleepNightDetail], in calendar: Calendar) -> SleepPattern? {
        guard details.count >= minimumNights else { return nil }
        let offsets = details.map { day, detail in
            let start = SleepNight.window(wakingOn: day, in: calendar).lowerBound
            return (bed: detail.fellAsleep.timeIntervalSince(start) / 60, wake: detail.woke.timeIntervalSince(start) / 60)
        }
        let (bedtime, bedtimeSpread) = averageAndSpread(offsets.map(\.bed))
        let (wake, wakeSpread) = averageAndSpread(offsets.map(\.wake))
        return SleepPattern(bedtime: bedtime, bedtimeSpread: bedtimeSpread, wake: wake, wakeSpread: wakeSpread, nights: details.count)
    }

    private static func averageAndSpread(_ values: [Double]) -> (Double, Double) {
        let average = values.reduce(0, +) / Double(values.count)
        let spread = values.map { abs($0 - average) }.reduce(0, +) / Double(values.count)
        return (average, spread)
    }

    /// A time of day for minutes after 6 PM: "11:40 PM".
    static func clockText(minutesAfterSixPM minutes: Double, calendar: Calendar = .current) -> String {
        let sixPM = calendar.date(bySettingHour: SleepNight.boundaryHour, minute: 0, second: 0, of: Date(timeIntervalSinceReferenceDate: 0))!
        let rounded = (minutes / 5).rounded() * 5
        return sixPM.addingTimeInterval(rounded * 60).formatted(date: .omitted, time: .shortened)
    }

    /// A spread as words: "± 35 min", "± 1h 10m".
    static func spreadText(_ minutes: Double) -> String {
        let rounded = max(5, (minutes / 5).rounded() * 5)
        return "± " + (rounded < 60 ? "\(Int(rounded)) min" : HealthText.duration(rounded * 60))
    }
}
