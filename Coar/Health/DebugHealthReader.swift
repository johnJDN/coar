import Foundation

#if DEBUG
/// Canned sleep and steps for looking at the Sleep and Steps pages in a simulator, which has
/// no Watch: launch a debug build with `-FakeHealthData`. Each Night is a Watch-style night in
/// stages (bedtime around 11:30 PM, up around 7 AM) and each Day has steps spread over the
/// waking hours; both vary by Day but are the same on every launch. Never used by tests.
final class DebugHealthReader: HealthReader {

    static var isRequested: Bool {
        ProcessInfo.processInfo.arguments.contains("-FakeHealthData")
    }

    private let calendar = Calendar.current

    func timeAsleep(wakingOn days: [Day]) async throws -> [Day: TimeInterval] {
        SleepNight.timeAsleep(wakingOn: days, from: days.flatMap(samples), in: calendar)
    }

    func sleepNights(wakingOn days: [Day]) async throws -> [Day: SleepNightDetail] {
        SleepNight.details(wakingOn: days, from: days.flatMap(samples), in: calendar)
    }

    func steps(on days: [Day]) async throws -> [Day: Int] {
        var result: [Day: Int] = [:]
        for day in days {
            let hours = hourly(day)
            if !hours.isEmpty { result[day] = hours.values.reduce(0, +) }
        }
        return result
    }

    func hourlySteps(on day: Day) async throws -> [Int: Int] {
        hourly(day)
    }

    /// A number from 0 to 1 that depends only on the Day and a salt.
    private func noise(_ day: Day, _ salt: Int) -> Double {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in "\(day.rawValue)#\(salt)".utf8 {
            hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return Double(hash % 10_000) / 10_000
    }

    private func samples(wakingOn day: Day) -> [SleepSample] {
        guard day <= .today(), noise(day, 0) > 0.06 else { return [] }
        let midnight = day.start(in: calendar)
        var at = midnight.addingTimeInterval((-40 + noise(day, 1) * 80) * 60)
        let woke = midnight.addingTimeInterval((6.6 + noise(day, 2) * 1.1) * 3_600)
        var samples: [SleepSample] = []
        var cycle = 0
        while at < woke {
            let plan: [(SleepSample.Stage, Double)] = [(.asleepCore, 25), (.asleepDeep, cycle < 2 ? 30 : 8), (.asleepCore, 20), (.asleepREM, 12 + Double(cycle) * 6), (.awake, cycle % 2 == 1 ? 4 : 0)]
            for (stage, minutes) in plan where minutes > 0 && at < woke {
                let end = min(woke, at.addingTimeInterval(minutes * (0.8 + noise(day, 10 + cycle) * 0.4) * 60))
                samples.append(SleepSample(start: at, end: end, stage: stage))
                at = end
            }
            cycle += 1
        }
        return samples
    }

    private func hourly(_ day: Day) -> [Int: Int] {
        guard day <= .today() else { return [:] }
        let isToday = day == .today()
        let nowHour = calendar.component(.hour, from: Date())
        let busy = 0.6 + noise(day, 3) * 0.9
        var result: [Int: Int] = [:]
        for hour in 7...22 where !isToday || hour <= nowHour {
            let peak = hour == 8 || hour == 12 || hour == 18 ? 1_600.0 : 350.0
            result[hour] = Int(peak * busy * (0.5 + noise(day, 100 + hour)))
        }
        return result
    }
}
#endif
