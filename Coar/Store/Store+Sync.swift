import CoreData
import os

/// The sync dedupe pass (`.scratch/data-model/issues/01`). CloudKit cannot enforce the
/// model's one-per-key invariants (ADR 0002), so two devices syncing offline can each make a
/// row for the same key. The pass groups rows by key and keeps the one with the latest
/// `modifiedAt`, which every device computes alike, so all converge on the same survivor.
/// The Active Workout is the exception because the loser can hold Logged Sets: the later
/// `startedAt` stays active and the older is finished as history if any set was completed,
/// deleted if none was.
enum DedupePass {

    /// What one pass changed. Empty when the store already held one row per key.
    struct Report: Equatable {
        var checkInsDeleted = 0
        var bodyWeightsDeleted = 0
        var servingDefaultsCleared = 0
        var workoutsFinished = 0
        var workoutsDeleted = 0

        var isEmpty: Bool { self == Report() }
    }

    /// Runs every invariant's pass in `context` and saves once, on the context's queue.
    /// Stamps `modifiedAt` on the rows it changes, as every façade write does.
    static func run(in context: NSManagedObjectContext) throws -> Report {
        var report = Report()
        report.checkInsDeleted = try dedupeCheckIns(in: context)
        report.bodyWeightsDeleted = try dedupeBodyWeights(in: context)
        report.servingDefaultsCleared = try dedupeDefaultServings(in: context)
        (report.workoutsFinished, report.workoutsDeleted) = try dedupeActiveWorkouts(in: context)
        guard context.hasChanges else { return report }
        let now = Date()
        for object in context.updatedObjects {
            (object as? ModifiedAtStamped)?.modifiedAt = now
        }
        try context.save()
        return report
    }

    // MARK: - Invariants

    private struct CheckInKey: Hashable {
        let habit: NSManagedObjectID
        let day: String
    }

    /// One Check-in per Habit per Day: the latest `modifiedAt` stays, whatever its amount.
    private static func dedupeCheckIns(in context: NSManagedObjectContext) throws -> Int {
        let checkIns = try context.fetch(CheckIn.fetchRequest())
        let losers = losers(among: checkIns) { checkIn -> CheckInKey? in
            guard let habit = checkIn.habit, let day = checkIn.day else { return nil }
            return CheckInKey(habit: habit.objectID, day: day)
        } outranks: {
            ($0.modifiedAt ?? .distantPast, $0.amount) > ($1.modifiedAt ?? .distantPast, $1.amount)
        }
        losers.forEach(context.delete)
        return losers.count
    }

    /// One Body Weight per Day: the latest `modifiedAt` stays.
    private static func dedupeBodyWeights(in context: NSManagedObjectContext) throws -> Int {
        let weights = try context.fetch(BodyWeight.fetchRequest())
        let losers = losers(among: weights, key: \.day) {
            ($0.modifiedAt ?? .distantPast, $0.kilograms) > ($1.modifiedAt ?? .distantPast, $1.kilograms)
        }
        losers.forEach(context.delete)
        return losers.count
    }

    /// One default Serving per Food Item: the latest `modifiedAt` keeps the flag; the others
    /// lose only the flag, since each is still a Serving the user made.
    private static func dedupeDefaultServings(in context: NSManagedObjectContext) throws -> Int {
        let request = Serving.fetchRequest()
        request.predicate = NSPredicate(format: "isDefault == YES")
        let defaults = try context.fetch(request)
        let losers = losers(among: defaults, key: { $0.foodItem?.objectID }) {
            ($0.modifiedAt ?? .distantPast, $0.id?.uuidString ?? "") > ($1.modifiedAt ?? .distantPast, $1.id?.uuidString ?? "")
        }
        for serving in losers {
            serving.isDefault = false
        }
        return losers.count
    }

    /// At most one Active Workout: the later `startedAt` stays active. An older one with a
    /// completed Logged Set is finished the way Finish does it (uncompleted sets dropped,
    /// `finishedAt` the moment the survivor started, so every device writes the same
    /// instant); one with nothing completed is deleted, pre-filled Plan sets and all.
    private static func dedupeActiveWorkouts(in context: NSManagedObjectContext) throws -> (finished: Int, deleted: Int) {
        let request = Workout.fetchRequest()
        request.predicate = NSPredicate(format: "finishedAt == nil")
        let active = try context.fetch(request)
        let losers = losers(among: active, key: { _ in 0 }) {
            ($0.startedAt ?? .distantPast, $0.id?.uuidString ?? "") > ($1.startedAt ?? .distantPast, $1.id?.uuidString ?? "")
        }
        guard let survivor = active.first(where: { !losers.contains($0) }) else { return (0, 0) }
        var finished = 0, deleted = 0
        for workout in losers {
            let sets = workout.exerciseObjects.flatMap(\.loggedSetObjects)
            if sets.contains(where: \.isCompleted) {
                for set in sets where !set.isCompleted {
                    context.delete(set)
                }
                workout.finishedAt = survivor.startedAt
                finished += 1
            } else {
                context.delete(workout)
                deleted += 1
            }
        }
        return (finished, deleted)
    }

    // MARK: - Grouping

    /// Every object that shares a key with one that outranks it. Objects with no key (an
    /// orphan whose parent is gone) are never duplicates. Each ranking breaks a `modifiedAt`
    /// tie on content or id, so two devices ranking the same rows pick the same survivor.
    private static func losers<Object: NSManagedObject, Key: Hashable>(
        among objects: [Object],
        key: (Object) -> Key?,
        outranks: (Object, Object) -> Bool
    ) -> [Object] {
        var best: [Key: Object] = [:]
        var losers: [Object] = []
        for object in objects {
            guard let key = key(object) else { continue }
            guard let standing = best[key] else { best[key] = object; continue }
            if outranks(object, standing) {
                losers.append(standing)
                best[key] = object
            } else {
                losers.append(object)
            }
        }
        return losers
    }
}

extension Store {

    /// Posted on the main queue, with the `Store` as the object, after a remote-change
    /// import has been merged and deduped; a screen on show re-reads through the façade and
    /// applies its snapshot.
    static let remoteChangesDidMerge = Notification.Name("Store.remoteChangesDidMerge")

    private static let syncLogger = Logger(category: "Sync")

    /// Runs the dedupe pass once on a background context, saving once; the view context
    /// merges the result before this returns. Posts `activeWorkoutDidChange` when the pass
    /// touched an Active Workout.
    @discardableResult
    func runDedupePass() async throws -> DedupePass.Report {
        let context = container.newBackgroundContext()
        context.transactionAuthor = "dedupe"
        let report = try await context.perform { try DedupePass.run(in: context) }
        if !report.isEmpty {
            Self.syncLogger.info("Dedupe pass: \(String(describing: report), privacy: .public)")
        }
        if report.workoutsFinished + report.workoutsDeleted > 0 {
            NotificationCenter.default.post(name: Self.activeWorkoutDidChange, object: self)
        }
        return report
    }
}

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
        observer = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: store.container.persistentStoreCoordinator, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.schedule(after: self.settle)
            }
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
