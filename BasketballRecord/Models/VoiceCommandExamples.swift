import Foundation

struct VoiceCommandExamples {

    struct Templates {
        let locale: String
        let hintPrefix: String
        let hintSeparator: String
        let shotTypeNames: [String]
        let statTypeNames: [(String, String)]
        let substitutionFormat: String
        let periodPauseCommands: [String]
        let gameEndCommands: [String]
        let shotExamples: [(String, String)]
        let statExamples: [(String, String)]
        let substitutionExamples: [String]
        let actionTemplates: [StatAction: [String]]
    }

    static func templates(for languageCode: String) -> Templates {
        switch languageCode {
        case "zh-Hans": return chineseTemplates
        case "zh-Hant": return traditionalChineseTemplates
        case "en": return englishTemplates
        case "ja": return japaneseTemplates
        case "ko": return koreanTemplates
        case "de": return germanTemplates
        case "es": return spanishTemplates
        case "fr": return frenchTemplates
        case "it": return italianTemplates
        case "ru": return russianTemplates
        default: return englishTemplates
        }
    }

    // MARK: - Chinese Simplified

    private static let chineseTemplates = Templates(
        locale: "zh-Hans",
        hintPrefix: "请说",
        hintSeparator: "·",
        shotTypeNames: ["两分", "三分", "罚球", "加罚", "上篮", "中投", "篮下"],
        statTypeNames: [
            ("stat.foul", "犯规"), ("stat.rebound", "篮板"), ("stat.offensiveRebound", "前场板"),
            ("stat.defensiveRebound", "后场板"), ("stat.assist", "助攻"),
            ("stat.block", "盖帽"), ("stat.steal", "抢断"), ("stat.turnover", "失误"),
        ],
        substitutionFormat: "场上球员 + 换 + 替补球员",
        periodPauseCommands: ["第一节开始", "第二节开始", "暂停", "停表", "继续"],
        gameEndCommands: [],
        shotExamples: [
            ("两分命中", "张三两分命中"), ("两分未中", "李四两分未中"),
            ("三分命中", "张三三分命中"), ("三分未中", "李四三分未中"),
            ("罚球命中", "张三罚球命中"), ("罚球未中", "李四罚球未中"),
            ("加罚命中", "张三加罚命中"), ("上篮命中", "张三上篮命中"),
            ("中投命中", "张三中投命中"), ("篮下命中", "张三篮下命中"),
        ],
        statExamples: [
            ("犯规", "张三犯规"), ("篮板", "张三篮板"), ("助攻", "张三助攻"),
            ("盖帽", "张三盖帽"), ("抢断", "张三抢断"), ("失误", "张三失误"),
        ],
        substitutionExamples: ["张三换李四", "3号换5号", "王五替换赵六"],
        actionTemplates: [
            .twoMade: ["{name}两分", "{number}号两分", "{team}{number}号两分"],
            .twoMissed: ["{number}号两分不中", "{name}两分没进", "{number}号两分没中"],
            .threeMade: ["{name}三分", "{number}号三分"],
            .threeMissed: ["{name}三分不中", "{number}号三分没进", "{name}三分没中"],
            .freeThrowMade: ["{name}罚球", "{number}号罚球"],
            .freeThrowMissed: ["{name}罚球不中", "{number}号罚球没进", "{name}罚球没中"],
            .layupMade: ["{name}上篮", "{number}号上篮"],
            .midRangeMade: ["{name}中投", "{number}号中距离"],
            .paintMade: ["{name}篮下", "{team}{number}号内线", "{name}篮下得分"],
            .rebound: ["{name}篮板", "{team}{number}号篮板", "{name}抢到篮板"],
            .offensiveRebound: ["{name}前场板", "{number}号前场板", "{name}前场篮板"],
            .defensiveRebound: ["{name}后场板", "{number}号后场板", "{name}后场篮板"],
            .assist: ["{name}助攻", "{number}号助攻", "{name}传出助攻"],
            .block: ["{name}盖帽", "{number}号盖帽", "{name}封盖"],
            .steal: ["{name}抢断", "{number}号抢断", "{name}断球", "{name}抢断{target}"],
            .turnover: ["{name}失误", "{number}号失误", "{name}走步"],
            .foul: ["{name}犯规", "{team}{number}号犯规", "{name}犯规了"],
            .bonusMade: ["{name}加罚", "{number}号加罚", "{name}加罚命中"],
        ]
    )

    // MARK: - Chinese Traditional

