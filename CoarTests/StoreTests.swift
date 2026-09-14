import XCTest
@testable import Coar

/// Seam 1: the store façade over an in-memory container (same model, no CloudKit).
@MainActor
final class StoreTests: XCTestCase {

    func test_bodyWeightLoggedThroughFacade_readsBackOnItsDayWithModifiedAtStamped() throws {
        let store = Store.inMemory()
        let day = Day(year: 2026, month: 9, day: 13)
        let before = Date()

        try store.logBodyWeight(kilograms: 84.2, on: day)

        let record = try XCTUnwrap(store.bodyWeight(on: day))
        XCTAssertEqual(record.day, day)
        XCTAssertEqual(record.kilograms, 84.2)
        XCTAssertGreaterThanOrEqual(record.modifiedAt, before)
        XCTAssertNil(try store.bodyWeight(on: Day(year: 2026, month: 9, day: 12)))
    }
}
