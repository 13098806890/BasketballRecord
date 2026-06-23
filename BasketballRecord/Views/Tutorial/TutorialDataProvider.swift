import Foundation
import SwiftUI

// MARK: - Localized Tutorial Data Types

struct TutorialPlayers {
    let home: [Player]
    let away: [Player]
    let homeTeamName: String
    let awayTeamName: String

    var all: [Player] { home + away }
}
struct TutorialTaskDef {
    let id: Int
    let description: String
    let hint: String
    let expectedPlayerID: UUID
    let expectedAction: StatAction
}
// MARK: - Localized Tutorial Data

struct TutorialLocalizedData {
        let players: TutorialPlayers
        let tasks: [TutorialTaskDef]
        let substitutionTaskID: Int
        let freePlayTaskID: Int
    }

// MARK: - Tutorial Data Provider
struct TutorialDataProvider {
    private static let keepOriginalHintTaskIDs: Set<Int> = [18]
    private static let dualActionTaskIDs: Set<Int> = [20, 25]
    private static let commandTaskIDs: Set<Int> = [21, 22, 23, 24]


    static func localizedData(for language: String, playerIDs: [UUID]) -> TutorialLocalizedData {
        let t = VoiceCommandExamples.templates(for: language)
        let raw: TutorialLocalizedData
        switch language {
        case "en":
            raw = englishData(playerIDs: playerIDs)
        case "ja":
            raw = japaneseData(playerIDs: playerIDs)
        case "ko":
            raw = koreanData(playerIDs: playerIDs)
        case "de":
            raw = germanData(playerIDs: playerIDs)
        case "es":
            raw = spanishData(playerIDs: playerIDs)
        case "fr":
            raw = frenchData(playerIDs: playerIDs)
        case "it":
            raw = italianData(playerIDs: playerIDs)
        case "ru":
            raw = russianData(playerIDs: playerIDs)
        case "zh-Hant-TW", "zh-Hant-HK":
            raw = traditionalChineseData(playerIDs: playerIDs)
        default:
            raw = chineseData(playerIDs: playerIDs)
        }
        let prefixes = teamPrefixes(for: language)
        let hPlayers = raw.players.home
        let aPlayers = raw.players.away
        let homeNumbers = Set(hPlayers.map(\.number))
        let awayNumbers = Set(aPlayers.map(\.number))
        let dupNumbers = homeNumbers.intersection(awayNumbers)
        let dupNote: String? = dupNumbers.isEmpty ? nil : dupNumberNote(for: language)
        func playerInfo(_ id: UUID) -> (name: String, number: String, isHome: Bool) {
            if id == playerIDs[0] { return (hPlayers[0].name, hPlayers[0].number, true) }
            if id == playerIDs[1] { return (hPlayers[1].name, hPlayers[1].number, true) }
            if id == playerIDs[2] { return (aPlayers[0].name, aPlayers[0].number, false) }
            return (aPlayers[1].name, aPlayers[1].number, false)
        }
        let sharedNumbers = dupNumbers
        let updatedTasks = raw.tasks.map { task in
            if task.id == raw.freePlayTaskID {
                let awayPlayer = aPlayers[0]
                let note: String
                if sharedNumbers.contains(awayPlayer.number) {
                    note = freePlayTeamPrefixHint(for: language, awayName: awayPlayer.name, awayNumber: awayPlayer.number, awayPrefix: prefixes.away, homePrefix: prefixes.home)
                } else {
                    note = task.hint
                }
                return TutorialTaskDef(
                    id: task.id, description: task.description, hint: note,
                    expectedPlayerID: task.expectedPlayerID,
                    expectedAction: task.expectedAction
                )
            }
            if task.id == raw.substitutionTaskID {
                let out = hPlayers[0]
                let inn = hPlayers[1]
                return TutorialTaskDef(
                    id: task.id, description: task.description,
                    hint: VoiceCommandExamples.substitutionHint(
                        templates: t, outName: out.name, outNumber: out.number,
                        inName: inn.name, inNumber: inn.number
                    ),
                    expectedPlayerID: task.expectedPlayerID,
                    expectedAction: task.expectedAction
                )
            }
            if Self.keepOriginalHintTaskIDs.contains(task.id) {
                var hint = task.hint
                if let note = dupNote {
                    let pi = playerInfo(task.expectedPlayerID)
                    if dupNumbers.contains(pi.number) {
                        hint += "\n\(note)"
                    }
                }
                return TutorialTaskDef(id: task.id, description: task.description, hint: hint, expectedPlayerID: task.expectedPlayerID, expectedAction: task.expectedAction)
            }
            if Self.dualActionTaskIDs.contains(task.id) || Self.commandTaskIDs.contains(task.id) {
                return task
            }
            let pi = playerInfo(task.expectedPlayerID)
            let team = pi.isHome ? prefixes.home : prefixes.away
            let oppTeam = pi.isHome ? prefixes.away : prefixes.home
            var hint = VoiceCommandExamples.buildHint(
                for: task.expectedAction, templates: t,
                name: pi.name, number: pi.number, team: team, oppTeam: oppTeam
            )
            if let note = dupNote, dupNumbers.contains(pi.number) {
                hint += "\n\(note)"
            }
            return TutorialTaskDef(
                id: task.id, description: task.description, hint: hint,
                expectedPlayerID: task.expectedPlayerID,
                expectedAction: task.expectedAction
            )
        }
        return TutorialLocalizedData(players: raw.players, tasks: updatedTasks,
                             substitutionTaskID: raw.substitutionTaskID,
                             freePlayTaskID: raw.freePlayTaskID)
    }

    static func teamPrefixes(for language: String) -> (home: String, away: String) {
        switch language {
        case "zh-Hans": return ("主队", "客队")
        case "zh-Hant": return ("主隊", "客隊")
        case "en": return ("home", "away")
        case "ja": return ("ホーム", "アウェイ")
        case "ko": return ("홈", "어웨이")
        case "de": return ("Heim", "Auswärts")
        case "es": return ("Local", "Visitante")
        case "fr": return ("Domicile", "Extérieur")
        case "it": return ("Casa", "Ospite")
        case "ru": return ("Хозяева", "Гости")
        default: return ("home", "away")
        }
    }

    static func freePlayTeamPrefixHint(for language: String, awayName: String, awayNumber: String, awayPrefix: String, homePrefix: String) -> String {
        let q = "\u{00AB}"
        let qe = "\u{00BB}"
        switch language {
        case "zh-Hans":
            return "请说「\(awayPrefix)\(awayNumber)号两分」或「\(awayName)两分」来测试相同号码时的匹配规则"
        case "zh-Hant":
            return "請說「\(awayPrefix)\(awayNumber)號兩分」或「\(awayName)兩分」來測試相同號碼時的匹配規則"
        case "en":
            return "Try saying \"\(awayPrefix) \(awayNumber) two\" or \"\(awayName) two\" to test matching when both teams have #\(awayNumber)"
        case "ja":
            return "「\(awayPrefix)\(awayNumber)番ツー」または「\(awayName)ツー」と言って、同じ番号の一致ルールをテストしてみましょう"
        case "ko":
            return "「\(awayPrefix) \(awayNumber)번 투」또는「\(awayName) 투」라고 말해서 같은 번호 매칭 규칙을 테스트해보세요"
        case "de":
            return "Versuche \(q)\(awayPrefix) \(awayNumber) zwei\(qe) oder \(q)\(awayName) zwei\(qe) um die Unterscheidung bei gleicher Nummer zu testen"
        case "es":
            return "Prueba diciendo \(q)\(awayPrefix) \(awayNumber) dos\(qe) o \(q)\(awayName) dos\(qe) para probar la regla con numeros duplicados"
        case "fr":
            return "Essaie de dire \(q)\(awayPrefix) \(awayNumber) deux\(qe) ou \(q)\(awayName) deux\(qe) pour tester la regle des numeros identiques"
        case "it":
            return "Prova a dire \(q)\(awayPrefix) \(awayNumber) due\(qe) o \(q)\(awayName) due\(qe) per testare la regola con numeri uguali"
        case "ru":
            return "Попробуйте сказать \(q)\(awayPrefix) \(awayNumber) два\(qe) или \(q)\(awayName) два\(qe), чтобы проверить правило совпадающих номеров"
        default:
            return "Try saying \"\(awayPrefix) \(awayNumber) two\" or \"\(awayName) two\" to test matching when both teams have #\(awayNumber)"
        }
    }