    private static let traditionalChineseTemplates = Templates(
        locale: "zh-Hant",
        hintPrefix: "請說",
        hintSeparator: "·",
        shotTypeNames: ["兩分", "三分", "罰球", "加罰", "上籃", "中投", "籃下"],
        statTypeNames: [
            ("stat.foul", "犯規"), ("stat.rebound", "籃板"), ("stat.offensiveRebound", "前場板"),
            ("stat.defensiveRebound", "後場板"), ("stat.assist", "助攻"),
            ("stat.block", "蓋帽"), ("stat.steal", "抄截"), ("stat.turnover", "失誤"),
        ],
        substitutionFormat: "場上球員 + 換 + 替補球員",
        periodPauseCommands: ["第一節開始", "第二節開始", "暫停", "停表", "繼續"],
        gameEndCommands: [],
        shotExamples: [
            ("兩分命中", "張三兩分命中"), ("兩分未中", "李四兩分未中"),
            ("三分命中", "張三分命中"), ("三分未中", "李四三分未中"),
            ("罰球命中", "張三罰球命中"), ("罰球未中", "李四罰球未中"),
            ("加罰命中", "張三加罰命中"), ("上籃命中", "張三上籃命中"),
            ("中投命中", "張三中投命中"), ("籃下命中", "張三籃下命中"),
        ],
        statExamples: [
            ("犯規", "張三犯規"), ("籃板", "張三籃板"), ("助攻", "張三助攻"),
            ("蓋帽", "張三蓋帽"), ("抄截", "張三抄截"), ("失誤", "張三失誤"),
        ],
        substitutionExamples: ["張三換李四", "3號換5號", "王五替換趙六"],
        actionTemplates: [
            .twoMade: ["{name}兩分", "{number}號兩分", "{team}{number}號兩分"],
            .twoMissed: ["{number}號兩分不中", "{name}兩分沒進", "{number}號兩分沒中"],
            .threeMade: ["{name}三分", "{number}號三分"],
            .threeMissed: ["{name}三分不中", "{number}號三分沒進", "{name}三分沒中"],
            .freeThrowMade: ["{name}罰球", "{number}號罰球"],
            .freeThrowMissed: ["{name}罰球不中", "{number}號罰球沒進", "{name}罰球沒中"],
            .layupMade: ["{name}上籃", "{number}號上籃"],
            .midRangeMade: ["{name}中投", "{number}號中距離"],
            .paintMade: ["{name}籃下", "{team}{number}號內線", "{name}籃下得分"],
            .rebound: ["{name}籃板", "{team}{number}號籃板", "{name}搶到籃板"],
            .offensiveRebound: ["{name}前場板", "{number}號前場板", "{name}前場籃板"],
            .defensiveRebound: ["{name}後場板", "{number}號後場板", "{name}後場籃板"],
            .assist: ["{name}助攻", "{number}號助攻", "{name}傳出助攻"],
            .block: ["{name}蓋帽", "{number}號蓋帽", "{name}封蓋"],
            .steal: ["{name}抄截", "{number}號抄截", "{name}抄截了", "{name}抄截{target}"],
            .turnover: ["{name}失誤", "{number}號失誤", "{name}走步"],
            .foul: ["{name}犯規", "{team}{number}號犯規", "{name}犯規了"],
            .bonusMade: ["{name}加罰", "{number}號加罰", "{name}加罰命中"],
        ]
    )

    // MARK: - English

    private static let englishTemplates = Templates(
        locale: "en",
        hintPrefix: "Say ",
        hintSeparator: "·",
        shotTypeNames: ["two", "three", "free throw", "bonus/and one", "layup", "mid(range)", "paint/inside"],
        statTypeNames: [
            ("stat.foul", "foul"), ("stat.rebound", "rebound"), ("stat.offensiveRebound", "offensive rebound"),
            ("stat.defensiveRebound", "defensive rebound"), ("stat.assist", "assist"),
            ("stat.block", "block"), ("stat.steal", "steal"), ("stat.turnover", "turnover"),
        ],
        substitutionFormat: "outgoing player + sub/replace + incoming player",
        periodPauseCommands: ["Start", "Begin", "Tip off", "Timeout", "Pause", "Stop", "Resume", "Continue", "Play"],
        gameEndCommands: ["End", "Finish", "Game over"],
        shotExamples: [
            ("two made", "John two"), ("two missed", "John miss 2"),
            ("three made", "Mike three"), ("three missed", "Mike miss 3"),
            ("free throw made", "Mike free throw"), ("free throw missed", "Mike miss free"),
            ("layup made", "John layup"), ("mid made", "Mike mid range"),
            ("paint made", "Steve paint"), ("bonus made", "John and one"),
        ],
        statExamples: [
            ("foul", "Jones foul"), ("rebound", "Smith rebound"), ("assist", "Mike assist"),
            ("block", "Brown block"), ("steal", "Williams steal"), ("turnover", "Wilson turnover"),
        ],
        substitutionExamples: ["23 sub 5", "sub 7 for 10", "Jordan sub Curry"],
        actionTemplates: [
            .twoMade: ["{name} two", "{name} got 2", "{number} two"],
            .twoMissed: ["{number} no 2", "{name} miss 2", "{number} missed two"],
            .threeMade: ["{name} three", "{team} {number} three", "{name} got 3"],
            .threeMissed: ["{name} no 3", "{number} miss three", "{name} missed three"],
            .freeThrowMade: ["{name} free throw", "{number} free", "{name} free"],
            .freeThrowMissed: ["{name} no free", "{number} miss free throw", "{number} free no"],
            .layupMade: ["{name} layup", "{number} lay up", "{name} layup made"],
            .midRangeMade: ["{name} mid range", "{name} jumper", "{number} mid"],
            .paintMade: ["{name} paint", "{team} {number} inside", "{number} paint"],
            .rebound: ["{name} rebound", "{team} {number} rebound", "{name} got rebound"],
            .offensiveRebound: ["{name} offensive rebound", "{number} oreb", "{name} got offensive board"],
            .defensiveRebound: ["{name} defensive rebound", "{number} dreb", "{name} got defensive board"],
            .assist: ["{name} assist", "{team} {number} assist", "{number} assist"],
            .block: ["{name} block", "{number} block", "{team} {number} block"],
            .steal: ["{name} steal", "{number} steal", "{team} {number} steal", "{name} steal {target}"],
            .turnover: ["{name} turnover", "{number} turnover", "{name} turn over"],
            .foul: ["{name} foul", "{team} {number} foul", "{name} fouls"],
            .bonusMade: ["{name} bonus", "{number} and one", "{name} and one"],
        ]
    )

