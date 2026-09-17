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
    /// Posted, before `didChange`, when the countdown reaches zero on its own while the app
    /// is running; not when it is found to be over on return from the background.
    static let didExpire = Notification.Name("RestTimer.didExpire")

    private(set) var endsAt: Date?
    private var expiry: Timer?

    /// An expiry that fires this long after the end moment was not the countdown running
    /// out on screen but the app being suspended past it; `didExpire` is then withheld.
    static let expiryGrace: TimeInterval = 2

    var isRunning: Bool { endsAt != nil }

    /// Starts (or restarts) the countdown. The expiry runs on the common run-loop mode so a
    /// scroll never holds it back.
    func start(seconds: Int, now: Date = Date()) {
        let endsAt = now.addingTimeInterval(TimeInterval(seconds))
        self.endsAt = endsAt
        expiry?.invalidate()
        let expiry = Timer(fire: endsAt, interval: 0, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.expire() }
        }
        RunLoop.main.add(expiry, forMode: .common)
        self.expiry = expiry
        notify()
    }

    /// Whole seconds left at `now`, rounded up so `0` shows only once the timer is over.
    func remainingSeconds(at now: Date) -> Int {
        guard let endsAt else { return 0 }
        return Self.remainingSeconds(until: endsAt, at: now)
    }

    /// The same count for anyone holding only the end moment (the accessory bar).
    static func remainingSeconds(until endsAt: Date, at now: Date) -> Int {
        max(0, Int(endsAt.timeIntervalSince(now).rounded(.up)))
    }

    /// Stops the countdown early. Silent when nothing is running.
    func dismiss() {
        guard isRunning else { return }
        clear()
        notify()
    }

    private func expire() {
        guard let endsAt else { return }
        let onTime = Date().timeIntervalSince(endsAt) < Self.expiryGrace
        clear()
        if onTime {
            NotificationCenter.default.post(name: Self.didExpire, object: self)
        }
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
