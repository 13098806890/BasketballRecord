import XCTest
@testable import BasketballRecord

@MainActor
final class VoiceASRTests: XCTestCase {
    var store: AppStore!
    var snapshot: GameSnapshot!
    let p1 = UUID(), p2 = UUID(), p3 = UUID()
    let homeTID = UUID(), awayTID = UUID()

    override func setUp() async throws {
        try await super.setUp()
        store = AppStore()
        store.players = [Player(id: p1, name: "张三", number: "3"), Player(id: p2, name: "李四", number: "7"), Player(id: p3, name: "bobo", number: "8")]
        store.teams = [Team(id: homeTID, name: "红队", playerIDs: [p1, p2, p3]), Team(id: awayTID, name: "蓝队", playerIDs: [])]
        snapshot = GameSnapshot(); snapshot.homeTeamID = homeTID; snapshot.awayTeamID = awayTID
        snapshot.homeOnCourtPlayerIDs = [p1, p2, p3]; snapshot.homeAvailablePlayerIDs = [p1, p2, p3]
    }

    // MARK: - zh-CN
    // Tests: twoMade, threeMade, freeThrowMade, bonusMade, layupMade, midRangeMade, paintMade, plus foul/rebound/assist/block/steal/turnover

    func testZhTwo_common() throws { assertMatch(text: "张三两分", .chinese, "stat.twoMade") }

    func testZhThree_common() throws { assertMatch(text: "张三三分", .chinese, "stat.threeMade") }
    func testZhThree_zsh() throws { assertMatch(text: "张三山分", .chinese, "stat.threeMade") }
    func testZhThree_anap() throws { assertMatch(text: "张三散分", .chinese, "stat.threeMade") }
    func testZhThree_tone() throws { assertMatch(text: "张三三份", .chinese, "stat.threeMade") }

    func testZhFreeThrow_common() throws { assertMatch(text: "张三罚球", .chinese, "stat.freeThrowMade") }
    func testZhFreeThrow_f() throws { assertMatch(text: "张三法球", .chinese, "stat.freeThrowMade") }

    func testZhBonus_common() throws { assertMatch(text: "张三加罚", .chinese, "stat.bonusMade") }
    func testZhBonus_tongue() throws { assertMatch(text: "张三加法", .chinese, "stat.bonusMade") }

    func testZhLayup_common() throws { assertMatch(text: "李四上篮", .chinese, "stat.layupMade") }
    func testZhLayup_nasal() throws { assertMatch(text: "李四上南", .chinese, "stat.layupMade") }
    func testZhLayup_sangs() throws { assertMatch(text: "李四桑兰", .chinese, "stat.layupMade") }

    func testZhMid_common() throws { assertMatch(text: "张三中投", .chinese, "stat.midRangeMade") }
    func testZhMid_zong() throws { assertMatch(text: "张三总投", .chinese, "stat.midRangeMade") }

    func testZhPaint_common() throws { assertMatch(text: "张三篮下", .chinese, "stat.paintMade") }
    func testZhPaint_nanxia() throws { assertMatch(text: "张三南夏", .chinese, "stat.paintMade") }

    func testZhFoul_common() throws { assertMatch(text: "张三犯规", .chinese, "stat.foul") }
    func testZhFoul_fang() throws { assertMatch(text: "张三方归", .chinese, "stat.foul") }

    func testZhRebound_common() throws { assertMatch(text: "张三篮板", .chinese, "stat.rebound") }
    func testZhRebound_nanban() throws { assertMatch(text: "张三nanban", .chinese, "stat.rebound") }
    func testZhRebound_lanban() throws { assertMatch(text: "张三lan ban", .chinese, "stat.rebound") }
    func testZhRebound_homophone() throws { assertMatch(text: "张三兰板", .chinese, "stat.rebound") }

    func testZhAssist_common() throws { assertMatch(text: "张三助攻", .chinese, "stat.assist") }
    func testZhAssist_zhugong() throws { assertMatch(text: "张三主攻", .chinese, "stat.assist") }

