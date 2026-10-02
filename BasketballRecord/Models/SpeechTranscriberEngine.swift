import AVFoundation
import Foundation
import OSLog
import Speech

@available(iOS 26.0, *)
struct SpeechTranscriberProfile: Sendable {
    let name: String
    let reportingOptions: Set<SpeechTranscriber.ReportingOption>
    let transcriptionOptions: Set<SpeechTranscriber.TranscriptionOption>
    let attributeOptions: Set<SpeechTranscriber.ResultAttributeOption>

    static func forLocale(_ locale: Locale, live: Bool) -> SpeechTranscriberProfile {
        let languageCode = locale.language.languageCode?.identifier ?? locale.identifier.split(separator: "-").first.map(String.init) ?? locale.identifier
        let name: String
        switch languageCode {
        case "zh": name = "cjk-accurate"
        case "ja": name = "japanese-accurate"
        case "ko": name = "korean-accurate"
        case "en": name = "english-accurate"
        case "de", "es", "fr", "it", "ru": name = "latin-accurate"
        default: name = "default-accurate"
        }
        return SpeechTranscriberProfile(
            name: live ? name + "-live" : name + "-file",
            reportingOptions: live ? [.volatileResults, .fastResults, .alternativeTranscriptions] : [.alternativeTranscriptions],
            transcriptionOptions: [],
            attributeOptions: [.transcriptionConfidence]
        )
    }
}

@available(iOS 26.0, *)
private final class SpeechTranscriberInputTimeline: @unchecked Sendable {
    private let lock = NSLock()
    private let sampleRate: CMTimeScale
    private var endTime = CMTime.zero
    private var hasInput = false

    init(sampleRate: Double) {
        self.sampleRate = CMTimeScale(sampleRate.rounded())
    }

    func append(frameCount: AVAudioFrameCount) -> CMTime {
        lock.lock()
        defer { lock.unlock() }
        let startTime = endTime
        let duration = CMTime(value: CMTimeValue(frameCount), timescale: sampleRate)
        endTime = CMTimeAdd(endTime, duration)
        hasInput = hasInput || frameCount > 0
        return startTime
    }

    func end() -> CMTime? {
        lock.lock()
        defer { lock.unlock() }
        guard hasInput else { return nil }
        let lastSampleDuration = CMTime(value: 1, timescale: sampleRate)
        return CMTimeSubtract(endTime, lastSampleDuration)
    }
}

@available(iOS 26.0, *)
@MainActor
final class SpeechTranscriberEngine {
    enum EngineError: LocalizedError {
        case unavailable
        case localeUnsupported
        case modelUnavailable
        case setupFailed

        var errorDescription: String? {
            switch self {
            case .unavailable, .localeUnsupported, .modelUnavailable:
                return NSLocalizedString("voice_speech_transcriber_unavailable", comment: "")
            case .setupFailed:
                return NSLocalizedString("voice_speech_transcriber_setup_failed", comment: "")
            }
        }
    }

    var onResult: ((String, [String], Bool) -> Void)?
    var onError: ((Error) -> Void)?
    var onFinished: (() -> Void)?

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BasketballRecord", category: "SpeechTranscriber")
    private var audioEngine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultTask: Task<Void, Never>?
    private var stopRequested = false
    private var reservedLocale: Locale?
    private var preparedLocale: Locale?
    private var preparedAudioFormat: AVAudioFormat?
    private var inputTimeline: SpeechTranscriberInputTimeline?
    private var recordingStartedAt: Date?
    private var stopRequestedAt: Date?

