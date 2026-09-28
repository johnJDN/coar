import XCTest
@testable import Coar

/// OpenRouter (ADR 0007) is reached through one client whose transport is stubbed here: no
/// test touches the network. Covers what Settings shows for a key's spending and how every
/// failure becomes an error a screen can state.
final class OpenRouterTests: XCTestCase {

    private func reply(_ status: Int, _ body: String) -> OpenRouterClient.Transport {
        { request in
            (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }

    private let weeklyTwoDollars = #"{"data":{"label":"x","limit":2,"limit_reset":"weekly","limit_remaining":1.86,"usage":0.5,"usage_weekly":0.14}}"#

    // MARK: Spending

    func test_keyStatus_readsSpendingInTheLimitsWindow() async throws {
        let client = OpenRouterClient(keys: FakeAPIKeyStore(key: "sk-or-test"), transport: reply(200, weeklyTwoDollars))
        let status = try await client.keyStatus()
        XCTAssertEqual(status, OpenRouterKeyStatus(usage: 0.5, limit: 2, limitRemaining: 1.86, reset: .weekly))
        XCTAssertEqual(status.spendText, "$0.14 of $2 this week")
    }

    func test_spendText_withoutAResetOrALimit() {
        XCTAssertEqual(OpenRouterKeyStatus(usage: 0.5, limit: 5, limitRemaining: 4.5, reset: nil).spendText, "$0.50 of $5")
        XCTAssertEqual(OpenRouterKeyStatus(usage: 3.1, limit: nil, limitRemaining: nil, reset: nil).spendText, "$3.10 spent, no limit")
        XCTAssertEqual(OpenRouterKeyStatus(usage: 0.001, limit: 2, limitRemaining: 1.999, reset: .monthly).spendText, "under $0.01 of $2 this month")
        XCTAssertEqual(OpenRouterKeyStatus(usage: 0, limit: 2, limitRemaining: 2, reset: .daily).spendText, "$0 of $2 today")
    }

    func test_aKeyBeingChecked_isSentInsteadOfTheSavedOne() async throws {
        var sent: String?
        let client = OpenRouterClient(keys: FakeAPIKeyStore(key: "sk-or-saved")) { request in
            sent = request.value(forHTTPHeaderField: "Authorization")
            return try await self.reply(200, self.weeklyTwoDollars)(request)
        }
        _ = try await client.keyStatus(of: "sk-or-typed")
        XCTAssertEqual(sent, "Bearer sk-or-typed")
    }

    // MARK: Failures

    func test_noSavedKey_failsBeforeAnyRequest() async {
        var requested = false
        let client = OpenRouterClient(keys: FakeAPIKeyStore()) { request in
            requested = true
            return try await self.reply(200, self.weeklyTwoDollars)(request)
        }
        await assertThrows(.noKey) { _ = try await client.keyStatus() }
        XCTAssertFalse(requested)
    }

    func test_replies_mapToTheErrorTheScreenStates() async {
        let key = FakeAPIKeyStore(key: "sk-or-test")
        await assertThrows(.keyRejected) {
            _ = try await OpenRouterClient(keys: key, transport: self.reply(401, #"{"error":{"message":"User not found.","code":401}}"#)).keyStatus()
        }
        await assertThrows(.limitReached) {
            _ = try await OpenRouterClient(keys: key, transport: self.reply(402, #"{"error":{"message":"Insufficient credits"}}"#)).keyStatus()
        }
        await assertThrows(.limitReached) {
            _ = try await OpenRouterClient(keys: key, transport: self.reply(403, #"{"error":{"message":"Key limit exceeded"}}"#)).keyStatus()
        }
        await assertThrows(.failed("OpenRouter: Upstream error")) {
            _ = try await OpenRouterClient(keys: key, transport: self.reply(502, #"{"error":{"message":"Upstream error"}}"#)).keyStatus()
        }
        await assertThrows(.failed("OpenRouter sent a reply Coar couldn't read")) {
            _ = try await OpenRouterClient(keys: key, transport: self.reply(200, "<html>")).keyStatus()
        }
    }

    func test_noNetwork_isOffline_andATimeoutIsNot() async {
        let key = FakeAPIKeyStore(key: "sk-or-test")
        await assertThrows(.offline) {
            _ = try await OpenRouterClient(keys: key) { _ in throw URLError(.notConnectedToInternet) }.keyStatus()
        }
        await assertThrows(.failed("OpenRouter took too long to reply")) {
            _ = try await OpenRouterClient(keys: key) { _ in throw URLError(.timedOut) }.keyStatus()
        }
    }

    // MARK: Helpers

    private func assertThrows(_ expected: OpenRouterError, file: StaticString = #filePath, line: UInt = #line, _ body: () async throws -> Void) async {
        do {
            try await body()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? OpenRouterError, expected, file: file, line: line)
        }
    }
}
