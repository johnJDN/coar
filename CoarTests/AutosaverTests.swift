import XCTest
@testable import Coar

@MainActor
final class AutosaverTests: XCTestCase {

    func test_aBurstOfChanges_savesOnce_afterTheLast() async throws {
        var saves = 0
        let autosaver = Autosaver(delay: .milliseconds(50)) { saves += 1 }
        for _ in 0..<5 { autosaver.schedule() }
        XCTAssertEqual(saves, 0, "nothing is written while typing")
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(saves, 1)
    }

    func test_flush_savesAtOnce_andCancelsTheScheduledSave() async throws {
        var saves = 0
        let autosaver = Autosaver(delay: .milliseconds(50)) { saves += 1 }
        autosaver.schedule()
        autosaver.flush()
        XCTAssertEqual(saves, 1)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(saves, 1, "the scheduled save does not run as well")
    }

    func test_cancelPending_dropsTheScheduledSave() async throws {
        var saves = 0
        let autosaver = Autosaver(delay: .milliseconds(50)) { saves += 1 }
        autosaver.schedule()
        autosaver.cancelPending()
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(saves, 0)
    }
}