    func testZhBlock_common() throws { assertMatch(text: "张三盖帽", .chinese, "stat.block") }
    func testZhBlock_gaimao() throws { assertMatch(text: "张三概貌", .chinese, "stat.block") }

    func testZhSteal_common() throws { assertMatch(text: "张三抢断", .chinese, "stat.steal") }
    func testZhSteal_qiang() throws { assertMatch(text: "张三强段", .chinese, "stat.steal") }

    func testZhTurnover_common() throws { assertMatch(text: "张三失误", .chinese, "stat.turnover") }
    func testZhTurnover_shi() throws { assertMatch(text: "张三失物", .chinese, "stat.turnover") }

    func testZhSubstitution() throws { assertCmd(text: "换人3号7号", .chinese, "substitution") }
    func testZhSubstitution_dan() throws { assertCmd(text: "3号换7号", .chinese, "substitution") }

    // MARK: - zh-Hant (Traditional Chinese / Taiwan)

    func testHantThree() throws { assertMatch(text: "張三三分", .traditionalChinese, "stat.threeMade") }
    func testHantSteal() throws { assertMatch(text: "張三抄截", .traditionalChinese, "stat.steal") }
    func testHantMissed() throws { assertMatch(text: "張三三分沒進", .traditionalChinese, "stat.threeMissed") }
    func testHantFoul() throws { assertMatch(text: "張三犯規", .traditionalChinese, "stat.foul") }
    func testHantRebound() throws { assertMatch(text: "張三籃板", .traditionalChinese, "stat.rebound") }

    // MARK: - en-US
    // Tests for every event with common ASR homophone/phonetic errors

    func testEnThree_common() throws { assertMatch(text: "Bob three", .english, "stat.threeMade") }
    func testEnThree_tree() throws { assertMatch(text: "Bob tree", .english, "stat.threeMade") }
    func testEnThree_free() throws { assertMatch(text: "Bob free", .english, "stat.threeMade") }
    func testEnThree_3pt() throws { assertMatch(text: "Bob three pointer", .english, "stat.threeMade") }
    func testEnThree_trey() throws { assertMatch(text: "Bob trey", .english, "stat.threeMade") }

    func testEnTwo_common() throws { assertMatch(text: "Bob two", .english, "stat.twoMade") }
    func testEnTwo_too() throws { assertMatch(text: "Bob too", .english, "stat.twoMade") }
    func testEnTwo_2pt() throws { assertMatch(text: "Bob two pointer", .english, "stat.twoMade") }

    func testEnFreeThrow_common() throws { assertMatch(text: "Bob free throw", .english, "stat.freeThrowMade") }
    func testEnFreeThrow_foul() throws { assertMatch(text: "Bob foul shot", .english, "stat.freeThrowMade") }

    func testEnLayup_common() throws { assertMatch(text: "Bob layup", .english, "stat.layupMade") }
    func testEnLayup_separated() throws { assertMatch(text: "Bob lay up", .english, "stat.layupMade") }

    func testEnMid_common() throws { assertMatch(text: "Bob mid range", .english, "stat.midRangeMade") }
    func testEnMid_jumper() throws { assertMatch(text: "Bob jumper", .english, "stat.midRangeMade") }
    func testEnMid_pullup() throws { assertMatch(text: "Bob pull up", .english, "stat.midRangeMade") }

    func testEnPaint_common() throws { assertMatch(text: "Bob paint", .english, "stat.paintMade") }
    func testEnPaint_inside() throws { assertMatch(text: "Bob inside", .english, "stat.paintMade") }
    func testEnPaint_post() throws { assertMatch(text: "Bob post up", .english, "stat.paintMade") }

    func testEnFoul_common() throws { assertMatch(text: "Bob foul", .english, "stat.foul") }
    func testEnFoul_fowl() throws { assertMatch(text: "Bob fowl", .english, "stat.foul") }
    func testEnFoul_faul() throws { assertMatch(text: "Bob faul", .english, "stat.foul") }