    // MARK: - Japanese

    private static let japaneseTemplates = Templates(
        locale: "ja",
        hintPrefix: "",
        hintSeparator: "·",
        shotTypeNames: ["ツーポイント", "スリーポイント", "フリースロー", "レイアップ", "ミドル", "ペイント", "ボーナス"],
        statTypeNames: [
            ("stat.foul", "ファウル"), ("stat.rebound", "リバウンド"), ("stat.offensiveRebound", "オフェンスリバウンド"),
            ("stat.defensiveRebound", "ディフェンスリバウンド"), ("stat.assist", "アシスト"),
            ("stat.block", "ブロック"), ("stat.steal", "スティール"), ("stat.turnover", "ターンオーバー"),
        ],
        substitutionFormat: "コート上の選手 + 交代キーワード + 控え選手",
        periodPauseCommands: ["第1クオーター開始", "タイムアウト", "一時停止", "再開", "試合終了"],
        gameEndCommands: ["終了", "試合終了", "ゲーム終了"],
        shotExamples: [
            ("ツー成功", "田中ツー成功"), ("ツー失敗", "田中ツー失敗"),
            ("スリー成功", "鈴木スリー成功"), ("スリー失敗", "鈴木スリー失敗"),
            ("フリー成功", "鈴木フリー成功"), ("フリー失敗", "鈴木フリー失敗"),
            ("レイアップ", "田中レイアップ"), ("ミドル", "鈴木ミドル"),
            ("ペイント", "山田ペイント"), ("ボーナス", "田中ボーナス"),
        ],
        statExamples: [
            ("ファウル", "山田ファウル"), ("リバウンド", "山田リバウンド"), ("アシスト", "鈴木アシスト"),
            ("ブロック", "佐藤ブロック"), ("スティール", "田中止ティール"), ("ターンオーバー", "佐藤ターンオーバー"),
        ],
        substitutionExamples: ["田中と鈴木を交代", "7番10番交代"],
        actionTemplates: [
            .twoMade: ["{name}ツー", "{name}２点", "{number}番ツー成功"],
            .twoMissed: ["{name}ツーなし", "{number}番ツー外した", "{name}２点ミス"],
            .threeMade: ["{name}スリー", "{number}番スリー", "{name}３点"],
            .threeMissed: ["{name}スリーなし", "{number}番スリー外した", "{name}３点ミス"],
            .freeThrowMade: ["{name}フリースロー", "{number}番フリー", "{name}フリー成功"],
            .freeThrowMissed: ["{name}フリーなし", "{number}番フリーミス", "{name}フリー失敗"],
            .layupMade: ["{name}レイアップ", "{number}番レイアップ", "{name}レイアップ成功"],
            .midRangeMade: ["{name}ミドルレンジ", "{number}番ジャンパー", "{name}中距離"],
            .paintMade: ["{name}ペイント", "{team}{number}番ペイント", "{team}{number}番インサイド"],
            .rebound: ["{name}リバウンド", "{team}{number}番リバウンド", "{team}リバウンド"],
            .offensiveRebound: ["{name}オフェンスリバウンド", "{number}番オフェンスリバウンド", "{name}オフェンスリバウンド"],
            .defensiveRebound: ["{name}ディフェンスリバウンド", "{number}番ディフェンスリバウンド", "{name}ディフェンスリバウンド"],
            .foul: ["{name}ファウル", "{team}{number}番ファウル", "{team}{number}番ファウル"],
            .assist: ["{name}アシスト", "{team}{number}番アシスト", "{number}番アシスト"],
            .block: ["{name}ブロック", "{number}番ブロック", "{team}{number}番ブロック"],
            .steal: ["{name}スティール", "{number}番スティール", "{team}{number}番スティール", "{name}が{target}からスティール"],
            .turnover: ["{name}ターンオーバー", "{number}番ターンオーバー", "{name}ボールロスト"],
            .bonusMade: ["{name}ボーナス", "{number}番アンドワン", "{name}追加フリー"],
        ]
    )

    // MARK: - Korean

