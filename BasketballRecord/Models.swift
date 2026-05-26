import Foundation

struct Player: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var height: String = ""
    var weight: String = ""
    var number: String = ""
    var photoData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        height: String = "",
        weight: String = "",
        number: String = "",
        photoData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.height = height
        self.weight = weight
        self.number = number
        self.photoData = photoData
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        height = try container.decodeIfPresent(String.self, forKey: .height) ?? ""
        weight = try container.decodeIfPresent(String.self, forKey: .weight) ?? ""
        number = try container.decodeIfPresent(String.self, forKey: .number) ?? ""
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
    }
}

struct Team: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var playerIDs: [UUID] = []

    init(id: UUID = UUID(), name: String, playerIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.playerIDs = playerIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        playerIDs = try container.decodeIfPresent([UUID].self, forKey: .playerIDs) ?? []
    }
}

struct ExportPlayer: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var height: String
    var weight: String
    var number: String

    init(player: Player) {
        id = player.id
        name = player.name
        height = player.height
        weight = player.weight
        number = player.number
    }

    init(id: UUID, name: String, height: String = "", weight: String = "", number: String = "") {
        self.id = id
        self.name = name
        self.height = height
        self.weight = weight
        self.number = number
    }

    var playerWithoutPhoto: Player {
        Player(id: id, name: name, height: height, weight: weight, number: number)
    }
}

struct ExportTeam: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var playerIDs: [UUID]

    init(team: Team) {
        id = team.id
        name = team.name
        playerIDs = team.playerIDs
    }

    init(id: UUID, name: String, playerIDs: [UUID]) {
        self.id = id
        self.name = name
        self.playerIDs = playerIDs
    }

    var team: Team {
        Team(id: id, name: name, playerIDs: playerIDs)
    }
}

struct ExportedGamePackage: Codable, Hashable {
    var version = 1
    var exportedAt = Date()
    var players: [ExportPlayer]
    var teams: [ExportTeam]
    var game: SavedGame
}

struct ExportedTeamPackage: Codable, Hashable {
    var version = 1
    var exportedAt = Date()
    var team: ExportTeam
    var players: [ExportPlayer]
}

struct ExportedPlayerPackage: Codable, Hashable {
    var version = 1
    var exportedAt = Date()
    var player: ExportPlayer
}

struct PlayerStats: Codable, Hashable {
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
    var allFreeThrowMade: Int { bonusFreeThrowMade + freeThrowMade }
    var allFreeThrowAttempts: Int { bonusFreeThrowAttempts + freeThrowAttempts }
    var points: Int { twoMade * 2 + threeMade * 3 + bonusFreeThrowMade + freeThrowMade }

    var fieldGoalRate: Double { rate(made, attempts) }
    var twoPointRate: Double { rate(twoMade, twoAttempts) }
    var threePointRate: Double { rate(threeMade, threeAttempts) }
    var freeThrowRate: Double { rate(allFreeThrowMade, allFreeThrowAttempts) }
    var effectiveFieldGoalRate: Double {
        guard attempts > 0 else { return 0 }
        return (Double(made) + 0.5 * Double(threeMade)) / Double(attempts)
    }
    var trueShootingRate: Double {
        let denominator = 2 * (Double(attempts) + 0.44 * Double(allFreeThrowAttempts))
        guard denominator > 0 else { return 0 }
        return Double(points) / denominator
    }
    var pointsPerShot: Double {
        guard attempts > 0 else { return 0 }
        return Double(points) / Double(attempts)
    }

    private func rate(_ made: Int, _ attempts: Int) -> Double {
        guard attempts > 0 else { return 0 }
        return Double(made) / Double(attempts)
    }
}

struct GameLogEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var timestamp: Date
    var message: String
}

struct GameSnapshot: Codable, Hashable {
    var statsByPlayerID: [UUID: PlayerStats] = [:]
    var logs: [GameLogEntry] = []
    var homeTeamID: UUID?
    var awayTeamID: UUID?
    var periodCount: Int = 4
    var currentPeriod: Int = 1
    var periodIsRunning = false
    var isComplete = false
    var courtPlayerCount = 4
    var resetsTeamFoulsEachPeriod = true
    var showsReboundButton = true 
    var showsAssistButton = true
    var showsFoulButton = true
    var homeOnCourtPlayerIDs: [UUID] = []
    var awayOnCourtPlayerIDs: [UUID] = []
    var startersRecorded = false
    var playingSecondsByPlayerID: [UUID: TimeInterval] = [:]
    var activeSinceByPlayerID: [UUID: Date] = [:]
    var plusMinusByPlayerID: [UUID: Int] = [:]
    var currentPeriodFoulsBySide: [String: Int] = [:]

