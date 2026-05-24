import Foundation

struct Player: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var height: String = ""
    var weight: String = ""
    var number: String = ""
    var photoData: Data?
}

struct Team: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var playerIDs: [UUID] = []
}

struct PlayerStats: Codable, Equatable {
    var twoMade = 0
    var twoAttempts = 0
    var threeMade = 0
    var threeAttempts = 0
    var bonusFreeThrowMade = 0
    var bonusFreeThrowAttempts = 0
    var freeThrowMade = 0
    var freeThrowAttempts = 0
    var rebounds = 0
    var assists = 0
    var fouls = 0

    var made: Int { twoMade + threeMade }
    var attempts: Int { twoAttempts + threeAttempts }
    var points: Int { twoMade * 2 + threeMade * 3 + bonusFreeThrowMade + freeThrowMade }

    var fieldGoalRate: Double { rate(made, attempts) }
    var twoPointRate: Double { rate(twoMade, twoAttempts) }
    var threePointRate: Double { rate(threeMade, threeAttempts) }

    private func rate(_ made: Int, _ attempts: Int) -> Double {
        guard attempts > 0 else { return 0 }
        return Double(made) / Double(attempts)
    }
}

struct GameLogEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var timestamp: Date
    var message: String
}

struct GameSnapshot: Codable, Equatable {
    var statsByPlayerID: [UUID: PlayerStats] = [:]
    var logs: [GameLogEntry] = []
    var homeTeamID: UUID?
    var awayTeamID: UUID?
}
