import Foundation

/// The one rest timer (DESIGN.md §8 "Rest timer / in-progress"): a moment it ends at, set
/// when a set is completed and cleared when it runs out or the user dismisses it. Owned by
/// the app's dependencies so the logger starts it and the shell's accessory bar shows it
/// on every tab. Time is passed in for the tests; the app passes `Date()`.
@MainActor
final class RestTimer {

    /// Posted with the timer as the object when it starts, ends, or is dismissed. Ticks
    /// are the bar's own business.
    static let didChange = Notification.Name("RestTimer.didChange")
    /// Posted, before `didChange`, when the countdown reaches zero on its own.
    static let didExpire = Notification.Name("RestTimer.didExpire")

    private(set) var endsAt: Date?
    private(set) var totalSeconds = 0
    private var expiry: Timer?

    var isRunning: Bool { endsAt != nil }

    /// Starts (or restarts) the countdown.
    func start(seconds: Int, now: Date = Date()) {
        totalSeconds = seconds
        endsAt = now.addingTimeInterval(TimeInterval(seconds))
        expiry?.invalidate()
        expiry = Timer.scheduledTimer(withTimeInterval: TimeInterval(seconds), repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.expire() }
        }
        notify()
    }

    /// Whole seconds left at `now`, rounded up so `0` shows only once the timer is over.
    func remainingSeconds(at now: Date) -> Int {
        guard let endsAt else { return 0 }
        return max(0, Int(endsAt.timeIntervalSince(now).rounded(.up)))
    }

    /// Stops the countdown early. Silent when nothing is running.
    func dismiss() {
        guard isRunning else { return }
        clear()
        notify()
    }

    private func expire() {
        guard isRunning else { return }
        clear()
        NotificationCenter.default.post(name: Self.didExpire, object: self)
        notify()
    }

    private func clear() {
        expiry?.invalidate()
        expiry = nil
        endsAt = nil
    }

    private func notify() {
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }
}
