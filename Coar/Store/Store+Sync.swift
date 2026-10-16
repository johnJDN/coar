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
        var goalWeightsDeleted = 0
        var profilesDeleted = 0
        var moodsDeleted = 0
        var placesDeleted = 0
        var journalEntriesDeleted = 0
        var journalEventsDeleted = 0
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
        report.goalWeightsDeleted = try dedupeGoalWeights(in: context)
        report.profilesDeleted = try dedupeProfiles(in: context)
        report.moodsDeleted = try dedupeMoods(in: context)
        report.placesDeleted = try dedupePlaces(in: context)
        (report.journalEntriesDeleted, report.journalEventsDeleted) = try dedupeJournal(in: context)
        report.servingDefaultsCleared = try dedupeDefaultServings(in: context)
        (report.workoutsFinished, report.workoutsDeleted) = try dedupeActiveWorkouts(in: context)
        try Store.stampAndSave(context)
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
        let bodyWeights = try context.fetch(BodyWeight.fetchRequest())
        let losers = losers(among: bodyWeights, key: \.day) {
            ($0.modifiedAt ?? .distantPast, $0.kilograms) > ($1.modifiedAt ?? .distantPast, $1.kilograms)
        }
        losers.forEach(context.delete)
        return losers.count
    }

    /// One Goal Weight: the latest `modifiedAt` stays.
    private static func dedupeGoalWeights(in context: NSManagedObjectContext) throws -> Int {
        let goals = try context.fetch(GoalWeight.fetchRequest())
        let losers = losers(among: goals, key: { _ in 0 }) {
            ($0.modifiedAt ?? .distantPast, $0.kilograms) > ($1.modifiedAt ?? .distantPast, $1.kilograms)
        }
        losers.forEach(context.delete)
        return losers.count
    }

    /// One About me: the latest `modifiedAt` stays.
    private static func dedupeProfiles(in context: NSManagedObjectContext) throws -> Int {
        let profiles = try context.fetch(Profile.fetchRequest())
        let losers = losers(among: profiles, key: { _ in 0 }) {
            ($0.modifiedAt ?? .distantPast, $0.objectID.uriRepresentation().absoluteString) > ($1.modifiedAt ?? .distantPast, $1.objectID.uriRepresentation().absoluteString)
        }
        losers.forEach(context.delete)
        return losers.count
    }

    /// One mood and energy per Day: the latest `modifiedAt` stays.
    private static func dedupeMoods(in context: NSManagedObjectContext) throws -> Int {
        let moods = try context.fetch(DayMood.fetchRequest())
        let losers = losers(among: moods, key: \.day) {
            ($0.modifiedAt ?? .distantPast, $0.mood, $0.energy) > ($1.modifiedAt ?? .distantPast, $1.mood, $1.energy)
        }
        losers.forEach(context.delete)
        return losers.count
    }

    /// One place per Day and source: the latest `modifiedAt` stays.
    private static func dedupePlaces(in context: NSManagedObjectContext) throws -> Int {
        let places = try context.fetch(DayPlace.fetchRequest())
        let losers = losers(among: places, key: { place in place.day.map { "\($0)#\(place.fromJournal)" } }) {
            ($0.modifiedAt ?? .distantPast, $0.name ?? "") > ($1.modifiedAt ?? .distantPast, $1.name ?? "")
        }
        losers.forEach(context.delete)
        return losers.count
    }

    /// One read of each journal entry: two devices reading the same entry keep the later read,
    /// and the events of any other read go with it.
    private static func dedupeJournal(in context: NSManagedObjectContext) throws -> (entries: Int, events: Int) {
        let entries = try context.fetch(JournalEntry.fetchRequest())
        let losers = losers(among: entries, key: \.fileName) {
            ($0.modifiedAt ?? .distantPast, $0.readID?.uuidString ?? "") > ($1.modifiedAt ?? .distantPast, $1.readID?.uuidString ?? "")
        }
        losers.forEach(context.delete)
        // An event whose entry hasn't synced yet is left alone: only one from another read of
        // an entry that is here goes.
        var currentRead: [String: UUID] = [:]
        for entry in entries where !losers.contains(entry) {
            if let file = entry.fileName, let read = entry.readID { currentRead[file] = read }
        }
        let stale = try context.fetch(JournalEvent.fetchRequest()).filter { event in
            guard let file = event.fileName, let read = currentRead[file] else { return false }
            return event.readID != read
        }
        stale.forEach(context.delete)
        return (losers.count, stale.count)
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
        // One global bucket: every Active Workout competes with every other.
        let losers = losers(among: active, key: { _ in 0 }) {
            ($0.startedAt ?? .distantPast, $0.id?.uuidString ?? "") > ($1.startedAt ?? .distantPast, $1.id?.uuidString ?? "")
        }
        guard let survivor = active.first(where: { !losers.contains($0) }) else { return (0, 0) }
        var finished = 0, deleted = 0
        for workout in losers {
            if workout.hasCompletedSet {
                workout.finish(at: survivor.startedAt ?? Date())
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

    /// Runs the dedupe pass once on a background context, saving once. The view context
    /// merges the result as it does any background save: queued on the main queue during
    /// the save, so ahead of this call's return in practice. Posts `activeWorkoutDidChange`
    /// when the pass touched an Active Workout.
    @discardableResult
    func runDedupePass() async throws -> DedupePass.Report {
        let context = container.newBackgroundContext()
        context.transactionAuthor = "dedupe"
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        let report = try await context.perform { try DedupePass.run(in: context) }
        if !report.isEmpty {
            Self.syncLogger.info("Dedupe pass: \(String(describing: report), privacy: .public)")
        }
        if report.workoutsFinished + report.workoutsDeleted > 0 {
            notifyActiveWorkoutChanged()
        }
        return report
    }

    /// Calls `handler` on the main queue each time the store posts a remote change: a
    /// CloudKit import landed, or any context saved. Keep the token and remove it when done.
    func observeRemoteChanges(_ handler: @escaping @MainActor () -> Void) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange, object: container.persistentStoreCoordinator, queue: .main
        ) { _ in
            MainActor.assumeIsolated(handler)
        }
    }
}
