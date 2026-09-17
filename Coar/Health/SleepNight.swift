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
