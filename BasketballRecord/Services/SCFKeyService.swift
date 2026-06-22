import Foundation

enum SCFKeyServiceError: LocalizedError {
    case invalidURL, networkError(String), emptyKey, notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidURL: return NSLocalizedString("scf_error_invalid_url", comment: "Invalid SCF URL")
        case .networkError(let msg): return msg
        case .emptyKey: return NSLocalizedString("scf_error_empty_key", comment: "Empty key from server")
        case .notConfigured: return NSLocalizedString("scf_error_not_configured", comment: "SCF URL not configured")
        }
    }
}

struct SCFKeyService {
    static let scfURLKey = "scf_deepseek_url"

    static var configuredURL: String? {
        UserDefaults.standard.string(forKey: scfURLKey)
    }

    static func fetchDeepSeekKey(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw SCFKeyServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["action": "getDeepSeekKey"])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SCFKeyServiceError.networkError(NSLocalizedString("scf_error_no_response", comment: "No response"))
        }

        guard httpResponse.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw SCFKeyServiceError.networkError(msg)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let key = json["key"] as? String, !key.isEmpty else {
            throw SCFKeyServiceError.emptyKey
        }

        try AIKeychain.shared.saveAPIKey(key, for: .deepseek)
        return key
    }

    static func fetchAndSaveFromConfiguredURL() async throws -> String {
        guard let url = configuredURL else {
            throw SCFKeyServiceError.notConfigured
        }
        return try await fetchDeepSeekKey(from: url)
    }
}