    static func dupNumberNote(for language: String) -> String {
        switch language {
        case "zh-Hans": return "提示：两队都有此号码，请加主队/客队前缀"
        case "zh-Hant": return "提示：兩隊都有此號碼，請加主隊/客隊前綴"
        case "en": return "Tip: same number on both teams, use home/away prefix"
        case "ja": return "ヒント：両チームに同じ番号がいます。ホーム/アウェイを付けてください"
        case "ko": return "힌트: 양 팀에 같은 번호가 있습니다. 홈/어웨이를 붙여주세요"
        case "de": return "Tipp: gleiche Nummer in beiden Teams, Heim/Auswärts voranstellen"
        case "es": return "Pista: mismo número en ambos equipos, añade Local/Visitante"
        case "fr": return "Astuce : même numéro dans les deux équipes, ajoutez Domicile/Extérieur"
        case "it": return "Suggerimento: stesso numero in entrambe le squadre, aggiungi Casa/Ospite"
        case "ru": return "Подсказка: одинаковый номер в обеих командах, добавьте Хозяева/Гости"
        default: return "Tip: same number on both teams, use home/away prefix"
        }
    }

    static func makePlayers(
        ids: [UUID],
        homeNames: [String],
        awayNames: [String],
        homeNumbers: [String],
        awayNumbers: [String]
    ) -> TutorialPlayers {
        TutorialPlayers(
            home: [
                Player(id: ids[0], name: homeNames[0], number: homeNumbers[0]),
                Player(id: ids[1], name: homeNames[1], number: homeNumbers[1]),
            ],
            away: [
                Player(id: ids[2], name: awayNames[0], number: awayNumbers[0]),
                Player(id: ids[3], name: awayNames[1], number: awayNumbers[1]),
            ],
            homeTeamName: homeNames.count > 2 ? homeNames[2] : "Home",
            awayTeamName: awayNames.count > 2 ? awayNames[2] : "Away"
        )
    }

    static func taskDef(
        id: Int, desc: String, hint: String,
        playerID: UUID, action: StatAction
    ) -> TutorialTaskDef {
        TutorialTaskDef(id: id, description: desc, hint: hint,
                        expectedPlayerID: playerID, expectedAction: action)
    }

    // MARK: - English

    static func englishData(playerIDs: [UUID]) -> TutorialLocalizedData {
        let ids = playerIDs
        let players = makePlayers(
            ids: ids,
            homeNames: ["John", "Mike", "Reds"],
            awayNames: ["Steve", "Dave", "Blues"],
            homeNumbers: ["7", "10"],
            awayNumbers: ["7", "12"]
        )
        let tasks = [
            taskDef(id: 1, desc: "John scores a two-pointer",
                    hint: "Say \"John two\" · \"John got 2\" · \"7 two\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 2, desc: "John misses a two-point shot",
                    hint: "Say \"7 no 2\" · \"John miss 2\" · \"7 missed two\"",
                    playerID: ids[0], action: .twoMissed),
            taskDef(id: 3, desc: "Mike drains a three-pointer",
                    hint: "Say \"Mike three\" · \"home 10 three\" · \"Mike got 3\"",
                    playerID: ids[1], action: .threeMade),
            taskDef(id: 4, desc: "Mike misses from beyond the arc",
                    hint: "Say \"Mike no 3\" · \"10 miss three\" · \"Mike missed three\"",
                    playerID: ids[1], action: .threeMissed),
            taskDef(id: 5, desc: "Mike knocks down a free throw",
                    hint: "Say \"Mike free throw\" · \"10 free\" · \"Mike free\"",
                    playerID: ids[1], action: .freeThrowMade),
            taskDef(id: 6, desc: "Mike misses at the free throw line",
                    hint: "Say \"Mike no free\" · \"10 miss free throw\" · \"10 free no\"",
                    playerID: ids[1], action: .freeThrowMissed),
            taskDef(id: 7, desc: "John finishes with a layup",
                    hint: "Say \"John layup\" · \"7 lay up\" · \"John layup made\"",
                    playerID: ids[0], action: .layupMade),
            taskDef(id: 8, desc: "Mike hits a mid-range jumper",
                    hint: "Say \"Mike mid range\" · \"Mike jumper\" · \"10 mid\"",
                    playerID: ids[1], action: .midRangeMade),
            taskDef(id: 9, desc: "Steve scores inside the paint",
                    hint: "Say \"Steve paint\" · \"away 7 inside\" · \"7 paint\"",
                    playerID: ids[2], action: .paintMade),
            taskDef(id: 10, desc: "Steve pulls down a rebound",
                    hint: "Say \"Steve rebound\" · \"away 7 rebound\" · \"Steve got rebound\"",
                    playerID: ids[2], action: .rebound),
            taskDef(id: 11, desc: "Mike dishes out an assist",
                    hint: "Say \"Mike assist\" · \"home 10 assist\" · \"10 assist\"",
                    playerID: ids[1], action: .assist),
            taskDef(id: 12, desc: "Dave rejects a shot with a block",
                    hint: "Say \"Dave block\" · \"12 block\" · \"away 12 block\"",
                    playerID: ids[3], action: .block),
            taskDef(id: 13, desc: "John comes up with a steal",
                    hint: "Say \"John steal\" · \"7 steal\" · \"home 7 steal\"",
                    playerID: ids[0], action: .steal),
            taskDef(id: 14, desc: "Dave gives the ball away with a turnover",
                    hint: "Say \"Dave turnover\" · \"12 turnover\" · \"Dave turn over\"",
                    playerID: ids[3], action: .turnover),
            taskDef(id: 15, desc: "Steve commits a foul",
                    hint: "Say \"Steve foul\" · \"away 7 foul\" · \"Steve fouls\"",
                    playerID: ids[2], action: .foul),
            taskDef(id: 16, desc: "John converts the and-one opportunity",
                    hint: "Say \"John bonus\" · \"7 and one\" · \"John and one\"",
                    playerID: ids[0], action: .bonusMade),
            taskDef(id: 17, desc: "Substitute John off for Mike on the home team",
                    hint: "Say \"sub 7 for 10\" · \"substitute John for Mike\" · \"sub 7 10\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 18, desc: "Steve scores two for the away side",
                    hint: "Say \"Steve two\"",
                    playerID: ids[2], action: .twoMade),
            taskDef(id: 20, desc: "Mike assists John for a two-pointer",
                    hint: "Say \"Mike assist John two\" · \"Mike assist John two got\"",
                    playerID: ids[1], action: .assist),
            taskDef(id: 25, desc: "Mike steals from Dave",
                    hint: "Say \"Mike steal Dave\" · \"Mike steal 12\" · \"10 steal Dave\"",
                    playerID: ids[1], action: .steal),
            taskDef(id: 26, desc: "Steve grabs an offensive rebound",
                    hint: "",
                    playerID: ids[2], action: .offensiveRebound),
            taskDef(id: 27, desc: "Steve hauls in a defensive rebound",
                    hint: "",
                    playerID: ids[2], action: .defensiveRebound),
            taskDef(id: 21, desc: "Start a period",
                    hint: "Say \"start\" · \"begin\" · \"tip off\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 22, desc: "Pause the game",
                    hint: "Say \"pause\" · \"timeout\" · \"stop\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 23, desc: "Resume the game",
                    hint: "Say \"resume\" · \"continue\" · \"play\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 24, desc: "End a quarter",
                    hint: "Say \"quarter done\" · \"quarter down\" · \"quarter end\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 19, desc: "Free Practice — try any command",
                    hint: "Say anything to practice — names, numbers, or team prefixes",
                    playerID: ids[0], action: .twoMade),
        ]
        return TutorialLocalizedData(players: players, tasks: tasks, substitutionTaskID: 17, freePlayTaskID: 19)
    }

    // MARK: - Japanese

