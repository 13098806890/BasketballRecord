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

struct GameShareChunk: Hashable {
    var transferID: String
    var partIndex: Int
    var totalParts: Int
    var checksum: String
    var payload: String
    var rawLine: String
}

struct GameShareAssembledPayload {
    var transferID: String
    var totalParts: Int
    var payload: String
}

enum GameShareChunkAssembleResult {
    case success(GameShareAssembledPayload)
    case failure(String)
}

enum GameShareChunkCodec {
    static let keyword = "篮球生涯手账-比赛导出"
    static let teamKeyword = "篮球生涯手账-球队导出"
    static let playerKeyword = "篮球生涯手账-球员导出"
    static let scheme = "BSG2"

    static func generateTransferID() -> String {
        String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
    }

    static func makeChunkLines(
        payload: String,
        preferredParts: Int,
        transferID: String,
        keyword: String = keyword
    ) -> [String] {
        let trimmedPayload = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPayload.isEmpty else { return [] }

        let totalParts = min(max(preferredParts, 1), max(trimmedPayload.count, 1))
        let chunks = split(trimmedPayload, count: totalParts)
        guard !chunks.isEmpty else { return [] }

        return chunks.enumerated().map { offset, chunk in
            let part = offset + 1
            let checksum = checksumHex(for: chunk)
            return "\(keyword)-\(part)/\(totalParts):\(scheme)|id=\(transferID)|crc=\(checksum)|\(chunk)"
        }
    }

    static func parseChunkLine(_ text: String, expectedKeyword: String = keyword) -> GameShareChunk? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let segments = trimmed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard segments.count == 2 else { return nil }

        let title = String(segments[0])
        let body = String(segments[1])

        let prefix = "\(expectedKeyword)-"
        guard title.hasPrefix(prefix) else { return nil }

        let partInfo = String(title.dropFirst(prefix.count))
        let partNumbers = partInfo.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
        guard partNumbers.count == 2,
              let partIndex = Int(partNumbers[0]),
              let totalParts = Int(partNumbers[1]),
              partIndex >= 1,
              totalParts >= 1,
              partIndex <= totalParts else {
            return nil
        }

        let fields = body.split(separator: "|", maxSplits: 3, omittingEmptySubsequences: false)
        guard fields.count == 4,
              fields[0] == Substring(scheme) else {
            return nil
        }

        let idField = String(fields[1])
        let crcField = String(fields[2])
        let payload = String(fields[3])

        guard idField.hasPrefix("id="), crcField.hasPrefix("crc=") else {
            return nil
        }

        let transferID = String(idField.dropFirst(3)).uppercased()
        let checksum = String(crcField.dropFirst(4)).uppercased()
        guard !transferID.isEmpty, !payload.isEmpty else {
            return nil
        }

        guard checksumHex(for: payload) == checksum else {
            return nil
        }

        return GameShareChunk(
            transferID: transferID,
            partIndex: partIndex,
            totalParts: totalParts,
            checksum: checksum,
            payload: payload,
            rawLine: trimmed
        )
    }

    static func parseChunks(in text: String, expectedKeyword: String = keyword) -> [GameShareChunk] {
        text
            .components(separatedBy: .newlines)
            .compactMap { parseChunkLine($0, expectedKeyword: expectedKeyword) }
    }

    static func looksLikeChunkText(_ text: String, keyword: String = keyword) -> Bool {
        text.contains(keyword) && text.contains(scheme)
    }

    static func assemblePayload(from lines: [String], expectedKeyword: String = keyword) -> GameShareChunkAssembleResult {
        let nonEmptyLines = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !nonEmptyLines.isEmpty else {
            return .failure("请先粘贴完整分段编码。")
        }

        var chunks: [GameShareChunk] = []
        for (index, line) in nonEmptyLines.enumerated() {
            guard let chunk = parseChunkLine(line, expectedKeyword: expectedKeyword) else {
                return .failure("第\(index + 1)段格式错误或校验失败，请确认复制完整。")
            }
            chunks.append(chunk)
        }

        guard let first = chunks.first else {
            return .failure("未识别到有效分段编码。")
        }

        for chunk in chunks {
            guard chunk.transferID == first.transferID else {
                return .failure("检测到不同批次的分段编码（id 不一致）。")
            }
            guard chunk.totalParts == first.totalParts else {
                return .failure("检测到分段总数不一致，请检查是否混入了其他比赛编码。")
            }
        }

        let grouped = Dictionary(grouping: chunks, by: \.partIndex)
        for part in 1...first.totalParts {
            guard let partChunks = grouped[part], !partChunks.isEmpty else {
                return .failure("缺少第\(part)/\(first.totalParts)段编码。")
            }
            if partChunks.count > 1 {
                return .failure("第\(part)/\(first.totalParts)段重复，请仅保留一条。")
            }
        }

        let orderedPayload = (1...first.totalParts)
            .compactMap { grouped[$0]?.first?.payload }
            .joined()

        return .success(
            GameShareAssembledPayload(
                transferID: first.transferID,
                totalParts: first.totalParts,
                payload: orderedPayload
            )
        )
    }

    private static func split(_ text: String, count: Int) -> [String] {
        guard count > 0 else { return [] }

        let totalLength = text.count
        let baseSize = totalLength / count
        let remainder = totalLength % count

        var chunks: [String] = []
        chunks.reserveCapacity(count)

        var start = text.startIndex
        for index in 0..<count {
            let size = baseSize + (index < remainder ? 1 : 0)
            let end = text.index(start, offsetBy: size)
            chunks.append(String(text[start..<end]))
            start = end
        }

        return chunks
    }

    private static func checksumHex(for payload: String) -> String {
        let crc = crc16CCITT(payload.utf8)
        return String(format: "%04X", crc)
    }

    private static func crc16CCITT<S: Sequence>(_ bytes: S) -> UInt16 where S.Element == UInt8 {
        var crc: UInt16 = 0xFFFF
        for byte in bytes {
            crc ^= UInt16(byte) << 8
            for _ in 0..<8 {
                if (crc & 0x8000) != 0 {
                    crc = (crc << 1) ^ 0x1021
                } else {
                    crc <<= 1
                }
            }
        }
        return crc
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
