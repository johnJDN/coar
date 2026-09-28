import Foundation
import os

/// The Describe tab's draft kept on this iPhone (spec "The Describe draft lives on this
/// iPhone"): a small JSON file in Application Support, written on every change and never
/// synced, so typing is never lost to a closed sheet or a quit app. Not Core Data: a draft is
/// not a record, and keeping it out of the model needs no CloudKit schema change.
struct DescribeDraftFile {

    private static let logger = Logger(category: "Food")

    let url: URL

    static let standard = DescribeDraftFile(url: URL.applicationSupportDirectory.appending(path: "describe-draft.json"))

    /// The saved draft, with any line that was checking when the app quit made ready to send
    /// again; an empty draft when there is none, or it can't be read (logged, never a crash).
    func load() -> DescribeDraft {
        guard let data = try? Data(contentsOf: url) else { return DescribeDraft() }
        do {
            var draft = try JSONDecoder().decode(DescribeDraft.self, from: data)
            draft.resume()
            return draft
        } catch {
            Self.logger.error("Describe draft unreadable, starting empty: \(error, privacy: .public)")
            return DescribeDraft()
        }
    }

    func save(_ draft: DescribeDraft) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(draft).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            Self.logger.error("Failed to save the Describe draft: \(error, privacy: .public)")
        }
    }
}

extension FoodText {

    /// A typed line as the cache and the library compare it: lowercased, trimmed, and spaces
    /// collapsed, so "2 Eggs " and "2 eggs" are the same line.
    static func normalised(_ line: String) -> String {
        line.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

/// Estimates already paid for, by normalised line (spec "Estimating" step 2): a line typed
/// before, word for word, fills in again for free. Holds at most `capacity` lines and drops
/// the least recently used first. A value; `EstimateCacheFile` keeps it on this iPhone.
struct EstimateCache: Codable, Equatable {

    static let capacity = 500

    /// Least recently used first.
    private var order: [String] = []
    private var estimates: [String: Estimate] = [:]
    private let capacity: Int

    init(capacity: Int = EstimateCache.capacity) {
        self.capacity = capacity
    }

    var count: Int { order.count }

    /// The Estimate last given for this line, which now counts as just used.
    mutating func estimate(for line: String) -> Estimate? {
        let key = FoodText.normalised(line)
        guard let estimate = estimates[key] else { return nil }
        touch(key)
        return estimate
    }

    mutating func store(_ estimate: Estimate, for line: String) {
        let key = FoodText.normalised(line)
        estimates[key] = estimate
        touch(key)
        while order.count > capacity {
            estimates[order.removeFirst()] = nil
        }
    }

    private mutating func touch(_ key: String) {
        order.removeAll { $0 == key }
        order.append(key)
    }
}

/// Answers from the cache when it can and asks the wrapped estimator otherwise, keeping every
/// loggable answer. Failures and impossible numbers are never kept, so they are asked again;
/// nor are matches to the user's catalogue, which can change or be archived.
/// Safe to call from any task: the cache is behind a lock, and written to Caches (which the
/// system may empty; it is only a cache) after each new answer.
final class CachingFoodEstimator: FoodEstimator {

    private let wrapped: FoodEstimator
    private let url: URL?
    private let lock = NSLock()
    private var cache: EstimateCache

    /// `url` nil keeps the cache in memory only (tests).
    init(wrapping wrapped: FoodEstimator, url: URL? = URL.cachesDirectory.appending(path: "estimate-cache.json"), capacity: Int = EstimateCache.capacity) {
        self.wrapped = wrapped
        self.url = url
        cache = url.flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(EstimateCache.self, from: $0) } ?? EstimateCache(capacity: capacity)
    }

    func estimate(_ line: String, library: FoodLibrary) async throws -> Estimate {
        if let cached = lock.withLock({ cache.estimate(for: line) }) {
            return cached
        }
        let estimate = try await wrapped.estimate(line, library: library)
        guard estimate.impossibility == nil, estimate.match == nil else { return estimate }
        let snapshot = lock.withLock {
            cache.store(estimate, for: line)
            return cache
        }
        if let url, let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
        return estimate
    }
}
