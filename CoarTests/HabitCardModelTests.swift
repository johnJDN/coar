import XCTest
@testable import Coar

/// Seam 2: pure rule functions. Everything a habit card shows is derived from the Habit's
/// dated target series and its Check-ins (ADR 0003): each Day is judged against the target
/// in force on it, each week against the target in force on its Sunday, and the Streak is
/// counted in the Period in force today.
final class HabitCardModelTests: XCTestCase {

    private let sep1 = Day(year: 2026, month: 9, day: 1)
    private let thursday10 = Day(year: 2026, month: 9, day: 10)
    private let sunday13 = Day(year: 2026, month: 9, day: 13)

    private func habit(kind: HabitKind = .yesNo, targets: [HabitTargetRecord]) -> HabitRecord {
        HabitRecord(id: UUID(), emoji: "🏋️", name: "Gym", kind: kind, isArchived: false, sortOrder: 0, targets: targets, modifiedAt: Date())
    }

    private func checkIns(_ days: [Day], amount: Double = 1) -> [CheckInRecord] {
        days.map { CheckInRecord(day: $0, amount: amount, modifiedAt: Date()) }
    }

    private func days(_ numbers: ClosedRange<Int>) -> [Day] {
        numbers.map { Day(year: 2026, month: 9, day: $0) }
    }

    // MARK: Period seam

    func test_switchingFromDayToWeek_countsTheStreakInWeeksFromTheWeekOfTheSwitch() {
        let habit = habit(targets: [
            HabitTargetRecord(amount: 1, period: .day, effectiveFrom: sep1),
            HabitTargetRecord(amount: 3, period: .week, effectiveFrom: thursday10),
        ])
        let everyDay = checkIns(days(1...13))

        let before = HabitCardModel(habit: habit, checkIns: everyDay, today: Day(year: 2026, month: 9, day: 9))
        XCTAssertEqual(before.streak, 9)
        XCTAssertEqual(before.streakUnit, "days")

        let after = HabitCardModel(habit: habit, checkIns: everyDay, today: sunday13)
        XCTAssertEqual(after.streak, 1)
        XCTAssertEqual(after.streakUnit, "week")
    }

    func test_weeklyHabit_captionsThisWeeksProgress_andCountsTheCurrentWeekOnceMet() {
        let habit = habit(targets: [HabitTargetRecord(amount: 3, period: .week, effectiveFrom: sep1)])
        let model = HabitCardModel(habit: habit, checkIns: checkIns(days(7...8)), today: thursday10)
        XCTAssertEqual(model.weekCaption, "2 of 3 this week")
        XCTAssertEqual(model.streak, 0)
        XCTAssertFalse(model.isDoneToday)

        let met = HabitCardModel(habit: habit, checkIns: checkIns(days(7...10)), today: thursday10)
        XCTAssertEqual(met.weekCaption, "4 of 3 this week")
        XCTAssertEqual(met.streak, 1)
        XCTAssertTrue(met.isDoneToday)
    }

    func test_dailyHabit_hasNoWeekCaptionAndNoDotRow() {
        let habit = habit(targets: [HabitTargetRecord(amount: 1, period: .day, effectiveFrom: sep1)])
        let model = HabitCardModel(habit: habit, checkIns: [], today: sunday13)
        XCTAssertNil(model.weekCaption)
        XCTAssertNil(model.weekDots)
    }

    func test_weeklyHabit_hasOneDotPerColumn_filledForWeeksThatMetTheTarget() {
        let habit = habit(targets: [HabitTargetRecord(amount: 3, period: .week, effectiveFrom: sep1)])
        let lastWeek = checkIns(days(1...3))
        let model = HabitCardModel(habit: habit, checkIns: lastWeek, today: thursday10, columns: 3)
        XCTAssertEqual(model.weekDots, [false, true, false])
    }

    // MARK: Cells against the target in force

