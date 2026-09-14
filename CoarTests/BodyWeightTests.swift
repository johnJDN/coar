import XCTest
@testable import Coar

/// Seam 1: the store façade. Body Weight is the first one-per-Day, Day-keyed, kg-canonical
/// record (CONTEXT.md "Body Weight"; ADRs 0004 and 0005).
@MainActor
final class BodyWeightTests: XCTestCase {

    private let sep11 = Day(year: 2026, month: 9, day: 11)
    private let sep12 = Day(year: 2026, month: 9, day: 12)
    private let sep13 = Day(year: 2026, month: 9, day: 13)

    func test_bodyWeightLoggedLateEveningInOneZone_keepsItsDayWhenReadInAnother() throws {
        let store = Store.inMemory()
        let losAngeles = Self.calendar(in: "America/Los_Angeles")
        let tokyo = Self.calendar(in: "Asia/Tokyo")
        let lateEvening = losAngeles.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 23, minute: 30))!
        // The same instant is already 14 September in Tokyo.
        XCTAssertEqual(Day(lateEvening, in: tokyo), Day(year: 2026, month: 9, day: 14))

        try store.logBodyWeight(kilograms: 84.2, on: Day(lateEvening, in: losAngeles))

        XCTAssertEqual(try store.bodyWeights().map(\.day), [sep13])
        XCTAssertEqual(try store.bodyWeight(on: sep13)?.kilograms, 84.2)
        XCTAssertNil(try store.bodyWeight(on: Day(lateEvening, in: tokyo)))
    }

    func test_loggingBodyWeightTwiceOnOneDay_replacesThatDaysValue() throws {
        let store = Store.inMemory()
        try store.logBodyWeight(kilograms: 84.2, on: sep13)

        try store.logBodyWeight(kilograms: 83.9, on: sep13)

        XCTAssertEqual(try store.bodyWeights().map(\.kilograms), [83.9])
        XCTAssertEqual(try store.bodyWeight(on: sep13)?.kilograms, 83.9)
    }

    func test_bodyWeights_areReturnedInDayOrderRegardlessOfLoggingOrder() throws {
        let store = Store.inMemory()
        try store.logBodyWeight(kilograms: 84.2, on: sep13)
        try store.logBodyWeight(kilograms: 84.6, on: sep11)
        try store.logBodyWeight(kilograms: 84.4, on: sep12)

        XCTAssertEqual(try store.bodyWeights().map(\.day), [sep11, sep12, sep13])
    }

    func test_bodyWeights_withNothingLogged_isEmpty() throws {
        XCTAssertEqual(try Store.inMemory().bodyWeights(), [])
    }

    private static func calendar(in zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }
}
