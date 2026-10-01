import AVFoundation
import Foundation
import Speech

struct VoiceASRFileTranscriptionResult: Sendable {
    let transcript: String
    let alternatives: [String]
    let firstResultMilliseconds: Int?
    let finalResultMilliseconds: Int?
}

enum VoiceASRFileTranscriberError: LocalizedError {
    case speechAuthorizationDenied
    case recognizerUnavailable
    case noResult
    case localeUnsupported
    case modelUnavailable
    case emptyAudio

    var errorDescription: String? {
        switch self {
        case .speechAuthorizationDenied:
            return NSLocalizedString("voice_auth_speech", comment: "")
        case .recognizerUnavailable:
            return NSLocalizedString("voice_unavailable", comment: "")
        case .noResult:
            return NSLocalizedString("voice_unrecognized_format", comment: "")
        case .localeUnsupported, .modelUnavailable:
            return NSLocalizedString("voice_speech_transcriber_unavailable", comment: "")
        case .emptyAudio:
            return NSLocalizedString("voice_speech_transcriber_setup_failed", comment: "")
        }
    }
}

@MainActor
enum VoiceASRFileTranscriber {
    static func transcribeLegacy(url: URL, locale: Locale) async throws -> VoiceASRFileTranscriptionResult {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw VoiceASRFileTranscriberError.speechAuthorizationDenied
        }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw VoiceASRFileTranscriberError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        let startedAt = Date()

        return try await withCheckedThrowingContinuation { continuation in
            var firstResultMilliseconds: Int?
            var didFinish = false
            _ = recognizer.recognitionTask(with: request) { result, error in
                guard !didFinish else { return }
                if let error {
                    didFinish = true
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else { return }

                let elapsedMilliseconds = Int(Date().timeIntervalSince(startedAt) * 1000)
                if firstResultMilliseconds == nil {
                    firstResultMilliseconds = elapsedMilliseconds
                }
                guard result.isFinal else { return }

                didFinish = true
                let transcript = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !transcript.isEmpty else {
                    continuation.resume(throwing: VoiceASRFileTranscriberError.noResult)
                    return
                }
                continuation.resume(returning: VoiceASRFileTranscriptionResult(
                    transcript: transcript,
                    alternatives: [],
                    firstResultMilliseconds: firstResultMilliseconds,
                    finalResultMilliseconds: elapsedMilliseconds
                ))
            }
        }
    }

    @available(iOS 26.0, *)
    static func transcribeSpeechTranscriber(url: URL, locale: Locale, contextualStrings: [String] = []) async throws -> VoiceASRFileTranscriptionResult {
        guard SpeechTranscriber.isAvailable else {
            print("VOICE_ASR_DIAGNOSTIC,locale=\(locale.identifier),reason=transcriber_unavailable")
            throw VoiceASRFileTranscriberError.modelUnavailable
        }
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            print("VOICE_ASR_DIAGNOSTIC,locale=\(locale.identifier),reason=locale_unsupported")
            throw VoiceASRFileTranscriberError.localeUnsupported
        }

        let audioFile = try AVAudioFile(forReading: url)
        guard audioFile.length > 0 else {
            throw VoiceASRFileTranscriberError.emptyAudio
        }

