import Foundation

/// One sleep-analysis sample as Apple Health records it: a span and the stage it was in.
struct SleepSample: Equatable {
    enum Stage: Equatable {
        case inBed, awake, asleepUnspecified, asleepCore, asleepDeep, asleepREM

        /// The stages that count as time asleep; awake and in-bed do not.
        var isAsleep: Bool {
            switch self {
            case .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM: return true
            case .inBed, .awake: return false
            }
        }
    }

    let start: Date
    let end: Date
    let stage: Stage
}

/// The one Apple Health reader: sleep for the night ending on a wake Day and steps for a Day,
/// each read live for any set of Days (the details ask for 30) and never persisted
/// (ADR 0002). A Day missing from the result has no data. Faked in tests.
protocol HealthReader: AnyObject {
    /// Seconds asleep per wake Day, for the Days that have any asleep sample.
    func timeAsleep(wakingOn days: [Day]) async throws -> [Day: TimeInterval]
    /// Steps per Day, for the Days that have any.
    func steps(on days: [Day]) async throws -> [Day: Int]
}

extension HealthReader {
    /// Seconds asleep in the night that ended on `day`; nil when there is no data.
    func timeAsleep(wakingOn day: Day) async throws -> TimeInterval? {
        try await timeAsleep(wakingOn: [day])[day]
    }

    /// Steps on `day`; nil when there is no data.
    func steps(on day: Day) async throws -> Int? {
        try await steps(on: [day])[day]
    }
}