    static func japaneseData(playerIDs: [UUID]) -> TutorialLocalizedData {
        let ids = playerIDs
        let players = makePlayers(
            ids: ids,
            homeNames: ["田中", "鈴木", "赤チーム"],
            awayNames: ["山田", "佐藤", "青チーム"],
            homeNumbers: ["7", "10"],
            awayNumbers: ["7", "12"]
        )
        let tasks = [
            taskDef(id: 1, desc: "田中がツーポイントを決める",
                    hint: "「田中ツー」·「田中２点」·「７番ツー成功」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 2, desc: "田中がツーポイントを外す",
                    hint: "「田中ツーなし」·「７番ツー外した」·「田中２点ミス」",
                    playerID: ids[0], action: .twoMissed),
            taskDef(id: 3, desc: "鈴木がスリーポイントを決める",
                    hint: "「鈴木スリー」·「１０番スリー」·「鈴木３点」",
                    playerID: ids[1], action: .threeMade),
            taskDef(id: 4, desc: "鈴木がスリーポイントを外す",
                    hint: "「鈴木スリーなし」·「１０番スリー外した」·「鈴木３点ミス」",
                    playerID: ids[1], action: .threeMissed),
            taskDef(id: 5, desc: "鈴木がフリースローを決める",
                    hint: "「鈴木フリースロー」·「１０番フリー」·「鈴木フリー成功」",
                    playerID: ids[1], action: .freeThrowMade),
            taskDef(id: 6, desc: "鈴木がフリースローを外す",
                    hint: "「鈴木フリーなし」·「１０番フリーミス」·「鈴木フリー失敗」",
                    playerID: ids[1], action: .freeThrowMissed),
            taskDef(id: 7, desc: "田中がレイアップを決める",
                    hint: "「田中レイアップ」·「７番レイアップ」·「田中レイアップ成功」",
                    playerID: ids[0], action: .layupMade),
            taskDef(id: 8, desc: "鈴木がミッドレンジシュートを決める",
                    hint: "「鈴木ミッドレンジ」·「１０番ジャンパー」·「鈴木中距離」",
                    playerID: ids[1], action: .midRangeMade),
            taskDef(id: 9, desc: "山田がペイント内で得点する",
                    hint: "「山田ペイント」·「アウェイ７番ペイント」·「青チーム７番インサイド」",
                    playerID: ids[2], action: .paintMade),
            taskDef(id: 10, desc: "山田がリバウンドを取る",
                    hint: "「山田リバウンド」·「アウェイ７番リバウンド」·「青チームリバウンド」",
                    playerID: ids[2], action: .rebound),
            taskDef(id: 11, desc: "鈴木がアシストを出す",
                    hint: "「鈴木アシスト」·「１０番アシスト」·「ホーム１０番アシスト」",
                    playerID: ids[1], action: .assist),
            taskDef(id: 12, desc: "佐藤がブロックをする",
                    hint: "「佐藤ブロック」·「１２番ブロック」·「アウェイ１２番ブロック」",
                    playerID: ids[3], action: .block),
            taskDef(id: 13, desc: "田中がスティールをする",
                    hint: "「田中スティール」·「７番スティール」·「ホーム７番スティール」",
                    playerID: ids[0], action: .steal),
            taskDef(id: 14, desc: "佐藤がターンオーバーをする",
                    hint: "「佐藤ターンオーバー」·「１２番ターンオーバー」·「佐藤ボールロスト」",
                    playerID: ids[3], action: .turnover),
            taskDef(id: 15, desc: "山田がファウルをする",
                    hint: "「山田ファウル」·「アウェイ７番ファウル」·「青チーム７番ファウル」",
                    playerID: ids[2], action: .foul),
            taskDef(id: 16, desc: "田中がボーナスフリースローを決める",
                    hint: "「田中ボーナス」·「７番アンドワン」·「田中追加フリー」",
                    playerID: ids[0], action: .bonusMade),
            taskDef(id: 17, desc: "田中に代えて鈴木をホームチームに投入する",
                    hint: "「田中を鈴木に交代」·「７番１０番交代」·「７番アウト１０番イン」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 18, desc: "山田がアウェイでツーポイントを決める",
                    hint: "「山田２点」",
                    playerID: ids[2], action: .twoMade),
            taskDef(id: 20, desc: "鈴木が田中にアシストしてツーポイント",
                    hint: "「鈴木アシスト田中ツー」·「鈴木アシスト田中ツー成功」",
                    playerID: ids[1], action: .assist),
            taskDef(id: 25, desc: "鈴木が佐藤からスティール",
                    hint: "「鈴木スティール佐藤」·「鈴木スティール１２番」·「１０番スティール佐藤」",
                    playerID: ids[1], action: .steal),
            taskDef(id: 26, desc: "山田がオフェンスリバウンドを取る",
                    hint: "",
                    playerID: ids[2], action: .offensiveRebound),
            taskDef(id: 27, desc: "山田がディフェンスリバウンドを取る",
                    hint: "",
                    playerID: ids[2], action: .defensiveRebound),
            taskDef(id: 21, desc: "クオーターを開始",
                    hint: "「開始」·「スタート」·「第1クオーター」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 22, desc: "一時停止",
                    hint: "「一時停止」·「タイムアウト」·「休憩」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 23, desc: "再開",
                    hint: "「再開」·「リスタート」·「続ける」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 24, desc: "クオーターエンド",
                    hint: "「クオーターエンド」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 19, desc: "自由練習——任意のコマンドを試そう",
                    hint: "名前や番号やチーム名を自由に話して練習しよう",
                    playerID: ids[0], action: .twoMade),
        ]
        return TutorialLocalizedData(players: players, tasks: tasks, substitutionTaskID: 17, freePlayTaskID: 19)
    }

    // MARK: - Korean

    static func koreanData(playerIDs: [UUID]) -> TutorialLocalizedData {
        let ids = playerIDs
        let players = makePlayers(
            ids: ids,
            homeNames: ["김철수", "이영희", "빨강팀"],
            awayNames: ["박민수", "정지원", "파랑팀"],
            homeNumbers: ["7", "10"],
            awayNumbers: ["7", "12"]
        )
        let tasks = [
            taskDef(id: 1, desc: "김철수가 2점슛을 성공합니다",
                    hint: "「김철수 투」·「김철수 2점」·「7번 2점 성공」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 2, desc: "김철수가 2점슛을 놓칩니다",
                    hint: "「김철수 투 실패」·「7번 2점 못 넣음」·「김철수 2점 미스」",
                    playerID: ids[0], action: .twoMissed),
            taskDef(id: 3, desc: "이영희가 3점슛을 성공합니다",
                    hint: "「이영희 쓰리」·「10번 3점」·「이영희 3점 성공」",
                    playerID: ids[1], action: .threeMade),
            taskDef(id: 4, desc: "이영희가 3점슛을 놓칩니다",
                    hint: "「이영희 쓰리 실패」·「10번 3점 못 넣음」·「이영희 3점 미스」",
                    playerID: ids[1], action: .threeMissed),
            taskDef(id: 5, desc: "이영희가 자유투를 성공합니다",
                    hint: "「이영희 자유투」·「10번 자유투」·「이영희 프리 성공」",
                    playerID: ids[1], action: .freeThrowMade),
            taskDef(id: 6, desc: "이영희가 자유투를 놓칩니다",
                    hint: "「이영희 자유투 실패」·「10번 자유투 못 넣음」·「이영희 프리 미스」",
                    playerID: ids[1], action: .freeThrowMissed),
            taskDef(id: 7, desc: "김철수가 레이업을 성공합니다",
                    hint: "「김철수 레이업」·「7번 레이업」·「김철수 레이업 성공」",
                    playerID: ids[0], action: .layupMade),
            taskDef(id: 8, desc: "이영희가 미드레인지슛을 성공합니다",
                    hint: "「이영희 미드레인지」·「10번 점퍼」·「이영희 중거리」",
                    playerID: ids[1], action: .midRangeMade),
            taskDef(id: 9, desc: "박민수가 페인트 안에서 득점합니다",
                    hint: "「박민수 페인트」·「어웨이 7번 페인트」·「파랑팀 7번 인사이드」",
                    playerID: ids[2], action: .paintMade),
            taskDef(id: 10, desc: "박민수가 리바운드를 잡습니다",
                    hint: "「박민수 리바운드」·「어웨이 7번 리바운드」·「파랑팀 7번 리바운드」",
                    playerID: ids[2], action: .rebound),
            taskDef(id: 11, desc: "이영희가 어시스트를 기록합니다",
                    hint: "「이영희 어시스트」·「10번 어시스트」·「홈 10번 어시스트」",
                    playerID: ids[1], action: .assist),
            taskDef(id: 12, desc: "정지원이 블록슛을 합니다",
                    hint: "「정지원 블록」·「12번 블록」·「어웨이 12번 블록」",
                    playerID: ids[3], action: .block),
            taskDef(id: 13, desc: "김철수가 스틸을 합니다",
                    hint: "「김철수 스틸」·「7번 스틸」·「홈 7번 스틸」",
                    playerID: ids[0], action: .steal),
            taskDef(id: 14, desc: "정지원이 턴오버를 범합니다",
                    hint: "「정지원 턴오버」·「12번 턴오버」·「정지원 볼 손실」",
                    playerID: ids[3], action: .turnover),
            taskDef(id: 15, desc: "박민수가 파울을 범합니다",
                    hint: "「박민수 파울」·「어웨이 7번 파울」·「파랑팀 7번 파울」",
                    playerID: ids[2], action: .foul),
            taskDef(id: 16, desc: "김철수가 보너스 자유투를 성공합니다",
                    hint: "「김철수 보너스」·「7번 앤드원」·「김철수 추가 자유투」",
                    playerID: ids[0], action: .bonusMade),
            taskDef(id: 17, desc: "김철수를 빼고 이영희를 홈팀에 투입합니다",
                    hint: "「7번 10번 교체」·「김철수 교체 이영희」·「7번 아웃 10번 인」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 18, desc: "박민수가 어웨이 팀에서 2점을 득점합니다",
                    hint: "「박민수 2점」",
                    playerID: ids[2], action: .twoMade),
            taskDef(id: 20, desc: "이영희가 김철수의 2점슛을 어시스트합니다",
                    hint: "「이영희 어시스트 김철수 투」·「이영희 어시스트 김철수 2점 성공」",
                    playerID: ids[1], action: .assist),
            taskDef(id: 25, desc: "이영희가 정지원을 스틸",
                    hint: "「이영희 스틸 정지원」·「이영희 스틸 12번」·「10번 스틸 정지원」",
                    playerID: ids[1], action: .steal),
            taskDef(id: 26, desc: "박민수가 공격 리바운드를 잡습니다",
                    hint: "",
                    playerID: ids[2], action: .offensiveRebound),
            taskDef(id: 27, desc: "박민수가 수비 리바운드를 잡습니다",
                    hint: "",
                    playerID: ids[2], action: .defensiveRebound),
            taskDef(id: 21, desc: "쿼터 시작",
                    hint: "「시작」·「첫 쿼터」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 22, desc: "일시 정지",
                    hint: "「일시정지」·「타임아웃」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 23, desc: "재개",
                    hint: "「재개」·「계속」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 24, desc: "쿼터 종결",
                    hint: "「쿼터종결」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 19, desc: "자유 연습 — 원하는 명령을 시도해보세요",
                    hint: "이름이나 번호나 팀명을 자유롭게 말해서 연습해보세요",
                    playerID: ids[0], action: .twoMade),
        ]
        return TutorialLocalizedData(players: players, tasks: tasks, substitutionTaskID: 17, freePlayTaskID: 19)
    }

