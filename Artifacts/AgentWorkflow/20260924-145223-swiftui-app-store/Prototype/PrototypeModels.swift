import Foundation

enum PrototypeTab: String, CaseIterable {
    case score
    case history
    case career
    case settings
    case profile
}

struct PrototypePlayer {
    let id: String
    let name: String
    let height: String
    let weight: String
    let number: String
    let position: String
    let teamName: String
}

struct PrototypePlayerStats {
    let twoMade: Int
    let twoAttempts: Int
    let threeMade: Int
    let threeAttempts: Int
    let rebounds: Int
    let assists: Int
    let fouls: Int
    let steals: Int
    let blocks: Int
    let turnovers: Int

    var points: Int {
        twoMade * 2 + threeMade * 3
    }

    var fieldGoalRate: String {
        let attempts = twoAttempts + threeAttempts
        guard attempts > 0 else { return "0%" }
        return "\(Int(Double(twoMade + threeMade) / Double(attempts) * 100))%"
    }
}

struct PrototypeGameLog {
    let timestamp: String
    let message: String
    let eventCode: String
    let period: Int
    let elapsedSeconds: Int
}

struct PrototypeSavedGame {
    let displayName: String
    let homeTeamName: String
    let awayTeamName: String
    let homeScore: Int
    let awayScore: Int
    let aiSummary: String
    let modifiedDate: String
    let playerNamesByID: [String: String]
    let logs: [PrototypeGameLog]
}

struct PrototypeMockData {
    let homePlayer: PrototypePlayer
    let awayPlayer: PrototypePlayer
    let homeStats: PrototypePlayerStats
    let awayStats: PrototypePlayerStats
    let game: PrototypeSavedGame
    let teams: [String]
    let players: [PrototypePlayer]

    static let current = PrototypeMockData(
        homePlayer: PrototypePlayer(id: "p1", name: "樱木花道", height: "189 cm", weight: "82 kg", number: "10", position: "PF", teamName: "湘北高中"),
        awayPlayer: PrototypePlayer(id: "p2", name: "流川枫", height: "187 cm", weight: "75 kg", number: "11", position: "SF", teamName: "湘北高中"),
        homeStats: PrototypePlayerStats(twoMade: 3, twoAttempts: 6, threeMade: 1, threeAttempts: 3, rebounds: 8, assists: 2, fouls: 1, steals: 1, blocks: 1, turnovers: 2),
        awayStats: PrototypePlayerStats(twoMade: 2, twoAttempts: 5, threeMade: 0, threeAttempts: 2, rebounds: 4, assists: 1, fouls: 2, steals: 2, blocks: 0, turnovers: 1),
        game: PrototypeSavedGame(
            displayName: "湘北高中 vs 海南大附属",
            homeTeamName: "湘北高中",
            awayTeamName: "海南大附属",
            homeScore: 9,
            awayScore: 5,
            aiSummary: "湘北在篮板和二次进攻上建立优势，末节用连续防守锁定胜局。",
            modifiedDate: "2026年9月24日",
            playerNamesByID: ["p1": "樱木花道", "p2": "流川枫"],
            logs: [
                PrototypeGameLog(timestamp: "02:18", message: "樱木花道 抢到进攻篮板", eventCode: "offensive_rebound", period: 4, elapsedSeconds: 138),
                PrototypeGameLog(timestamp: "01:42", message: "流川枫 完成抢断", eventCode: "steal", period: 4, elapsedSeconds: 102),
                PrototypeGameLog(timestamp: "00:36", message: "樱木花道 命中两分球", eventCode: "two_point_made", period: 4, elapsedSeconds: 36)
            ]
        ),
        teams: ["湘北高中", "海南大附属"],
        players: [
            PrototypePlayer(id: "p1", name: "樱木花道", height: "189 cm", weight: "82 kg", number: "10", position: "PF", teamName: "湘北高中"),
            PrototypePlayer(id: "p2", name: "流川枫", height: "187 cm", weight: "75 kg", number: "11", position: "SF", teamName: "湘北高中"),
            PrototypePlayer(id: "p3", name: "赤木刚宪", height: "197 cm", weight: "90 kg", number: "4", position: "C", teamName: "湘北高中"),
            PrototypePlayer(id: "p4", name: "宫城良田", height: "168 cm", weight: "59 kg", number: "7", position: "PG", teamName: "湘北高中"),
            PrototypePlayer(id: "p5", name: "三井寿", height: "184 cm", weight: "70 kg", number: "14", position: "SG", teamName: "湘北高中"),
            PrototypePlayer(id: "p6", name: "牧绅一", height: "184 cm", weight: "79 kg", number: "4", position: "PG", teamName: "海南大附属")
        ]
    )
}