    private static let koreanTemplates = Templates(
        locale: "ko",
        hintPrefix: "",
        hintSeparator: "·",
        shotTypeNames: ["투포인트", "쓰리포인트", "자유투", "레이업", "미드", "페인트", "보너스"],
        statTypeNames: [
            ("stat.foul", "파울"), ("stat.rebound", "리바운드"), ("stat.offensiveRebound", "공격 리바운드"),
            ("stat.defensiveRebound", "수비 리바운드"), ("stat.assist", "어시스트"),
            ("stat.block", "블록"), ("stat.steal", "스틸"), ("stat.turnover", "턴오버"),
        ],
        substitutionFormat: "코트 선수 + 교체 키워드 + 대기 선수",
        periodPauseCommands: ["첫 쿼터 시작", "타임아웃", "일시정지", "재개", "경기종료"],
        gameEndCommands: ["종료", "경기종료", "끝"],
        shotExamples: [
            ("투 성공", "김철수 투 성공"), ("투 실패", "김철수 투 실패"),
            ("쓰리 성공", "이영희 쓰리 성공"), ("쓰리 실패", "이영희 쓰리 실패"),
            ("자유투 성공", "이영희 자유투 성공"), ("자유투 실패", "이영희 자유투 실패"),
            ("레이업", "김철수 레이업"), ("미드레인지", "이영희 미드레인지"),
            ("페인트", "박민수 페인트"), ("보너스", "김철수 보너스"),
        ],
        statExamples: [
            ("파울", "박민수 파울"), ("리바운드", "박민수 리바운드"), ("어시스트", "이영희 어시스트"),
            ("블록", "정지원 블록"), ("스틸", "김철수 스틸"), ("턴오버", "정지원 턴오버"),
        ],
        substitutionExamples: ["7번 10번 교체", "김철수 교체 이영희"],
        actionTemplates: [
            .twoMade: ["{name} 투", "{name} 2점", "{number}번 2점 성공"],
            .twoMissed: ["{name} 투 실패", "{number}번 2점 못 넣음", "{name} 2점 미스"],
            .threeMade: ["{name} 쓰리", "{number}번 3점", "{name} 3점 성공"],
            .threeMissed: ["{name} 쓰리 실패", "{number}번 3점 못 넣음", "{name} 3점 미스"],
            .freeThrowMade: ["{name} 자유투", "{number}번 자유투", "{name} 프리 성공"],
            .freeThrowMissed: ["{name} 자유투 실패", "{number}번 자유투 못 넣음", "{name} 프리 미스"],
            .layupMade: ["{name} 레이업", "{number}번 레이업", "{name} 레이업 성공"],
            .midRangeMade: ["{name} 미드레인지", "{number}번 점퍼", "{name} 중거리"],
            .paintMade: ["{name} 페인트", "{team} {number}번 페인트", "{team} {number}번 인사이드"],
            .rebound: ["{name} 리바운드", "{team} {number}번 리바운드", "{team} {number}번 리바운드"],
            .offensiveRebound: ["{name} 공격 리바운드", "{number}번 공격 리바운드", "{name} 공격 리바운드"],
            .defensiveRebound: ["{name} 수비 리바운드", "{number}번 수비 리바운드", "{name} 수비 리바운드"],
            .foul: ["{name} 파울", "{team} {number}번 파울", "{team} {number}번 파울"],
            .assist: ["{name} 어시스트", "{team} {number}번 어시스트", "{number}번 어시스트"],
            .block: ["{name} 블록", "{number}번 블록", "{team} {number}번 블록"],
            .steal: ["{name} 스틸", "{number}번 스틸", "{team} {number}번 스틸", "{name}가{target}를 스틸"],
            .turnover: ["{name} 턴오버", "{number}번 턴오버", "{name} 볼 손실"],
            .bonusMade: ["{name} 보너스", "{number}번 앤드원", "{name} 추가 자유투"],
        ]
    )

    // MARK: - German

    private static let germanTemplates = Templates(
        locale: "de",
        hintPrefix: "",
        hintSeparator: "·",
        shotTypeNames: ["zwei", "drei", "Freiwurf", "Bonus", "Layup", "Mitteldistanz", "Korb"],
        statTypeNames: [
            ("stat.foul", "Foul"), ("stat.rebound", "Rebound"), ("stat.offensiveRebound", "Offensiv Rebound"),
            ("stat.defensiveRebound", "Defensiv Rebound"), ("stat.assist", "Assist"),
            ("stat.block", "Block"), ("stat.steal", "Steal"), ("stat.turnover", "Turnover"),
        ],
        substitutionFormat: "ausgehender Spieler + Wechsel + eingehender Spieler",
        periodPauseCommands: ["Start", "Erstes Viertel", "Pause", "Auszeit", "Weiter", "Ende", "Spielende"],
        gameEndCommands: ["Ende", "Spielende", "Schluss"],
        shotExamples: [
            ("zwei getroffen", "Hans zwei getroffen"), ("zwei verfehlt", "Hans zwei verfehlt"),
            ("drei getroffen", "Fritz drei getroffen"), ("drei verfehlt", "Fritz drei verfehlt"),
            ("Freiwurf getroffen", "Fritz Freiwurf getroffen"), ("Freiwurf verfehlt", "Fritz Freiwurf verfehlt"),
            ("Layup", "Hans Layup"), ("Mitteldistanz", "Fritz Mitteldistanz"),
            ("Korb", "Klaus Korb"), ("Bonus", "Hans Bonus"),
        ],
        statExamples: [
            ("Foul", "Hans Foul"), ("Rebound", "Klaus Rebound"), ("Assist", "Fritz Assist"),
            ("Block", "Gerd Block"), ("Steal", "Hans Steal"), ("Turnover", "Gerd Turnover"),
        ],
        substitutionExamples: ["Wechsel 7 und 10", "Hans raus Fritz rein"],
        actionTemplates: [
            .twoMade: ["{name} zwei", "{name} 2 Punkte", "{number} zwei getroffen"],
            .twoMissed: ["{name} zwei daneben", "{number} zwei verfehlt", "{name} 2 Punkte nicht"],
            .threeMade: ["{name} drei", "{number} drei", "{name} 3 Punkte"],
            .threeMissed: ["{name} drei daneben", "{number} drei verfehlt", "{name} 3 Punkte nicht"],
            .freeThrowMade: ["{name} Freiwurf", "{number} Freiwurf", "{name} frei getroffen"],
            .freeThrowMissed: ["{name} Freiwurf daneben", "{number} Freiwurf verfehlt", "{name} frei nicht"],
            .layupMade: ["{name} Layup", "{number} Layup", "{name} Korbleger"],
            .midRangeMade: ["{name} Mitteldistanz", "{number} Jumpshot", "{name} mittlerer Wurf"],
            .paintMade: ["{name} Korb", "{team} {number} Korb", "{team} {number} innen"],
            .rebound: ["{name} Rebound", "{team} {number} Rebound", "{team} {number} Rebound"],
            .offensiveRebound: ["{name} offensiv Rebound", "{number} offensiv", "{name} offensiver Rebound"],
            .defensiveRebound: ["{name} defensiv Rebound", "{number} defensiv", "{name} defensiver Rebound"],
            .foul: ["{name} Foul", "{team} {number} Foul", "{team} {number} Foul"],
            .assist: ["{name} Assist", "{team} {number} Assist", "{number} Assist"],
            .block: ["{name} Block", "{number} Block", "{team} {number} Block"],
            .steal: ["{name} Steal", "{number} Steal", "{team} {number} Steal", "{name} Steal {target}"],
            .turnover: ["{name} Turnover", "{number} Turnover", "{name} Ballverlust"],
            .bonusMade: ["{name} Bonus", "{number} and one", "{name} Bonus Freiwurf"],
        ]
    )