    init(
        statsByPlayerID: [UUID: PlayerStats] = [:],
        logs: [GameLogEntry] = [],
        homeTeamID: UUID? = nil,
        awayTeamID: UUID? = nil,
        periodCount: Int = 4,
        currentPeriod: Int = 1,
        periodIsRunning: Bool = false,
        isComplete: Bool = false,
        courtPlayerCount: Int = 4,
        resetsTeamFoulsEachPeriod: Bool = true,
        showsReboundButton: Bool = true,
        showsAssistButton: Bool = true,
        showsFoulButton: Bool = true,
        homeOnCourtPlayerIDs: [UUID] = [],
        awayOnCourtPlayerIDs: [UUID] = [],
        startersRecorded: Bool = false,
        playingSecondsByPlayerID: [UUID: TimeInterval] = [:],
        activeSinceByPlayerID: [UUID: Date] = [:],
        plusMinusByPlayerID: [UUID: Int] = [:],
        currentPeriodFoulsBySide: [String: Int] = [:]
    ) {
        self.statsByPlayerID = statsByPlayerID
        self.logs = logs
        self.homeTeamID = homeTeamID
        self.awayTeamID = awayTeamID
        self.periodCount = periodCount
        self.currentPeriod = currentPeriod
        self.periodIsRunning = periodIsRunning
        self.isComplete = isComplete
        self.courtPlayerCount = courtPlayerCount
        self.resetsTeamFoulsEachPeriod = resetsTeamFoulsEachPeriod
        self.showsReboundButton = showsReboundButton
        self.showsAssistButton = showsAssistButton
        self.showsFoulButton = showsFoulButton
        self.homeOnCourtPlayerIDs = homeOnCourtPlayerIDs
        self.awayOnCourtPlayerIDs = awayOnCourtPlayerIDs
        self.startersRecorded = startersRecorded
        self.playingSecondsByPlayerID = playingSecondsByPlayerID
        self.activeSinceByPlayerID = activeSinceByPlayerID
        self.plusMinusByPlayerID = plusMinusByPlayerID
        self.currentPeriodFoulsBySide = currentPeriodFoulsBySide
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        statsByPlayerID = try container.decodeIfPresent([UUID: PlayerStats].self, forKey: .statsByPlayerID) ?? [:]
        logs = try container.decodeIfPresent([GameLogEntry].self, forKey: .logs) ?? []
        homeTeamID = try container.decodeIfPresent(UUID.self, forKey: .homeTeamID)
        awayTeamID = try container.decodeIfPresent(UUID.self, forKey: .awayTeamID)
        periodCount = try container.decodeIfPresent(Int.self, forKey: .periodCount) ?? 4
        currentPeriod = try container.decodeIfPresent(Int.self, forKey: .currentPeriod) ?? 1
        periodIsRunning = try container.decodeIfPresent(Bool.self, forKey: .periodIsRunning) ?? false
        isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? false
        courtPlayerCount = try container.decodeIfPresent(Int.self, forKey: .courtPlayerCount) ?? 4
        resetsTeamFoulsEachPeriod = try container.decodeIfPresent(Bool.self, forKey: .resetsTeamFoulsEachPeriod) ?? true
        showsReboundButton = try container.decodeIfPresent(Bool.self, forKey: .showsReboundButton) ?? true
        showsAssistButton = try container.decodeIfPresent(Bool.self, forKey: .showsAssistButton) ?? true
        showsFoulButton = try container.decodeIfPresent(Bool.self, forKey: .showsFoulButton) ?? true
        homeOnCourtPlayerIDs = try container.decodeIfPresent([UUID].self, forKey: .homeOnCourtPlayerIDs) ?? []
        awayOnCourtPlayerIDs = try container.decodeIfPresent([UUID].self, forKey: .awayOnCourtPlayerIDs) ?? []
        startersRecorded = try container.decodeIfPresent(Bool.self, forKey: .startersRecorded) ?? false
        playingSecondsByPlayerID = try container.decodeIfPresent([UUID: TimeInterval].self, forKey: .playingSecondsByPlayerID) ?? [:]
        activeSinceByPlayerID = try container.decodeIfPresent([UUID: Date].self, forKey: .activeSinceByPlayerID) ?? [:]
        plusMinusByPlayerID = try container.decodeIfPresent([UUID: Int].self, forKey: .plusMinusByPlayerID) ?? [:]
        currentPeriodFoulsBySide = try container.decodeIfPresent([String: Int].self, forKey: .currentPeriodFoulsBySide) ?? [:]
    }
}

struct SavedGame: Identifiable, Codable, Hashable {
    var id = UUID()
    var savedAt: Date
    var snapshot: GameSnapshot
    var previousSnapshot: GameSnapshot?
    var undoSnapshots: [GameSnapshot] = []
    var homeTeamName: String
    var awayTeamName: String
    var homePlayerIDs: [UUID]
    var awayPlayerIDs: [UUID]
    var playerNamesByID: [UUID: String]

    init(
        id: UUID = UUID(),
        savedAt: Date,
        snapshot: GameSnapshot,
        previousSnapshot: GameSnapshot? = nil,
        undoSnapshots: [GameSnapshot] = [],
        homeTeamName: String,
        awayTeamName: String,
        homePlayerIDs: [UUID],
        awayPlayerIDs: [UUID],
        playerNamesByID: [UUID: String]
    ) {
        self.id = id
        self.savedAt = savedAt
        self.snapshot = snapshot
        self.previousSnapshot = previousSnapshot
        self.undoSnapshots = undoSnapshots
        self.homeTeamName = homeTeamName
        self.awayTeamName = awayTeamName
        self.homePlayerIDs = homePlayerIDs
        self.awayPlayerIDs = awayPlayerIDs
        self.playerNamesByID = playerNamesByID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        snapshot = try container.decode(GameSnapshot.self, forKey: .snapshot)
        previousSnapshot = try container.decodeIfPresent(GameSnapshot.self, forKey: .previousSnapshot)
        undoSnapshots = try container.decodeIfPresent([GameSnapshot].self, forKey: .undoSnapshots) ?? []
        homeTeamName = try container.decodeIfPresent(String.self, forKey: .homeTeamName) ?? "主队"
        awayTeamName = try container.decodeIfPresent(String.self, forKey: .awayTeamName) ?? "客队"
        homePlayerIDs = try container.decodeIfPresent([UUID].self, forKey: .homePlayerIDs) ?? []
        awayPlayerIDs = try container.decodeIfPresent([UUID].self, forKey: .awayPlayerIDs) ?? []
        playerNamesByID = try container.decodeIfPresent([UUID: String].self, forKey: .playerNamesByID) ?? [:]
    }
}
