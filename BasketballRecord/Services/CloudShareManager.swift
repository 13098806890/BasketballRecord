import Foundation
import OSLog
import DeviceCheck

private let shareServiceBaseURL = "https://1443094980-e9pcdbf48s.ap-shanghai.tencentscf.com"
private var shareUploadURL: URL {
    guard let url = URL(string: "\(shareServiceBaseURL)/v2/upload") else {
        fatalError("Invalid share upload URL")
    }
    return url
}
private var shareDownloadURL: URL {
    guard let url = URL(string: "\(shareServiceBaseURL)/v2/download") else {
        fatalError("Invalid share download URL")
    }
    return url
}
private var shareCheckURL: URL {
    guard let url = URL(string: "\(shareServiceBaseURL)/v2/check") else {
        fatalError("Invalid share check URL")
    }
    return url
}
private let shareLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "BasketballRecord", category: "CloudShare")

enum CloudShareError: LocalizedError {
    case notConfigured
    case notFound
    case emptyData
    case deviceCheckNotSupported
    case deviceCheckFailed(Error?)
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
        case .deviceCheckNotSupported:
            return NSLocalizedString("cloudshare_error_devicecheck_unsupported", comment: "")
        case .deviceCheckFailed(let error):
            return error?.localizedDescription ?? NSLocalizedString("cloudshare_error_devicecheck_failed", comment: "")
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
    static func generateDeviceToken() async throws -> String {
        let device = DCDevice.current
        guard device.isSupported else {
            throw CloudShareError.deviceCheckNotSupported
        }
        let tokenData: Data = try await withCheckedThrowingContinuation { continuation in
            device.generateToken { token, error in
                if let error = error {
                    continuation.resume(throwing: CloudShareError.deviceCheckFailed(error))
                } else if let token = token {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: CloudShareError.deviceCheckFailed(nil))
                }
            }
        }
        return tokenData.base64EncodedString()
    }

    static func upload(data: Data) async throws -> String {
        guard !data.isEmpty else {
            throw CloudShareError.emptyData
        }

        var request = URLRequest(url: shareUploadURL)
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
        var request = URLRequest(url: shareDownloadURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["uuid": uuid]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

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

    static func check(uuid: String) async throws -> (exists: Bool, remainingSeconds: Int) {
        guard var components = URLComponents(url: shareCheckURL, resolvingAgainstBaseURL: false) else {
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
}