    // MARK: - Spanish

    private static let spanishTemplates = Templates(
        locale: "es",
        hintPrefix: "",
        hintSeparator: "·",
        shotTypeNames: ["dos", "tres", "tiro libre", "bonus", "bandeja", "media", "pintura"],
        statTypeNames: [
            ("stat.foul", "falta"), ("stat.rebound", "rebote"), ("stat.offensiveRebound", "rebote ofensivo"),
            ("stat.defensiveRebound", "rebote defensivo"), ("stat.assist", "asistencia"),
            ("stat.block", "bloqueo"), ("stat.steal", "robo"), ("stat.turnover", "perdida"),
        ],
        substitutionFormat: "jugador saliente + cambio + jugador entrante",
        periodPauseCommands: ["Inicio", "Primer cuarto", "Pausa", "Tiempo muerto", "Continuar", "Final"],
        gameEndCommands: ["Final", "Fin del partido", "Terminar"],
        shotExamples: [
            ("dos canasta", "Carlos dos canasta"), ("dos fallado", "Carlos dos fallado"),
            ("tres canasta", "Luis tres canasta"), ("tres fallado", "Luis tres fallado"),
            ("libre canasta", "Luis tiro libre canasta"), ("libre fallado", "Luis libre fallado"),
            ("bandeja", "Carlos bandeja"), ("media", "Luis media"),
            ("pintura", "Jose pintura"), ("bonus", "Carlos bonus"),
        ],
        statExamples: [
            ("falta", "Carlos falta"), ("rebote", "Jose rebote"), ("asistencia", "Luis asistencia"),
            ("bloqueo", "Juan bloqueo"), ("robo", "Carlos robo"), ("perdida", "Juan perdida"),
        ],
        substitutionExamples: ["Cambio 7 por 10", "Carlos sale Luis entra"],
        actionTemplates: [
            .twoMade: ["{name} dos", "{name} 2 puntos", "{number} dos canasta"],
            .twoMissed: ["{name} dos fallado", "{number} dos no", "{name} 2 puntos fallado"],
            .threeMade: ["{name} tres", "{number} tres", "{name} 3 puntos"],
            .threeMissed: ["{name} tres fallado", "{number} tres no", "{name} 3 puntos fallado"],
            .freeThrowMade: ["{name} tiro libre", "{number} libre", "{name} libre canasta"],
            .freeThrowMissed: ["{name} libre fallado", "{number} libre no", "{name} tiro libre fallado"],
            .layupMade: ["{name} bandeja", "{number} bandeja", "{name} layup"],
            .midRangeMade: ["{name} media distancia", "{number} jumper", "{name} tiro medio"],
            .paintMade: ["{name} pintura", "{team} {number} pintura", "{team} {number} interior"],
            .rebound: ["{name} rebote", "{team} {number} rebote", "{team} {number} rebote"],
            .offensiveRebound: ["{name} rebote ofensivo", "{number} rebote ofensivo", "{name} rebote ofensivo"],
            .defensiveRebound: ["{name} rebote defensivo", "{number} rebote defensivo", "{name} rebote defensivo"],
            .foul: ["{name} falta", "{team} {number} falta", "{team} {number} falta"],
            .assist: ["{name} asistencia", "{team} {number} asistencia", "{number} asistencia"],
            .block: ["{name} bloqueo", "{number} bloqueo", "{team} {number} bloqueo"],
            .steal: ["{name} robo", "{number} robo", "{team} {number} robo", "{name} robo {target}"],
            .turnover: ["{name} perdida", "{number} perdida", "{name} turnover"],
            .bonusMade: ["{name} bonus", "{number} and one", "{name} tiro extra"],
        ]
    )

    // MARK: - French

