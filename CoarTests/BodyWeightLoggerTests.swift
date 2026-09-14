import XCTest
@testable import Coar

/// The log path: a Body Weight entered in the display unit is stored in kilograms
/// (ADR 0004) and written to Apple Health as a body-mass sample; Health never blocks the
/// record.
@MainActor
final class BodyWeightLoggerTests: XCTestCase {

    private let sep13 = Day(year: 2026, month: 9, day: 13)

    func test_bodyWeightEnteredInPounds_isStoredInKilograms() async throws {
        let store = Store.inMemory()
        let logger = BodyWeightLogger(store: store, healthWriter: FakeBodyWeightWriter())

        try await logger.log(185.3, in: .pounds, on: sep13)

        // 185.3 lb is 84.05 kg.
        let record = try XCTUnwrap(store.bodyWeight(on: sep13))
        XCTAssertEqual(record.kilograms, 84.05, accuracy: 0.01)
        XCTAssertEqual(MassUnit.pounds.displayValue(fromKilograms: record.kilograms), 185.3)
    }

    func test_bodyWeightEnteredInKilograms_isStoredAsEntered() async throws {
        let store = Store.inMemory()
        let logger = BodyWeightLogger(store: store, healthWriter: FakeBodyWeightWriter())

        try await logger.log(84.2, in: .kilograms, on: sep13)

        XCTAssertEqual(try store.bodyWeight(on: sep13)?.kilograms, 84.2)
    }

    func test_bodyWeightLogged_isWrittenToAppleHealthInKilogramsForItsDay() async throws {
        let health = FakeBodyWeightWriter()
        let logger = BodyWeightLogger(store: Store.inMemory(), healthWriter: health)

        try await logger.log(84.2, in: .kilograms, on: sep13)

        XCTAssertEqual(health.samples, [.init(kilograms: 84.2, day: sep13)])
    }

    func test_bodyWeightLogged_whenAppleHealthWriteFails_isStillStored() async throws {
        let store = Store.inMemory()
        let health = FakeBodyWeightWriter()
        health.failure = CocoaError(.featureUnsupported)
        let logger = BodyWeightLogger(store: store, healthWriter: health)

        try await logger.log(84.2, in: .kilograms, on: sep13)

        XCTAssertEqual(try store.bodyWeight(on: sep13)?.kilograms, 84.2)
    }
}
