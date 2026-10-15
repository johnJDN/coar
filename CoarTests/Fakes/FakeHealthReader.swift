import Foundation
@testable import Coar

/// Apple Health stands in behind its reader protocol: holds the sleep samples and step
/// counts a device would have, applies the same night rule the live reader does, or fails on
/// demand.
final class FakeHealthReader: HealthReader {

    var sleepSamples: [SleepSample] = []
    var stepsByDay: [Day: Int] = [:]
    var hourlyStepsByDay: [Day: [Int: Int]] = [:]
    var vitals: [VitalSample] = []
    var vo2Max: [DatedValue] = []
    var vitalsAsked = false
    var failure: Error?
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func timeAsleep(wakingOn days: [Day]) async throws -> [Day: TimeInterval] {
        if let failure { throw failure }
        return SleepNight.timeAsleep(wakingOn: days, from: sleepSamples, in: calendar)
    }

    func sleepNights(wakingOn days: [Day]) async throws -> [Day: SleepNightDetail] {
        if let failure { throw failure }
        return SleepNight.details(wakingOn: days, from: sleepSamples, in: calendar)
    }

    func vitalsAccessNeeded() async -> Bool { !vitalsAsked }

    func requestVitalsAccess() async throws { vitalsAsked = true }

    func vitalSamples(from start: Date, to end: Date) async throws -> [VitalSample] {
        if let failure { throw failure }
        return vitals.filter { $0.date >= start && $0.date <= end }
    }

    func cardioFitness(from start: Date, to end: Date) async throws -> [DatedValue] {
        if let failure { throw failure }
        return vo2Max.filter { $0.date >= start && $0.date <= end }
    }

    func hourlySteps(on day: Day) async throws -> [Int: Int] {
        if let failure { throw failure }
        return hourlyStepsByDay[day] ?? [:]
    }

    func steps(on days: [Day]) async throws -> [Day: Int] {
        if let failure { throw failure }
        return stepsByDay.filter { days.contains($0.key) }
    }
}