    private static let frenchTemplates = Templates(
        locale: "fr",
        hintPrefix: "",
        hintSeparator: "·",
        shotTypeNames: ["deux", "trois", "lancer franc", "bonus", "layup", "mi-distance", "interieur"],
        statTypeNames: [
            ("stat.foul", "faute"), ("stat.rebound", "rebond"), ("stat.offensiveRebound", "rebond offensif"),
            ("stat.defensiveRebound", "rebond défensif"), ("stat.assist", "passe decisive"),
            ("stat.block", "contre"), ("stat.steal", "interception"), ("stat.turnover", "perte de balle"),
        ],
        substitutionFormat: "joueur sortant + remplace + joueur entrant",
        periodPauseCommands: ["Debut", "Premier quart", "Pause", "Temps mort", "Continuer", "Fin"],
        gameEndCommands: ["Fin", "Fin du match", "Termine"],
        shotExamples: [
            ("deux bon", "Pierre deux bon"), ("deux non", "Pierre deux non"),
            ("trois bon", "Paul trois bon"), ("trois non", "Paul trois non"),
            ("lancer franc bon", "Paul lancer franc bon"), ("lancer franc non", "Paul lancer franc non"),
            ("layup", "Pierre layup"), ("mi-distance", "Paul mi-distance"),
            ("interieur", "Jacques interieur"), ("bonus", "Pierre bonus"),
        ],
        statExamples: [
            ("faute", "Jacques faute"), ("rebond", "Jacques rebond"), ("passe decisive", "Paul passe decisive"),
            ("contre", "Luc contre"), ("interception", "Pierre interception"), ("perte de balle", "Luc perte de balle"),
        ],
        substitutionExamples: ["Remplace 7 par 10", "Pierre sort Paul entre"],
        actionTemplates: [
            .twoMade: ["{name} deux", "{name} 2 points", "{number} deux bon"],
            .twoMissed: ["{name} deux non", "{number} deux loupe", "{name} 2 points non"],
            .threeMade: ["{name} trois", "{number} trois", "{name} 3 points"],
            .threeMissed: ["{name} trois non", "{number} trois loupe", "{name} 3 points non"],
            .freeThrowMade: ["{name} lancer franc", "{number} lancer franc", "{name} libre bon"],
            .freeThrowMissed: ["{name} lancer franc non", "{number} libre non", "{name} lancer franc loupe"],
            .layupMade: ["{name} layup", "{number} layup", "{name} panier facile"],
            .midRangeMade: ["{name} mi-distance", "{number} jumper", "{name} tir moyen"],
            .paintMade: ["{name} interieur", "{team} {number} interieur", "{team} {number} raquette"],
            .rebound: ["{name} rebond", "{team} {number} rebond", "{team} {number} rebond"],
            .offensiveRebound: ["{name} rebond offensif", "{number} rebond offensif", "{name} rebond offensif"],
            .defensiveRebound: ["{name} rebond défensif", "{number} rebond défensif", "{name} rebond défensif"],
            .foul: ["{name} faute", "{team} {number} faute", "{team} {number} faute"],
            .assist: ["{name} assist", "{number} passe decisive", "{team} {number} assist"],
            .block: ["{name} contre", "{number} contre", "{team} {number} contre"],
            .steal: ["{name} interception", "{number} interception", "{team} {number} interception", "{name} interception {target}"],
            .turnover: ["{name} turnover", "{number} turnover", "{name} perte de balle"],
            .bonusMade: ["{name} bonus", "{number} and one", "{name} lancer franc bonus"],
        ]
    )

    // MARK: - Italian

    private static let italianTemplates = Templates(
        locale: "it",
        hintPrefix: "",
        hintSeparator: "·",
        shotTypeNames: ["due", "tre", "tiro libero", "bonus", "layup", "media", "dentro"],
        statTypeNames: [
            ("stat.foul", "fallo"), ("stat.rebound", "rimbalzo"), ("stat.offensiveRebound", "rimbalzo offensivo"),
            ("stat.defensiveRebound", "rimbalzo difensivo"), ("stat.assist", "assist"),
            ("stat.block", "stoppata"), ("stat.steal", "palla rubata"), ("stat.turnover", "perse"),
        ],
        substitutionFormat: "giocatore uscente + cambio + giocatore entrante",
        periodPauseCommands: ["Inizio", "Primo quarto", "Pausa", "Timeout", "Continua", "Fine"],
        gameEndCommands: ["Fine", "Fine partita", "Finito"],
        shotExamples: [
            ("due segnato", "Marco due segnato"), ("due sbagliato", "Marco due sbagliato"),
            ("tre segnato", "Luca tre segnato"), ("tre sbagliato", "Luca tre sbagliato"),
            ("libero segnato", "Luca tiro libero segnato"), ("libero sbagliato", "Luca libero sbagliato"),
            ("layup", "Marco layup"), ("media", "Luca media"),
            ("dentro", "Paolo dentro"), ("bonus", "Marco bonus"),
        ],
        statExamples: [
            ("fallo", "Paolo fallo"), ("rimbalzo", "Paolo rimbalzo"), ("assist", "Luca assist"),
            ("stoppata", "Mario stoppata"), ("palla rubata", "Marco palla rubata"), ("perse", "Mario perse"),
        ],
        substitutionExamples: ["Cambia 7 con 10", "Marco fuori Luca dentro"],
        actionTemplates: [
            .twoMade: ["{name} due", "{name} 2 punti", "{number} due segnato"],
            .twoMissed: ["{name} due sbagliato", "{number} due no", "{name} 2 punti fallito"],
            .threeMade: ["{name} tre", "{number} tre", "{name} 3 punti"],
            .threeMissed: ["{name} tre sbagliato", "{number} tre no", "{name} 3 punti fallito"],
            .freeThrowMade: ["{name} tiro libero", "{number} libero", "{name} libero segnato"],
            .freeThrowMissed: ["{name} libero sbagliato", "{number} libero no", "{name} tiro libero fallito"],
            .layupMade: ["{name} layup", "{number} layup", "{name} layup segnato"],
            .midRangeMade: ["{name} media distanza", "{number} jumper", "{name} tiro medio"],
            .paintMade: ["{name} dentro", "{team} {number} dentro", "{team} {number} interno"],
            .rebound: ["{name} rimbalzo", "{team} {number} rimbalzo", "{team} {number} rimbalzo"],
            .offensiveRebound: ["{name} rimbalzo offensivo", "{number} rimbalzo offensivo", "{name} rimbalzo offensivo"],
            .defensiveRebound: ["{name} rimbalzo difensivo", "{number} rimbalzo difensivo", "{name} rimbalzo difensivo"],
            .foul: ["{name} fallo", "{team} {number} fallo", "{team} {number} fallo"],
            .assist: ["{name} assist", "{team} {number} assist", "{number} assist"],
            .block: ["{name} stoppata", "{number} stoppata", "{team} {number} blocco"],
            .steal: ["{name} palla rubata", "{number} rubata", "{team} {number} rubata", "{name} rubata {target}"],
            .turnover: ["{name} turnover", "{number} turnover", "{name} palla persa"],
            .bonusMade: ["{name} bonus", "{number} and one", "{name} tiro extra"],
        ]
    )