    func testEnRebound_common() throws { assertMatch(text: "Bob rebound", .english, "stat.rebound") }
    func testEnRebound_board() throws { assertMatch(text: "Bob board", .english, "stat.rebound") }

    func testEnAssist_common() throws { assertMatch(text: "Bob assist", .english, "stat.assist") }
    func testEnAssist_sister() throws { assertMatch(text: "Bob a sister", .english, "stat.assist") }
    func testEnAssist_dime() throws { assertMatch(text: "Bob dime", .english, "stat.assist") }

    func testEnBlock_common() throws { assertMatch(text: "Bob block", .english, "stat.block") }
    func testEnBlock_bloc() throws { assertMatch(text: "Bob bloc", .english, "stat.block") }
    func testEnBlock_swat() throws { assertMatch(text: "Bob swat", .english, "stat.block") }

    func testEnSteal_common() throws { assertMatch(text: "Bob steal", .english, "stat.steal") }
    func testEnSteal_steel() throws { assertMatch(text: "Bob steel", .english, "stat.steal") }
    func testEnSteal_takeaway() throws { assertMatch(text: "Bob takeaway", .english, "stat.steal") }

    func testEnTurnover_common() throws { assertMatch(text: "Bob turnover", .english, "stat.turnover") }
    func testEnTurnover_travel() throws { assertMatch(text: "Bob travel", .english, "stat.turnover") }
    func testEnTurnover_walk() throws { assertMatch(text: "Bob walk", .english, "stat.turnover") }
    func testEnTurnover_carry() throws { assertMatch(text: "Bob carry", .english, "stat.turnover") }

    func testEnSubstitution() throws { assertCmd(text: "sub Bob for Tom", .english, "substitution") }
    func testEnTimeout() throws { assertCmd(text: "timeout", .english, "togglePause") }
    func testEnGameEnd() throws { assertCmd(text: "game over", .english, "finishGame") }

    // MARK: - ja-JP
    // Short vowel (dropped ー) and other common ASR errors

    func testJaThree_common() throws { assertMatch(text: "山田スリー", .japanese, "stat.threeMade") }
    func testJaThree_short() throws { assertMatch(text: "山田スリ", .japanese, "stat.threeMade") }
    func testJaThree_pt() throws { assertMatch(text: "山田スリーポイント", .japanese, "stat.threeMade") }

    func testJaTwo_common() throws { assertMatch(text: "山田ツー", .japanese, "stat.twoMade") }
    func testJaTwo_short() throws { assertMatch(text: "山田ツ", .japanese, "stat.twoMade") }

    func testJaLayup_common() throws { assertMatch(text: "山田レイアップ", .japanese, "stat.layupMade") }
    func testJaLayup_drop() throws { assertMatch(text: "山田レアップ", .japanese, "stat.layupMade") }

    func testJaFreeThrow_common() throws { assertMatch(text: "山田フリースロー", .japanese, "stat.freeThrowMade") }
    func testJaFreeThrow_short() throws { assertMatch(text: "山田フリスロー", .japanese, "stat.freeThrowMade") }
    func testJaFreeThrow_both_short() throws { assertMatch(text: "山田フリスロ", .japanese, "stat.freeThrowMade") }

    func testJaBonus() throws { assertMatch(text: "山田ボーナス", .japanese, "stat.bonusMade") }
    func testJaAndOne() throws { assertMatch(text: "山田アンドワン", .japanese, "stat.bonusMade") }

