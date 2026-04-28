import Foundation
import Security

struct SecretsStore: Sendable {

    static let groq = SecretsStore(service: "de.neon.neowispr.groq")

    private static let defaultAccount = "api-key"

    let service: String

    init(service: String) {
        self.service = service
    }

    func read(account: String = Self.defaultAccount) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData] = kCFBooleanTrue
        query[kSecMatchLimit] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw SecretsStoreError.unhandledStatus(status)
        }
        guard let data = item as? Data else {
            throw SecretsStoreError.invalidData
        }
        return String(data: data, encoding: .utf8)
    }

    func save(_ value: String, account: String = Self.defaultAccount) throws {
        try delete(account: account, ignoreMissing: true)

        guard let data = value.data(using: .utf8) else {
            throw SecretsStoreError.invalidData
        }

        var query = baseQuery(account: account)
        query[kSecValueData] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecretsStoreError.unhandledStatus(status)
        }
    }

    func delete(account: String = Self.defaultAccount) throws {
        try delete(account: account, ignoreMissing: false)
    }

    func deleteIfExists(account: String = Self.defaultAccount) throws {
        try delete(account: account, ignoreMissing: true)
    }

    func migrateGroqAPIKeyFromUserDefaults(_ defaults: UserDefaults = .standard) {
        let legacyKey = (defaults.string(forKey: AppSettings.groqApiKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !legacyKey.isEmpty else { return }

        do {
            if try read()?.isEmpty ?? true {
                try save(legacyKey)
            }
            defaults.removeObject(forKey: AppSettings.groqApiKey)
        } catch {
            NSLog("Groq API-Key migration failed: \(error.localizedDescription)")
        }
    }

    private func delete(account: String, ignoreMissing: Bool) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        if status == errSecItemNotFound, ignoreMissing {
            return
        }
        guard status == errSecSuccess else {
            throw SecretsStoreError.unhandledStatus(status)
        }
    }

    private func baseQuery(account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
    }
}

enum SecretsStoreError: LocalizedError {
    case invalidData
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Keychain-Daten sind ungültig."
        case .unhandledStatus(let status):
            let message = SecCopyErrorMessageString(status, nil) as String?
            return message ?? "Keychain-Fehler \(status)."
        }
    }
}
