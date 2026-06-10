import XCTest
@testable import BasketballRecord

final class VoiceRulesTests: XCTestCase {
    // Test that each language rule set has all required fields
    func testAllLanguagesHaveRequiredFields() {
        for rules in VoiceRules.allSupported {
            XCTAssertFalse(rules.shotKeywords.isEmpty, "\(rules.locale.identifier) shotKeywords")
            XCTAssertFalse(rules.madeStates.isEmpty, "\(rules.locale.identifier) madeStates")
            XCTAssertFalse(rules.missedStates.isEmpty, "\(rules.locale.identifier) missedStates")
            XCTAssertFalse(rules.statEvents.isEmpty, "\(rules.locale.identifier) statEvents")
            XCTAssertFalse(rules.substitutionKeywords.isEmpty, "\(rules.locale.identifier) substitutionKeywords")
            XCTAssertFalse(rules.commandEvents.isEmpty, "\(rules.locale.identifier) commandEvents")
        }
    }

    // MARK: - Chinese (Simplified)

    func testChineseShotMade() {
        let rules = VoiceRules.chinese
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "三分" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "两分" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "罚球" }))
        XCTAssertTrue(rules.madeStates.contains("命中"))
        XCTAssertTrue(rules.missedStates.contains("打铁"))
        XCTAssertTrue(rules.substitutionKeywords.contains("换"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "暂停" }))
        XCTAssertFalse(rules.fuzzyMap.isEmpty)
    }

    func testChineseColloquial() {
        let rules = VoiceRules.chinese
        // Natural spoken patterns
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "2分" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "3分" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "中距离" }))
        XCTAssertTrue(rules.missedStates.contains("没中"))
        XCTAssertTrue(rules.missedStates.contains("不进"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "抢断" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "完场" }))
    }

    // MARK: - Chinese (Traditional)

    func testTraditionalChinese() {
        let rules = VoiceRules.traditionalChinese
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "兩分" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "上籃" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "罰球" }))
        XCTAssertTrue(rules.madeStates.contains("進"))
        XCTAssertTrue(rules.missedStates.contains("沒中"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "犯規" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "失誤" }))
    }

    // MARK: - English

    func testEnglishShots() {
        let rules = VoiceRules.english
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "two" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "three" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "free throw" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "layup" }))
        XCTAssertTrue(rules.madeStates.contains("made"))
        XCTAssertTrue(rules.missedStates.contains("airball"))
    }

    func testEnglishColloquial() {
        let rules = VoiceRules.english
        XCTAssertTrue(rules.madeStates.contains("good"))
        XCTAssertTrue(rules.missedStates.contains("no"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "board" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "travel" }))
        XCTAssertTrue(rules.substitutionKeywords.contains("sub"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "tip off" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "game over" }))
    }

    func testEnglishNoFuzzyMap() {
        XCTAssertTrue(VoiceRules.english.fuzzyMap.isEmpty)
    }

    // MARK: - Japanese

    func testJapaneseShots() {
        let rules = VoiceRules.japanese
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "スリー" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "フリースロー" }))
        XCTAssertTrue(rules.madeStates.contains("入った"))
        XCTAssertTrue(rules.madeStates.contains("決まった"))
        XCTAssertTrue(rules.missedStates.contains("外した"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "リバウンド" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "ターンオーバー" }))
        XCTAssertTrue(rules.substitutionKeywords.contains("交代"))
    }

    func testJapaneseColloquial() {
        let rules = VoiceRules.japanese
        // Common short forms
        XCTAssertTrue(rules.missedStates.contains("ミス"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "タイムアウト" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "試合終了" }))
    }

    // MARK: - Korean

    func testKoreanShots() {
        let rules = VoiceRules.korean
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "쓰리" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "자유투" }))
        XCTAssertTrue(rules.madeStates.contains("성공"))
        XCTAssertTrue(rules.missedStates.contains("실패"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "리바운드" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "턴오버" }))
        XCTAssertTrue(rules.substitutionKeywords.contains("교체"))
    }

    func testKoreanColloquial() {
        let rules = VoiceRules.korean
        XCTAssertTrue(rules.missedStates.contains("빗나감"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "타임아웃" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "경기종료" }))
    }

    // MARK: - German

    func testGermanShots() {
        let rules = VoiceRules.german
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "zwei" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "drei" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "freiwurf" }))
        XCTAssertTrue(rules.madeStates.contains("getroffen"))
        XCTAssertTrue(rules.missedStates.contains("daneben"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "assist" }))
    }

    func testGermanColloquial() {
        let rules = VoiceRules.german
        XCTAssertTrue(rules.madeStates.contains("drin"))    // casual "drin!" for made shot
        XCTAssertTrue(rules.missedStates.contains("verfehlt"))
        XCTAssertTrue(rules.substitutionKeywords.contains("wechsel"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "auszeit" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "spielende" }))
    }

    // MARK: - Spanish

    func testSpanishShots() {
        let rules = VoiceRules.spanish
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "dos" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "tres" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "bandeja" }))
        XCTAssertTrue(rules.madeStates.contains("encestado"))
        XCTAssertTrue(rules.missedStates.contains("fallado"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "asistencia" }))
    }

    func testSpanishColloquial() {
        let rules = VoiceRules.spanish
        XCTAssertTrue(rules.madeStates.contains("dentro"))      // "dentro!" = it's in!
        XCTAssertTrue(rules.missedStates.contains("fuera"))     // "fuera" = out
        XCTAssertTrue(rules.substitutionKeywords.contains("cambio"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "tiempo muerto" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "fin del partido" }))
    }

    // MARK: - French

    func testFrenchShots() {
        let rules = VoiceRules.french
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "deux" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "trois" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "lancer franc" }))
        XCTAssertTrue(rules.madeStates.contains("marqué"))
        XCTAssertTrue(rules.missedStates.contains("raté"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "rebond" }))
    }

    func testFrenchColloquial() {
        let rules = VoiceRules.french
        XCTAssertTrue(rules.madeStates.contains("dedans"))          // "dedans!" = inside!
        XCTAssertTrue(rules.missedStates.contains("dehors"))        // "dehors" = outside
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "interception" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "perte de balle" }))
        XCTAssertTrue(rules.substitutionKeywords.contains("remplacement"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "temps mort" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "fin du match" }))
    }

    // MARK: - Italian

    func testItalianShots() {
        let rules = VoiceRules.italian
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "due" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "tre" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "tiro libero" }))
        XCTAssertTrue(rules.madeStates.contains("segnato"))
        XCTAssertTrue(rules.missedStates.contains("sbagliato"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "rimbalzo" }))
    }

    func testItalianColloquial() {
        let rules = VoiceRules.italian
        XCTAssertTrue(rules.madeStates.contains("dentro"))           // "dentro!" = inside!
        XCTAssertTrue(rules.missedStates.contains("fuori"))          // "fuori" = out
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "palla rubata" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "perse" }))
        XCTAssertTrue(rules.substitutionKeywords.contains("cambio"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "fine partita" }))
    }

    // MARK: - Russian

    func testRussianShots() {
        let rules = VoiceRules.russian
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "два" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "три" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "штрафной" }))
        XCTAssertTrue(rules.madeStates.contains("забил"))
        XCTAssertTrue(rules.missedStates.contains("промах"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "подбор" }))
    }

    func testRussianColloquial() {
        let rules = VoiceRules.russian
        XCTAssertTrue(rules.madeStates.contains("попал"))            // "попал!" = (he) hit it!
        XCTAssertTrue(rules.missedStates.contains("мимо"))           // "мимо" = past/by (missed)
        XCTAssertTrue(rules.missedStates.contains("заблокировали"))  // blocked
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "перехват" }))
        XCTAssertTrue(rules.substitutionKeywords.contains("замена"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "тайм-аут" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "конец игры" }))
    }

    // MARK: - No Cross-Contamination

    func testLanguagesAreIndependent() {
        // Chinese-specific phrases should not appear in English
        for kw in VoiceRules.chinese.shotKeywords {
            XCTAssertFalse(VoiceRules.english.shotKeywords.contains(where: { $0.keyword == kw.keyword }),
                          "English should not contain Chinese shot keyword: \(kw.keyword)")
        }
        // English 'good' should not be a Chinese made state
        XCTAssertFalse(VoiceRules.chinese.madeStates.contains("good"))
        XCTAssertFalse(VoiceRules.chinese.madeStates.contains("made"))
    }

    func testLocaleDetection() {
        // Verify each language variant has a matching rule
        let localePairs: [(bundleId: String, ruleLocale: String)] = [
            ("zh-Hans", "zh-CN"), ("en", "en-US"), ("ja", "ja-JP"), ("ko", "ko-KR"),
            ("de", "de-DE"), ("es", "es-ES"), ("fr", "fr-FR"), ("it", "it-IT"), ("ru", "ru-RU"),
            ("zh-Hant-TW", "zh-Hant-TW"),
        ]
        for (bundleId, ruleLocale) in localePairs {
            let found = VoiceRules.allSupported.first(where: { $0.locale.identifier == ruleLocale })
            XCTAssertNotNil(found, "No rules for bundle locale: \(bundleId) → expected rule locale: \(ruleLocale)")
        }
    }
}
