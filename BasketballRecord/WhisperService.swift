import Foundation
import whisper
import AVFoundation

@MainActor
final class WhisperService {
    static let shared = WhisperService()

    private var ctx: OpaquePointer?
    private var isLoaded = false
    private let modelName = "ggml-tiny"

    var isAvailable: Bool { isLoaded && ctx != nil }

    func loadModel() -> Bool {
        guard !isLoaded else { return true }

        guard let modelPath = Bundle.main.path(forResource: modelName, ofType: "bin") else {
            // Try Documents directory
            let docsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let modelURL = docsPath.appendingPathComponent("\(modelName).bin")
            guard FileManager.default.fileExists(atPath: modelURL.path) else {
                print("[Whisper] Model not found")
                return false
            }
            let params = whisper_context_defaults()
            guard let c = whisper_init_from_file_with_params(modelURL.path, params) else {
                print("[Whisper] Failed to init model")
                return false
            }
            ctx = c
            isLoaded = true
            return true
        }

        let params = whisper_context_defaults()
        guard let c = whisper_init_from_file_with_params(modelPath, params) else {
            print("[Whisper] Failed to init model")
            return false
        }
        ctx = c
        isLoaded = true
        print("[Whisper] Model loaded successfully")
        return true
    }

    func transcribe(_ audioData: Data, sampleRate: Int = 16000) -> String? {
        guard let ctx else { return nil }

        let frameCount = audioData.count / MemoryLayout<Float>.stride
        var pcmData = [Float](repeating: 0, count: frameCount)
        audioData.withUnsafeBytes { ptr in
            guard let base = ptr.baseAddress else { return }
            pcmData = Array(UnsafeBufferPointer(start: base.assumingMemoryBound(to: Float.self), count: frameCount))
        }

        var wparams = whisper_full_defaults(WHISPER_SAMPLING_GREEDY)
        wparams.print_realtime = false
        wparams.print_progress = false
        wparams.print_timestamps = false
        wparams.print_special = false
        wparams.translate = false
        wparams.language = nil  // auto-detect
        wparams.n_threads = 4
        wparams.offset_ms = 0
        wparams.no_context = true

        let ret = whisper_full(ctx, wparams, pcmData, Int32(frameCount))
        guard ret == 0 else {
            print("[Whisper] whisper_full failed: \(ret)")
            return nil
        }

        let nSegments = whisper_full_n_segments(ctx)
        var result = ""
        for i in 0..<nSegments {
            if let text = whisper_full_get_segment_text(ctx, i) {
                let segment = String(cString: text)
                result += segment
            }
        }
        return result.isEmpty ? nil : result.trimmingCharacters(in: .whitespaces)
    }

    func unload() {
        guard let ctx else { return }
        whisper_free(ctx)
        self.ctx = nil
        isLoaded = false
    }

    deinit {
        unload()
    }
}