    // MARK: - German

    static func germanData(playerIDs: [UUID]) -> TutorialLocalizedData {
        let ids = playerIDs
        let players = makePlayers(
            ids: ids,
            homeNames: ["Hans", "Fritz", "Rot"],
            awayNames: ["Klaus", "Gerd", "Blau"],
            homeNumbers: ["7", "10"],
            awayNumbers: ["7", "12"]
        )
        let tasks = [
            taskDef(id: 1, desc: "Hans erzielt zwei Punkte",
                    hint: "„Hans zwei\" · „Hans 2 Punkte\" · „7 zwei getroffen\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 2, desc: "Hans vergibt einen Zwei-Punkte-Wurf",
                    hint: "„Hans zwei daneben\" · „7 zwei verfehlt\" · „Hans 2 Punkte nicht\"",
                    playerID: ids[0], action: .twoMissed),
            taskDef(id: 3, desc: "Fritz trifft einen Dreipunktewurf",
                    hint: "„Fritz drei\" · „10 drei\" · „Fritz 3 Punkte\"",
                    playerID: ids[1], action: .threeMade),
            taskDef(id: 4, desc: "Fritz vergibt einen Dreipunktewurf",
                    hint: "„Fritz drei daneben\" · „10 drei verfehlt\" · „Fritz 3 Punkte nicht\"",
                    playerID: ids[1], action: .threeMissed),
            taskDef(id: 5, desc: "Fritz verwandelt einen Freiwurf",
                    hint: "„Fritz Freiwurf\" · „10 Freiwurf\" · „Fritz frei getroffen\"",
                    playerID: ids[1], action: .freeThrowMade),
            taskDef(id: 6, desc: "Fritz vergibt einen Freiwurf",
                    hint: "„Fritz Freiwurf daneben\" · „10 Freiwurf verfehlt\" · „Fritz frei nicht\"",
                    playerID: ids[1], action: .freeThrowMissed),
            taskDef(id: 7, desc: "Hans legt den Ball per Layup in den Korb",
                    hint: "„Hans Layup\" · „7 Layup\" · „Hans Korbleger\"",
                    playerID: ids[0], action: .layupMade),
            taskDef(id: 8, desc: "Fritz trifft aus der Mitteldistanz",
                    hint: "„Fritz Mitteldistanz\" · „10 Jumpshot\" · „Fritz mittlerer Wurf\"",
                    playerID: ids[1], action: .midRangeMade),
            taskDef(id: 9, desc: "Klaus punktet aus dem Paint",
                    hint: "„Klaus Paint\" · „Auswärts 7 Paint\" · „Blau 7 innen\"",
                    playerID: ids[2], action: .paintMade),
            taskDef(id: 10, desc: "Klaus holt sich den Rebound",
                    hint: "„Klaus Rebound\" · „Auswärts 7 Rebound\" · „Blau 7 Rebound\"",
                    playerID: ids[2], action: .rebound),
            taskDef(id: 11, desc: "Fritz bereitet einen Korb mit einem Assist vor",
                    hint: "„Fritz Assist\" · „10 Assist\" · „Heim 10 Assist\"",
                    playerID: ids[1], action: .assist),
            taskDef(id: 12, desc: "Gerd blockt einen Wurf",
                    hint: "„Gerd Block\" · „12 Block\" · „Auswärts 12 Block\"",
                    playerID: ids[3], action: .block),
            taskDef(id: 13, desc: "Hans erobert den Ball mit einem Steal",
                    hint: "„Hans Steal\" · „7 Steal\" · „Heim 7 Steal\"",
                    playerID: ids[0], action: .steal),
            taskDef(id: 14, desc: "Gerd begeht einen Turnover",
                    hint: "„Gerd Turnover\" · „12 Turnover\" · „Gerd Ballverlust\"",
                    playerID: ids[3], action: .turnover),
            taskDef(id: 15, desc: "Klaus begeht ein Foul",
                    hint: "„Klaus Foul\" · „Auswärts 7 Foul\" · „Blau 7 Foul\"",
                    playerID: ids[2], action: .foul),
            taskDef(id: 16, desc: "Hans verwandelt den Bonus-Freiwurf",
                    hint: "„Hans Bonus\" · „7 and one\" · „Hans Bonus Freiwurf\"",
                    playerID: ids[0], action: .bonusMade),
            taskDef(id: 17, desc: "Wechsel: Hans geht raus, Fritz kommt für das Heimteam rein",
                    hint: "„Wechsel 7 und 10\" · „Hans raus Fritz rein\" · „7 raus 10 rein\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 18, desc: "Klaus erzielt zwei Punkte für das Auswärtsteam",
                    hint: "„Klaus 2 Punkte\"",
                    playerID: ids[2], action: .twoMade),
            taskDef(id: 20, desc: "Fritz assistiert Hans bei einem Zweipunktewurf",
                    hint: "„Fritz Assist Hans zwei\" · „Fritz Assist Hans zwei getroffen\"",
                    playerID: ids[1], action: .assist),
            taskDef(id: 25, desc: "Fritz stiehlt Gerd den Ball",
                    hint: "„Fritz Steal Gerd\" · „Fritz Steal 12\" · „10 Steal Gerd\"",
                    playerID: ids[1], action: .steal),
            taskDef(id: 26, desc: "Klaus holt sich den offensiven Rebound",
                    hint: "",
                    playerID: ids[2], action: .offensiveRebound),
            taskDef(id: 27, desc: "Klaus holt sich den defensiven Rebound",
                    hint: "",
                    playerID: ids[2], action: .defensiveRebound),
            taskDef(id: 21, desc: "Starte ein Viertel",
                    hint: "„start\" · „sprungball\" · „erstes viertel\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 22, desc: "Pausiere das Spiel",
                    hint: "„pause\" · „auszeit\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 23, desc: "Spiel fortsetzen",
                    hint: "„weiter\" · „weiterspielen\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 24, desc: "Viertel beenden",
                    hint: "„viertel um\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 19, desc: "Freies Spiel — probiere beliebige Befehle",
                    hint: "Sage Namen, Nummern oder Teamnamen zum Üben",
                    playerID: ids[0], action: .twoMade),
        ]
        return TutorialLocalizedData(players: players, tasks: tasks, substitutionTaskID: 17, freePlayTaskID: 19)
    }