    func testJaFoul_common() throws { assertMatch(text: "山田ファウル", .japanese, "stat.foul") }
    func testJaRebound_common() throws { assertMatch(text: "山田リバウンド", .japanese, "stat.rebound") }
    func testJaRebound_drop_d() throws { assertMatch(text: "山田リバウン", .japanese, "stat.rebound") }
    func testJaAssist_common() throws { assertMatch(text: "山田アシスト", .japanese, "stat.assist") }
    func testJaAssist_drop_su() throws { assertMatch(text: "山田アシト", .japanese, "stat.assist") }
    func testJaBlock_common() throws { assertMatch(text: "山田ブロック", .japanese, "stat.block") }
    func testJaBlock_short() throws { assertMatch(text: "山田ブロク", .japanese, "stat.block") }
    func testJaSteal_common() throws { assertMatch(text: "山田スティール", .japanese, "stat.steal") }
    func testJaSteal_short() throws { assertMatch(text: "山田スティル", .japanese, "stat.steal") }
    func testJaTurnover_common() throws { assertMatch(text: "山田ターンオーバー", .japanese, "stat.turnover") }
    func testJaTurnover_short() throws { assertMatch(text: "山田ターンオーバ", .japanese, "stat.turnover") }
    func testJaTurnover_drop_t() throws { assertMatch(text: "山田タンオーバ", .japanese, "stat.turnover") }

    func testJaSubstitution() throws { assertCmd(text: "交代5番7番", .japanese, "substitution") }
    func testJaTimeout() throws { assertCmd(text: "タイムアウト", .japanese, "togglePause") }
    func testJaGameEnd() throws { assertCmd(text: "試合終了", .japanese, "finishGame") }

    // MARK: - ko-KR
    // Tense/lax consonant, aspirated/unaspirated confusions

    func testKoThree_common() throws { assertMatch(text: "김선수 쓰리", .korean, "stat.threeMade") }
    func testKoThree_lax() throws { assertMatch(text: "김선수 스리", .korean, "stat.threeMade") }
    func testKoThree_pt() throws { assertMatch(text: "김선수 쓰리포인트", .korean, "stat.threeMade") }

    func testKoTwo_common() throws { assertMatch(text: "김선수 투", .korean, "stat.twoMade") }
    func testKoTwo_lax() throws { assertMatch(text: "김선수 두", .korean, "stat.twoMade") }
    func testKoTwo_pt() throws { assertMatch(text: "김선수 투포인트", .korean, "stat.twoMade") }

    func testKoFreeThrow_common() throws { assertMatch(text: "김선수 자유투", .korean, "stat.freeThrowMade") }
    func testKoFreeThrow_eng() throws { assertMatch(text: "김선수 프리스로우", .korean, "stat.freeThrowMade") }

    func testKoFoul_common() throws { assertMatch(text: "김선수 파울", .korean, "stat.foul") }
    func testKoRebound_common() throws { assertMatch(text: "김선수 리바운드", .korean, "stat.rebound") }
    func testKoRebound_aspirated() throws { assertMatch(text: "김선수 리파운드", .korean, "stat.rebound") }
    func testKoAssist_common() throws { assertMatch(text: "김선수 어시스트", .korean, "stat.assist") }
    func testKoBlock_common() throws { assertMatch(text: "김선수 블록", .korean, "stat.block") }
    func testKoBlock_aspirated() throws { assertMatch(text: "김선수 프록", .korean, "stat.block") }
    func testKoSteal_common() throws { assertMatch(text: "김선수 스틸", .korean, "stat.steal") }
    func testKoTurnover_common() throws { assertMatch(text: "김선수 턴오버", .korean, "stat.turnover") }
    func testKoTurnover_geminate() throws { assertMatch(text: "김선수 턴노버", .korean, "stat.turnover") }

    func testKoSubstitution() throws { assertCmd(text: "교체7번5번", .korean, "substitution") }

    // MARK: - de-DE
    // Capitalization, affricate, loanword variations

    func testDeThree_common() throws { assertMatch(text: "Müller drei", .german, "stat.threeMade") }
    func testDeThree_capital() throws { assertMatch(text: "Müller Drei", .german, "stat.threeMade") }
    func testDeThree_dreier() throws { assertMatch(text: "Müller Dreier", .german, "stat.threeMade") }
    func testDeThree_dreier_lower() throws { assertMatch(text: "Müller dreier", .german, "stat.threeMade") }