    func test_quantitativeDays_areJudgedAgainstTheTargetInForceOnThatDay() {
        let habit = habit(kind: .quantitative, targets: [
            HabitTargetRecord(amount: 20, period: .day, effectiveFrom: sep1),
            HabitTargetRecord(amount: 40, period: .day, effectiveFrom: thursday10),
        ])
        let twentyEachDay = checkIns([Day(year: 2026, month: 9, day: 9), thursday10], amount: 20)
        let model = HabitCardModel(habit: habit, checkIns: twentyEachDay, today: thursday10)

        XCTAssertEqual(model.levels[Day(year: 2026, month: 9, day: 9)], .done)
        XCTAssertEqual(model.levels[thursday10], .half)
        // Yesterday stays met under the target that applied then; today is pending, not broken.
        XCTAssertEqual(model.streak, 1)
    }

    func test_aDayBeforeTheFirstTarget_isJudgedAgainstIt_andEditable() {
        let habit = habit(kind: .quantitative, targets: [HabitTargetRecord(amount: 20, period: .day, effectiveFrom: thursday10)])
        let model = HabitCardModel(habit: habit, checkIns: checkIns([sep1], amount: 10), today: sunday13)

        XCTAssertEqual(model.levels[sep1], .half)
        XCTAssertTrue(MonthCalendarView.Model(today: sunday13, levels: model.levels, editableFrom: model.editableFrom).isEditable(sep1))
    }

    func test_backfilledDaysBeforeCreation_countTowardTheStreak() {
        let habit = habit(targets: [HabitTargetRecord(amount: 1, period: .day, effectiveFrom: sunday13)])
        let model = HabitCardModel(habit: habit, checkIns: checkIns([Day(year: 2026, month: 9, day: 11), Day(year: 2026, month: 9, day: 12), sunday13]), today: sunday13)
        XCTAssertEqual(model.streak, 3)
    }

    func test_yesNoCells_stayBinaryOnAWeeklyHabit() {
        let habit = habit(targets: [HabitTargetRecord(amount: 3, period: .week, effectiveFrom: sep1)])
        let model = HabitCardModel(habit: habit, checkIns: checkIns([thursday10]), today: thursday10)
        XCTAssertEqual(model.levels[thursday10], .done)
    }

    func test_yesNoDailyHabit_isMetByAnyCheckIn_whateverAmountItsTargetStores() {
        let habit = habit(targets: [HabitTargetRecord(amount: 2, period: .day, effectiveFrom: sep1)])
        let model = HabitCardModel(habit: habit, checkIns: checkIns(days(8...10)), today: thursday10)
        XCTAssertEqual(model.streak, 3)
        XCTAssertTrue(model.isDoneToday)
    }

    func test_quantitativeControl_showsTodaysTotal() {
        let habit = habit(kind: .quantitative, targets: [HabitTargetRecord(amount: 20, period: .day, effectiveFrom: sep1)])
        let model = HabitCardModel(habit: habit, checkIns: checkIns([thursday10], amount: 12), today: thursday10)
        XCTAssertEqual(model.todayAmount, 12)
        XCTAssertFalse(model.isDoneToday)
    }

    // MARK: Quick-add chips

    func test_quickAdds_scaleWithTheTarget() {
        XCTAssertEqual(HabitAmount.quickAdds(target: 20), [1, 5, 10])
        XCTAssertEqual(HabitAmount.quickAdds(target: 100), [10, 50, 100])
        XCTAssertEqual(HabitAmount.quickAdds(target: 5_000), [100, 500, 1_000])
        XCTAssertEqual(HabitAmount.quickAdds(target: 3), [1, 2, 5])
        XCTAssertEqual(HabitAmount.quickAdds(target: nil), [1, 5, 10])
    }

    func test_amountText_dropsTrailingZeros() {
        XCTAssertEqual(HabitAmount.text(20), "20")
        XCTAssertEqual(HabitAmount.text(2.5), "2.5")
        XCTAssertEqual(HabitAmount.text(1_250), "1,250")
    }
}
