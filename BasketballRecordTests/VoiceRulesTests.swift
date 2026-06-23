import XCTest
@testable import BasketballRecord

final class VoiceRulesTests: XCTestCase {
    // Test that each language rule set has all required fields
    func testAllLanguagesHaveRequiredFields() {
        for rules in VoiceRules.allSupported {
            XCTAssertFalse(rules.shotKeywords.isEmpty, "\(rules.locale.identifier) shotKeywords")
            // Only CJK languages have madeStates; others rely on keyword-only → default made
            if ["zh-CN", "zh-Hant-TW"].contains(rules.locale.identifier) {
                XCTAssertFalse(rules.madeStates.isEmpty, "\(rules.locale.identifier) madeStates")
            }
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
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "暂停" }))
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
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "two pointer" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "three" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "trey" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "free throw" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "layup" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "jumper" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "pull up" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "post up" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "and one" }))
        XCTAssertTrue(rules.missedStates.contains("airball"))
        XCTAssertTrue(rules.missedStates.contains("brick"))
        XCTAssertTrue(rules.missedStates.contains("short"))
    }

    func testEnglishColloquial() {
        let rules = VoiceRules.english
        XCTAssertTrue(rules.missedStates.contains("no"))
        XCTAssertTrue(rules.missedStates.contains("not"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "board" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "glass" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "dime" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "travel" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "walk" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "carry" }))
        XCTAssertTrue(rules.substitutionKeywords.contains("sub"))
        XCTAssertTrue(rules.substitutionKeywords.contains("switch"))
        XCTAssertTrue(rules.substitutionKeywords.contains("in for"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "tip off" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "jump ball" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "game over" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "next quarter" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "final" }))
    }

    func testEnglishNoFuzzyMap() {
        XCTAssertTrue(VoiceRules.english.fuzzyMap.isEmpty)
    }

    // MARK: - Japanese

    func testJapaneseShots() {
        let rules = VoiceRules.japanese
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "スリー" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "スリーポイント" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "フリースロー" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "フリー" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "ミドルレンジ" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "アンドワン" }))
        XCTAssertTrue(rules.missedStates.contains("外した"))
        XCTAssertTrue(rules.missedStates.contains("入らない"))
        XCTAssertTrue(rules.missedStates.contains("失敗"))
    }

    func testJapaneseColloquial() {
        let rules = VoiceRules.japanese
        XCTAssertTrue(rules.missedStates.contains("ミス"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "トラベリング" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "ダブルドリブル" }))
        XCTAssertTrue(rules.substitutionKeywords.contains("選手交代"))
        XCTAssertTrue(rules.substitutionKeywords.contains("交代"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "タイムアウト" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "試合終了" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "第1クオーター" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "リスタート" }))
    }

    // MARK: - Korean

    func testKoreanShots() {
        let rules = VoiceRules.korean
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "투" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "투포인트" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "쓰리" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "쓰리포인트" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "레이업" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "미드" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "미드레인지" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "페인트" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "인사이드" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "자유투" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "프리스로우" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "보너스" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "앤드 원" }))
        XCTAssertTrue(rules.missedStates.contains("실패"))
        XCTAssertTrue(rules.missedStates.contains("빗나감"))
        XCTAssertTrue(rules.missedStates.contains("블록"))
        XCTAssertTrue(rules.missedStates.contains("못 넣음"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "파울" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "리바운드" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "공격 리바운드" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "수비 리바운드" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "어시스트" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "블록" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "스틸" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "턴오버" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "트래블링" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "더블드리블" }))
    }

    func testKoreanColloquial() {
        let rules = VoiceRules.korean
        XCTAssertTrue(rules.substitutionKeywords.contains("교체"))
        XCTAssertTrue(rules.substitutionKeywords.contains("체인지"))
        XCTAssertTrue(rules.substitutionKeywords.contains("교체 투입"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "시작" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "첫 쿼터" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "다음 쿼터" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "일시정지" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "타임아웃" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "재개" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "계속" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "종료" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "경기종료" }))
    }

    // MARK: - German

    func testGermanShots() {
        let rules = VoiceRules.german
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "zwei" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "zwei punkte" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "drei" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "dreier" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "freiwurf" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "korb" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "and one" }))
        XCTAssertTrue(rules.missedStates.contains("daneben"))
        XCTAssertTrue(rules.missedStates.contains("vorbei"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "assist" }))
    }

    func testGermanColloquial() {
        let rules = VoiceRules.german
        XCTAssertTrue(rules.missedStates.contains("verfehlt"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "abpraller" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "vorlage" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "ballverlust" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "schrittfehler" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "diebstahl" }))
        XCTAssertTrue(rules.substitutionKeywords.contains("wechsel"))
        XCTAssertTrue(rules.substitutionKeywords.contains("rein"))
        XCTAssertTrue(rules.substitutionKeywords.contains("raus"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "auszeit" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "spielende" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "schluss" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "sprungball" }))
    }

    // MARK: - Spanish

    func testSpanishShots() {
        let rules = VoiceRules.spanish
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "dos" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "dos puntos" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "tres" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "tres puntos" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "bandeja" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "media" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "media distancia" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "pintura" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "interior" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "tiro libre" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "libre" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "bonus" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "y uno" }))
        XCTAssertTrue(rules.missedStates.contains("fallado"))
        XCTAssertTrue(rules.missedStates.contains("fuera"))
        XCTAssertTrue(rules.missedStates.contains("bloqueado"))
        XCTAssertTrue(rules.missedStates.contains("fallado"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "falta" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "rebote" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "rebote ofensivo" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "rebote defensivo" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "asistencia" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "bloqueo" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "robo" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "perdida" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "pasos" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "doble dribble" }))
    }

    func testSpanishColloquial() {
        let rules = VoiceRules.spanish
        XCTAssertTrue(rules.substitutionKeywords.contains("cambio"))
        XCTAssertTrue(rules.substitutionKeywords.contains("sustitución"))
        XCTAssertTrue(rules.substitutionKeywords.contains("reemplazo"))
        XCTAssertTrue(rules.substitutionKeywords.contains("sustituye"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "inicio" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "primer cuarto" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "pausa" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "tiempo muerto" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "continuar" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "reanudar" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "final" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "fin del partido" }))
    }

    // MARK: - French

    func testFrenchShots() {
        let rules = VoiceRules.french
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "deux" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "deux points" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "trois" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "trois points" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "lancer franc" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "panier" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "intérieur" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "couche" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "moyenne distance" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "et un" }))
        XCTAssertTrue(rules.missedStates.contains("raté"))
        XCTAssertTrue(rules.missedStates.contains("dehors"))
        XCTAssertTrue(rules.missedStates.contains("loupé"))
        XCTAssertTrue(rules.missedStates.contains("manqué"))
        XCTAssertTrue(rules.missedStates.contains("bloqué"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "faute" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "rebond" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "rebond offensif" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "rebond défensif" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "passe décisive" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "contre" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "interception" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "perte de balle" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "marche" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "double dribble" }))
    }

    func testFrenchColloquial() {
        let rules = VoiceRules.french
        XCTAssertTrue(rules.substitutionKeywords.contains("remplacement"))
        XCTAssertTrue(rules.substitutionKeywords.contains("remplace"))
        XCTAssertTrue(rules.substitutionKeywords.contains("changement"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "début" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "premier quart-temps" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "temps mort" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "arrêter" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "reprendre" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "fin" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "fin du match" }))
    }

    // MARK: - Italian

    func testItalianShots() {
        let rules = VoiceRules.italian
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "due" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "due punti" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "tre" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "tre punti" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "layup" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "media" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "media distanza" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "dentro" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "pitturato" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "tiro libero" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "libero" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "bonus" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "e uno" }))
        XCTAssertTrue(rules.missedStates.contains("sbagliato"))
        XCTAssertTrue(rules.missedStates.contains("fuori"))
        XCTAssertTrue(rules.missedStates.contains("bloccato"))
        XCTAssertTrue(rules.missedStates.contains("mancato"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "fallo" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "rimbalzo" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "rimbalzo offensivo" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "rimbalzo difensivo" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "assist" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "stoppata" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "palla rubata" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "perse" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "passi" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "doppio dribbling" }))
    }

    func testItalianColloquial() {
        let rules = VoiceRules.italian
        XCTAssertTrue(rules.substitutionKeywords.contains("cambio"))
        XCTAssertTrue(rules.substitutionKeywords.contains("sostituzione"))
        XCTAssertTrue(rules.substitutionKeywords.contains("sostituisci"))
        XCTAssertTrue(rules.substitutionKeywords.contains("entra"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "inizio" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "primo quarto" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "pausa" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "timeout" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "continuare" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "riprendere" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "fine" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "fine partita" }))
    }

    // MARK: - Russian

    func testRussianShots() {
        let rules = VoiceRules.russian
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "два" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "три" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "лей-ап" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "средний" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "краска" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "изнутри" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "штрафной" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "штрафной бросок" }))
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "бонус" }))
        XCTAssertTrue(rules.missedStates.contains("промах"))
        XCTAssertTrue(rules.missedStates.contains("мимо"))
        XCTAssertTrue(rules.missedStates.contains("заблокировали"))
        XCTAssertTrue(rules.missedStates.contains("не попал"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "фол" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "подбор" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "подбор в нападении" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "подбор в защите" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "передача" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "ассист" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "блок" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "блок-шот" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "перехват" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "потеря" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "пробежка" }))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "нарушение" }))
    }

    func testRussianColloquial() {
        let rules = VoiceRules.russian
        XCTAssertTrue(rules.substitutionKeywords.contains("замена"))
        XCTAssertTrue(rules.substitutionKeywords.contains("меняем"))
        XCTAssertTrue(rules.substitutionKeywords.contains("заменить"))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "начало" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "старт" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "первая четверть" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "пауза" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "тайм-аут" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "продолжить" }))
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "конец" }))
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

    // MARK: - Tutorial Hint Verification

    typealias HintCheck = (rules: VoiceRules, taskID: Int, example: String, kind: String)

    /// Verify that all hint examples in VoiceTutorialView use keywords that actually
    /// exist in their corresponding VoiceRules. This catches invalid hints that don't
    /// match any recognition rule.
    func testTutorialHintsUseValidKeywords() {
        let allHints: [HintCheck] = Self.makeAllHintChecks()

        for (rules, taskID, example, kind) in allHints {
            let exLower = example.lowercased()
            let found: Bool

            switch kind {
            case "stat":
                found = rules.statEvents.contains(where: { exLower.contains($0.keyword.lowercased()) })

            case "cmd":
                found = rules.commandEvents.contains(where: { exLower.contains($0.keyword.lowercased()) })

            case "sub":
                found = rules.substitutionKeywords.contains(where: { exLower.contains($0.lowercased()) })

            case "shot":
                found = rules.shotKeywords.contains(where: { exLower.contains($0.keyword.lowercased()) })

            case "made":
                found = rules.madeStates.contains(where: { exLower.hasSuffix($0.lowercased()) })

            case "miss":
                found = rules.missedStates.contains(where: { exLower.hasSuffix($0.lowercased()) })

            default:
                found = false
            }

            XCTAssertTrue(found, "[\(rules.locale.identifier)] task \(taskID) kind=\(kind) no match in: \(example)")
        }
    }

    // MARK: - Hint Check Data

    /// Returns all hint check tuples for all 10 languages.
    /// These verify that each hint example contains a keyword that exists in the VoiceRules.
    /// When adding new tutorial tasks, add corresponding entries here.
    private static func makeAllHintChecks() -> [HintCheck] {
        var checks: [HintCheck] = []

        checks += Self.zhHints()
        checks += Self.zhHantHints()
        checks += Self.enHints()
        checks += Self.jaHints()
        checks += Self.koHints()
        checks += Self.deHints()
        checks += Self.esHints()
        checks += Self.frHints()
        checks += Self.itHints()
        checks += Self.ruHints()

        return checks
    }

    // MARK: - Chinese (Simplified)

    private static func zhHints() -> [HintCheck] {
        let r = VoiceRules.chinese
        var c: [HintCheck] = []
        for (tid, exs) in [(1, ["老张两分", "7号两分", "老张两分进了"]),
                           (2, ["7号两分不中", "老张两分没进", "7号两分没中"]),
                           (3, ["俊宏三分", "10号三分", "俊宏三分进了"]),
                           (4, ["俊宏三分不中", "10号三分没进", "俊宏三分没中"]),
                           (5, ["俊宏罚球", "10号罚球", "俊宏罚球进了"]),
                           (6, ["俊宏罚球不中", "10号罚球没进", "俊宏罚球没中"]),
                           (7, ["老张上篮", "7号上篮", "老张上篮进了"]),
                           (8, ["俊宏中投", "10号中距离", "俊宏中投进了"]),
                           (9, ["仔队篮下", "客队7号内线", "仔队篮下得分"]),
                           (18, ["客队7号两分", "仔队两分", "客队7号两分进了"])] {
            for ex in exs { c.append((r, tid, ex, "shot")) }
        }
        for (tid, exs) in [(2, ["不中", "没进", "没中"]),
                           (4, ["不中", "没进", "没中"]),
                           (6, ["不中", "没进", "没中"])] {
            for ex in exs { c.append((r, tid, ex, "miss")) }
        }
        for (tid, exs) in [(1, ["命中"]),
                           (3, ["命中"]),
                           (5, ["命中"]),
                           (7, ["命中"]),
                           (8, ["命中"]),
                           (9, ["得分"]),
                           (18, ["命中"])] {
            for ex in exs { c.append((r, tid, ex, "made")) }
        }
        for (tid, exs) in [(10, ["仔队篮板", "客队7号篮板", "仔队抢到篮板"]),
                           (11, ["俊宏助攻", "10号助攻"]),
                           (12, ["bobo盖帽", "12号盖帽", "bobo封盖"]),
                           (13, ["老张抢断", "7号抢断", "老张断球"]),
                           (14, ["bobo失误", "12号失误", "bobo失误"]),
                           (15, ["仔队犯规", "客队7号犯规", "仔队犯规"])] {
            for ex in exs { c.append((r, tid, ex, "stat")) }
        }
        for ex in ["老张加罚", "7号加罚", "老张加罚命中"] { c.append((r, 16, ex, "shot")) }
        for ex in ["俊宏助攻老张两分", "俊宏助攻老张两分命中", "俊宏助攻老张三分"] {
            c.append((r, 20, ex, "stat"))
        }
        for (tid, exs) in [(21, ["开始", "第一节", "第1节"]),
                           (22, ["暂停", "停表"]),
                           (23, ["继续", "继续比赛", "比赛继续"]),
                           (24, ["结束本节", "节结束"])] {
            for ex in exs { c.append((r, tid, ex, "cmd")) }
        }
        for ex in ["俊宏替换老张", "10号替换7号", "换人"] {
            c.append((r, 17, ex, "sub"))
        }
        return c
    }

    // MARK: - Chinese (Traditional)

    private static func zhHantHints() -> [HintCheck] {
        let r = VoiceRules.traditionalChinese
        var c: [HintCheck] = []
        for (tid, exs) in [(1, ["老張兩分", "7號兩分", "老張兩分進了"]),
                           (2, ["7號兩分不中", "老張兩分沒進", "7號兩分沒中"]),
                           (3, ["俊宏三分", "10號三分", "俊宏三分進了"]),
                           (4, ["俊宏三分不中", "10號三分沒進", "俊宏三分沒中"]),
                           (5, ["俊宏罰球", "10號罰球", "俊宏罰球進了"]),
                           (6, ["俊宏罰球不中", "10號罰球沒進", "俊宏罰球沒中"]),
                           (7, ["老張上籃", "7號上籃", "老張上籃進了"]),
                           (8, ["俊宏中投", "10號中距離", "俊宏中投進了"]),
                           (9, ["仔隊籃下", "客隊7號內線", "仔隊籃下得分"]),
                           (18, ["客隊7號兩分", "仔隊兩分", "客隊7號兩分進了"])] {
            for ex in exs { c.append((r, tid, ex, "shot")) }
        }
        for (tid, exs) in [(10, ["仔隊籃板", "客隊7號籃板", "仔隊搶到籃板"]),
                           (11, ["俊宏助攻", "10號助攻"]),
                           (12, ["bobo蓋帽", "12號蓋帽", "bobo封蓋"]),
                           (13, ["老張抄截", "7號抄截", "老張抄截了"]),
                           (14, ["bobo失誤", "12號失誤", "bobo失誤"]),
                           (15, ["仔隊犯規", "客隊7號犯規", "仔隊犯規"])] {
            for ex in exs { c.append((r, tid, ex, "stat")) }
        }
        for ex in ["老張加罰", "7號加罰", "老張加罰命中"] { c.append((r, 16, ex, "shot")) }
        for ex in ["俊宏助攻老張兩分", "俊宏助攻老張兩分命中", "俊宏助攻老張三分"] {
            c.append((r, 20, ex, "stat"))
        }
        for (tid, exs) in [(21, ["開始", "第一節", "第1節"]),
                           (22, ["暫停", "停表"]),
                           (23, ["繼續", "繼續比賽", "比賽繼續"]),
                           (24, ["結束本節", "節結束"])] {
            for ex in exs { c.append((r, tid, ex, "cmd")) }
        }
        for ex in ["俊宏替換老張", "10號替換7號", "換人"] {
            c.append((r, 17, ex, "sub"))
        }
        return c
    }

    // MARK: - English

    private static func enHints() -> [HintCheck] {
        let r = VoiceRules.english
        var c: [HintCheck] = []
        for (tid, exs) in [(1, ["John two", "7 two"]),
                           (2, ["7 no 2", "John miss 2", "7 missed two"]),
                           (3, ["Mike three", "home 10 three"]),
                           (4, ["Mike no 3", "10 miss three", "Mike missed three"]),
                           (5, ["Mike free throw", "10 free", "Mike free"]),
                           (6, ["Mike no free", "10 miss free throw", "10 free no"]),
                           (7, ["John layup", "7 lay up", "John layup made"]),
                           (8, ["Mike mid range", "Mike jumper", "10 mid"]),
                           (9, ["Steve paint", "away 7 inside", "7 paint"]),
                           (18, ["away 7 two", "Steve two", "away 7 got 2"])] {
            for ex in exs { c.append((r, tid, ex, "shot")) }
        }
        for (tid, exs) in [(10, ["Steve rebound", "away 7 rebound", "Steve got rebound"]),
                           (11, ["Mike assist", "home 10 assist", "10 assist"]),
                           (12, ["Dave block", "12 block", "away 12 block"]),
                           (13, ["John steal", "7 steal", "home 7 steal"]),
                           (14, ["Dave turnover", "12 turnover", "Dave turn over"]),
                           (15, ["Steve foul", "away 7 foul", "Steve fouls"])] {
            for ex in exs { c.append((r, tid, ex, "stat")) }
        }
        for ex in ["John bonus", "7 and one", "John and one"] { c.append((r, 16, ex, "shot")) }
        for ex in ["Mike assist John two", "Mike assist John two got", "Mike assist John three"] {
            c.append((r, 20, ex, "stat"))
        }
        for (tid, exs) in [(21, ["start", "begin", "tip off"]),
                           (22, ["pause", "timeout", "stop"]),
                           (23, ["resume", "continue", "play"]),
                           (24, ["quarter done"])] {
            for ex in exs { c.append((r, tid, ex, "cmd")) }
        }
        for ex in ["sub 7 for 10", "substitute John for Mike", "sub 7 10"] {
            c.append((r, 17, ex, "sub"))
        }
        return c
    }

    // MARK: - Japanese

    private static func jaHints() -> [HintCheck] {
        let r = VoiceRules.japanese
        var c: [HintCheck] = []
        for (tid, exs) in [(1, ["田中ツー", "田中ツー", "７番ツー成功"]),
                           (2, ["田中ツーなし", "７番ツー外した", "田中ツーミス"]),
                           (3, ["鈴木スリー", "１０番スリー", "鈴木スリー"]),
                           (4, ["鈴木スリーなし", "１０番スリー外した", "鈴木スリーミス"]),
                           (5, ["鈴木フリースロー", "１０番フリー", "鈴木フリー成功"]),
                           (6, ["鈴木フリーなし", "１０番フリーミス", "鈴木フリー失敗"]),
                           (7, ["田中レイアップ", "７番レイアップ", "田中レイアップ成功"]),
                           (8, ["鈴木ミドルレンジ", "１０番ミドル", "鈴木ミドル"]),
                           (9, ["山田ペイント", "アウェイ７番ペイント", "青チーム７番インサイド"]),
                           (18, ["アウェイ７番ツー", "山田ツー", "青チーム７番ツー"])] {
            for ex in exs { c.append((r, tid, ex, "shot")) }
        }
        for (tid, exs) in [(10, ["山田リバウンド", "アウェイ７番リバウンド", "青チームリバウンド"]),
                           (11, ["鈴木アシスト", "１０番アシスト", "ホーム１０番アシスト"]),
                           (12, ["佐藤ブロック", "１２番ブロック", "アウェイ１２番ブロック"]),
                           (13, ["田中スティール", "７番スティール", "ホーム７番スティール"]),
                           (14, ["佐藤ターンオーバー", "１２番ターンオーバー", "佐藤ターンオーバー"]),
                           (15, ["山田ファウル", "アウェイ７番ファウル", "青チーム７番ファウル"])] {
            for ex in exs { c.append((r, tid, ex, "stat")) }
        }
        for ex in ["田中ボーナス", "７番アンドワン", "田中追加フリー"] { c.append((r, 16, ex, "shot")) }
        for ex in ["鈴木アシスト田中ツー", "鈴木アシスト田中ツー成功", "鈴木アシスト田中スリー"] {
            c.append((r, 20, ex, "stat"))
        }
        for (tid, exs) in [(21, ["開始", "スタート", "第1クオーター"]),
                           (22, ["一時停止", "タイムアウト", "休憩"]),
                           (23, ["再開", "リスタート", "続ける"]),
                           (24, ["クオーターエンド"])] {
            for ex in exs { c.append((r, tid, ex, "cmd")) }
        }
        for ex in ["田中を鈴木に交代", "７番１０番交代", "７番１０番交代"] {
            c.append((r, 17, ex, "sub"))
        }
        return c
    }

    // MARK: - Korean

    private static func koHints() -> [HintCheck] {
        let r = VoiceRules.korean
        var c: [HintCheck] = []
        for (tid, exs) in [(1, ["김철수 투", "김철수 2점", "7번 2점 성공"]),
                           (2, ["김철수 투 실패", "7번 2점 못 넣음", "김철수 2점 미스"]),
                           (3, ["이영희 쓰리", "10번 3점", "이영희 3점 성공"]),
                           (4, ["이영희 쓰리 실패", "10번 3점 못 넣음", "이영희 3점 미스"]),
                           (5, ["이영희 자유투", "10번 자유투", "이영희 자유투 성공"]),
                           (6, ["이영희 자유투 실패", "10번 자유투 못 넣음", "이영희 자유투 미스"]),
                           (7, ["김철수 레이업", "7번 레이업", "김철수 레이업 성공"]),
                           (8, ["이영희 미드레인지", "10번 미드레인지", "이영희 미드레인지"]),
                           (9, ["박민수 페인트", "어웨이 7번 페인트", "파랑팀 7번 인사이드"]),
                           (18, ["어웨이 7번 투", "박민수 2점", "파랑팀 7번 2점"])] {
            for ex in exs { c.append((r, tid, ex, "shot")) }
        }
        for (tid, exs) in [(10, ["박민수 리바운드", "어웨이 7번 리바운드", "파랑팀 7번 리바운드"]),
                           (11, ["이영희 어시스트", "10번 어시스트", "홈 10번 어시스트"]),
                           (12, ["정지원 블록", "12번 블록", "어웨이 12번 블록"]),
                           (13, ["김철수 스틸", "7번 스틸", "홈 7번 스틸"]),
                           (14, ["정지원 턴오버", "12번 턴오버", "정지원 턴오버"]),
                           (15, ["박민수 파울", "어웨이 7번 파울", "파랑팀 7번 파울"])] {
            for ex in exs { c.append((r, tid, ex, "stat")) }
        }
        for ex in ["김철수 보너스", "7번 앤드 원", "김철수 추가 자유투"] { c.append((r, 16, ex, "shot")) }
        for ex in ["이영희 어시스트 김철수 투", "이영희 어시스트 김철수 2점 성공", "이영희 어시스트 김철수 쓰리"] {
            c.append((r, 20, ex, "stat"))
        }
        for (tid, exs) in [(21, ["시작", "첫 쿼터"]),
                           (22, ["일시정지", "타임아웃"]),
                           (23, ["재개", "계속"]),
                           (24, ["쿼터종결"])] {
            for ex in exs { c.append((r, tid, ex, "cmd")) }
        }
        for ex in ["7번 10번 교체", "김철수 교체 이영희", "7번 10번 교체"] {
            c.append((r, 17, ex, "sub"))
        }
        return c
    }

    // MARK: - German

    private static func deHints() -> [HintCheck] {
        let r = VoiceRules.german
        var c: [HintCheck] = []
        for (tid, exs) in [(1, ["Hans zwei", "Hans 2 Punkte", "7 zwei getroffen"]),
                           (2, ["Hans zwei daneben", "7 zwei verfehlt", "Hans 2 Punkte nicht"]),
                           (3, ["Fritz drei", "10 drei", "Fritz 3 Punkte"]),
                           (4, ["Fritz drei daneben", "10 drei verfehlt", "Fritz 3 Punkte nicht"]),
                           (5, ["Fritz Freiwurf", "10 Freiwurf", "Fritz Freiwurf getroffen"]),
                           (6, ["Fritz Freiwurf daneben", "10 Freiwurf verfehlt", "Fritz Freiwurf nicht"]),
                           (7, ["Hans Layup", "7 Layup", "Hans Korbleger"]),
                           (8, ["Fritz Mitteldistanz", "10 Mitteldistanz", "Fritz Mitteldistanz"]),
                           (9, ["Klaus Korb", "Auswärts 7 Korb", "Blau 7 Korb"]),
                           (18, ["Auswärts 7 zwei", "Klaus 2 Punkte", "Blau 7 zwei"])] {
            for ex in exs { c.append((r, tid, ex, "shot")) }
        }
        for (tid, exs) in [(10, ["Klaus Rebound", "Auswärts 7 Rebound", "Blau 7 Rebound"]),
                           (11, ["Fritz Assist", "10 Assist", "Heim 10 Assist"]),
                           (12, ["Gerd Block", "12 Block", "Auswärts 12 Block"]),
                           (13, ["Hans Steal", "7 Steal", "Heim 7 Steal"]),
                           (14, ["Gerd Turnover", "12 Turnover", "Gerd Ballverlust"]),
                           (15, ["Klaus Foul", "Auswärts 7 Foul", "Blau 7 Foul"])] {
            for ex in exs { c.append((r, tid, ex, "stat")) }
        }
        for ex in ["Hans Bonus", "7 and one", "Hans Bonus Freiwurf"] { c.append((r, 16, ex, "shot")) }
        for ex in ["Fritz Assist Hans zwei", "Fritz Assist Hans zwei getroffen", "Fritz Assist Hans drei"] {
            c.append((r, 20, ex, "stat"))
        }
        for (tid, exs) in [(21, ["start", "sprungball", "erstes viertel"]),
                           (22, ["pause", "auszeit"]),
                           (23, ["weiter", "weiterspielen"]),
                           (24, ["viertel um"])] {
            for ex in exs { c.append((r, tid, ex, "cmd")) }
        }
        for ex in ["Wechsel 7 und 10", "Hans raus Fritz rein", "7 raus 10 rein"] {
            c.append((r, 17, ex, "sub"))
        }
        return c
    }

    // MARK: - Spanish

    private static func esHints() -> [HintCheck] {
        let r = VoiceRules.spanish
        var c: [HintCheck] = []
        for (tid, exs) in [(1, ["Carlos dos", "Carlos 2 puntos", "7 dos anotado"]),
                           (2, ["Carlos dos fallo", "7 dos no", "Carlos 2 puntos fallado"]),
                           (3, ["Luis tres", "10 tres", "Luis 3 puntos"]),
                           (4, ["Luis tres fallo", "10 tres no", "Luis 3 puntos fallado"]),
                           (5, ["Luis tiro libre", "10 libre", "Luis libre anotado"]),
                           (6, ["Luis libre fallo", "10 libre no", "Luis tiro libre fallado"]),
                           (7, ["Carlos bandeja", "7 bandeja", "Carlos bandeja"]),
                           (8, ["Luis media distancia", "10 media distancia", "Luis media distancia"]),
                           (9, ["José pintura", "Visitante 7 pintura", "Azul 7 interior"]),
                           (18, ["Visitante 7 dos", "José 2 puntos", "Azul 7 dos"])] {
            for ex in exs { c.append((r, tid, ex, "shot")) }
        }
        for (tid, exs) in [(10, ["José rebote", "Visitante 7 rebote", "Azul 7 rebote"]),
                           (11, ["Luis asistencia", "10 asistencia", "Local 10 asistencia"]),
                           (12, ["Juan bloqueo", "12 bloqueo", "Visitante 12 bloqueo"]),
                           (13, ["Carlos robo", "7 robo", "Local 7 robo"]),
                           (14, ["Juan perdida", "12 perdida", "Juan perdida"]),
                           (15, ["José falta", "Visitante 7 falta", "Azul 7 falta"])] {
            for ex in exs { c.append((r, tid, ex, "stat")) }
        }
        for ex in ["Carlos bonus", "7 y uno", "Carlos y uno"] { c.append((r, 16, ex, "shot")) }
        for ex in ["Luis asistencia Carlos dos", "Luis asistencia Carlos dos canasta", "Luis asistencia Carlos tres"] {
            c.append((r, 20, ex, "stat"))
        }
        for (tid, exs) in [(21, ["inicio", "primer cuarto"]),
                           (22, ["pausa", "tiempo muerto"]),
                           (23, ["continuar", "reanudar"]),
                           (24, ["cuarto concluido"])] {
            for ex in exs { c.append((r, tid, ex, "cmd")) }
        }
        for ex in ["Cambio 7 por 10", "Cambio 7 por 10", "Cambio Carlos por Luis"] {
            c.append((r, 17, ex, "sub"))
        }
        return c
    }

    // MARK: - French

    private static func frHints() -> [HintCheck] {
        let r = VoiceRules.french
        var c: [HintCheck] = []
        for (tid, exs) in [(1, ["Pierre deux", "Pierre 2 points", "7 deux réussi"]),
                           (2, ["Pierre deux raté", "7 deux loupé", "Pierre 2 points non"]),
                           (3, ["Paul trois", "10 trois", "Paul 3 points"]),
                           (4, ["Paul trois raté", "10 trois loupé", "Paul 3 points non"]),
                           (5, ["Paul lancer franc", "10 lancer franc", "Paul lancer franc réussi"]),
                           (6, ["Paul lancer franc raté", "10 lancer franc non", "Paul lancer franc loupé"]),
                           (7, ["Pierre layup", "7 layup", "Pierre panier facile"]),
                           (8, ["Paul mi-distance", "10 mi-distance", "Paul moyenne distance"]),
                           (9, ["Jacques intérieur", "Extérieur 7 intérieur", "Bleu 7 intérieur"]),
                           (18, ["Extérieur 7 deux", "Jacques 2 points", "Bleu 7 deux"])] {
            for ex in exs { c.append((r, tid, ex, "shot")) }
        }
        for (tid, exs) in [(10, ["Jacques rebond", "Extérieur 7 rebond", "Bleu 7 rebond"]),
                           (11, ["Paul passe décisive", "10 passe décisive", "Domicile 10 passe"]),
                           (12, ["Luc contre", "12 contre", "Extérieur 12 contre"]),
                           (13, ["Pierre interception", "7 interception", "Domicile 7 interception"]),
                           (14, ["Luc perte de balle", "12 perte de balle", "Luc perte de balle"]),
                           (15, ["Jacques faute", "Extérieur 7 faute", "Bleu 7 faute"])] {
            for ex in exs { c.append((r, tid, ex, "stat")) }
        }
        for ex in ["Pierre bonus", "7 et un", "Pierre et un"] { c.append((r, 16, ex, "shot")) }
        for ex in ["Paul passe Pierre deux", "Paul passe Pierre deux réussi", "Paul passe Pierre trois"] {
            c.append((r, 20, ex, "stat"))
        }
        for (tid, exs) in [(21, ["début", "entre-deux", "premier quart"]),
                           (22, ["pause", "temps mort", "arrêter"]),
                           (23, ["continuer", "reprise", "reprendre"]),
                           (24, ["quart achevé"])] {
            for ex in exs { c.append((r, tid, ex, "cmd")) }
        }
        for ex in ["Remplace 7 par 10", "Remplace Paul par Pierre", "Remplace 10 par 7"] {
            c.append((r, 17, ex, "sub"))
        }
        return c
    }

    // MARK: - Italian

    private static func itHints() -> [HintCheck] {
        let r = VoiceRules.italian
        var c: [HintCheck] = []
        for (tid, exs) in [(1, ["Marco due", "Marco 2 punti", "7 due segnato"]),
                           (2, ["Marco due sbagliato", "7 due no", "Marco 2 punti fallito"]),
                           (3, ["Luca tre", "10 tre", "Luca 3 punti"]),
                           (4, ["Luca tre sbagliato", "10 tre no", "Luca 3 punti fallito"]),
                           (5, ["Luca tiro libero", "10 libero", "Luca libero segnato"]),
                           (6, ["Luca libero sbagliato", "10 libero no", "Luca tiro libero fallito"]),
                           (7, ["Marco layup", "7 layup", "Marco layup segnato"]),
                           (8, ["Luca media distanza", "10 media distanza", "Luca media distanza"]),
                           (9, ["Paolo pitturato", "Ospite 7 pitturato", "Blu 7 dentro"]),
                           (18, ["Ospite 7 due", "Paolo 2 punti", "Blu 7 due"])] {
            for ex in exs { c.append((r, tid, ex, "shot")) }
        }
        for (tid, exs) in [(10, ["Paolo rimbalzo", "Ospite 7 rimbalzo", "Blu 7 rimbalzo"]),
                           (11, ["Luca assist", "10 assist", "Casa 10 assist"]),
                           (12, ["Mario stoppata", "12 stoppata", "Ospite 12 stoppata"]),
                           (13, ["Marco palla rubata", "7 palla rubata", "Casa 7 palla rubata"]),
                           (14, ["Mario perso", "12 perso", "Mario perso"]),
                           (15, ["Paolo fallo", "Ospite 7 fallo", "Blu 7 fallo"])] {
            for ex in exs { c.append((r, tid, ex, "stat")) }
        }
        for ex in ["Marco bonus", "7 e uno", "Marco e uno"] { c.append((r, 16, ex, "shot")) }
        for ex in ["Luca assist Marco due", "Luca assist Marco due segnato", "Luca assist Marco tre"] {
            c.append((r, 20, ex, "stat"))
        }
        for (tid, exs) in [(21, ["inizio", "primo quarto"]),
                           (22, ["pausa", "timeout"]),
                           (23, ["continuare", "riprendere"]),
                           (24, ["quarto concluso"])] {
            for ex in exs { c.append((r, tid, ex, "cmd")) }
        }
        for ex in ["Cambio 7 con 10", "Marco entra Luca entra", "7 esce 10 entra"] {
            c.append((r, 17, ex, "sub"))
        }
        return c
    }

    // MARK: - Russian

    private static func ruHints() -> [HintCheck] {
        let r = VoiceRules.russian
        var c: [HintCheck] = []
        for (tid, exs) in [(1, ["Иван два", "Иван 2 очка", "7 два попал"]),
                           (2, ["Иван два промах", "7 два нет", "Иван 2 очка не попал"]),
                           (3, ["Пётр три", "10 три", "Пётр 3 очка"]),
                           (4, ["Пётр три промах", "10 три нет", "Пётр 3 очка не попал"]),
                           (5, ["Пётр штрафной", "10 штрафной", "Пётр штрафной попал"]),
                           (6, ["Пётр штрафной нет", "10 штрафной промах", "Пётр штрафной не попал"]),
                           (7, ["Иван лей-ап", "7 лей-ап", "Иван лей-ап"]),
                           (8, ["Пётр средний", "10 средний", "Пётр средний бросок"]),
                           (9, ["Сергей краска", "Гости 7 краска", "Синие 7 внутри"]),
                           (18, ["Гости 7 два", "Сергей 2 очка", "Синие 7 два"])] {
            for ex in exs { c.append((r, tid, ex, "shot")) }
        }
        for (tid, exs) in [(10, ["Сергей подбор", "Гости 7 подбор", "Синие 7 подбор"]),
                           (11, ["Пётр ассист", "10 ассист", "Дома 10 ассист"]),
                           (12, ["Алексей блок", "12 блок", "Гости 12 блок"]),
                           (13, ["Иван перехват", "7 перехват", "Дома 7 перехват"]),
                           (14, ["Алексей потеря", "12 потеря", "Алексей потеря"]),
                           (15, ["Сергей фол", "Гости 7 фол", "Синие 7 фол"])] {
            for ex in exs { c.append((r, tid, ex, "stat")) }
        }
        for ex in ["Иван бонус", "7 бонус", "Иван дополнительный штрафной"] { c.append((r, 16, ex, "shot")) }
        for ex in ["Пётр ассист Иван два", "Пётр ассист Иван 2 очка попал", "Пётр ассист Иван три"] {
            c.append((r, 20, ex, "stat"))
        }
        for (tid, exs) in [(21, ["начало", "первая четверть"]),
                           (22, ["пауза", "тайм-аут"]),
                           (23, ["продолжить"]),
                           (24, ["четверть завершена"])] {
            for ex in exs { c.append((r, tid, ex, "cmd")) }
        }
        for ex in ["Замена 7 на 10", "Замена Ивана на Петра", "Замена 7 на 10"] {
            c.append((r, 17, ex, "sub"))
        }
        return c
    }

    // MARK: - VoiceRulesData JSON validation

    func testAllEmbeddedJSONParsesSuccessfully() {
        let locales = ["en", "zh-Hans", "zh-Hant-TW", "ja", "ko", "de", "es", "fr", "it", "ru"]
        for locale in locales {
            let data = VoiceRulesData.load(language: locale)
            XCTAssertNotNil(data, "VoiceRulesData.load failed for \(locale)")
        }
    }
}