    // MARK: - Spanish

    static func spanishData(playerIDs: [UUID]) -> TutorialLocalizedData {
        let ids = playerIDs
        let players = makePlayers(
            ids: ids,
            homeNames: ["Carlos", "Luis", "Rojo"],
            awayNames: ["José", "Juan", "Azul"],
            homeNumbers: ["7", "10"],
            awayNumbers: ["7", "12"]
        )
        let tasks = [
            taskDef(id: 1, desc: "Carlos anota un tiro de dos puntos",
                    hint: "„Carlos dos\" · „Carlos 2 puntos\" · „7 dos anotado\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 2, desc: "Carlos falla un tiro de dos puntos",
                    hint: "„Carlos dos fallo\" · „7 dos no\" · „Carlos 2 puntos fallado\"",
                    playerID: ids[0], action: .twoMissed),
            taskDef(id: 3, desc: "Luis clava un triple",
                    hint: "„Luis tres\" · „10 tres\" · „Luis 3 puntos\"",
                    playerID: ids[1], action: .threeMade),
            taskDef(id: 4, desc: "Luis falla un triple",
                    hint: "„Luis tres fallo\" · „10 tres no\" · „Luis 3 puntos fallado\"",
                    playerID: ids[1], action: .threeMissed),
            taskDef(id: 5, desc: "Luis convierte un tiro libre",
                    hint: "„Luis tiro libre\" · „10 libre\" · „Luis libre anotado\"",
                    playerID: ids[1], action: .freeThrowMade),
            taskDef(id: 6, desc: "Luis falla desde la línea de tiros libres",
                    hint: "„Luis libre fallo\" · „10 libre no\" · „Luis tiro libre fallado\"",
                    playerID: ids[1], action: .freeThrowMissed),
            taskDef(id: 7, desc: "Carlos finaliza con una bandeja",
                    hint: "„Carlos bandeja\" · „7 bandeja\" · „Carlos layup\"",
                    playerID: ids[0], action: .layupMade),
            taskDef(id: 8, desc: "Luis anota un tiro de media distancia",
                    hint: "„Luis media distancia\" · „10 jumper\" · „Luis tiro medio\"",
                    playerID: ids[1], action: .midRangeMade),
            taskDef(id: 9, desc: "José anota desde la pintura",
                    hint: "„José pintura\" · „Visitante 7 pintura\" · „Azul 7 interior\"",
                    playerID: ids[2], action: .paintMade),
            taskDef(id: 10, desc: "José atrapa un rebote",
                    hint: "„José rebote\" · „Visitante 7 rebote\" · „Azul 7 rebote\"",
                    playerID: ids[2], action: .rebound),
            taskDef(id: 11, desc: "Luis reparte una asistencia",
                    hint: "„Luis asistencia\" · „10 asistencia\" · „Local 10 asistencia\"",
                    playerID: ids[1], action: .assist),
            taskDef(id: 12, desc: "Juan rechaza un tiro con un bloqueo",
                    hint: "„Juan bloqueo\" · „12 bloqueo\" · „Visitante 12 bloqueo\"",
                    playerID: ids[3], action: .block),
            taskDef(id: 13, desc: "Carlos roba el balón",
                    hint: "„Carlos robo\" · „7 robo\" · „Local 7 robo\"",
                    playerID: ids[0], action: .steal),
            taskDef(id: 14, desc: "Juan pierde el balón con una pérdida",
                    hint: "„Juan pérdida\" · „12 pérdida\" · „Juan turnover\"",
                    playerID: ids[3], action: .turnover),
            taskDef(id: 15, desc: "José comete una falta",
                    hint: "„José falta\" · „Visitante 7 falta\" · „Azul 7 falta\"",
                    playerID: ids[2], action: .foul),
            taskDef(id: 16, desc: "Carlos convierte el tiro adicional de bonus",
                    hint: "„Carlos bonus\" · „7 and one\" · „Carlos tiro extra\"",
                    playerID: ids[0], action: .bonusMade),
            taskDef(id: 17, desc: "Sustitución: Carlos sale, Luis entra por el equipo local",
                    hint: "„Cambio 7 por 10\" · „Carlos sale Luis entra\" · „7 fuera 10 dentro\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 18, desc: "José anota dos puntos para el equipo visitante",
                    hint: "„José 2 puntos\"",
                    playerID: ids[2], action: .twoMade),
            taskDef(id: 20, desc: "Luis asiste a Carlos para un tiro de dos puntos",
                    hint: "„Luis asistencia Carlos dos\" · „Luis asistencia Carlos dos canasta\"",
                    playerID: ids[1], action: .assist),
            taskDef(id: 25, desc: "Luis roba el balón a Juan",
                    hint: "„Luis robo Juan\" · „Luis robo 12\" · „10 robo Juan\"",
                    playerID: ids[1], action: .steal),
            taskDef(id: 26, desc: "José atrapa un rebote ofensivo",
                    hint: "",
                    playerID: ids[2], action: .offensiveRebound),
            taskDef(id: 27, desc: "José atrapa un rebote defensivo",
                    hint: "",
                    playerID: ids[2], action: .defensiveRebound),
            taskDef(id: 21, desc: "Iniciar un cuarto",
                    hint: "„inicio\" · „primer cuarto\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 22, desc: "Pausar el partido",
                    hint: "„pausa\" · „tiempo muerto\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 23, desc: "Reanudar el partido",
                    hint: "„continuar\" · „reanudar\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 24, desc: "Finalizar un cuarto",
                    hint: "„cuarto concluido\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 19, desc: "Juego libre — prueba cualquier comando",
                    hint: "Di nombres, números o nombres de equipo para practicar",
                    playerID: ids[0], action: .twoMade),
        ]
        return TutorialLocalizedData(players: players, tasks: tasks, substitutionTaskID: 17, freePlayTaskID: 19)
    }

    // MARK: - French

