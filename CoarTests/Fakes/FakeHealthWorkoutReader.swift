import Foundation
@testable import Coar

/// Apple Health's workouts stand in behind their reader protocol: the Health Workouts a
/// device would hold, read by Day or by identifier, or failing on demand.
final class FakeHealthWorkoutReader: HealthWorkoutReader {

    var workouts: [HealthWorkout] = []
    var failure: Error?
    private(set) var accessRequests = 0
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func requestWorkoutAccess() async throws {
        accessRequests += 1
        if let failure { throw failure }
    }

    func healthWorkouts(on day: Day) async throws -> [HealthWorkout] {
        if let failure { throw failure }
        return workouts.filter { Day($0.start, in: calendar) == day }.sorted { $0.start < $1.start }
    }

    func healthWorkouts(withIDs ids: [UUID]) async throws -> [UUID: HealthWorkout] {
        if let failure { throw failure }
        return Dictionary(workouts.filter { ids.contains($0.id) }.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
