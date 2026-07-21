import Foundation
import Security

struct AIKeychain {
    static let shared = AIKeychain()

    private let service: String

    init() {
        service = Bundle.main.bundleIdentifier ?? "BasketballRecord"
    }

    func loadAPIKey(for provider: AIProvider) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            // Migration: try legacy DeepSeek key
            if provider == .deepseek {
                return migrateLegacyDeepSeekKey()
            }
            return nil
        }
        return apiKey
    }

    private func migrateLegacyDeepSeekKey() -> String? {
        let legacyQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "deepseek_api_key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(legacyQuery as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return nil
        }
        // Migrate: save under new account, delete old
        try? saveAPIKey(key, for: .deepseek)
        SecItemDelete(legacyQuery as CFDictionary)
        return key
    }

    func saveAPIKey(_ apiKey: String, for provider: AIProvider) throws {
        let normalized = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw AIKeychainError.emptyKey }
        guard let data = normalized.data(using: .utf8) else { throw AIKeychainError.invalidEncoding }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw AIKeychainError.osStatus(addStatus) }
            return
        }
        throw AIKeychainError.osStatus(updateStatus)
    }

    func removeAPIKey(for provider: AIProvider) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AIKeychainError.osStatus(status)
        }
        if provider == .deepseek {
            let legacyQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: "deepseek_api_key"
            ]
            SecItemDelete(legacyQuery as CFDictionary)
        }
    }

    func hasSavedKey(for provider: AIProvider) -> Bool {
        loadAPIKey(for: provider) != nil
    }

    static func migrateIfNeeded() {
        _ = shared.loadAPIKey(for: .deepseek)
    }
}

enum AIKeychainError: LocalizedError {
    case emptyKey
    case invalidEncoding
    case osStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .emptyKey:
            return NSLocalizedString("deepseek_keychain_empty", comment: "API Key cannot be empty")
        case .invalidEncoding:
            return NSLocalizedString("deepseek_keychain_encode_failed", comment: "API Key encode failed")
        case let .osStatus(status):
            if let message = SecCopyErrorMessageString(status, nil) as String? {
                return String(format: NSLocalizedString("deepseek_keychain_failed_format", comment: "Keychain failed"), message)
            }
            return String(format: NSLocalizedString("deepseek_keychain_failed_status_format", comment: "Keychain failed status"), "\(status)")
        }
    }
}
