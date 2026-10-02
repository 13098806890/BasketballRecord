import Foundation
import Speech
import SwiftUI

let kVoiceASREngineKey = "voice_asr_engine"
let kVoiceASREngineUpgradeNoticePendingKey = "voice_asr_engine_upgrade_notice_pending"

private let kVoiceASREngineMigrationCompletedKey = "voice_asr_engine_migration_completed"

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

    var isAvailableOnCurrentDevice: Bool {
        guard isAvailableOnCurrentOS else { return false }
        if #available(iOS 26.0, *) {
            return SpeechTranscriber.isAvailable
        }
        return false
    }

    static func supportsSpeechLocale(_ locale: Locale) async -> Bool {
        guard speechTranscriber.isAvailableOnCurrentDevice else { return false }
        if #available(iOS 26.0, *) {
            return await SpeechTranscriber.supportedLocale(equivalentTo: locale) != nil
        }
        return false
    }

    static var stored: VoiceASREngine {
        guard let value = UserDefaults.standard.string(forKey: kVoiceASREngineKey) else {
            return .speechTranscriber
        }
        guard let engine = VoiceASREngine(rawValue: value) else {
            return .legacySpeech
        }
        return engine
    }

    static var effectiveStored: VoiceASREngine {
        let engine = stored
        return engine.isAvailableOnCurrentDevice ? engine : .legacySpeech
    }

    static func migrateToSpeechTranscriberIfNeeded(hasExistingUserData: Bool) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: kVoiceASREngineMigrationCompletedKey) else { return }

        guard hasExistingUserData else {
            defaults.set(true, forKey: kVoiceASREngineMigrationCompletedKey)
            return
        }

        guard speechTranscriber.isAvailableOnCurrentDevice else { return }

        let previousEngine = defaults.string(forKey: kVoiceASREngineKey).flatMap(VoiceASREngine.init(rawValue:)) ?? .legacySpeech
        defaults.set(speechTranscriber.rawValue, forKey: kVoiceASREngineKey)
        defaults.set(true, forKey: kVoiceASREngineMigrationCompletedKey)

        if previousEngine != .speechTranscriber {
            defaults.set(true, forKey: kVoiceASREngineUpgradeNoticePendingKey)
        }
    }
}