    // MARK: - Russian

    private static let russianTemplates = Templates(
        locale: "ru",
        hintPrefix: "",
        hintSeparator: "·",
        shotTypeNames: ["два", "три", "штрафной", "бонус", "лей-ап", "средний", "краска"],
        statTypeNames: [
            ("stat.foul", "фол"), ("stat.rebound", "подбор"), ("stat.offensiveRebound", "подбор в нападении"),
            ("stat.defensiveRebound", "подбор в защите"), ("stat.assist", "ассист"),
            ("stat.block", "блок"), ("stat.steal", "перехват"), ("stat.turnover", "потеря"),
        ],
        substitutionFormat: "выходящий игрок + замена + входящий игрок",
        periodPauseCommands: ["Начало", "Первая четверть", "Пауза", "Тайм-аут", "Продолжить", "Конец"],
        gameEndCommands: ["Конец", "Конец игры", "Финал"],
        shotExamples: [
            ("два попал", "Иван два попал"), ("два промах", "Иван два промах"),
            ("три попал", "Пётр три попал"), ("три промах", "Пётр три промах"),
            ("штрафной попал", "Пётр штрафной попал"), ("штрафной промах", "Пётр штрафной промах"),
            ("лей-ап", "Иван лей-ап"), ("средний", "Пётр средний"),
            ("краска", "Сергей краска"), ("бонус", "Иван бонус"),
        ],
        statExamples: [
            ("фол", "Сергей фол"), ("подбор", "Сергей подбор"), ("ассист", "Пётр ассист"),
            ("блок", "Алексей блок"), ("перехват", "Иван перехват"), ("потеря", "Алексей потеря"),
        ],
        substitutionExamples: ["Замена 7 на 10", "Иван вышел Пётр вышел"],
        actionTemplates: [
            .twoMade: ["{name} два", "{name} 2 очка", "{number} два попал"],
            .twoMissed: ["{name} два промах", "{number} два нет", "{name} 2 очка не попал"],
            .threeMade: ["{name} три", "{number} три", "{name} 3 очка"],
            .threeMissed: ["{name} три промах", "{number} три нет", "{name} 3 очка не попал"],
            .freeThrowMade: ["{name} штрафной", "{number} штрафной", "{name} штрафной попал"],
            .freeThrowMissed: ["{name} штрафной нет", "{number} штрафной промах", "{name} штрафной не попал"],
            .layupMade: ["{name} лей-ап", "{number} лей-ап", "{name} проход"],
            .midRangeMade: ["{name} средний", "{number} джампер", "{name} средний бросок"],
            .paintMade: ["{name} краска", "{team} {number} краска", "{team} {number} внутри"],
            .rebound: ["{name} подбор", "{team} {number} подбор", "{team} {number} подбор"],
            .offensiveRebound: ["{name} подбор в нападении", "{number} подбор в нападении", "{name} нападение подбор"],
            .defensiveRebound: ["{name} подбор в защите", "{number} подбор в защите", "{name} защита подбор"],
            .foul: ["{name} фол", "{team} {number} фол", "{team} {number} фол"],
            .assist: ["{name} ассист", "{team} {number} ассист", "{number} ассист"],
            .block: ["{name} блок", "{number} блок", "{team} {number} блок"],
            .steal: ["{name} перехват", "{number} перехват", "{team} {number} перехват", "{name} перехват {target}"],
            .turnover: ["{name} потеря", "{number} потеря", "{name} turnover"],
            .bonusMade: ["{name} бонус", "{number} and one", "{name} дополнительный штрафной"],
        ]
    )

    // MARK: - Helpers

    static func fill(_ template: String, name: String, number: String, team: String = "", oppTeam: String = "", target: String = "") -> String {
        template.replacingOccurrences(of: "{name}", with: name)
            .replacingOccurrences(of: "{number}", with: number)
            .replacingOccurrences(of: "{team}", with: team)
            .replacingOccurrences(of: "{oppTeam}", with: oppTeam)
            .replacingOccurrences(of: "{target}", with: target)
    }

    // MARK: - Instruction Content Builders

