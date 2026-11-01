import UIKit
import UserNotifications
import os

/// When the nightly reminder fires (`.scratch/reminders/issues/01`; a pure rule): at the chosen
/// time on each of the next 7 Days, today only while that time is still ahead. Every night, even
/// a Day that looks logged: mood and breakfast by morning made an earlier "skip when logged"
/// rule skip nearly every night. Re-planned whenever Coar comes forward or goes away, so a week
/// without opening it still gets its reminders.
enum ReminderPlan {

    static let days = 7
    /// 9 PM.
    static let defaultMinute = 21 * 60

    static func days(today: Day, now: Date, minuteOfDay: Int, calendar: Calendar = .current) -> [Day] {
        let todayAt = calendar.date(byAdding: .minute, value: minuteOfDay, to: today.start(in: calendar))!
        let first = todayAt > now ? 0 : 1
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

    /// Plans the next week again. Each Day's reminder is added over the one already planned (the
    /// same identifier replaces it), and only those no longer wanted are removed after, so Coar
    /// being suspended part way never leaves the week without reminders.
    func refresh() async {
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(Self.prefix) }
        guard preferences.reminderEnabled, await isAllowed() == true else {
            center.removePendingNotificationRequests(withIdentifiers: pending)
            return
        }
        let minute = preferences.reminderMinute
        let days = ReminderPlan.days(today: .today(), now: Date(), minuteOfDay: minute)
        let wanted = Set(days.map { Self.prefix + $0.rawValue })
        for day in days {
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
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { !wanted.contains($0) })
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
