import XCTest
@testable import Coar

/// The Describe tab keeps its draft on this iPhone and pays for each line once
/// (`.scratch/ai-food-logging/issues/03`). Covers the draft file, the line cache, and the
/// estimator that answers from it; the network is a fake.
@MainActor
final class DescribeStorageTests: XCTestCase {

    private let toast = Estimate(
        name: "Toast with butter", quantity: 1, unit: "slice", grams: 45,
        macros: Macros(calories: 135, protein: 3, fat: 6, carbs: 16),
        source: .estimated, assumption: ""
    )

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).json")
    }

    // MARK: The draft file

    func test_theDraft_comesBackAfterRelaunch_withCheckingLinesReadyToSendAgain() throws {
        let file = DescribeDraftFile(url: temporaryURL())
        var draft = DescribeDraft()
        let filled = try XCTUnwrap(draft.lines.first?.id)
        draft.edit(filled, text: "toast")
        draft.finish(filled, sentText: draft.begin(filled)!, result: .success(toast))
        let checking = draft.insertLine(after: filled)
        draft.edit(checking, text: "banana")
        _ = draft.begin(checking)
        let waiting = draft.insertLine(after: checking)
        draft.edit(waiting, text: "apple")
        draft.finish(waiting, sentText: draft.begin(waiting)!, result: .failure(OpenRouterError.offline))
        file.save(draft)

        let loaded = file.load()

        XCTAssertEqual(loaded.lines.map(\.text), ["toast", "banana", "apple"])
        XCTAssertEqual(loaded.line(filled)?.estimate, toast)
        XCTAssertEqual(loaded.line(checking)?.state, .typing, "its request died with the app")
        XCTAssertEqual(loaded.line(waiting)?.state, .waiting)
        XCTAssertEqual(loaded.unsent, [checking, waiting])
        XCTAssertEqual(loaded.waiting, [waiting])
    }

    func test_noFile_orAnUnreadableOne_startsAnEmptyDraft() throws {
        XCTAssertTrue(DescribeDraftFile(url: temporaryURL()).load().isEmpty)
        let url = temporaryURL()
        try Data("{ not json".utf8).write(to: url)
        let draft = DescribeDraftFile(url: url).load()
        XCTAssertEqual(draft.lines.count, 1)
        XCTAssertTrue(draft.isEmpty)
    }

    // MARK: The cache

    func test_normalising_ignoresCaseAndSpacing() {
        XCTAssertEqual(FoodText.normalised("  2 Eggs\t and  TOAST "), "2 eggs and toast")
    }

    func test_theCache_dropsTheLeastRecentlyUsedLine() {
        var cache = EstimateCache(capacity: 2)
        cache.store(toast, for: "toast")
        cache.store(toast, for: "bagel")
        XCTAssertNotNil(cache.estimate(for: "Toast "), "a hit counts as a use")
        cache.store(toast, for: "muffin")
        XCTAssertEqual(cache.count, 2)
        XCTAssertNil(cache.estimate(for: "bagel"))
        XCTAssertNotNil(cache.estimate(for: "toast"))
        XCTAssertNotNil(cache.estimate(for: "muffin"))
    }

    func test_aLineTypedAgain_isAnsweredWithoutARequest_andKeptAcrossLaunches() async throws {
        let fake = FakeFoodEstimator()
        fake.replies["toast"] = .success(toast)
        let url = temporaryURL()

        let first = CachingFoodEstimator(wrapping: fake, url: url)
        _ = try await first.estimate("toast")
        let again = try await first.estimate("  Toast")
        XCTAssertEqual(again, toast)
        XCTAssertEqual(fake.sent, ["toast"])

        let relaunched = CachingFoodEstimator(wrapping: fake, url: url)
        _ = try await relaunched.estimate("TOAST")
        XCTAssertEqual(fake.sent, ["toast"], "read from the file")
    }

    func test_failures_andImpossibleNumbers_areAskedAgain() async {
        let fake = FakeFoodEstimator()
        var huge = toast
        huge.macros.calories = 9_000
        fake.replies["huge"] = .success(huge)
        fake.replies["down"] = .failure(OpenRouterError.offline)
        let estimator = CachingFoodEstimator(wrapping: fake, url: nil)

        _ = try? await estimator.estimate("huge")
        _ = try? await estimator.estimate("huge")
        _ = try? await estimator.estimate("down")
        _ = try? await estimator.estimate("down")
        XCTAssertEqual(fake.sent, ["huge", "huge", "down", "down"])
    }
}