    static func frenchData(playerIDs: [UUID]) -> TutorialLocalizedData {
        let ids = playerIDs
        let players = makePlayers(
            ids: ids,
            homeNames: ["Pierre", "Paul", "Rouge"],
            awayNames: ["Jacques", "Luc", "Bleu"],
            homeNumbers: ["7", "10"],
            awayNumbers: ["7", "12"]
        )
        let tasks = [
            taskDef(id: 1, desc: "Pierre marque un panier à deux points",
                    hint: "„Pierre deux\" · „Pierre 2 points\" · „7 deux réussi\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 2, desc: "Pierre rate un tir à deux points",
                    hint: "„Pierre deux raté\" · „7 deux loupé\" · „Pierre 2 points non\"",
                    playerID: ids[0], action: .twoMissed),
            taskDef(id: 3, desc: "Paul envoie un trois points",
                    hint: "„Paul trois\" · „10 trois\" · „Paul 3 points\"",
                    playerID: ids[1], action: .threeMade),
            taskDef(id: 4, desc: "Paul rate un tir à trois points",
                    hint: "„Paul trois raté\" · „10 trois loupé\" · „Paul 3 points non\"",
                    playerID: ids[1], action: .threeMissed),
            taskDef(id: 5, desc: "Paul réussit un lancer franc",
                    hint: "„Paul lancer franc\" · „10 lancer franc\" · „Paul libre réussi\"",
                    playerID: ids[1], action: .freeThrowMade),
            taskDef(id: 6, desc: "Paul rate un lancer franc",
                    hint: "„Paul lancer franc raté\" · „10 libre non\" · „Paul lancer franc loupé\"",
                    playerID: ids[1], action: .freeThrowMissed),
            taskDef(id: 7, desc: "Pierre marque un lay-up",
                    hint: "„Pierre layup\" · „7 layup\" · „Pierre panier facile\"",
                    playerID: ids[0], action: .layupMade),
            taskDef(id: 8, desc: "Paul marque un tir à mi-distance",
                    hint: "„Paul mi-distance\" · „10 jumper\" · „Paul tir moyen\"",
                    playerID: ids[1], action: .midRangeMade),
            taskDef(id: 9, desc: "Jacques marque depuis la raquette",
                    hint: "„Jacques raquette\" · „Extérieur 7 raquette\" · „Bleu 7 intérieur\"",
                    playerID: ids[2], action: .paintMade),
            taskDef(id: 10, desc: "Jacques attrape un rebond",
                    hint: "„Jacques rebond\" · „Extérieur 7 rebond\" · „Bleu 7 rebond\"",
                    playerID: ids[2], action: .rebound),
            taskDef(id: 11, desc: "Paul fait une passe décisive",
                    hint: "„Paul assist\" · „10 passe décisive\" · „Domicile 10 assist\"",
                    playerID: ids[1], action: .assist),
            taskDef(id: 12, desc: "Luc contre un tir",
                    hint: "„Luc contre\" · „12 contre\" · „Extérieur 12 bloc\"",
                    playerID: ids[3], action: .block),
            taskDef(id: 13, desc: "Pierre intercepte le ballon",
                    hint: "„Pierre interception\" · „7 interception\" · „Domicile 7 steal\"",
                    playerID: ids[0], action: .steal),
            taskDef(id: 14, desc: "Luc perd le ballon sur un turnover",
                    hint: "„Luc turnover\" · „12 turnover\" · „Luc perte de balle\"",
                    playerID: ids[3], action: .turnover),
            taskDef(id: 15, desc: "Jacques commet une faute",
                    hint: "„Jacques faute\" · „Extérieur 7 faute\" · „Bleu 7 faute\"",
                    playerID: ids[2], action: .foul),
            taskDef(id: 16, desc: "Pierre convertit le lancer franc bonus",
                    hint: "„Pierre bonus\" · „7 and one\" · „Pierre lancer franc bonus\"",
                    playerID: ids[0], action: .bonusMade),
            taskDef(id: 17, desc: "Remplacement : Pierre sort, Paul entre pour l'équipe locale",
                    hint: "„Remplace 7 par 10\" · „Pierre sort Paul entre\" · „7 sort 10 entre\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 18, desc: "Jacques marque deux points pour l'équipe extérieure",
                    hint: "„Jacques 2 points\"",
                    playerID: ids[2], action: .twoMade),
            taskDef(id: 20, desc: "Paul fait une passe décisive à Pierre pour un deux points",
                    hint: "„Paul assist Pierre deux\" · „Paul assist Pierre deux réussi\"",
                    playerID: ids[1], action: .assist),
            taskDef(id: 25, desc: "Paul intercepte le ballon de Luc",
                    hint: "„Paul interception Luc\" · „Paul interception 12\" · „10 interception Luc\"",
                    playerID: ids[1], action: .steal),
            taskDef(id: 26, desc: "Jacques attrape un rebond offensif",
                    hint: "",
                    playerID: ids[2], action: .offensiveRebound),
            taskDef(id: 27, desc: "Jacques attrape un rebond défensif",
                    hint: "",
                    playerID: ids[2], action: .defensiveRebound),
            taskDef(id: 21, desc: "Commencer un quart-temps",
                    hint: "„début\" · „entre-deux\" · „premier quart\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 22, desc: "Faire une pause",
                    hint: "„pause\" · „temps mort\" · „arrêter\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 23, desc: "Reprendre le jeu",
                    hint: "„continuer\" · „reprise\" · „reprendre\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 24, desc: "Terminer un quart",
                    hint: "„quart achevé\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 19, desc: "Jeu libre — essaye n'importe quelle commande",
                    hint: "Dis des noms, numéros ou noms d'équipe pour t'entraîner",
                    playerID: ids[0], action: .twoMade),
        ]
        return TutorialLocalizedData(players: players, tasks: tasks, substitutionTaskID: 17, freePlayTaskID: 19)
    }

    // MARK: - Italian

    static func italianData(playerIDs: [UUID]) -> TutorialLocalizedData {
        let ids = playerIDs
        let players = makePlayers(
            ids: ids,
            homeNames: ["Marco", "Luca", "Rosso"],
            awayNames: ["Paolo", "Mario", "Blu"],
            homeNumbers: ["7", "10"],
            awayNumbers: ["7", "12"]
        )
        let tasks = [
            taskDef(id: 1, desc: "Marco segna un tiro da due punti",
                    hint: "„Marco due\" · „Marco 2 punti\" · „7 due segnato\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 2, desc: "Marco sbaglia un tiro da due punti",
                    hint: "„Marco due sbagliato\" · „7 due no\" · „Marco 2 punti fallito\"",
                    playerID: ids[0], action: .twoMissed),
            taskDef(id: 3, desc: "Luca realizza una tripla",
                    hint: "„Luca tre\" · „10 tre\" · „Luca 3 punti\"",
                    playerID: ids[1], action: .threeMade),
            taskDef(id: 4, desc: "Luca sbaglia un tiro da tre punti",
                    hint: "„Luca tre sbagliato\" · „10 tre no\" · „Luca 3 punti fallito\"",
                    playerID: ids[1], action: .threeMissed),
            taskDef(id: 5, desc: "Luca converte un tiro libero",
                    hint: "„Luca tiro libero\" · „10 libero\" · „Luca libero segnato\"",
                    playerID: ids[1], action: .freeThrowMade),
            taskDef(id: 6, desc: "Luca sbaglia dalla linea dei tiri liberi",
                    hint: "„Luca libero sbagliato\" · „10 libero no\" · „Luca tiro libero fallito\"",
                    playerID: ids[1], action: .freeThrowMissed),
            taskDef(id: 7, desc: "Marco finalizza con un layup",
                    hint: "„Marco layup\" · „7 layup\" · „Marco layup segnato\"",
                    playerID: ids[0], action: .layupMade),
            taskDef(id: 8, desc: "Luca segna un tiro da media distanza",
                    hint: "„Luca media distanza\" · „10 jumper\" · „Luca tiro medio\"",
                    playerID: ids[1], action: .midRangeMade),
            taskDef(id: 9, desc: "Paolo segna dalla vernice",
                    hint: "„Paolo vernice\" · „Ospite 7 vernice\" · „Blu 7 interno\"",
                    playerID: ids[2], action: .paintMade),
            taskDef(id: 10, desc: "Paolo prende un rimbalzo",
                    hint: "„Paolo rimbalzo\" · „Ospite 7 rimbalzo\" · „Blu 7 rimbalzo\"",
                    playerID: ids[2], action: .rebound),
            taskDef(id: 11, desc: "Luca serve un assist",
                    hint: "„Luca assist\" · „10 assist\" · „Casa 10 assist\"",
                    playerID: ids[1], action: .assist),
            taskDef(id: 12, desc: "Mario ferma un tiro con una stoppata",
                    hint: "„Mario stoppata\" · „12 stoppata\" · „Ospite 12 blocco\"",
                    playerID: ids[3], action: .block),
            taskDef(id: 13, desc: "Marco ruba il pallone",
                    hint: "„Marco rubata\" · „7 rubata\" · „Casa 7 rubata\"",
                    playerID: ids[0], action: .steal),
            taskDef(id: 14, desc: "Mario perde palla con un turnover",
                    hint: "„Mario turnover\" · „12 turnover\" · „Mario palla persa\"",
                    playerID: ids[3], action: .turnover),
            taskDef(id: 15, desc: "Paolo commette un fallo",
                    hint: "„Paolo fallo\" · „Ospite 7 fallo\" · „Blu 7 fallo\"",
                    playerID: ids[2], action: .foul),
            taskDef(id: 16, desc: "Marco converte il tiro libero bonus",
                    hint: "„Marco bonus\" · „7 and one\" · „Marco tiro extra\"",
                    playerID: ids[0], action: .bonusMade),
            taskDef(id: 17, desc: "Sostituzione: Marco esce, Luca entra per la squadra di casa",
                    hint: "„Cambia 7 con 10\" · „Marco fuori Luca dentro\" · „7 esce 10 entra\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 18, desc: "Paolo segna due punti per la squadra ospite",
                    hint: "„Paolo 2 punti\"",
                    playerID: ids[2], action: .twoMade),
            taskDef(id: 20, desc: "Luca assiste Marco per un tiro da due punti",
                    hint: "„Luca assist Marco due\" · „Luca assist Marco due segnato\"",
                    playerID: ids[1], action: .assist),
            taskDef(id: 25, desc: "Luca ruba il pallone a Mario",
                    hint: "„Luca rubata Mario\" · „Luca rubata 12\" · „10 rubata Mario\"",
                    playerID: ids[1], action: .steal),
            taskDef(id: 26, desc: "Paolo prende un rimbalzo offensivo",
                    hint: "",
                    playerID: ids[2], action: .offensiveRebound),
            taskDef(id: 27, desc: "Paolo prende un rimbalzo difensivo",
                    hint: "",
                    playerID: ids[2], action: .defensiveRebound),
            taskDef(id: 21, desc: "Iniziare un quarto",
                    hint: "„inizio\" · „primo quarto\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 22, desc: "Mettere in pausa",
                    hint: "„pausa\" · „timeout\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 23, desc: "Riprendere il gioco",
                    hint: "„continuare\" · „riprendere\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 24, desc: "Concludere un quarto",
                    hint: "„quarto concluso\"",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 19, desc: "Gioco libero — prova qualsiasi comando",
                    hint: "Pronuncia nomi, numeri o nomi di squadra per esercitarti",
                    playerID: ids[0], action: .twoMade),
        ]
        return TutorialLocalizedData(players: players, tasks: tasks, substitutionTaskID: 17, freePlayTaskID: 19)
    }