    func prepare(locale: Locale) async throws {
        logger.info("xdz prepare requested locale=\(locale.identifier, privacy: .public)")
        guard SpeechTranscriber.isAvailable else { throw EngineError.unavailable }
        guard let supportedLocale = await SpeechTranscriber.supportedLocale(equivalentTo: locale) else {
            logger.error("prepare locale unsupported requested=\(locale.identifier, privacy: .public)")
            throw EngineError.localeUnsupported
        }
        if let preparedLocale, preparedLocale.identifier == supportedLocale.identifier {
            return
        }
        if let preparedLocale, preparedLocale.identifier != supportedLocale.identifier {
            await releaseReservedLocale()
            self.preparedLocale = nil
        }

        let profile = SpeechTranscriberProfile.forLocale(supportedLocale, live: true)
        let reservedLocales = await AssetInventory.reservedLocales
        if !reservedLocales.contains(where: { $0.identifier == supportedLocale.identifier }) {
            guard try await AssetInventory.reserve(locale: supportedLocale) else {
                logger.error("prepare locale reservation failed locale=\(supportedLocale.identifier, privacy: .public)")
                throw EngineError.modelUnavailable
            }
            reservedLocale = supportedLocale
        }

        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            transcriptionOptions: profile.transcriptionOptions,
            reportingOptions: profile.reportingOptions,
            attributeOptions: profile.attributeOptions
        )
        let status = await AssetInventory.status(forModules: [transcriber])
        logger.info("prepare asset status=\(String(describing: status), privacy: .public) locale=\(supportedLocale.identifier, privacy: .public)")
        do {
            switch status {
            case .unsupported:
                await releaseReservedLocale()
                throw EngineError.modelUnavailable
            case .supported, .downloading:
                guard let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) else {
                    await releaseReservedLocale()
                    throw EngineError.modelUnavailable
                }
                try await installationRequest.downloadAndInstall()
            case .installed:
                break
            @unknown default:
                await releaseReservedLocale()
                throw EngineError.modelUnavailable
            }
        } catch {
            await releaseReservedLocale()
            throw error
        }
        if let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) {
            let analyzerOptions = SpeechAnalyzer.Options(
                priority: .userInitiated,
                modelRetention: .lingering
            )
            let analyzer = SpeechAnalyzer(modules: [transcriber], options: analyzerOptions)
            try await analyzer.prepareToAnalyze(in: analyzerFormat)
            preparedAudioFormat = analyzerFormat
        }
        preparedLocale = supportedLocale
    }

    func start(locale: Locale, contextualStrings: [String] = []) async throws {
        logger.info("xdz start requested locale=\(locale.identifier, privacy: .public) available=\(SpeechTranscriber.isAvailable, privacy: .public)")
        stopRequested = false
        try Task.checkCancellation()
        try await prepare(locale: locale)
        guard !Task.isCancelled else {
            await releaseReservedLocale()
            return
        }
        guard let supportedLocale = preparedLocale else { throw EngineError.modelUnavailable }
        let profile = SpeechTranscriberProfile.forLocale(supportedLocale, live: true)
        let reservedLocales = await AssetInventory.reservedLocales
        logger.info("profile=\(profile.name, privacy: .public) supportedLocale=\(supportedLocale.identifier, privacy: .public) reserved=\(reservedLocales.map(\.identifier).joined(separator: ","), privacy: .public)")
        let transcriber = SpeechTranscriber(
            locale: supportedLocale,
            transcriptionOptions: profile.transcriptionOptions,
            reportingOptions: profile.reportingOptions,
            attributeOptions: profile.attributeOptions
        )
        let analyzerOptions = SpeechAnalyzer.Options(
            priority: .userInitiated,
            modelRetention: .lingering
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber], options: analyzerOptions)

        guard !stopRequested else {
            await releaseReservedLocale()
            return
        }
        let analyzerFormat: AVAudioFormat?
        if let preparedAudioFormat {
            analyzerFormat = preparedAudioFormat
        } else {
            analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber])
        }
        guard let analyzerFormat else {
            throw EngineError.setupFailed
        }
        let (inputSequence, inputContinuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.transcriber = transcriber
        self.analyzer = analyzer
        self.inputContinuation = inputContinuation

        do {
            if !contextualStrings.isEmpty {
                let context = AnalysisContext()
                context.contextualStrings[.general] = contextualStrings
                try await analyzer.setContext(context)
            }
            try Task.checkCancellation()
            guard !stopRequested else {
                self.inputContinuation?.finish()
                self.inputContinuation = nil
                await analyzer.cancelAndFinishNow()
                await releaseReservedLocale()
                return
            }
            try await analyzer.prepareToAnalyze(in: analyzerFormat)
            try Task.checkCancellation()
            guard !stopRequested else {
                self.inputContinuation?.finish()
                self.inputContinuation = nil
                await analyzer.cancelAndFinishNow()
                await releaseReservedLocale()
                return
            }
            try await analyzer.start(inputSequence: inputSequence)
            recordingStartedAt = Date()
        } catch {
            self.inputContinuation?.finish()
            self.inputContinuation = nil
            self.analyzer = nil
            self.transcriber = nil
            await analyzer.cancelAndFinishNow()
            await releaseReservedLocale()
            throw error
        }
        guard !stopRequested else {
            await analyzer.cancelAndFinishNow()
            await releaseReservedLocale()
            return
        }

        resultTask = Task { [weak self, transcriber] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    guard !text.isEmpty else { continue }
                    let alternatives = result.alternatives.map { String($0.characters) }.filter { !$0.isEmpty && $0 != text }
                    self?.logger.debug("result final=\(result.isFinal, privacy: .public) chars=\(text.count, privacy: .public) alternatives=\(alternatives.count, privacy: .public)")
                    self?.onResult?(text, alternatives, result.isFinal)
                }
            } catch {
                self?.logger.error("result stream failed error=\(error.localizedDescription, privacy: .public)")
                self?.onError?(error)
            }
        }

        let engine = AVAudioEngine()
        let engineInputNode = engine.inputNode
        let engineFormat = engineInputNode.outputFormat(forBus: 0)
        guard engineFormat.sampleRate > 0, engineFormat.channelCount > 0 else {
            self.inputContinuation?.finish()
            self.inputContinuation = nil
            resultTask?.cancel()
            resultTask = nil
            self.analyzer = nil
            self.transcriber = nil
            await analyzer.cancelAndFinishNow()
            await releaseReservedLocale()
            throw EngineError.setupFailed
        }
        let continuation = inputContinuation
        let inputTimeline = SpeechTranscriberInputTimeline(sampleRate: analyzerFormat.sampleRate)
        self.inputTimeline = inputTimeline
        let converter = engineFormat.sampleRate == analyzerFormat.sampleRate && engineFormat.channelCount == analyzerFormat.channelCount
            ? nil
            : AVAudioConverter(from: engineFormat, to: analyzerFormat)

        engineInputNode.removeTap(onBus: 0)
        engineInputNode.installTap(onBus: 0, bufferSize: 512, format: engineFormat) { buffer, _ in
            if let converter {
                let ratio = analyzerFormat.sampleRate / engineFormat.sampleRate
                let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
                guard let converted = AVAudioPCMBuffer(pcmFormat: analyzerFormat, frameCapacity: capacity) else { return }
                var conversionError: NSError?
                var supplied = false
                converter.convert(to: converted, error: &conversionError) { _, status in
                    if supplied {
                        status.pointee = .noDataNow
                        return nil
                    }
                    supplied = true
                    status.pointee = .haveData
                    return buffer
                }
                guard conversionError == nil else { return }
                let bufferStartTime = inputTimeline.append(frameCount: converted.frameLength)
                continuation.yield(AnalyzerInput(buffer: converted, bufferStartTime: bufferStartTime))
            } else {
                let bufferStartTime = inputTimeline.append(frameCount: buffer.frameLength)
                continuation.yield(AnalyzerInput(buffer: buffer, bufferStartTime: bufferStartTime))
            }
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try await AudioSessionActivation.activate(audioSession)
            try Task.checkCancellation()
            guard !stopRequested else {
                engineInputNode.removeTap(onBus: 0)
                self.inputContinuation?.finish()
                self.inputContinuation = nil
                await analyzer.cancelAndFinishNow()
                await releaseReservedLocale()
                return
            }
            try engine.start()
            audioEngine = engine
        } catch {
            engineInputNode.removeTap(onBus: 0)
            self.inputContinuation?.finish()
            self.inputContinuation = nil
            resultTask?.cancel()
            resultTask = nil
            self.inputTimeline = nil
            self.analyzer = nil
            self.transcriber = nil
            await analyzer.cancelAndFinishNow()
            await releaseReservedLocale()
            throw error
        }
    }

    func requestStop() {
        stopRequested = true
        stopRequestedAt = Date()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        inputContinuation?.finish()
        inputContinuation = nil

        guard let analyzer else {
            onFinished?()
            return
        }
        let finalizationEndTime = inputTimeline?.end()
        self.analyzer = nil
        Task {
            if let finalizationEndTime {
                try? await analyzer.finalizeAndFinish(through: finalizationEndTime)
            } else {
                try? await analyzer.finalizeAndFinishThroughEndOfInput()
            }
            await resultTask?.value
            let elapsedMilliseconds = stopRequestedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
            let totalMilliseconds = recordingStartedAt.map { Int(Date().timeIntervalSince($0) * 1000) } ?? 0
            logger.info("xdz finish completed stopToFinishMs=\(elapsedMilliseconds, privacy: .public) recordingMs=\(totalMilliseconds, privacy: .public)")
            self.transcriber = nil
            self.resultTask = nil
            self.inputTimeline = nil
            self.recordingStartedAt = nil
            self.stopRequestedAt = nil
            self.onFinished?()
        }
    }

    func cancel() {
        Task {
            await releasePreparedResources()
        }
    }

    func releasePreparedResources() async {
        stopRequested = true
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        inputContinuation?.finish()
        inputContinuation = nil
        resultTask?.cancel()
        resultTask = nil
        inputTimeline = nil
        let analyzer = self.analyzer
        self.analyzer = nil
        self.transcriber = nil
        if let analyzer {
            await analyzer.cancelAndFinishNow()
        }
        await releaseReservedLocale()
    }

    private func releaseReservedLocale() async {
        guard let reservedLocale else {
            preparedLocale = nil
            preparedAudioFormat = nil
            return
        }
        _ = await AssetInventory.release(reservedLocale: reservedLocale)
        let remainingLocales = await AssetInventory.reservedLocales
        logger.info("locale released locale=\(reservedLocale.identifier, privacy: .public) remaining=\(remainingLocales.map(\.identifier).joined(separator: ","), privacy: .public)")
        self.reservedLocale = nil
        self.preparedLocale = nil
        self.preparedAudioFormat = nil
    }
}