    func testDeTwo_common() throws { assertMatch(text: "Müller zwei", .german, "stat.twoMade") }
    func testDeTwo_capital() throws { assertMatch(text: "Müller Zwei", .german, "stat.twoMade") }
    func testDeTwo_pts() throws { assertMatch(text: "Müller zwei punkte", .german, "stat.twoMade") }

    func testDeFreeThrow() throws { assertMatch(text: "Müller freiwurf", .german, "stat.freeThrowMade") }

    func testDeFoul_common() throws { assertMatch(text: "Müller foul", .german, "stat.foul") }
    func testDeRebound_common() throws { assertMatch(text: "Müller rebound", .german, "stat.rebound") }
    func testDeRebound_german() throws { assertMatch(text: "Müller abpraller", .german, "stat.rebound") }
    func testDeAssist_common() throws { assertMatch(text: "Müller assist", .german, "stat.assist") }
    func testDeAssist_german() throws { assertMatch(text: "Müller vorlage", .german, "stat.assist") }
    func testDeBlock_common() throws { assertMatch(text: "Müller block", .german, "stat.block") }
    func testDeSteal_common() throws { assertMatch(text: "Müller steal", .german, "stat.steal") }
    func testDeTurnover_common() throws { assertMatch(text: "Müller turnover", .german, "stat.turnover") }
    func testDeTurnover_german() throws { assertMatch(text: "Müller ballverlust", .german, "stat.turnover") }
    func testDeTurnover_steps() throws { assertMatch(text: "Müller schrittfehler", .german, "stat.turnover") }

    func testDeSubstitution() throws { assertCmd(text: "wechsel 5 für 3", .german, "substitution") }
    func testDeTimeout() throws { assertCmd(text: "auszeit", .german, "togglePause") }
    func testDeGameEnd() throws { assertCmd(text: "spielende", .german, "finishGame") }

    // MARK: - es-ES
    // S-dropping (Andalusian/Caribbean), l/r confusions

    func testEsThree_common() throws { assertMatch(text: "García tres", .spanish, "stat.threeMade") }
    func testEsThree_sdrop() throws { assertMatch(text: "García tre", .spanish, "stat.threeMade") }
    func testEsThree_sdrop_aspirated() throws { assertMatch(text: "García treh", .spanish, "stat.threeMade") }
    func testEsThree_pt() throws { assertMatch(text: "García tres puntos", .spanish, "stat.threeMade") }

    func testEsTwo_common() throws { assertMatch(text: "García dos", .spanish, "stat.twoMade") }
    func testEsTwo_sdrop() throws { assertMatch(text: "García do", .spanish, "stat.twoMade") }

    func testEsLayup_common() throws { assertMatch(text: "García bandeja", .spanish, "stat.layupMade") }
    func testEsFreeThrow_common() throws { assertMatch(text: "García tiro libre", .spanish, "stat.freeThrowMade") }
    func testEsFreeThrow_short() throws { assertMatch(text: "García libre", .spanish, "stat.freeThrowMade") }

    func testEsFoul_common() throws { assertMatch(text: "García falta", .spanish, "stat.foul") }
    func testEsFoul_lr() throws { assertMatch(text: "García farta", .spanish, "stat.foul") }
    func testEsRebound_common() throws { assertMatch(text: "García rebote", .spanish, "stat.rebound") }
    func testEsAssist_common() throws { assertMatch(text: "García asistencia", .spanish, "stat.assist") }
    func testEsBlock_common() throws { assertMatch(text: "García tapón", .spanish, "stat.block") }
    func testEsBlock_acent() throws { assertMatch(text: "García tapon", .spanish, "stat.block") }
    func testEsSteal_common() throws { assertMatch(text: "García robo", .spanish, "stat.steal") }
    func testEsTurnover_common() throws { assertMatch(text: "García perdida", .spanish, "stat.turnover") }