    // MARK: - Russian

    static func russianData(playerIDs: [UUID]) -> TutorialLocalizedData {
        let ids = playerIDs
        let players = makePlayers(
            ids: ids,
            homeNames: ["Иван", "Пётр", "Красные"],
            awayNames: ["Сергей", "Алексей", "Синие"],
            homeNumbers: ["7", "10"],
            awayNumbers: ["7", "12"]
        )
        let tasks = [
            taskDef(id: 1, desc: "Иван забивает двухочковый",
                    hint: "«Иван два»·«Иван 2 очка»·«7 два попал»",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 2, desc: "Иван промахивается из-за двух очков",
                    hint: "«Иван два промах»·«7 два нет»·«Иван 2 очка не попал»",
                    playerID: ids[0], action: .twoMissed),
            taskDef(id: 3, desc: "Пётр забивает трёхочковый",
                    hint: "«Пётр три»·«10 три»·«Пётр 3 очка»",
                    playerID: ids[1], action: .threeMade),
            taskDef(id: 4, desc: "Пётр промахивается из-за дуги",
                    hint: "«Пётр три промах»·«10 три нет»·«Пётр 3 очка не попал»",
                    playerID: ids[1], action: .threeMissed),
            taskDef(id: 5, desc: "Пётр забивает штрафной бросок",
                    hint: "«Пётр штрафной»·«10 штрафной»·«Пётр штрафной попал»",
                    playerID: ids[1], action: .freeThrowMade),
            taskDef(id: 6, desc: "Пётр промахивается со штрафной линии",
                    hint: "«Пётр штрафной нет»·«10 штрафной промах»·«Пётр штрафной не попал»",
                    playerID: ids[1], action: .freeThrowMissed),
            taskDef(id: 7, desc: "Иван забивает из-под кольца",
                    hint: "«Иван лейап»·«7 лейап»·«Иван проход»",
                    playerID: ids[0], action: .layupMade),
            taskDef(id: 8, desc: "Пётр забивает со средней дистанции",
                    hint: "«Пётр средняя»·«10 джампер»·«Пётр средний бросок»",
                    playerID: ids[1], action: .midRangeMade),
            taskDef(id: 9, desc: "Сергей забивает из краски",
                    hint: "«Сергей краска»·«Гости 7 краска»·«Синие 7 внутри»",
                    playerID: ids[2], action: .paintMade),
            taskDef(id: 10, desc: "Сергей подбирает мяч",
                    hint: "«Сергей подбор»·«Гости 7 подбор»·«Синие 7 подбор»",
                    playerID: ids[2], action: .rebound),
            taskDef(id: 11, desc: "Пётр отдаёт результативную передачу",
                    hint: "«Пётр ассист»·«10 ассист»·«Хозяева 10 ассист»",
                    playerID: ids[1], action: .assist),
            taskDef(id: 12, desc: "Алексей блокирует бросок",
                    hint: "«Алексей блок»·«12 блок»·«Гости 12 блок»",
                    playerID: ids[3], action: .block),
            taskDef(id: 13, desc: "Иван перехватывает мяч",
                    hint: "«Иван перехват»·«7 перехват»·«Хозяева 7 перехват»",
                    playerID: ids[0], action: .steal),
            taskDef(id: 14, desc: "Алексей теряет мяч",
                    hint: "«Алексей потеря»·«12 потеря»·«Алексей turnover»",
                    playerID: ids[3], action: .turnover),
            taskDef(id: 15, desc: "Сергей совершает фол",
                    hint: "«Сергей фол»·«Гости 7 фол»·«Синие 7 фол»",
                    playerID: ids[2], action: .foul),
            taskDef(id: 16, desc: "Иван забивает бонусный штрафной",
                    hint: "«Иван бонус»·«7 and one»·«Иван дополнительный штрафной»",
                    playerID: ids[0], action: .bonusMade),
            taskDef(id: 17, desc: "Замена: Иван уходит, Пётр выходит за хозяев",
                    hint: "«Замена 7 на 10»·«Иван вышел Пётр вышел»·«7 ушёл 10 вышел»",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 18, desc: "Сергей забивает два очка за гостевую команду",
                    hint: "«Сергей 2 очка»",
                    playerID: ids[2], action: .twoMade),
            taskDef(id: 20, desc: "Пётр отдаёт ассист на Ивана для двухочкового",
                    hint: "«Пётр ассист Иван два»·«Пётр ассист Иван два попал»",
                    playerID: ids[1], action: .assist),
            taskDef(id: 25, desc: "Пётр перехватывает мяч у Алексея",
                    hint: "«Пётр перехват Алексей»·«Пётр перехват 12»·«10 перехват Алексей»",
                    playerID: ids[1], action: .steal),
            taskDef(id: 26, desc: "Сергей подбирает мяч в нападении",
                    hint: "",
                    playerID: ids[2], action: .offensiveRebound),
            taskDef(id: 27, desc: "Сергей подбирает мяч в защите",
                    hint: "",
                    playerID: ids[2], action: .defensiveRebound),
            taskDef(id: 21, desc: "Начать четверть",
                    hint: "«начало»·«старт»·«первая четверть»",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 22, desc: "Пауза",
                    hint: "«пауза»·«тайм-аут»",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 23, desc: "Продолжить игру",
                    hint: "«продолжить»",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 24, desc: "Завершить четверть",
                    hint: "«четверть завершена»",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 19, desc: "Свободная игра — попробуй любую команду",
                    hint: "Говори имена, номера или название команды для практики",
                    playerID: ids[0], action: .twoMade),
        ]
        return TutorialLocalizedData(players: players, tasks: tasks, substitutionTaskID: 17, freePlayTaskID: 19)
    }

    // MARK: - Chinese Simplified

