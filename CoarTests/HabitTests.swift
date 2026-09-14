import XCTest
@testable import Coar

/// Seam 1: the store façade. A Habit has at most one Check-in per Day (writes replace,
/// toggling off deletes); archiving hides it from the active list while its history
/// survives; deleting permanently takes the Check-ins with it (CONTEXT.md "Habit",
/// "Check-in", "Archived").
@MainActor
final class HabitTests: XCTestCase {

    private let sep11 = Day(year: 2026, month: 9, day: 11)
    private let sep12 = Day(year: 2026, month: 9, day: 12)
    private let sep13 = Day(year: 2026, month: 9, day: 13)

    private func makeHabit(_ store: Store, _ name: String = "No phone on waking", emoji: String = "📵") throws -> HabitRecord {
        try store.createHabit(emoji: emoji, name: name, kind: .yesNo, targetAmount: 1, period: .day, effectiveFrom: sep11)
    }

    // MARK: Check-ins

    func test_checkIn_readsBackForThatHabitOnThatDay() throws {
        let store = Store.inMemory()
        let habit = try makeHabit(store)

        try store.checkIn(habit.id, on: sep13, amount: 1)

        XCTAssertEqual(try store.checkIns(for: habit.id).map(\.day), [sep13])
        XCTAssertEqual(try store.checkIns(for: habit.id).map(\.amount), [1])
        XCTAssertEqual(try store.checkIn(habit.id, on: sep13)?.amount, 1)
        XCTAssertNil(try store.checkIn(habit.id, on: sep12))
    }

    func test_checkingInTwiceOnOneDay_replacesThatDaysCheckIn() throws {
        let store = Store.inMemory()
        let habit = try makeHabit(store)
        try store.checkIn(habit.id, on: sep13, amount: 1)

        try store.checkIn(habit.id, on: sep13, amount: 3)

        XCTAssertEqual(try store.checkIns(for: habit.id).map(\.amount), [3])
    }

    func test_removingACheckIn_deletesOnlyThatDay() throws {
        let store = Store.inMemory()
        let habit = try makeHabit(store)
        try store.checkIn(habit.id, on: sep12, amount: 1)
        try store.checkIn(habit.id, on: sep13, amount: 1)

        try store.removeCheckIn(habit.id, on: sep13)

        XCTAssertEqual(try store.checkIns(for: habit.id).map(\.day), [sep12])
        XCTAssertNil(try store.checkIn(habit.id, on: sep13))
    }

    func test_removingACheckInThatDoesNotExist_isANoOp() throws {
        let store = Store.inMemory()
        let habit = try makeHabit(store)

        try store.removeCheckIn(habit.id, on: sep13)

        XCTAssertEqual(try store.checkIns(for: habit.id), [])
    }

    func test_checkIns_areReturnedInDayOrderAndScopedToTheirHabit() throws {
        let store = Store.inMemory()
        let phone = try makeHabit(store)
        let reading = try makeHabit(store, "Read", emoji: "📚")
        try store.checkIn(phone.id, on: sep13, amount: 1)
        try store.checkIn(phone.id, on: sep11, amount: 1)
        try store.checkIn(reading.id, on: sep12, amount: 1)

        XCTAssertEqual(try store.checkIns(for: phone.id).map(\.day), [sep11, sep13])
        XCTAssertEqual(try store.checkIns(for: reading.id).map(\.day), [sep12])
    }

    // MARK: Habits

    func test_newHabit_carriesItsFieldsAndTheTargetInForce() throws {
        let store = Store.inMemory()

        let habit = try makeHabit(store)

        let read = try XCTUnwrap(store.habit(habit.id))
        XCTAssertEqual(read.emoji, "📵")
        XCTAssertEqual(read.name, "No phone on waking")
        XCTAssertEqual(read.kind, .yesNo)
        XCTAssertFalse(read.isArchived)
        XCTAssertEqual(read.target, HabitTargetRecord(amount: 1, period: .day, effectiveFrom: sep11))
    }

    func test_newHabits_listAfterExistingOnes() throws {
        let store = Store.inMemory()
        let phone = try makeHabit(store)
        let reading = try makeHabit(store, "Read", emoji: "📚")

        XCTAssertEqual(try store.habits().map(\.id), [phone.id, reading.id])
    }

    func test_reorder_persistsTheGivenOrder() throws {
        let store = Store.inMemory()
        let phone = try makeHabit(store)
        let reading = try makeHabit(store, "Read", emoji: "📚")
        let water = try makeHabit(store, "Water", emoji: "💧")

        try store.reorderHabits([water.id, phone.id, reading.id])

        XCTAssertEqual(try store.habits().map(\.name), ["Water", "No phone on waking", "Read"])
    }

    // MARK: Archive

    func test_archivedHabit_leavesTheActiveList_keepsItsCheckIns_andRestoresToTheEnd() throws {
        let store = Store.inMemory()
        let habit = try makeHabit(store)
        let reading = try makeHabit(store, "Read", emoji: "📚")
        try store.checkIn(habit.id, on: sep13, amount: 1)

        try store.archiveHabit(habit.id)

        XCTAssertEqual(try store.habits().map(\.id), [reading.id])
        XCTAssertEqual(try store.archivedHabits().map(\.id), [habit.id])
        XCTAssertEqual(try store.checkIns(for: habit.id).map(\.day), [sep13])

        try store.restoreHabit(habit.id)

        XCTAssertEqual(try store.habits().map(\.id), [reading.id, habit.id])
        XCTAssertEqual(try store.archivedHabits(), [])
    }

    func test_deletingPermanently_removesTheHabitAndItsCheckIns() throws {
        let store = Store.inMemory()
        let habit = try makeHabit(store)
        let other = try makeHabit(store, "Read", emoji: "📚")
        try store.checkIn(habit.id, on: sep13, amount: 1)
        try store.checkIn(other.id, on: sep13, amount: 1)
        try store.archiveHabit(habit.id)

        try store.deleteHabitPermanently(habit.id)

        XCTAssertNil(try store.habit(habit.id))
        XCTAssertEqual(try store.archivedHabits(), [])
        XCTAssertEqual(try store.checkIns(for: habit.id), [])
        XCTAssertEqual(try store.checkIns(for: other.id).map(\.day), [sep13])
    }
}
