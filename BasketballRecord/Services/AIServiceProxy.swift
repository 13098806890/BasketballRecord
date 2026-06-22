import Foundation
import OSLog
import StoreKit

private let scfBaseURL = "https://1443094980-bwq2035uwg.ap-shanghai.tencentscf.com"
private let scfChatURL = URL(string: "\(scfBaseURL)/v1/chat")!
private let aiLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BasketballRecord", category: "AIService")

enum AIServiceProxyError: LocalizedError {
    case notConfigured, subscriptionInactive, serverError(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return NSLocalizedString("scf_error_not_configured", comment: "")
        case .subscriptionInactive: return NSLocalizedString("scf_error_subscription_inactive", comment: "")
        case .serverError(let msg): return msg
        }
    }
}

struct AIServiceProxy {
    static func chat(messages: [[String: String]], systemPrompt: String, temperature: Double, maxTokens: Int) async throws -> String {
        os_log(.info, log: aiLog, "AI chat started")

        let tid: String
        if let cached = await PurchaseManager.shared.latestTransactionId {
            tid = "\(cached)"
        } else {
            var found: String?
            for await result in Transaction.currentEntitlements {
                guard case let .verified(t) = result,
                      ["com.doxie.basketball.pro.monthly", "com.doxie.basketball.pro.yearly"].contains(t.productID) else { continue }
                found = "\(t.id)"
                break
            }
            guard let id = found else {
                os_log(.error, log: aiLog, "No subscription found")
                throw AIServiceProxyError.subscriptionInactive
            }
            tid = id
        }
        os_log(.debug, log: aiLog, "Using transactionId=%{public}@", tid)

        let requestBody: [String: Any] = [
            "transactionId": tid,
            "messages": messages,
            "systemPrompt": systemPrompt,
            "temperature": temperature,
            "maxTokens": maxTokens
        ]

        var request = URLRequest(url: scfChatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceProxyError.serverError(NSLocalizedString("scf_error_no_response", comment: ""))
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AIServiceProxyError.serverError(body)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIServiceProxyError.serverError(NSLocalizedString("scf_error_empty_key", comment: ""))
        }

        if let error = json["error"] as? String {
            throw AIServiceProxyError.serverError(error)
        }

        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceProxyError.serverError(NSLocalizedString("scf_error_empty_key", comment: ""))
        }

        os_log(.info, log: aiLog, "AI response received: %d chars", content.count)
        return content
    }
}
