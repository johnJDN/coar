import Foundation
import os

/// Runs the dedupe pass once at launch and after every remote-change import, one run at a
/// time. Imports arrive in bursts (and the store posts the same notification for the app's
/// own saves, the pass's included), so a run waits a moment for the burst to settle, and a
/// notification during a run queues one more. Owned by the app delegate for the live store.
@MainActor
final class SyncDedupeRunner {

    private static let logger = Logger(category: "Sync")

    private let store: Store
    private var observer: NSObjectProtocol?
    private var run: Task<Void, Never>?
    private var isPending = false

    /// How long a run waits after a remote change so a burst of imports coalesces.
    private let settle: Duration = .seconds(1)

    init(store: Store) {
        self.store = store
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        run?.cancel()
    }

    /// Runs the pass now, then after each remote change.
    func start() {
        guard observer == nil else { return }
        observer = store.observeRemoteChanges { [weak self] in
            guard let self else { return }
            schedule(after: settle)
        }
        schedule(after: .zero)
    }

    private func schedule(after delay: Duration) {
        guard run == nil else { isPending = true; return }
        run = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else { return }
            do {
                let report = try await store.runDedupePass()
                Self.logger.debug("Dedupe pass ran; changed anything: \(!report.isEmpty, privacy: .public)")
            } catch {
                Self.logger.error("Dedupe pass failed: \(error, privacy: .public)")
            }
            NotificationCenter.default.post(name: Store.remoteChangesDidMerge, object: store)
            run = nil
            if isPending {
                isPending = false
                schedule(after: settle)
            }
        }
    }
}
