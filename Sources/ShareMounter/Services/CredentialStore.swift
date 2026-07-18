import Foundation
import Security

/// Abstracts password storage so the app can use the Keychain in production and
/// an in-memory double in tests.
protocol CredentialStore: AnyObject {
    func password(for key: String) -> String?
    func setPassword(_ password: String, for key: String)
    func removePassword(for key: String)
}

/// Keychain-backed store. Passwords are generic-password items scoped to the
/// app's service identifier; the account is the share's `credentialKey`.
final class KeychainCredentialStore: CredentialStore {
    private let service: String

    init(service: String = "jp.nlink.share-mounter") { self.service = service }

    func password(for key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { return nil }
        return string
    }

    func setPassword(_ password: String, for key: String) {
        removePassword(for: key)
        guard !password.isEmpty, let data = password.data(using: .utf8) else { return }
        let add: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        SecItemAdd(add as CFDictionary, nil)
    }

    func removePassword(for key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// In-memory credential store for tests.
final class InMemoryCredentialStore: CredentialStore {
    private var store: [String: String]
    init(_ seed: [String: String] = [:]) { store = seed }
    func password(for key: String) -> String? { store[key] }
    func setPassword(_ password: String, for key: String) {
        if password.isEmpty { store[key] = nil } else { store[key] = password }
    }
    func removePassword(for key: String) { store[key] = nil }
}