    static func buildShotInstruction(templates: Templates) -> String {
        let ex = templates.shotExamples.prefix(5).map { "\u{300C}\($0.1)\u{300D}" }.joined(separator: "")
        return "\(templates.hintPrefix)「球员名 + 投篮类型 + 命中/未中」。\n\n示例：\n\(ex)\n\n投篮类型：\(templates.shotTypeNames.joined(separator: "、"))"
    }

    static func buildStatInstruction(templates: Templates) -> String {
        let ex = templates.statExamples.prefix(6).map { "\u{300C}\($0.1)\u{300D}" }.joined(separator: "")
        let names = templates.statTypeNames.map(\.1).joined(separator: "、")
        return "\(templates.hintPrefix)「球员名 + 统计类型」。\n\n示例：\n\(ex)\n\n统计类型：\(names)"
    }

    static func buildSubstitutionInstruction(templates: Templates) -> String {
        let ex = templates.substitutionExamples.map { "\u{300C}\($0)\u{300D}" }.joined(separator: "")
        return "\(templates.hintPrefix)「\(templates.substitutionFormat)」。\n\n示例：\n\(ex)"
    }

    static func buildPeriodPauseInstruction(templates: Templates) -> String {
        let cmds = templates.periodPauseCommands.map { "\u{300C}\($0)\u{300D}" }.joined(separator: "")
        return "直接说出指令，无需球员名。\n\n示例：\n\(cmds)"
    }

    static func fillFirst(_ templates: [String], name: String, number: String, team: String = "", oppTeam: String = "", target: String = "") -> String {
        guard let first = templates.first else { return "" }
        return fill(first, name: name, number: number, team: team, oppTeam: oppTeam, target: target)
    }

    static func buildHint(for action: StatAction, templates: Templates, name: String, number: String, team: String = "", oppTeam: String = "", target: String = "") -> String {
        guard let tpls = templates.actionTemplates[action] else { return "" }
        let filled = tpls.map { fill($0, name: name, number: number, team: team, oppTeam: oppTeam, target: target) }
        return "\(templates.hintPrefix)\(filled.map { "\u{300C}\($0)\u{300D}" }.joined(separator: templates.hintSeparator))"
    }

    static func substitutionHint(templates: Templates, outName: String, outNumber: String, inName: String, inNumber: String) -> String {
        switch templates.locale {
        case "zh-Hans":
            return "\(templates.hintPrefix)\u{300C}\(inName)替换\(outName)\u{300D}\(templates.hintSeparator)\u{300C}\(inNumber)号替换\(outNumber)号\u{300D}"
        case "zh-Hant":
            return "\(templates.hintPrefix)\u{300C}\(inName)替換\(outName)\u{300D}\(templates.hintSeparator)\u{300C}\(inNumber)號替換\(outNumber)號\u{300D}"
        case "en":
            return "\(templates.hintPrefix)\"sub \(outNumber) for \(inNumber)\" · \"substitute \(outName) for \(inName)\" · \"sub \(outNumber) \(inNumber)\""
        case "ja":
            return "\u{300C}\(outName)を\(inName)に交代\u{300D}\(templates.hintSeparator)\u{300C}\(outNumber)番\(inNumber)番交代\u{300D}\(templates.hintSeparator)\u{300C}\(outNumber)番アウト\(inNumber)番イン\u{300D}"
        case "ko":
            return "\u{300C}\(outNumber)번 \(inNumber)번 교체\u{300D}\(templates.hintSeparator)\u{300C}\(outName) 교체 \(inName)\u{300D}\(templates.hintSeparator)\u{300C}\(outNumber)번 아웃 \(inNumber)번 인\u{300D}"
        case "de":
            return "\u{300C}Wechsel \(outNumber) und \(inNumber)\u{300D}\(templates.hintSeparator)\u{300C}\(outName) raus \(inName) rein\u{300D}\(templates.hintSeparator)\u{300C}\(outNumber) raus \(inNumber) rein\u{300D}"
        case "es":
            return "\u{300C}Cambio \(outNumber) por \(inNumber)\u{300D}\(templates.hintSeparator)\u{300C}\(outName) sale \(inName) entra\u{300D}\(templates.hintSeparator)\u{300C}\(outNumber) fuera \(inNumber) dentro\u{300D}"
        case "fr":
            return "\u{300C}Remplace \(outNumber) par \(inNumber)\u{300D}\(templates.hintSeparator)\u{300C}\(outName) sort \(inName) entre\u{300D}\(templates.hintSeparator)\u{300C}\(outNumber) sort \(inNumber) entre\u{300D}"
        case "it":
            return "\u{300C}Cambia \(outNumber) con \(inNumber)\u{300D}\(templates.hintSeparator)\u{300C}\(outName) fuori \(inName) dentro\u{300D}\(templates.hintSeparator)\u{300C}\(outNumber) esce \(inNumber) entra\u{300D}"
        case "ru":
            return "\u{300C}Замена \(outNumber) на \(inNumber)\u{300D}\(templates.hintSeparator)\u{300C}\(outName) вышел \(inName) вышел\u{300D}\(templates.hintSeparator)\u{300C}\(outNumber) ушёл \(inNumber) вышел\u{300D}"
        default:
            return "\(templates.hintPrefix)\"sub \(outNumber) for \(inNumber)\" · \"substitute \(outName) for \(inName)\" · \"sub \(outNumber) \(inNumber)\""
        }
    }
}
