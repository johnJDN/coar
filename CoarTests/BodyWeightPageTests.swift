import XCTest
@testable import Coar

/// The weight page's rules (`.scratch/health-pages/`): how fast Trend Weight moves, where it
/// stands against the Goal Weight, the Goal Weight itself, and removing a weigh-in.
@MainActor
final class BodyWeightPageTests: XCTestCase {

    private let oct1 = Day(year: 2026, month: 10, day: 1)
    private let noon = Date(timeIntervalSince1970: 1_789_300_000)

    private func records(_ kilograms: [Double], every step: Int = 1) -> [BodyWeightRecord] {
        kilograms.enumerated().map { BodyWeightRecord(day: oct1.advanced(by: $0.offset * step), kilograms: $0.element, modifiedAt: noon) }
    }

    func test_weeklyRate_followsTheTrendOverFourWeeks() throws {
        // Steady loss of 0.1 kg a day for 8 weeks: the trend lags but moves 0.7 kg a week.
        let series = records((0..<57).map { 90 - Double($0) * 0.1 })

        let rate = try XCTUnwrap(TrendWeight.weeklyRate(of: series))

        XCTAssertEqual(rate, -0.7, accuracy: 0.05)
    }

    func test_weeklyRate_needsTwoWeeks() {
        XCTAssertNil(TrendWeight.weeklyRate(of: records([90, 89.8, 89.7], every: 6)))
        XCTAssertNotNil(TrendWeight.weeklyRate(of: records([90, 89.8, 89.7], every: 7)))
    }

    func test_progress_againstTheGoal() {
        XCTAssertEqual(TrendWeight.progress(trend: 84, goal: 80, weeklyRate: -0.5), .toward(weeks: 8))
        XCTAssertEqual(TrendWeight.progress(trend: 84, goal: 80, weeklyRate: 0.2), .away)
        XCTAssertEqual(TrendWeight.progress(trend: 84, goal: 80, weeklyRate: 0.01), .steady)
        XCTAssertEqual(TrendWeight.progress(trend: 84, goal: 80, weeklyRate: nil), .unknown)
        XCTAssertEqual(TrendWeight.progress(trend: 80.1, goal: 80, weeklyRate: -0.5), .reached)
        XCTAssertEqual(TrendWeight.progress(trend: 70, goal: 75, weeklyRate: 0.25), .toward(weeks: 20), "a gaining goal works the same way")
    }

    func test_goalWeight_setsChangesAndClears() throws {
        let store = Store.inMemory()
        XCTAssertNil(try store.goalWeight())

        try store.setGoalWeight(kilograms: 80)
        try store.setGoalWeight(kilograms: 78)
        XCTAssertEqual(try store.goalWeight(), 78)

        try store.setGoalWeight(kilograms: nil)
        XCTAssertNil(try store.goalWeight())
    }

    func test_deletingAWeighIn_removesItFromTheStoreAndAppleHealth_only() async throws {
        let store = Store.inMemory()
        let health = FakeBodyWeightWriter()
        let logger = BodyWeightLogger(store: store, healthWriter: health)
        try await logger.log(84.2, in: .kilograms, on: oct1)
        try await logger.log(84.0, in: .kilograms, on: oct1.advanced(by: 1))

        try await logger.delete(on: oct1)

        XCTAssertEqual(try store.bodyWeights().map(\.day), [oct1.advanced(by: 1)])
        XCTAssertEqual(health.deletedDays, [oct1])
        XCTAssertEqual(health.samples.map(\.day), [oct1.advanced(by: 1)])
    }

    func test_logging_tellsTheScreenOnceStored_beforeAppleHealth() async throws {
        let store = Store.inMemory()
        let health = FakeBodyWeightWriter()
        var storedFirst = false
        try await BodyWeightLogger(store: store, healthWriter: health).log(84.2, in: .kilograms, on: oct1, stored: {
            storedFirst = (try? store.bodyWeight(on: oct1)) != nil && health.samples.isEmpty
        })
        XCTAssertTrue(storedFirst)
    }
}
