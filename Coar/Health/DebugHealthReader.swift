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

    func vitalsAccessNeeded() async -> Bool { false }

    func requestVitalsAccess() async throws {}

    /// A few readings each night (every 90 minutes from 1 AM) and a resting heart rate each
    /// morning; the last night runs a little hot, as after a hard day.
    func vitalSamples(from start: Date, to end: Date) async throws -> [VitalSample] {
        var result: [VitalSample] = []
        var day = Day(start, in: calendar)
        while day <= Day(end, in: calendar), day <= .today() {
            let strain = day == .today() ? 1.0 : 0.0
            let midnight = day.start(in: calendar)
            for hour in [1.0, 2.5, 4.0, 5.5] {
                let at = midnight.addingTimeInterval(hour * 3_600)
                result.append(VitalSample(vital: .hrv, date: at, value: 42 + noise(day, 20) * 14 - strain * 14))
                result.append(VitalSample(vital: .recoveryHRV, date: at, value: 55 + noise(day, 21) * 16 - strain * 18))
                result.append(VitalSample(vital: .respiratoryRate, date: at, value: 14 + noise(day, 22) * 1.2 + strain * 1.5))
                result.append(VitalSample(vital: .bloodOxygen, date: at, value: 95.5 + noise(day, 23) * 2.5))
            }
            result.append(VitalSample(vital: .restingHeartRate, date: midnight.addingTimeInterval(9 * 3_600), value: 50 + noise(day, 24) * 4 + strain * 6))
            day = day.advanced(by: 1)
        }
        return result.filter { $0.date >= start && $0.date <= end }
    }

    /// An estimate every week or so, creeping up over the year.
    func cardioFitness(from start: Date, to end: Date) async throws -> [DatedValue] {
        var result: [DatedValue] = []
        var day = Day(start, in: calendar)
        var index = 0.0
        while day <= Day(end, in: calendar), day <= .today() {
            if noise(day, 30) < 0.15 {
                result.append(DatedValue(date: day.start(in: calendar).addingTimeInterval(8 * 3_600), value: 39 + index * 0.012 + noise(day, 31) * 1.2))
            }
            index += 1
            day = day.advanced(by: 1)
        }
        return result
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
