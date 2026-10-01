import XCTest
@testable import BasketballRecord

final class VoiceASREngineTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: kVoiceASREngineKey)
        super.tearDown()
    }

    func testMissingStoredEngineUsesLegacySpeech() {
        UserDefaults.standard.removeObject(forKey: kVoiceASREngineKey)

        XCTAssertEqual(VoiceASREngine.stored, .legacySpeech)
        XCTAssertEqual(VoiceASREngine.effectiveStored, .legacySpeech)
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
    func testSpeechTranscriberProfilesPreferAccuracyOverFastResults() {
        for locale in ["zh-Hans", "en-US", "ja-JP", "ko-KR", "de-DE", "es-ES", "fr-FR", "it-IT", "ru-RU"] {
            let profile = SpeechTranscriberProfile.forLocale(Locale(identifier: locale), live: false)
            XCTAssertFalse(profile.reportingOptions.contains(.fastResults), locale)
            XCTAssertTrue(profile.reportingOptions.contains(.alternativeTranscriptions), locale)
            XCTAssertTrue(profile.attributeOptions.contains(.transcriptionConfidence), locale)
        }
    }
}
