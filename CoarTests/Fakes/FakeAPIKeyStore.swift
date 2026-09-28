import Foundation
@testable import Coar

/// The Keychain stands in behind its protocol: a key held in memory.
final class FakeAPIKeyStore: APIKeyStore {

    var key: String?

    init(key: String? = nil) {
        self.key = key
    }

    func read() -> String? { key }
    func save(_ key: String) throws { self.key = key }
    func delete() throws { key = nil }
}