    func testEsTimeout() throws { assertCmd(text: "tiempo muerto", .spanish, "togglePause") }

    // MARK: - fr-FR
    // Liaison, silent consonants, nasal vowels

    func testFrThree_common() throws { assertMatch(text: "Martin trois", .french, "stat.threeMade") }
    func testFrThree_sdrop() throws { assertMatch(text: "Martin troi", .french, "stat.threeMade") }
    func testFrThree_silent() throws { assertMatch(text: "Martin troiz", .french, "stat.threeMade") }
    func testFrThree_pts() throws { assertMatch(text: "Martin trois points", .french, "stat.threeMade") }

    func testFrTwo_common() throws { assertMatch(text: "Martin deux", .french, "stat.twoMade") }
    func testFrTwo_silentx() throws { assertMatch(text: "Martin deu", .french, "stat.twoMade") }

    func testFrFreeThrow() throws { assertMatch(text: "Martin lancer franc", .french, "stat.freeThrowMade") }
    func testFrLayup() throws { assertMatch(text: "Martin lay-up", .french, "stat.layupMade") }

    func testFrFoul_common() throws { assertMatch(text: "Martin faute", .french, "stat.foul") }
    func testFrFoul_vowel() throws { assertMatch(text: "Martin fot", .french, "stat.foul") }
    func testFrRebound_common() throws { assertMatch(text: "Martin rebond", .french, "stat.rebound") }
    func testFrRebound_silentd() throws { assertMatch(text: "Martin rebon", .french, "stat.rebound") }
    func testFrAssist_common() throws { assertMatch(text: "Martin passe décisive", .french, "stat.assist") }
    func testFrBlock_common() throws { assertMatch(text: "Martin contre", .french, "stat.block") }
    func testFrSteal_common() throws { assertMatch(text: "Martin interception", .french, "stat.steal") }
    func testFrTurnover_common() throws { assertMatch(text: "Martin perte de balle", .french, "stat.turnover") }

    func testFrTimeout() throws { assertCmd(text: "temps mort", .french, "togglePause") }

    // MARK: - it-IT
    // Diphthongization, double consonants, open/closed vowels

    func testItThree_common() throws { assertMatch(text: "Rossi tre", .italian, "stat.threeMade") }
    func testItThree_diphthong() throws { assertMatch(text: "Rossi trei", .italian, "stat.threeMade") }
    func testItThree_tripla() throws { assertMatch(text: "Rossi tripla", .italian, "stat.threeMade") }
    func testItThree_pts() throws { assertMatch(text: "Rossi tre punti", .italian, "stat.threeMade") }

    func testItTwo_common() throws { assertMatch(text: "Rossi due", .italian, "stat.twoMade") }
    func testItFreeThrow_common() throws { assertMatch(text: "Rossi tiro libero", .italian, "stat.freeThrowMade") }
    func testItFreeThrow_geminate() throws { assertMatch(text: "Rossi tiro libbero", .italian, "stat.freeThrowMade") }

    func testItFoul_common() throws { assertMatch(text: "Rossi fallo", .italian, "stat.foul") }
    func testItRebound_common() throws { assertMatch(text: "Rossi rimbalzo", .italian, "stat.rebound") }
    func testItRebound_zs() throws { assertMatch(text: "Rossi rimbalso", .italian, "stat.rebound") }
    func testItAssist_common() throws { assertMatch(text: "Rossi assist", .italian, "stat.assist") }
    func testItBlock_common() throws { assertMatch(text: "Rossi stoppata", .italian, "stat.block") }
    func testItBlock_open() throws { assertMatch(text: "Rossi stòppata", .italian, "stat.block") }
    func testItSteal_common() throws { assertMatch(text: "Rossi palla rubata", .italian, "stat.steal") }
    func testItTurnover_common() throws { assertMatch(text: "Rossi palle perse", .italian, "stat.turnover") }

    // MARK: - ru-RU
    // р/л, в/л, devoicing, vowel reduction

