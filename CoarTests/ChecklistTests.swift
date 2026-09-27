import XCTest
@testable import Coar

/// A checklist Habit (CONTEXT.md "Item"): Items ticked one by one. Seam 1 covers the store
/// (a daily list per Day, a weekly list where an Item counts once a week, editing the list
/// without losing history); seam 2 covers the rules (the goal following the list, the card
/// counting each Item once a week).
@MainActor
final class ChecklistTests: XCTestCase {

    private let monday7 = Day(year: 2026, month: 9, day: 7)
    private let wednesday9 = Day(year: 2026, month: 9, day: 9)
    private let thursday10 = Day(year: 2026, month: 9, day: 10)
    private let sunday13 = Day(year: 2026, month: 9, day: 13)

    private func makeList(_ store: Store, period: HabitPeriod, names: [String], goal: Double? = nil) throws -> HabitRecord {
        try store.createHabit(
            emoji: "💊", name: "Supplements", kind: .checklist,
            targetAmount: goal ?? Double(names.count), period: period,
            items: names.map { HabitItemDraft(name: $0) }, effectiveFrom: monday7
        )
    }

    // MARK: Store

    func test_createdList_keepsItsItemsInOrder_withoutBlankOnes() throws {
        let store = Store.inMemory()
        let habit = try makeList(store, period: .day, names: ["Vitamin D", " ", "Fish oil", "Magnesium"])

        XCTAssertEqual(try store.habit(habit.id)?.items.map(\.name), ["Vitamin D", "Fish oil", "Magnesium"])
    }

    func test_dailyTicks_landOnTheirDay_andTheLastUntickRemovesTheCheckIn() throws {
        let store = Store.inMemory()
        let habit = try makeList(store, period: .day, names: ["Vitamin D", "Fish oil"])
        let (d, fish) = (habit.items[0].id, habit.items[1].id)

        try store.setChecklistItem(habit.id, item: d, on: thursday10, ticked: true)
        try store.setChecklistItem(habit.id, item: fish, on: thursday10, ticked: true)
        XCTAssertEqual(try store.checkIn(habit.id, on: thursday10)?.itemIDs, [d, fish])
        XCTAssertEqual(try store.checkIn(habit.id, on: thursday10)?.amount, 2)
        XCTAssertNil(try store.checkIn(habit.id, on: wednesday9))

        try store.setChecklistItem(habit.id, item: d, on: thursday10, ticked: false)
        XCTAssertEqual(try store.checkIn(habit.id, on: thursday10)?.amount, 1)
        try store.setChecklistItem(habit.id, item: fish, on: thursday10, ticked: false)
        XCTAssertNil(try store.checkIn(habit.id, on: thursday10))
    }

    func test_weeklyList_countsAnItemOncePerWeek_andUntickingClearsItFromTheWeek() throws {
        let store = Store.inMemory()
        let habit = try makeList(store, period: .week, names: ["Alex", "Sam"])
        let alex = habit.items[0].id

        try store.setChecklistItem(habit.id, item: alex, on: monday7, ticked: true)
        try store.setChecklistItem(habit.id, item: alex, on: wednesday9, ticked: true)
        XCTAssertEqual(try store.checkIns(for: habit.id).map(\.day), [monday7])

        try store.setChecklistItem(habit.id, item: alex, on: thursday10, ticked: false)
        XCTAssertEqual(try store.checkIns(for: habit.id), [])
    }

    func test_editingTheList_keepsIdsAndHistory_andTheGoalFollowsAnAllItemsList() throws {
        let store = Store.inMemory()
        let habit = try makeList(store, period: .week, names: ["Alex", "Sam", "Jo"])
        let (alex, sam) = (habit.items[0], habit.items[1])
        try store.setChecklistItem(habit.id, item: sam.id, on: monday7, ticked: true)

        try store.setHabitItems(habit.id, items: [
            HabitItemDraft(id: alex.id, name: "Alex R"),
            HabitItemDraft(id: habit.items[2].id, name: "Jo"),
            HabitItemDraft(name: "Kim"),
            HabitItemDraft(name: "Lee"),
        ], effectiveFrom: thursday10)

        let edited = try XCTUnwrap(store.habit(habit.id))
        XCTAssertEqual(edited.items.map(\.name), ["Alex R", "Jo", "Kim", "Lee"])
        XCTAssertEqual(edited.items[0].id, alex.id)
        XCTAssertEqual(try store.checkIn(habit.id, on: monday7)?.itemIDs, [sam.id])
        XCTAssertEqual(edited.target(inForceOn: thursday10)?.amount, 4)
        XCTAssertEqual(edited.target(inForceOn: wednesday9)?.amount, 3)
    }

