import UIKit
import UserNotifications
import os

/// When the nightly reminder fires (`.scratch/reminders/issues/01`; a pure rule): at the chosen
/// time on each of the next 7 Days, today only while that time is still ahead and the Day isn't
/// logged yet. Re-planned whenever Coar comes forward or goes away, so a week without opening
/// it still gets its reminders.
enum ReminderPlan {

    static let days = 7
    /// 9 PM.
    static let defaultMinute = 21 * 60

    /// A Day counts as logged once it has food and both mood and energy.
    static func isLogged(foodEntries: Int, mood: MoodRecord?) -> Bool {
        foodEntries > 0 && mood?.mood != nil && mood?.energy != nil
    }

    static func days(today: Day, now: Date, minuteOfDay: Int, todayLogged: Bool, calendar: Calendar = .current) -> [Day] {
        let todayAt = calendar.date(byAdding: .minute, value: minuteOfDay, to: today.start(in: calendar))!
        let first = !todayLogged && todayAt > now ? 0 : 1
        return (first..<(first + days)).map { today.advanced(by: $0) }
    }
}

/// The nightly "log today" notification: scheduled one Day at a time from `ReminderPlan`, with
/// iOS asking permission when it's first turned on. Tapping it opens the Day page.
@MainActor
final class EveningReminder: NSObject, UNUserNotificationCenterDelegate {

    private static let logger = Logger(category: "Reminder")
    private static let prefix = "evening-"

    private let store: Store
    private let preferences: Preferences
    private let center = UNUserNotificationCenter.current()
    /// Set by the scene; a tap that arrives first is kept until it is.
    var onOpen: (() -> Void)? {
        didSet { if pendingOpen, let onOpen { pendingOpen = false; onOpen() } }
    }
    private var pendingOpen = false

    init(store: Store, preferences: Preferences) {
        self.store = store
        self.preferences = preferences
        super.init()
        center.delegate = self
    }

    /// Whether iOS lets Coar notify; nil before it was asked.
    func isAllowed() async -> Bool? {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return nil
        }
    }

    /// Turns the reminder on (asking iOS the first time) or off; true when it ends up on and
    /// allowed.
    func setEnabled(_ on: Bool) async -> Bool {
        preferences.reminderEnabled = on
        var allowed = false
        if on {
            allowed = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
        await refresh()
        return on && allowed
    }

    func setMinute(_ minute: Int) async {
        preferences.reminderMinute = minute
        await refresh()
    }

    /// Clears the planned reminders and plans the next week again.
    func refresh() async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard preferences.reminderEnabled, await isAllowed() == true else { return }
        let today = Day.today()
        let logged = ReminderPlan.isLogged(foodEntries: ((try? store.entries(on: today)) ?? []).count, mood: (try? store.mood(on: today)) ?? nil)
        let minute = preferences.reminderMinute
        for day in ReminderPlan.days(today: today, now: Date(), minuteOfDay: minute, todayLogged: logged) {
            let content = UNMutableNotificationContent()
            content.title = "Log today"
            content.body = "Meals, mood and energy, and anything else from today."
            content.sound = .default
            var when = Calendar.current.dateComponents([.year, .month, .day], from: day.start())
            when.hour = minute / 60
            when.minute = minute % 60
            let request = UNNotificationRequest(identifier: Self.prefix + day.rawValue, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false))
            do {
                try await center.add(request)
            } catch {
                Self.logger.error("Failed to plan a reminder: \(error, privacy: .public)")
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard response.notification.request.identifier.hasPrefix(Self.prefix) else { return }
        await MainActor.run {
            if let onOpen { onOpen() } else { pendingOpen = true }
        }
    }
}
