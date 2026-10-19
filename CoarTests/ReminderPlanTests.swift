import XCTest
@testable import Coar

/// The nightly reminder's plan (`.scratch/reminders/issues/01`): the next 7 Days at the chosen
/// time, today only while that's ahead and the Day isn't logged.
final class ReminderPlanTests: XCTestCase {

    private let oct18 = Day(year: 2026, month: 10, day: 18)

    private func at(_ hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: oct18.start())!
    }

    func test_beforeNine_andNotLogged_remindsTonightAndTheNextSixNights() {
        let days = ReminderPlan.days(today: oct18, now: at(14), minuteOfDay: 21 * 60, todayLogged: false)
        XCTAssertEqual(days.first, oct18)
        XCTAssertEqual(days.count, 7)
    }

    func test_aLoggedDay_orOnePastTheTime_startsTomorrow() {
        XCTAssertEqual(ReminderPlan.days(today: oct18, now: at(14), minuteOfDay: 21 * 60, todayLogged: true).first, oct18.advanced(by: 1))
        XCTAssertEqual(ReminderPlan.days(today: oct18, now: at(22), minuteOfDay: 21 * 60, todayLogged: false).first, oct18.advanced(by: 1))
        XCTAssertEqual(ReminderPlan.days(today: oct18, now: at(22), minuteOfDay: 21 * 60, todayLogged: false).count, 7)
    }

    func test_loggedMeansFoodAndBothMoodAndEnergy() {
        XCTAssertTrue(ReminderPlan.isLogged(foodEntries: 3, mood: MoodRecord(day: oct18, mood: 4, energy: 3)))
        XCTAssertFalse(ReminderPlan.isLogged(foodEntries: 0, mood: MoodRecord(day: oct18, mood: 4, energy: 3)))
        XCTAssertFalse(ReminderPlan.isLogged(foodEntries: 3, mood: MoodRecord(day: oct18, mood: 4, energy: nil)))
        XCTAssertFalse(ReminderPlan.isLogged(foodEntries: 3, mood: nil))
    }

    func test_theTimeDefaultsToNine() {
        let preferences = Preferences(defaults: UserDefaults(suiteName: #function)!)
        XCTAssertEqual(preferences.reminderMinute, 21 * 60)
        XCTAssertFalse(preferences.reminderEnabled)
    }
}
