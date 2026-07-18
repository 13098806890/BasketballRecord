import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case deepseek
    case openAI
    case anthropic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .openAI: return "OpenAI"
        case .anthropic: return "Anthropic"
        }
    }

    static var availableProviders: [AIProvider] {
        if Locale.current.region?.identifier == "CN" {
            return [.deepseek]
        }
        return allCases
    }

    var endpoint: URL? {
        switch self {
        case .deepseek: return URL(string: "https://api.deepseek.com/chat/completions")
        case .openAI: return URL(string: "https://api.openai.com/v1/chat/completions")
        case .anthropic: return URL(string: "https://api.anthropic.com/v1/messages")
        }
    }

    var models: [AIModel] {
        switch self {
        case .deepseek: return [AIModel(provider: .deepseek, id: "deepseek-chat", displayName: "DeepSeek Chat")]
        case .openAI: return [
            AIModel(provider: .openAI, id: "gpt-4o", displayName: "GPT-4o"),
            AIModel(provider: .openAI, id: "gpt-4o-mini", displayName: "GPT-4o Mini"),
            AIModel(provider: .openAI, id: "gpt-4-turbo", displayName: "GPT-4 Turbo"),
            AIModel(provider: .openAI, id: "gpt-3.5-turbo", displayName: "GPT-3.5 Turbo"),
        ]
        case .anthropic: return [
            AIModel(provider: .anthropic, id: "claude-sonnet-4", displayName: "Claude Sonnet 4"),
            AIModel(provider: .anthropic, id: "claude-haiku-4", displayName: "Claude Haiku 4"),
        ]
        }
    }

    static var defaultModel: AIModel {
        AIModel(provider: .deepseek, id: "deepseek-chat", displayName: "DeepSeek Chat")
    }
}

struct AIModel: Codable, Hashable, Identifiable {
    let provider: AIProvider
    let id: String
    let displayName: String
}

struct AIService {
    static let shared = AIService()

    func sendChat(model: AIModel, apiKey: String, systemPrompt: String, userPrompt: String, temperature: Double = 0.6, maxTokens: Int = 2500) async throws -> String {
        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedKey.isEmpty else { throw AIServiceError.missingAPIKey }

        switch model.provider {
        case .deepseek, .openAI:
            return try await sendOpenAICompatible(model: model, apiKey: normalizedKey, systemPrompt: systemPrompt, userPrompt: userPrompt, temperature: temperature, maxTokens: maxTokens)
        case .anthropic:
            return try await sendAnthropic(model: model, apiKey: normalizedKey, systemPrompt: systemPrompt, userPrompt: userPrompt, temperature: temperature, maxTokens: maxTokens)
        }
    }

    func testConnection(model: AIModel, apiKey: String) async throws {
        let _ = try await sendChat(model: model, apiKey: apiKey, systemPrompt: "You are a helpful assistant.", userPrompt: "Reply only: OK", temperature: 0, maxTokens: 16)
    }

    private func sendOpenAICompatible(model: AIModel, apiKey: String, systemPrompt: String, userPrompt: String, temperature: Double, maxTokens: Int) async throws -> String {
        guard let endpoint = model.provider.endpoint else { throw AIServiceError.invalidEndpoint }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let payload = OpenAIRequest(
            model: model.id,
            messages: [
                AIMessage(role: "system", content: systemPrompt),
                AIMessage(role: "user", content: userPrompt)
            ],
            temperature: temperature,
            maxTokens: maxTokens
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let msg = extractServerError(from: data)
            throw AIServiceError.serverError(statusCode: httpResponse.statusCode, message: msg)
        }

        let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
            throw AIServiceError.emptyResponse
        }
        return content
    }

    private func sendAnthropic(model: AIModel, apiKey: String, systemPrompt: String, userPrompt: String, temperature: Double, maxTokens: Int) async throws -> String {
        guard let endpoint = model.provider.endpoint else { throw AIServiceError.invalidEndpoint }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let payload = AnthropicRequest(
            model: model.id,
            system: systemPrompt,
            messages: [AnthropicMessage(role: "user", content: userPrompt)],
            maxTokens: maxTokens,
            temperature: temperature
        )
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let msg = extractServerError(from: data)
            throw AIServiceError.serverError(statusCode: httpResponse.statusCode, message: msg)
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let texts = decoded.content.compactMap { $0.text }
        let joined = texts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !joined.isEmpty else { throw AIServiceError.emptyResponse }
        return joined
    }

    private func extractServerError(from data: Data) -> String {
        if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data), let msg = envelope.error?.message, !msg.isEmpty { return msg }
        if let text = String(data: data, encoding: .utf8), !text.isEmpty { return text }
        return NSLocalizedString("deepseek_error_unavailable", comment: "Service unavailable")
    }
}

enum AIServiceError: LocalizedError {
    case missingAPIKey, invalidResponse, emptyResponse, invalidEndpoint
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return NSLocalizedString("deepseek_error_missing_api_key", comment: "Missing API Key")
        case .invalidResponse: return NSLocalizedString("deepseek_error_bad_response", comment: "Bad response")
        case .emptyResponse: return NSLocalizedString("deepseek_error_empty_response", comment: "Empty response")
        case .invalidEndpoint: return "Invalid API endpoint"
        case let .serverError(code, msg): return String(format: NSLocalizedString("deepseek_error_request_failed_format", comment: "Request failed"), code, msg)
        }
    }
}

// MARK: - OpenAI-compatible request/response

private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [AIMessage]
    let temperature: Double
    let maxTokens: Int
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct AIMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIResponse: Decodable {
    let choices: [AIChoice]
}

private struct AIChoice: Decodable {
    let message: AIMessage
}

// MARK: - Anthropic request/response

private struct AnthropicRequest: Encodable {
    let model: String
    let system: String
    let messages: [AnthropicMessage]
    let maxTokens: Int
    let temperature: Double
    enum CodingKeys: String, CodingKey {
        case model, system, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

private struct AnthropicResponse: Decodable {
    let content: [AnthropicContent]
}

private struct AnthropicContent: Decodable {
    let text: String?
}

// MARK: - Shared error envelope

private struct ErrorEnvelope: Decodable {
    let error: ServerError?
}

private struct ServerError: Decodable {
    let message: String?
}