    static func chineseData(playerIDs: [UUID]) -> TutorialLocalizedData {
        let ids = playerIDs
        let players = makePlayers(
            ids: ids,
            homeNames: ["老张", "俊宏", "红队"],
            awayNames: ["仔队", "bobo", "蓝队"],
            homeNumbers: ["7", "10"],
            awayNumbers: ["7", "12"]
        )
        let tasks = [
            taskDef(id: 1, desc: "老张两分命中",
                    hint: "请说「老张两分」·「7号两分」·「老张两分命中」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 2, desc: "老张两分不中",
                    hint: "请说「7号两分不中」·「老张两分没进」·「7号两分没中」",
                    playerID: ids[0], action: .twoMissed),
            taskDef(id: 3, desc: "俊宏三分命中",
                    hint: "请说「俊宏三分」·「10号三分」·「俊宏三分命中」",
                    playerID: ids[1], action: .threeMade),
            taskDef(id: 4, desc: "俊宏三分不中",
                    hint: "请说「俊宏三分不中」·「10号三分没进」·「俊宏三分没中」",
                    playerID: ids[1], action: .threeMissed),
            taskDef(id: 5, desc: "俊宏罚球命中",
                    hint: "请说「俊宏罚球」·「10号罚球」·「俊宏罚球命中」",
                    playerID: ids[1], action: .freeThrowMade),
            taskDef(id: 6, desc: "俊宏罚球不中",
                    hint: "请说「俊宏罚球不中」·「10号罚球没进」·「俊宏罚球没中」",
                    playerID: ids[1], action: .freeThrowMissed),
            taskDef(id: 7, desc: "老张上篮得分",
                    hint: "请说「老张上篮」·「7号上篮」·「老张上篮命中」",
                    playerID: ids[0], action: .layupMade),
            taskDef(id: 8, desc: "俊宏中投命中",
                    hint: "请说「俊宏中投」·「10号中距离」·「俊宏中投命中」",
                    playerID: ids[1], action: .midRangeMade),
            taskDef(id: 9, desc: "仔队篮下得分",
                    hint: "请说「仔队篮下」·「客队7号内线」·「仔队篮下得分」",
                    playerID: ids[2], action: .paintMade),
            taskDef(id: 10, desc: "仔队抢到篮板",
                    hint: "请说「仔队篮板」·「客队7号篮板」·「仔队抢到篮板」",
                    playerID: ids[2], action: .rebound),
            taskDef(id: 11, desc: "俊宏送出助攻",
                    hint: "请说「俊宏助攻」·「10号助攻」·「俊宏传给队友得分」",
                    playerID: ids[1], action: .assist),
            taskDef(id: 12, desc: "bobo送出盖帽",
                    hint: "请说「bobo盖帽」·「12号盖帽」·「bobo封盖」",
                    playerID: ids[3], action: .block),
            taskDef(id: 13, desc: "老张完成抢断",
                    hint: "请说「老张抢断」·「7号抢断」·「老张断球」",
                    playerID: ids[0], action: .steal),
            taskDef(id: 14, desc: "bobo出现失误",
                    hint: "请说「bobo失误」·「12号失误」·「bobo丢球」",
                    playerID: ids[3], action: .turnover),
            taskDef(id: 15, desc: "仔队防守犯规",
                    hint: "请说「仔队犯规」·「客队7号犯规」·「仔队打手」",
                    playerID: ids[2], action: .foul),
            taskDef(id: 16, desc: "老张加罚命中",
                    hint: "请说「老张加罚」·「7号加罚」·「老张加罚命中」",
                    playerID: ids[0], action: .bonusMade),
            taskDef(id: 17, desc: "俊宏替换老张上场",
                    hint: "请说「俊宏替换老张」·「10号替换7号」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 18, desc: "仔队为客队拿下两分",
                    hint: "请说「仔队两分」",
                    playerID: ids[2], action: .twoMade),
            taskDef(id: 20, desc: "俊宏助攻老张两分命中",
                    hint: "请说「俊宏助攻老张两分」·「俊宏助攻老张两分命中」",
                    playerID: ids[1], action: .assist),
            taskDef(id: 25, desc: "俊宏抢断bobo",
                    hint: "请说「俊宏抢断bobo」·「俊宏抢断12号」·「10号抢断bobo」",
                    playerID: ids[1], action: .steal),
            taskDef(id: 26, desc: "仔队抢到前场篮板",
                    hint: "",
                    playerID: ids[2], action: .offensiveRebound),
            taskDef(id: 27, desc: "仔队抢到后场篮板",
                    hint: "",
                    playerID: ids[2], action: .defensiveRebound),
            taskDef(id: 21, desc: "开始一节比赛",
                    hint: "请说「开始」·「第一节」·「第1节」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 22, desc: "暂停比赛",
                    hint: "请说「暂停」·「停表」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 23, desc: "继续比赛",
                    hint: "请说「继续」·「继续比赛」·「比赛继续」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 24, desc: "结束本节",
                    hint: "请说「结束本节」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 19, desc: "自由练习——试试任意指令",
                    hint: "说任何指令来自由练习",
                    playerID: ids[0], action: .twoMade),
        ]
        return TutorialLocalizedData(players: players, tasks: tasks, substitutionTaskID: 17, freePlayTaskID: 19)
    }

    // MARK: - Chinese Traditional

    static func traditionalChineseData(playerIDs: [UUID]) -> TutorialLocalizedData {
        let ids = playerIDs
        let players = makePlayers(
            ids: ids,
            homeNames: ["老張", "俊宏", "紅隊"],
            awayNames: ["仔隊", "bobo", "藍隊"],
            homeNumbers: ["7", "10"],
            awayNumbers: ["7", "12"]
        )
        let tasks = [
            taskDef(id: 1, desc: "老張兩分命中",
                    hint: "請說「老張兩分」·「7號兩分」·「老張兩分命中」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 2, desc: "老張兩分不中",
                    hint: "請說「7號兩分不中」·「老張兩分沒進」·「7號兩分沒中」",
                    playerID: ids[0], action: .twoMissed),
            taskDef(id: 3, desc: "俊宏三分命中",
                    hint: "請說「俊宏三分」·「10號三分」·「俊宏三分命中」",
                    playerID: ids[1], action: .threeMade),
            taskDef(id: 4, desc: "俊宏三分不中",
                    hint: "請說「俊宏三分不中」·「10號三分沒進」·「俊宏三分沒中」",
                    playerID: ids[1], action: .threeMissed),
            taskDef(id: 5, desc: "俊宏罰球命中",
                    hint: "請說「俊宏罰球」·「10號罰球」·「俊宏罰球命中」",
                    playerID: ids[1], action: .freeThrowMade),
            taskDef(id: 6, desc: "俊宏罰球不中",
                    hint: "請說「俊宏罰球不中」·「10號罰球沒進」·「俊宏罰球沒中」",
                    playerID: ids[1], action: .freeThrowMissed),
            taskDef(id: 7, desc: "老張上籃得分",
                    hint: "請說「老張上籃」·「7號上籃」·「老張上籃命中」",
                    playerID: ids[0], action: .layupMade),
            taskDef(id: 8, desc: "俊宏中投命中",
                    hint: "請說「俊宏中投」·「10號中距離」·「俊宏中投命中」",
                    playerID: ids[1], action: .midRangeMade),
            taskDef(id: 9, desc: "仔隊籃下得分",
                    hint: "請說「仔隊籃下」·「客隊7號內線」·「仔隊籃下得分」",
                    playerID: ids[2], action: .paintMade),
            taskDef(id: 10, desc: "仔隊搶到籃板",
                    hint: "請說「仔隊籃板」·「客隊7號籃板」·「仔隊搶到籃板」",
                    playerID: ids[2], action: .rebound),
            taskDef(id: 11, desc: "俊宏送出助攻",
                    hint: "請說「俊宏助攻」·「10號助攻」·「俊宏傳給隊友得分」",
                    playerID: ids[1], action: .assist),
            taskDef(id: 12, desc: "bobo送出蓋帽",
                    hint: "請說「bobo蓋帽」·「12號蓋帽」·「bobo封蓋」",
                    playerID: ids[3], action: .block),
            taskDef(id: 13, desc: "老張完成抄截",
                    hint: "請說「老張抄截」·「7號抄截」·「老張抄截了」",
                    playerID: ids[0], action: .steal),
            taskDef(id: 14, desc: "bobo出現失誤",
                    hint: "請說「bobo失誤」·「12號失誤」·「bobo掉球」",
                    playerID: ids[3], action: .turnover),
            taskDef(id: 15, desc: "仔隊防守犯規",
                    hint: "請說「仔隊犯規」·「客隊7號犯規」·「仔隊打手」",
                    playerID: ids[2], action: .foul),
            taskDef(id: 16, desc: "老張加罰命中",
                    hint: "請說「老張加罰」·「7號加罰」·「老張加罰命中」",
                    playerID: ids[0], action: .bonusMade),
            taskDef(id: 17, desc: "俊宏替換老張上場",
                    hint: "請說「俊宏替換老張」·「10號替換7號」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 18, desc: "仔隊為客隊拿下兩分",
                    hint: "請說「仔隊兩分」",
                    playerID: ids[2], action: .twoMade),
            taskDef(id: 20, desc: "俊宏助攻老張兩分命中",
                    hint: "請說「俊宏助攻老張兩分」·「俊宏助攻老張兩分命中」",
                    playerID: ids[1], action: .assist),
            taskDef(id: 25, desc: "俊宏抄截bobo",
                    hint: "請說「俊宏抄截bobo」·「俊宏抄截12號」·「10號抄截bobo」",
                    playerID: ids[1], action: .steal),
            taskDef(id: 26, desc: "仔隊搶到前場籃板",
                    hint: "",
                    playerID: ids[2], action: .offensiveRebound),
            taskDef(id: 27, desc: "仔隊搶到後場籃板",
                    hint: "",
                    playerID: ids[2], action: .defensiveRebound),
            taskDef(id: 21, desc: "開始一節比賽",
                    hint: "請說「開始」·「第一節」·「第1節」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 22, desc: "暫停比賽",
                    hint: "請說「暫停」·「停表」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 23, desc: "繼續比賽",
                    hint: "請說「繼續」·「繼續比賽」·「比賽繼續」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 24, desc: "結束本節",
                    hint: "請說「結束本節」",
                    playerID: ids[0], action: .twoMade),
            taskDef(id: 19, desc: "自由練習——試試任意指令",
                    hint: "說任何指令來自由練習",
                    playerID: ids[0], action: .twoMade),
        ]
        return TutorialLocalizedData(players: players, tasks: tasks, substitutionTaskID: 17, freePlayTaskID: 19)
    }


}