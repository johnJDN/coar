import Foundation
import Security

/// Where the user's OpenRouter key is kept (ADR 0007). The key never goes to Core Data,
/// `UserDefaults`, or a log line; screens only ever see its last four characters.
protocol APIKeyStore: AnyObject {
    func read() -> String?
    func save(_ key: String) throws
    func delete() throws
}

extension APIKeyStore {
    /// The last four characters, for recognising which key is saved.
    var lastFour: String? {
        read().map { String($0.suffix(4)) }
    }
}

/// The key as a Keychain generic password on this iPhone only: readable after the first
/// unlock (so a request from a sheet opened on a locked-then-unlocked phone works), never
/// synced to iCloud Keychain, and gone if the app is deleted with its data.
final class KeychainKeyStore: APIKeyStore {

    struct Failure: Error, CustomStringConvertible {
        let status: OSStatus
        var description: String { "Keychain error \(status)" }
    }

    private let service: String

    init(service: String = "com.johnnguyen.coar.openrouter") {
        self.service = service
    }

    private var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "api-key",
            kSecAttrSynchronizable as String: false,
        ]
    }

    func read() -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ key: String) throws {
        try delete()
        var item = query
        item[kSecValueData as String] = Data(key.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure(status: status) }
    }

    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Failure(status: status) }
    }
}
