import XCTest
@testable import Coar

/// The rest timer's clock: it counts down from a start moment, ends itself, and can be
/// dismissed early. Time is passed in, so the tests never wait.
@MainActor
final class RestTimerTests: XCTestCase {

    private let start = Date(timeIntervalSinceReferenceDate: 1_000_000)

    func test_startedTimer_countsDownFromItsDuration() {
        let timer = RestTimer()
        timer.start(seconds: 90, now: start)

        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(timer.endsAt, start.addingTimeInterval(90))
        XCTAssertEqual(timer.remainingSeconds(at: start), 90)
        XCTAssertEqual(timer.remainingSeconds(at: start.addingTimeInterval(30.2)), 60, "rounds up so 0 shows only at the end")
        XCTAssertEqual(timer.remainingSeconds(at: start.addingTimeInterval(120)), 0)
    }

    func test_dismiss_stopsTheTimer() {
        let timer = RestTimer()
        timer.start(seconds: 90, now: start)

        timer.dismiss()

        XCTAssertFalse(timer.isRunning)
        XCTAssertNil(timer.endsAt)
        XCTAssertEqual(timer.remainingSeconds(at: start), 0)
    }

    func test_startingAgain_replacesTheRunningTimer() {
        let timer = RestTimer()
        timer.start(seconds: 90, now: start)

        timer.start(seconds: 60, now: start.addingTimeInterval(10))

        XCTAssertEqual(timer.endsAt, start.addingTimeInterval(70))
    }

    func test_countdownThatRunsOut_endsItselfAndSaysSo() {
        let timer = RestTimer()
        let expired = expectation(forNotification: RestTimer.didExpire, object: timer)
        let changed = expectation(forNotification: RestTimer.didChange, object: timer)
        changed.expectedFulfillmentCount = 2

        timer.start(seconds: 0)

        wait(for: [expired, changed], timeout: 2)
        XCTAssertFalse(timer.isRunning)
    }

    func test_changes_arePostedForStartAndDismiss() {
        let timer = RestTimer()
        var posts = 0
        let observer = NotificationCenter.default.addObserver(forName: RestTimer.didChange, object: timer, queue: nil) { _ in posts += 1 }
        defer { NotificationCenter.default.removeObserver(observer) }

        timer.start(seconds: 90, now: start)
        timer.dismiss()
        timer.dismiss()

        XCTAssertEqual(posts, 2, "a dismiss with nothing running is silent")
    }
}
