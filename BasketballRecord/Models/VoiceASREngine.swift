import Foundation
import SwiftUI

let kVoiceASREngineKey = "voice_asr_engine"

enum VoiceASREngine: String, CaseIterable, Identifiable {
    case legacySpeech = "legacySpeech"
    case speechTranscriber = "speechTranscriber"

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .legacySpeech: return "settings_voice_asr_legacy"
        case .speechTranscriber: return "settings_voice_asr_speech_transcriber"
        }
    }

    var isAvailableOnCurrentOS: Bool {
        switch self {
        case .legacySpeech: return true
        case .speechTranscriber: return ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: 26, minorVersion: 0, patchVersion: 0))
        }
    }

    static var stored: VoiceASREngine {
        guard let value = UserDefaults.standard.string(forKey: kVoiceASREngineKey),
              let engine = VoiceASREngine(rawValue: value) else {
            return .legacySpeech
        }
        return engine
    }

    static var effectiveStored: VoiceASREngine {
        let engine = stored
        return engine.isAvailableOnCurrentOS ? engine : .legacySpeech
    }
}
