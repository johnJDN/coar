import XCTest
@testable import Coar

/// Copying Entries to another time or Day (`.scratch/food-logging/issues/03`).
@MainActor
final class CopyEntriesTests: XCTestCase {

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    private let monday = Day(year: 2026, month: 10, day: 26)
    private let thursday = Day(year: 2026, month: 10, day: 29)

    private func at(_ day: Day, _ hour: Int, _ minute: Int = 0) -> Date {
        Self.calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day.start(in: Self.calendar))!
    }

    func test_copies_landAtTheChosenTime_withTheSameSnapshotAndFoodLink_andTheOriginalsStay() throws {
        let store = Store.inMemory()
        let eggs = try store.createFoodItem(name: "Eggs", servings: [ServingDraft(name: "1 egg", macros: Macros(calories: 70, protein: 6, fat: 5, carbs: 0), isDefault: true)])
        let egg = try store.logEntry(foodItem: eggs.id, serving: try XCTUnwrap(eggs.defaultServing).id, quantity: 2, at: at(monday, 8), in: Self.calendar)
        let toast = try store.logEntry(name: "Toast", servingName: "slice", quantity: 1, macros: Macros(calories: 90, protein: 3, fat: 1, carbs: 17), at: at(monday, 8, 5), in: Self.calendar)

        let copies = try store.copyEntries([egg, toast], to: at(thursday, 13), keepingTimes: false, in: Self.calendar)

        XCTAssertEqual(copies.map(\.name), ["Eggs", "Toast"])
        XCTAssertEqual(copies.map(\.day), [thursday, thursday])
        XCTAssertEqual(copies.map(\.loggedAt), [at(thursday, 13), at(thursday, 13)])
        XCTAssertEqual(copies[0].macros, egg.macros)
        XCTAssertEqual(copies[0].quantity, 2)
        XCTAssertEqual(copies[0].foodItemID, eggs.id)
        XCTAssertNotEqual(copies[0].id, egg.id)
        XCTAssertEqual(try store.entries(on: monday).count, 2)
    }

    func test_keepingTimes_putsEachAtItsOwnTimeOnTheNewDay() throws {
        let store = Store.inMemory()
        let macros = Macros(calories: 100, protein: 1, fat: 1, carbs: 1)
        let breakfast = try store.logEntry(name: "Oats", servingName: "bowl", quantity: 1, macros: macros, at: at(monday, 8, 30), in: Self.calendar)
        let dinner = try store.logEntry(name: "Rice", servingName: "cup", quantity: 1, macros: macros, at: at(monday, 19, 15), in: Self.calendar)

        let copies = try store.copyEntries([breakfast, dinner], to: at(thursday, 12), keepingTimes: true, in: Self.calendar)

        XCTAssertEqual(copies.map(\.loggedAt), [at(thursday, 8, 30), at(thursday, 19, 15)])
    }
}
