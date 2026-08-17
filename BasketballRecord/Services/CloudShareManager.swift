import Foundation
import OSLog

private let shareServiceBaseURL = "https://1443094980-e9pcdbf48s.ap-shanghai.tencentscf.com"
private var shareUploadURL: URL? {
    URL(string: "\(shareServiceBaseURL)/v2/upload")
}
private var shareDownloadURL: URL? {
    URL(string: "\(shareServiceBaseURL)/v2/download")
}
private var shareCheckURL: URL? {
    URL(string: "\(shareServiceBaseURL)/v2/check")
}
private let shareLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BasketballRecord", category: "CloudShare")

enum CloudShareError: LocalizedError {
    case notConfigured
    case notFound
    case emptyData
    case networkError(Error)
    case serverError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return NSLocalizedString("cloudshare_error_not_configured", comment: "")
        case .notFound:
            return NSLocalizedString("cloudshare_error_not_found", comment: "")
        case .emptyData:
            return NSLocalizedString("cloudshare_error_empty_data", comment: "")
        case .networkError(let error):
            return error.localizedDescription
        case .serverError(let msg):
            return msg
        case .invalidResponse:
            return NSLocalizedString("cloudshare_error_invalid_response", comment: "")
        }
    }
}

struct CloudShareUploadResponse: Decodable {
    let uuid: String
}

struct CloudShareCheckResponse: Decodable {
    let exists: Bool
    let remainingSeconds: Int
}

@MainActor
struct CloudShareManager {

    static func upload(data: Data) async throws -> String {
        guard !data.isEmpty else {
            throw CloudShareError.emptyData
        }

        guard let uploadURL = shareUploadURL else {
            throw CloudShareError.notConfigured
        }
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudShareError.networkError(URLError(.badServerResponse))
        }
        guard httpResponse.statusCode == 201 else {
            let body = String(data: responseData, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw CloudShareError.serverError(body)
        }

        let decoded = try JSONDecoder().decode(CloudShareUploadResponse.self, from: responseData)
        return decoded.uuid
    }

    static func retrieve(uuid: String) async throws -> Data {
        guard let downloadURL = shareDownloadURL else {
            throw CloudShareError.notConfigured
        }
        var request = URLRequest(url: downloadURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["uuid": uuid]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudShareError.networkError(URLError(.badServerResponse))
        }
        print("[CloudShare] retrieve uuid=\(uuid) status=\(httpResponse.statusCode) dataSize=\(data.count)")

        if httpResponse.statusCode == 404 {
            throw CloudShareError.notFound
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            print("[CloudShare] retrieve error body=\(body.prefix(500))")
            throw CloudShareError.serverError(body)
        }

        if let preview = String(data: data.prefix(500), encoding: .utf8) {
            print("[CloudShare] retrieve data preview=\(preview)")
        } else {
            print("[CloudShare] retrieve data is not UTF-8 text, size=\(data.count)")
        }
        return data
    }

    static func check(uuid: String) async throws -> (exists: Bool, remainingSeconds: Int) {
        guard let checkURL = shareCheckURL else {
            throw CloudShareError.notConfigured
        }
        guard var components = URLComponents(url: checkURL, resolvingAgainstBaseURL: false) else {
            throw CloudShareError.invalidResponse
        }
        components.path = "/v2/check/\(uuid)"
        guard let url = components.url else {
            throw CloudShareError.invalidResponse
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(CloudShareCheckResponse.self, from: data)
        return (decoded.exists, decoded.remainingSeconds)
    }

    static func uploadBundle(_ bundle: CloudShareBundle) async throws -> String {
        let data = try JSONEncoder().encode(bundle)
        return try await upload(data: data)
    }

    static func retrieveBundle(uuid: String) async throws -> CloudShareBundle {
        let data = try await retrieve(uuid: uuid)
        return try JSONDecoder().decode(CloudShareBundle.self, from: data)
    }

    static func uploadPhoto(uuid: String, playerID: UUID, data: Data) async throws {
        guard let url = URL(string: "\(shareServiceBaseURL)/v2/upload/photo/\(uuid)/\(playerID.uuidString)") else {
            throw CloudShareError.networkError(URLError(.badURL))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = data

        let (responseData, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudShareError.networkError(URLError(.badServerResponse))
        }
        guard httpResponse.statusCode == 201 else {
            let body = String(data: responseData, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw CloudShareError.serverError(body)
        }
    }

    static func retrievePhoto(uuid: String, playerID: UUID) async throws -> Data {
        guard let url = URL(string: "\(shareServiceBaseURL)/v2/download/photo/\(uuid)/\(playerID.uuidString)") else {
            throw CloudShareError.networkError(URLError(.badURL))
        }
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudShareError.networkError(URLError(.badServerResponse))
        }
        if httpResponse.statusCode == 404 {
            throw CloudShareError.notFound
        }
        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw CloudShareError.serverError(body)
        }
        return data
    }
}
