import XCTest
@testable import BasketballRecord

final class VoiceASREngineTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: kVoiceASREngineKey)
        UserDefaults.standard.removeObject(forKey: kVoiceASREngineUpgradeNoticePendingKey)
        UserDefaults.standard.removeObject(forKey: "voice_asr_engine_migration_completed")
        super.tearDown()
    }

    func testMissingStoredEngineUsesSpeechTranscriber() {
        UserDefaults.standard.removeObject(forKey: kVoiceASREngineKey)

        XCTAssertEqual(VoiceASREngine.stored, .speechTranscriber)
        XCTAssertEqual(VoiceASREngine.effectiveStored, VoiceASREngine.speechTranscriber.isAvailableOnCurrentDevice ? .speechTranscriber : .legacySpeech)
    }

    func testStoredEngineRoundTrips() {
        UserDefaults.standard.set(VoiceASREngine.speechTranscriber.rawValue, forKey: kVoiceASREngineKey)

        XCTAssertEqual(VoiceASREngine.stored, .speechTranscriber)
    }

    func testUnknownStoredEngineUsesLegacySpeech() {
        UserDefaults.standard.set("unknown", forKey: kVoiceASREngineKey)

        XCTAssertEqual(VoiceASREngine.stored, .legacySpeech)
        XCTAssertEqual(VoiceASREngine.effectiveStored, .legacySpeech)
    }

    func testExistingUserWithLegacyEngineMigratesToSpeechTranscriber() {
        guard VoiceASREngine.speechTranscriber.isAvailableOnCurrentDevice else { return }

        UserDefaults.standard.set(VoiceASREngine.legacySpeech.rawValue, forKey: kVoiceASREngineKey)

        VoiceASREngine.migrateToSpeechTranscriberIfNeeded(hasExistingUserData: true)

        XCTAssertEqual(VoiceASREngine.stored, .speechTranscriber)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: kVoiceASREngineUpgradeNoticePendingKey))
    }

    func testNewUserDoesNotReceiveUpgradeNotice() {
        VoiceASREngine.migrateToSpeechTranscriberIfNeeded(hasExistingUserData: false)

        XCTAssertFalse(UserDefaults.standard.bool(forKey: kVoiceASREngineUpgradeNoticePendingKey))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "voice_asr_engine_migration_completed"))
    }

    func testEveryEngineHasStableIdentifierAndTitle() {
        XCTAssertEqual(Set(VoiceASREngine.allCases.map(\.id)).count, VoiceASREngine.allCases.count)
        XCTAssertEqual(VoiceASREngine.allCases.count, 2)
    }

    func testEveryLocaleProvidesSpeechContextVocabulary() {
        let locales = ["zh-Hans", "zh-Hant-TW", "en", "ja", "ko", "de", "es", "fr", "it", "ru"]
        for locale in locales {
            let rules = VoiceRules.forLocale(Locale(identifier: locale))
            let context = rules.contextualStrings(playerNames: ["Alex Morgan", "王Emma"])
            XCTAssertTrue(context.contains("Alex Morgan"), locale)
            XCTAssertTrue(context.contains(rules.commandEvents[0].keyword), locale)
            XCTAssertTrue(context.contains(rules.statEvents[0].keyword), locale)
        }
    }

    @available(iOS 26.0, *)
    func testSpeechTranscriberProfilesUseFastResultsForLiveRecognition() {
        for locale in ["zh-Hans", "en-US", "ja-JP", "ko-KR", "de-DE", "es-ES", "fr-FR", "it-IT", "ru-RU"] {
            let liveProfile = SpeechTranscriberProfile.forLocale(Locale(identifier: locale), live: true)
            let fileProfile = SpeechTranscriberProfile.forLocale(Locale(identifier: locale), live: false)
            XCTAssertTrue(liveProfile.reportingOptions.contains(.fastResults), locale)
            XCTAssertTrue(liveProfile.reportingOptions.contains(.volatileResults), locale)
            XCTAssertTrue(liveProfile.reportingOptions.contains(.alternativeTranscriptions), locale)
            XCTAssertFalse(fileProfile.reportingOptions.contains(.fastResults), locale)
            XCTAssertTrue(fileProfile.reportingOptions.contains(.alternativeTranscriptions), locale)
            XCTAssertTrue(fileProfile.attributeOptions.contains(.transcriptionConfidence), locale)
        }
    }
}
