import XCTest
@testable import Coar

/// Seam 1: the store façade. A Progress Photo is a Day-keyed record whose bytes are an
/// external-binary attribute (CONTEXT.md "Progress Photo"; ADRs 0002 and 0005), and the
/// compare screen captions each one with the Body Weight on the nearest Day.
@MainActor
final class ProgressPhotoTests: XCTestCase {

    private let sep01 = Day(year: 2026, month: 9, day: 1)
    private let sep10 = Day(year: 2026, month: 9, day: 10)
    private let sep12 = Day(year: 2026, month: 9, day: 12)
    private let sep13 = Day(year: 2026, month: 9, day: 13)
    private let sep14 = Day(year: 2026, month: 9, day: 14)
    private let sep15 = Day(year: 2026, month: 9, day: 15)
    private let sep30 = Day(year: 2026, month: 9, day: 30)

    private let image = Data("full-size jpeg bytes".utf8)
    private let thumbnail = Data("thumbnail jpeg bytes".utf8)

    // MARK: - Day-keying

    func test_progressPhotoAddedLateEveningInOneZone_keepsItsDayWhenReadInAnother() throws {
        let store = Store.inMemory()
        let losAngeles = Self.calendar(in: "America/Los_Angeles")
        let tokyo = Self.calendar(in: "Asia/Tokyo")
        let lateEvening = losAngeles.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 23, minute: 30))!
        // The same instant is already 14 September in Tokyo.
        XCTAssertEqual(Day(lateEvening, in: tokyo), sep14)

        let added = try store.addProgressPhoto(image: image, thumbnail: thumbnail, on: Day(lateEvening, in: losAngeles))

        XCTAssertEqual(added.day, sep13)
        XCTAssertEqual(try store.progressPhotos().map(\.day), [sep13])
    }

    func test_progressPhotos_areNewestFirst() throws {
        let store = Store.inMemory()
        try store.addProgressPhoto(image: image, thumbnail: thumbnail, on: sep12)
        try store.addProgressPhoto(image: image, thumbnail: thumbnail, on: sep15)
        try store.addProgressPhoto(image: image, thumbnail: thumbnail, on: sep10)

        XCTAssertEqual(try store.progressPhotos().map(\.day), [sep15, sep12, sep10])
    }

    func test_progressPhotos_withNothingAdded_isEmpty() throws {
        XCTAssertEqual(try Store.inMemory().progressPhotos(), [])
    }

    func test_progressPhotoCount_countsWhatIsStored() throws {
        let store = Store.inMemory()
        XCTAssertEqual(try store.progressPhotoCount(), 0)
        try store.addProgressPhoto(image: image, thumbnail: thumbnail, on: sep12)
        try store.addProgressPhoto(image: image, thumbnail: thumbnail, on: sep12)

        XCTAssertEqual(try store.progressPhotoCount(), 2)
    }

    // MARK: - Bytes

    func test_progressPhotoImageAndThumbnail_readBackTheBytesThatWereStored() throws {
        let store = Store.inMemory()
        let added = try store.addProgressPhoto(image: image, thumbnail: thumbnail, on: sep13)

        XCTAssertEqual(try store.progressPhotoImage(added.id), image)
        XCTAssertEqual(try store.progressPhotoThumbnail(added.id), thumbnail)
    }

    func test_deleteProgressPhoto_removesItAndItsBytes() throws {
        let store = Store.inMemory()
        let kept = try store.addProgressPhoto(image: image, thumbnail: thumbnail, on: sep12)
        let deleted = try store.addProgressPhoto(image: image, thumbnail: thumbnail, on: sep13)

        try store.deleteProgressPhoto(deleted.id)

        XCTAssertEqual(try store.progressPhotos().map(\.id), [kept.id])
        XCTAssertNil(try store.progressPhotoImage(deleted.id))
    }

    // MARK: - Nearest Body Weight

    func test_bodyWeightNearest_picksTheClosestDayOnEitherSide() throws {
        let store = Store.inMemory()
        try store.logBodyWeight(kilograms: 84.0, on: sep10)
        try store.logBodyWeight(kilograms: 83.0, on: sep15)

        XCTAssertEqual(try store.bodyWeight(nearest: sep12)?.day, sep10)
        XCTAssertEqual(try store.bodyWeight(nearest: sep14)?.day, sep15)
        XCTAssertEqual(try store.bodyWeight(nearest: sep15)?.day, sep15)
        XCTAssertEqual(try store.bodyWeight(nearest: sep01)?.day, sep10)
        XCTAssertEqual(try store.bodyWeight(nearest: sep30)?.day, sep15)
    }

    func test_bodyWeightNearest_whenTwoDaysAreEquallyClose_picksTheEarlier() throws {
        let store = Store.inMemory()
        try store.logBodyWeight(kilograms: 84.0, on: sep10)
        try store.logBodyWeight(kilograms: 83.0, on: sep14)

        XCTAssertEqual(try store.bodyWeight(nearest: sep12)?.day, sep10)
    }

    func test_bodyWeightNearest_withNothingLogged_isNil() throws {
        XCTAssertNil(try Store.inMemory().bodyWeight(nearest: sep12))
    }

    private static func calendar(in zone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar
    }
}