    func test_editingTheList_toNothing_writesNothing() throws {
        let store = Store.inMemory()
        let habit = try makeList(store, period: .day, names: ["Vitamin D"])

        try store.setHabitItems(habit.id, items: [HabitItemDraft(name: "  ")])

        XCTAssertEqual(try store.habit(habit.id)?.items.map(\.name), ["Vitamin D"])
    }

    // MARK: Rules

    func test_goal_followsAnAllItemsList_keepsASmallerOne_andCapsIt() {
        XCTAssertEqual(Checklist.goal(current: 3, oldCount: 3, newCount: 5), 5)
        XCTAssertNil(Checklist.goal(current: 2, oldCount: 5, newCount: 6))
        XCTAssertEqual(Checklist.goal(current: 4, oldCount: 6, newCount: 3), 3)
        XCTAssertNil(Checklist.goal(current: 3, oldCount: 3, newCount: 0))
    }

    func test_card_countsAWeeklyItemOnce_andMeetsTheWeekOnceEveryItemIsTicked() {
        let alex = HabitItemRecord(id: UUID(), name: "Alex")
        let sam = HabitItemRecord(id: UUID(), name: "Sam")
        let habit = HabitRecord(
            id: UUID(), emoji: "💬", name: "Text friends", kind: .checklist, isArchived: false, sortOrder: 0,
            targets: [HabitTargetRecord(amount: 2, period: .week, effectiveFrom: monday7)],
            items: [alex, sam], modifiedAt: Date()
        )
        let alexTwice = [
            CheckInRecord(day: monday7, amount: 1, modifiedAt: Date(), itemIDs: [alex.id]),
            CheckInRecord(day: wednesday9, amount: 1, modifiedAt: Date(), itemIDs: [alex.id]),
        ]

        let halfway = HabitCardModel(habit: habit, checkIns: alexTwice, today: thursday10)
        XCTAssertEqual(halfway.tickedItemCount, 1)
        XCTAssertEqual(halfway.itemCount, 2)
        XCTAssertFalse(halfway.isDoneToday)
        XCTAssertEqual(halfway.weekCaption, "1 of 2 this week")

        let done = HabitCardModel(habit: habit, checkIns: alexTwice + [CheckInRecord(day: thursday10, amount: 1, modifiedAt: Date(), itemIDs: [sam.id])], today: sunday13)
        XCTAssertTrue(done.isDoneToday)
        XCTAssertEqual(done.streak, 1)
    }

    func test_card_meetsADailyListOnlyWhenItsGoalIsTicked() {
        let items = (0..<3).map { HabitItemRecord(id: UUID(), name: "Pill \($0)") }
        let habit = HabitRecord(
            id: UUID(), emoji: "💊", name: "Supplements", kind: .checklist, isArchived: false, sortOrder: 0,
            targets: [HabitTargetRecord(amount: 3, period: .day, effectiveFrom: monday7)],
            items: items, modifiedAt: Date()
        )
        let two = [CheckInRecord(day: thursday10, amount: 2, modifiedAt: Date(), itemIDs: Set(items.prefix(2).map(\.id)))]
        XCTAssertFalse(HabitCardModel(habit: habit, checkIns: two, today: thursday10).isDoneToday)
        XCTAssertEqual(HabitCardModel(habit: habit, checkIns: two, today: thursday10).tickedItemCount, 2)

        let three = [CheckInRecord(day: thursday10, amount: 3, modifiedAt: Date(), itemIDs: Set(items.map(\.id)))]
        XCTAssertTrue(HabitCardModel(habit: habit, checkIns: three, today: thursday10).isDoneToday)
        XCTAssertEqual(HabitCardModel(habit: habit, checkIns: three, today: thursday10).tickedItemCount, 3)
    }

    func test_checklistGoal_emptyMeansEveryItem_andMustBeAWholeNumberWithinTheList() {
        var draft = HabitTargetDraft(kind: .checklist, period: .week, typedAmount: nil, itemCount: 5)
        XCTAssertEqual(draft.amount, 5)
        draft.typedAmount = 3
        XCTAssertEqual(draft.amount, 3)
        draft.typedAmount = 6
        XCTAssertNil(draft.amount)
        draft.typedAmount = 2.5
        XCTAssertNil(draft.amount)
        draft = HabitTargetDraft(kind: .checklist, period: .day, typedAmount: nil, itemCount: 0)
        XCTAssertNil(draft.amount)
    }
}
