import Foundation

struct DeepSeekService {
    static let shared = DeepSeekService()

    private let endpoint = URL(string: "https://api.deepseek.com/chat/completions")!
    private let model = "deepseek-chat"

    func testConnection(apiKey: String) async throws {
        _ = try await sendChat(
            messages: [
                DeepSeekChatMessage(role: "system", content: "You are a helpful assistant."),
                DeepSeekChatMessage(role: "user", content: "请仅回复：连接成功")
            ],
            apiKey: apiKey,
            temperature: 0,
            maxTokens: 16
        )
    }

    func generateSummary(prompt: String, apiKey: String) async throws -> String {
        try await sendChat(
            messages: [
                DeepSeekChatMessage(role: "system", content: "你是专业篮球解说与数据分析师。"),
                DeepSeekChatMessage(role: "user", content: prompt)
            ],
            apiKey: apiKey,
            temperature: 0.6,
            maxTokens: 1200
        )
    }

    private func sendChat(
        messages: [DeepSeekChatMessage],
        apiKey: String,
        temperature: Double,
        maxTokens: Int
    ) async throws -> String {
        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else {
            throw DeepSeekServiceError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(normalizedKey)", forHTTPHeaderField: "Authorization")

        let payload = DeepSeekChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekServiceError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = extractServerError(from: data)
            throw DeepSeekServiceError.serverError(statusCode: httpResponse.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(DeepSeekChatResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw DeepSeekServiceError.emptyResponse
        }

        return content
    }

    private func extractServerError(from data: Data) -> String {
        if let envelope = try? JSONDecoder().decode(DeepSeekErrorEnvelope.self, from: data),
           let message = envelope.error.message,
           !message.isEmpty {
            return message
        }

        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }

        return "服务暂时不可用。"
    }
}

enum DeepSeekServiceError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case emptyResponse
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先填写 DeepSeek API Key。"
        case .invalidResponse:
            return "连接成功，但响应格式异常。"
        case .emptyResponse:
            return "模型返回为空，请稍后重试。"
        case let .serverError(statusCode, message):
            return "请求失败（\(statusCode)）：\(message)"
        }
    }
}

private struct DeepSeekChatRequest: Encodable {
    let model: String
    let messages: [DeepSeekChatMessage]
    let temperature: Double
    let maxTokens: Int

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case temperature
        case maxTokens = "max_tokens"
    }
}

private struct DeepSeekChatMessage: Codable {
    let role: String
    let content: String
}

private struct DeepSeekChatResponse: Decodable {
    let choices: [DeepSeekChatChoice]
}

private struct DeepSeekChatChoice: Decodable {
    let message: DeepSeekChatMessage
}

private struct DeepSeekErrorEnvelope: Decodable {
    let error: DeepSeekServerError
}

private struct DeepSeekServerError: Decodable {
    let message: String?
}
