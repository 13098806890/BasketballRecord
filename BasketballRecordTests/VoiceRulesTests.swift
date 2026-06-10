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
        XCTAssertTrue(rules.madeStates.contains("made"))
        XCTAssertTrue(rules.madeStates.contains("score"))
        XCTAssertTrue(rules.madeStates.contains("scores"))
        XCTAssertTrue(rules.missedStates.contains("airball"))
        XCTAssertTrue(rules.missedStates.contains("brick"))
        XCTAssertTrue(rules.missedStates.contains("short"))
    }

    func testEnglishColloquial() {
        let rules = VoiceRules.english
        XCTAssertTrue(rules.madeStates.contains("good"))
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
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "ワンワン" }))
        XCTAssertTrue(rules.madeStates.contains("入った"))
        XCTAssertTrue(rules.madeStates.contains("決まった"))
        XCTAssertTrue(rules.madeStates.contains("得点"))
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
        XCTAssertTrue(rules.substitutionKeywords.contains("リプレース"))
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
        XCTAssertTrue(rules.shotKeywords.contains(where: { $0.keyword == "원 플러스" }))
        XCTAssertTrue(rules.madeStates.contains("성공"))
        XCTAssertTrue(rules.madeStates.contains("들어감"))
        XCTAssertTrue(rules.madeStates.contains("득점"))
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
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "트레블링" }))
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
        XCTAssertTrue(rules.madeStates.contains("getroffen"))
        XCTAssertTrue(rules.madeStates.contains("rein"))
        XCTAssertTrue(rules.missedStates.contains("daneben"))
        XCTAssertTrue(rules.missedStates.contains("vorbei"))
        XCTAssertTrue(rules.statEvents.contains(where: { $0.keyword == "assist" }))
    }

    func testGermanColloquial() {
        let rules = VoiceRules.german
        XCTAssertTrue(rules.madeStates.contains("drin"))
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
        XCTAssertTrue(rules.commandEvents.contains(where: { $0.keyword == "anpfiff" }))
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
        XCTAssertTrue(rules.madeStates.contains("encestado"))
        XCTAssertTrue(rules.madeStates.contains("dentro"))
        XCTAssertTrue(rules.madeStates.contains("bueno"))
        XCTAssertTrue(rules.madeStates.contains("canasta"))
        XCTAssertTrue(rules.missedStates.contains("fallado"))
        XCTAssertTrue(rules.missedStates.contains("fuera"))
        XCTAssertTrue(rules.missedStates.contains("bloqueado"))
        XCTAssertTrue(rules.missedStates.contains("perdido"))
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
        XCTAssertTrue(rules.madeStates.contains("marqué"))
        XCTAssertTrue(rules.madeStates.contains("dedans"))
        XCTAssertTrue(rules.madeStates.contains("dans"))
        XCTAssertTrue(rules.madeStates.contains("bon"))
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
        XCTAssertTrue(rules.madeStates.contains("segnato"))
        XCTAssertTrue(rules.madeStates.contains("dentro"))
        XCTAssertTrue(rules.madeStates.contains("buono"))
        XCTAssertTrue(rules.madeStates.contains("fatto"))
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
        XCTAssertTrue(rules.madeStates.contains("забил"))
        XCTAssertTrue(rules.madeStates.contains("попал"))
        XCTAssertTrue(rules.madeStates.contains("есть"))
        XCTAssertTrue(rules.madeStates.contains("очко"))
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
}