    func testRuThree_common() throws { assertMatch(text: "Иванов три", .russian, "stat.threeMade") }
    func testRuThree_rl() throws { assertMatch(text: "Иванов тли", .russian, "stat.threeMade") }

    func testRuTwo_common() throws { assertMatch(text: "Иванов два", .russian, "stat.twoMade") }
    func testRuTwo_vl() throws { assertMatch(text: "Иванов дла", .russian, "stat.twoMade") }

    func testRuFreeThrow() throws { assertMatch(text: "Иванов штрафной", .russian, "stat.freeThrowMade") }
    func testRuTwo_pts() throws { assertMatch(text: "Иванов два очка", .russian, "stat.twoMade") }

    func testRuFoul_common() throws { assertMatch(text: "Иванов фол", .russian, "stat.foul") }
    func testRuFoul_vowel_reduction() throws { assertMatch(text: "Иванов фал", .russian, "stat.foul") }
    func testRuFoul_fv() throws { assertMatch(text: "Иванов вал", .russian, "stat.foul") }
    func testRuRebound_common() throws { assertMatch(text: "Иванов подбор", .russian, "stat.rebound") }
    func testRuRebound_devoice() throws { assertMatch(text: "Иванов потбор", .russian, "stat.rebound") }
    func testRuAssist_common() throws { assertMatch(text: "Иванов передача", .russian, "stat.assist") }
    func testRuBlock_common() throws { assertMatch(text: "Иванов блок", .russian, "stat.block") }
    func testRuSteal_common() throws { assertMatch(text: "Иванов перехват", .russian, "stat.steal") }
    func testRuTurnover_common() throws { assertMatch(text: "Иванов потеря", .russian, "stat.turnover") }

    func testRuSubstitution() throws { assertCmd(text: "замена 7 на 5", .russian, "substitution") }
    func testRuGameEnd() throws { assertCmd(text: "конец игры", .russian, "finishGame") }

    // MARK: - Helpers

    private func assertMatch(text: String, _ rules: VoiceRules, _ expected: String, line: UInt = #line) {
        guard let code = findEvent(text: text, rules: rules) else {
            XCTFail("❌ NO MATCH: '\(text)' with \(rules.locale.identifier)", line: line); return
        }
        let prefix = expected.replacingOccurrences(of: "Made", with: "").replacingOccurrences(of: "Missed", with: "")
        XCTAssertTrue(code.hasPrefix(prefix) || code == expected,
                      "❌ WRONG: '\(text)' → '\(code)' expected '\(expected)'", line: line)
    }

    private func assertCmd(text: String, _ rules: VoiceRules, _ expected: String, line: UInt = #line) {
        guard let code = findEvent(text: text, rules: rules) else {
            XCTFail("No command matched: \(text)", line: line); return
        }
        let map: [String: [String]] = ["togglePause": ["event.pause"], "startPeriod": ["event.period"],
                                        "finishGame": ["event.game_end"], "substitution": ["event.substitution"]]
        guard let codes = map[expected] else { XCTFail("Unknown: \(expected)", line: line); return }
        XCTAssertTrue(codes.contains(code), "'\(text)' → '\(code)' expected '\(expected)'", line: line)
    }

    private func findEvent(text: String, rules: VoiceRules) -> String? {
        for kw in rules.substitutionKeywords { if text.lowercased().contains(kw.lowercased()) { return "event.substitution" } }
        for shot in rules.shotKeywords {
            guard let r = text.range(of: shot.keyword, options: .caseInsensitive) else { continue }
            let right = String(text[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            for s in rules.missedStates { if right.contains(s) { return shot.eventPrefix + "Missed" } }
            return shot.eventPrefix + "Made"
        }
        for (kw, code) in rules.statEvents { if text.contains(kw) { return code } }
        for (kw, code) in rules.commandEvents { if text.lowercased().contains(kw.lowercased()) { return code } }
        return nil
    }
}