        let profile = SpeechTranscriberProfile.forLocale(supportedLocale, live: false)
        let reservedLocales = await AssetInventory.reservedLocales
        let alreadyReserved = reservedLocales.contains { $0.identifier == supportedLocale.identifier }
        var reservedByTranscriber = false
        if !alreadyReserved {
            guard try await AssetInventory.reserve(locale: supportedLocale) else {
                print("VOICE_ASR_DIAGNOSTIC,locale=\(supportedLocale.identifier),reason=reserve_failed")
                throw VoiceASRFileTranscriberError.modelUnavailable
            }
            reservedByTranscriber = true
        }
        let currentReservedLocales = await AssetInventory.reservedLocales
        print("VOICE_ASR_DIAGNOSTIC,locale=\(supportedLocale.identifier),profile=\(profile.name),reserved=\(currentReservedLocales.map(\.identifier).joined(separator: "|")),maxReserved=\(AssetInventory.maximumReservedLocales)")

        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            transcriptionOptions: profile.transcriptionOptions,
            reportingOptions: profile.reportingOptions,
            attributeOptions: profile.attributeOptions
        )
        let status = await AssetInventory.status(forModules: [transcriber])
        print("VOICE_ASR_DIAGNOSTIC,locale=\(supportedLocale.identifier),assetStatus=\(String(describing: status))")
        do {
            switch status {
            case .unsupported:
                print("VOICE_ASR_DIAGNOSTIC,locale=\(supportedLocale.identifier),reason=asset_unsupported")
                throw VoiceASRFileTranscriberError.modelUnavailable
            case .supported, .downloading:
                guard let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
                    print("VOICE_ASR_DIAGNOSTIC,locale=\(supportedLocale.identifier),reason=installation_request_missing")
                    throw VoiceASRFileTranscriberError.modelUnavailable
                }
                try await installationRequest.downloadAndInstall()
            case .installed:
                break
            @unknown default:
                print("VOICE_ASR_DIAGNOSTIC,locale=\(supportedLocale.identifier),reason=asset_status_unknown")
                throw VoiceASRFileTranscriberError.modelUnavailable
            }
        } catch {
            if reservedByTranscriber {
                _ = await AssetInventory.release(reservedLocale: supportedLocale)
            }
            throw error
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let startedAt = Date()
        let resultTask = Task { () throws -> VoiceASRFileTranscriptionResult in
            var finalTranscript = ""
            var finalAlternatives: [String] = []
            var volatileTranscript = ""
            var firstResultMilliseconds: Int?
            var finalResultMilliseconds: Int?
            var resultCount = 0
            var alternativeCount = 0

            for try await result in transcriber.results {
                resultCount += 1
                alternativeCount += result.alternatives.count
                let text = String(result.text.characters)
                guard !text.isEmpty else { continue }
                let elapsedMilliseconds = Int(Date().timeIntervalSince(startedAt) * 1000)
                if firstResultMilliseconds == nil {
                    firstResultMilliseconds = elapsedMilliseconds
                }
                if result.isFinal {
                    finalTranscript = Self.appendTranscriptFragment(finalTranscript, text)
                    finalAlternatives = result.alternatives.map { String($0.characters) }
                    finalResultMilliseconds = elapsedMilliseconds
                    volatileTranscript = ""
                } else {
                    volatileTranscript = Self.appendTranscriptFragment("", text)
                }
            }

            let transcript = Self.appendTranscriptFragment(finalTranscript, volatileTranscript)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !transcript.isEmpty else {
                throw VoiceASRFileTranscriberError.noResult
            }
            print("VOICE_ASR_DIAGNOSTIC,locale=\(supportedLocale.identifier),results=\(resultCount),alternatives=\(alternativeCount),transcriptChars=\(transcript.count)")
            return VoiceASRFileTranscriptionResult(
                transcript: transcript,
                alternatives: finalAlternatives.filter { !$0.isEmpty && $0 != transcript },
                firstResultMilliseconds: firstResultMilliseconds,
                finalResultMilliseconds: finalResultMilliseconds ?? firstResultMilliseconds
            )
        }

        do {
            if !contextualStrings.isEmpty {
                let context = AnalysisContext()
                context.contextualStrings[.general] = contextualStrings
                try await analyzer.setContext(context)
            }
            if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
                try await analyzer.finalizeAndFinish(through: lastSample)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            let result = try await resultTask.value
            if reservedByTranscriber {
                _ = await AssetInventory.release(reservedLocale: supportedLocale)
                reservedByTranscriber = false
            }
            return result
        } catch {
            resultTask.cancel()
            await analyzer.cancelAndFinishNow()
            if reservedByTranscriber {
                _ = await AssetInventory.release(reservedLocale: supportedLocale)
            }
            throw error
        }
    }

    private static func appendTranscriptFragment(_ current: String, _ fragment: String) -> String {
        let current = current.trimmingCharacters(in: .whitespacesAndNewlines)
        let fragment = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !current.isEmpty else { return fragment }
        guard !fragment.isEmpty else { return current }
        if current.last?.isWhitespace == true || fragment.first?.isWhitespace == true {
            return current + fragment
        }
        return current + " " + fragment
    }
}
