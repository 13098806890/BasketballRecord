import Foundation
import Security

struct DeepSeekKeychain {
    static let shared = DeepSeekKeychain()

    private let account = "deepseek_api_key"
    private let service: String

    init() {
        service = Bundle.main.bundleIdentifier ?? "BasketballRecord"
    }

    func loadAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        return apiKey
    }

    func saveAPIKey(_ apiKey: String) throws {
        let normalized = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw DeepSeekKeychainError.emptyKey }
        guard let data = normalized.data(using: .utf8) else { throw DeepSeekKeychainError.invalidEncoding }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw DeepSeekKeychainError.osStatus(addStatus)
            }
            return
        }

        throw DeepSeekKeychainError.osStatus(updateStatus)
    }

    func removeAPIKey() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw DeepSeekKeychainError.osStatus(status)
        }
    }
}

enum DeepSeekKeychainError: LocalizedError {
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
