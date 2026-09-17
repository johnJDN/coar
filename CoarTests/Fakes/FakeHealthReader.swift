import Foundation
@testable import Coar

/// Apple Health stands in behind its reader protocol: holds the sleep samples and step
/// counts a device would have, applies the same night rule the live reader does, or fails on
/// demand.
final class FakeHealthReader: HealthReader {

    var sleepSamples: [SleepSample] = []
    var stepsByDay: [Day: Int] = [:]
    var failure: Error?
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func timeAsleep(wakingOn days: [Day]) async throws -> [Day: TimeInterval] {
        if let failure { throw failure }
        return SleepNight.timeAsleep(wakingOn: days, from: sleepSamples, in: calendar)
    }

    func steps(on days: [Day]) async throws -> [Day: Int] {
        if let failure { throw failure }
        return stepsByDay.filter { days.contains($0.key) }
    }
}
