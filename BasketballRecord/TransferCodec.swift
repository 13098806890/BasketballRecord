import Foundation

private enum TransferSerialization: UInt8, CaseIterable {
    case json = 1
    case plist = 2
}

private enum TransferCompression: UInt8, CaseIterable {
    case lzma = 1
    case lzfse = 2
    case zlib = 3

    var algorithm: NSData.CompressionAlgorithm {
        switch self {
        case .lzma:
            return .lzma
        case .lzfse:
            return .lzfse
        case .zlib:
            return .zlib
        }
    }
}

private struct TransferEnvelopeFormat {
    let serialization: TransferSerialization
    let compression: TransferCompression

    var headerByte: UInt8 {
        (serialization.rawValue << 4) | compression.rawValue
    }

    init(serialization: TransferSerialization, compression: TransferCompression) {
        self.serialization = serialization
        self.compression = compression
    }

    init?(headerByte: UInt8) {
        let serializationRaw = (headerByte & 0xF0) >> 4
        let compressionRaw = headerByte & 0x0F

        guard let serialization = TransferSerialization(rawValue: serializationRaw),
              let compression = TransferCompression(rawValue: compressionRaw) else {
            return nil
        }

        self.serialization = serialization
        self.compression = compression
    }
}

enum TransferCodec {
    static func encode<T: Encodable>(_ value: T) -> String? {
        let sourceCandidates = serializedCandidates(for: value)
        guard !sourceCandidates.isEmpty else { return nil }

        var bestEnvelope: Data?

        for (serialization, sourceData) in sourceCandidates {
            for compression in TransferCompression.allCases {
                guard let compressed = compress(sourceData, using: compression) else { continue }

                var envelope = Data(capacity: compressed.count + 1)
                envelope.append(TransferEnvelopeFormat(serialization: serialization, compression: compression).headerByte)
                envelope.append(compressed)

                if let currentBest = bestEnvelope {
                    if envelope.count < currentBest.count {
                        bestEnvelope = envelope
                    }
                } else {
                    bestEnvelope = envelope
                }
            }
        }

        guard let bestEnvelope else { return nil }
        return bestEnvelope.base64URLEncodedString()
    }

    static func decode<T: Decodable>(_ text: String, as type: T.Type) -> T? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let envelope = Data(base64URLEncoded: trimmed),
              let headerByte = envelope.first,
              let format = TransferEnvelopeFormat(headerByte: headerByte) else {
            return nil
        }

        let compressedPayload = Data(envelope.dropFirst())
        guard let sourceData = decompress(compressedPayload, using: format.compression) else {
            return nil
        }

        switch format.serialization {
        case .json:
            return try? JSONDecoder().decode(type, from: sourceData)
        case .plist:
            return try? PropertyListDecoder().decode(type, from: sourceData)
        }
    }

    private static func serializedCandidates<T: Encodable>(for value: T) -> [(TransferSerialization, Data)] {
        var candidates: [(TransferSerialization, Data)] = []

        if let jsonData = try? JSONEncoder().encode(value) {
            candidates.append((.json, jsonData))
        }

        let plistEncoder = PropertyListEncoder()
        plistEncoder.outputFormat = .binary
        if let plistData = try? plistEncoder.encode(value) {
            candidates.append((.plist, plistData))
        }

        return candidates
    }

    private static func compress(_ data: Data, using compression: TransferCompression) -> Data? {
        try? (data as NSData).compressed(using: compression.algorithm) as Data
    }

    private static func decompress(_ data: Data, using compression: TransferCompression) -> Data? {
        try? (data as NSData).decompressed(using: compression.algorithm) as Data
    }
}

private extension Data {
    init?(base64URLEncoded value: String) {
        var normalized = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = normalized.count % 4
        if remainder > 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }

        self.init(base64Encoded: normalized)
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
