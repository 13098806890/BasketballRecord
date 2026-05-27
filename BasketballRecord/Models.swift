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
    var players: [ExportPlayer]
    var teams: [ExportTeam]
    var game: ExportGameRecord
}

struct ExportGameRecord: Codable, Hashable {
    var id: UUID
    var savedAt: Date
    var snapshot: GameSnapshot
    var homeTeamName: String
    var awayTeamName: String
    var homePlayerIDs: [UUID]
    var awayPlayerIDs: [UUID]
    var playerNamesByID: [UUID: String]

    init(savedGame: SavedGame) {
        id = savedGame.id
        savedAt = savedGame.savedAt
        snapshot = savedGame.snapshot
        homeTeamName = savedGame.homeTeamName
        awayTeamName = savedGame.awayTeamName
        homePlayerIDs = savedGame.homePlayerIDs
        awayPlayerIDs = savedGame.awayPlayerIDs
        playerNamesByID = savedGame.playerNamesByID
    }

    var savedGame: SavedGame {
        SavedGame(
            id: id,
            savedAt: savedAt,
            snapshot: snapshot,
            aiSummary: nil,
            previousSnapshot: nil,
            undoSnapshots: [],
            homeTeamName: homeTeamName,
            awayTeamName: awayTeamName,
            homePlayerIDs: homePlayerIDs,
            awayPlayerIDs: awayPlayerIDs,
            playerNamesByID: playerNamesByID
        )
    }
}

struct ExportedTeamPackage: Codable, Hashable {
    var team: ExportTeam
    var players: [ExportPlayer]
}

struct ExportedPlayerPackage: Codable, Hashable {
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

enum PlayerGameRole: String, Codable, Hashable {
    case starter
    case bench

    var title: String {
        switch self {
        case .starter:
            return "首发"
        case .bench:
            return "替补"
        }
    }
}

enum CareerStatSection: String, CaseIterable, Codable, Identifiable {
    case total
    case average

    var id: String { rawValue }

    var title: String {
        switch self {
        case .total:
            return "总数据"
        case .average:
            return "场均"
        }
    }
}

enum CareerStatItem: String, CaseIterable, Codable, Identifiable {
    case totalPoints
    case totalRebounds
    case totalAssists
    case totalFouls
    case totalStarterGames
    case totalBenchGames
    case totalMinutes
    case totalPlusMinus
    case totalTwoPoint
    case totalThreePoint
    case totalFreeThrow
    case averagePoints
    case averageRebounds
    case averageAssists
    case averageFouls
    case averageMinutes
    case averagePlusMinus
    case averageTwoMade
    case averageThreeMade
    case averageFreeThrowMade
    case averageThreePointRate
    case averageFreeThrowRate

    var id: String { rawValue }

    var section: CareerStatSection {
        switch self {
        case .totalPoints,
             .totalRebounds,
             .totalAssists,
             .totalFouls,
             .totalStarterGames,
             .totalBenchGames,
             .totalMinutes,
             .totalPlusMinus,
             .totalTwoPoint,
             .totalThreePoint,
             .totalFreeThrow:
            return .total
        case .averagePoints,
             .averageRebounds,
             .averageAssists,
             .averageFouls,
             .averageMinutes,
             .averagePlusMinus,
             .averageTwoMade,
             .averageThreeMade,
             .averageFreeThrowMade,
             .averageThreePointRate,
             .averageFreeThrowRate:
            return .average
        }
    }

    var title: String {
        switch self {
        case .totalPoints:
            return "得分"
        case .totalRebounds:
            return "篮板"
        case .totalAssists:
            return "助攻"
        case .totalFouls:
            return "犯规"
        case .totalStarterGames:
            return "首发场次"
        case .totalBenchGames:
            return "替补场次"
        case .totalMinutes:
            return "时间"
        case .totalPlusMinus:
            return "正负值"
        case .totalTwoPoint:
            return "2分投篮"
        case .totalThreePoint:
            return "3分投篮"
        case .totalFreeThrow:
            return "罚球"
        case .averagePoints:
            return "场均得分"
        case .averageRebounds:
            return "场均篮板"
        case .averageAssists:
            return "场均助攻"
        case .averageFouls:
            return "场均犯规"
        case .averageMinutes:
            return "场均时间"
        case .averagePlusMinus:
            return "场均正负值"
        case .averageTwoMade:
            return "场均2分命中"
        case .averageThreeMade:
            return "场均3分命中"
        case .averageFreeThrowMade:
            return "场均罚球命中"
        case .averageThreePointRate:
            return "三分命中率"
        case .averageFreeThrowRate:
            return "罚球命中率"
        }
    }
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
    var homeAvailablePlayerIDs: [UUID] = []
    var awayAvailablePlayerIDs: [UUID] = []
    var starterPlayerIDs: [UUID] = []
    var isPaused = false
    var startersRecorded = false
    var playingSecondsByPlayerID: [UUID: TimeInterval] = [:]
    var activeSinceByPlayerID: [UUID: Date] = [:]
    var plusMinusByPlayerID: [UUID: Int] = [:]
    var currentPeriodFoulsBySide: [String: Int] = [:]
    var matchElapsedSeconds: TimeInterval = 0
    var matchActiveSince: Date?

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
        homeAvailablePlayerIDs: [UUID] = [],
        awayAvailablePlayerIDs: [UUID] = [],
        starterPlayerIDs: [UUID] = [],
        isPaused: Bool = false,
        startersRecorded: Bool = false,
        playingSecondsByPlayerID: [UUID: TimeInterval] = [:],
        activeSinceByPlayerID: [UUID: Date] = [:],
        plusMinusByPlayerID: [UUID: Int] = [:],
        currentPeriodFoulsBySide: [String: Int] = [:],
        matchElapsedSeconds: TimeInterval = 0,
        matchActiveSince: Date? = nil
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
        self.homeAvailablePlayerIDs = homeAvailablePlayerIDs
        self.awayAvailablePlayerIDs = awayAvailablePlayerIDs
        self.starterPlayerIDs = starterPlayerIDs
        self.isPaused = isPaused
        self.startersRecorded = startersRecorded
        self.playingSecondsByPlayerID = playingSecondsByPlayerID
        self.activeSinceByPlayerID = activeSinceByPlayerID
        self.plusMinusByPlayerID = plusMinusByPlayerID
        self.currentPeriodFoulsBySide = currentPeriodFoulsBySide
        self.matchElapsedSeconds = matchElapsedSeconds
        self.matchActiveSince = matchActiveSince
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
        homeAvailablePlayerIDs = try container.decodeIfPresent([UUID].self, forKey: .homeAvailablePlayerIDs) ?? homeOnCourtPlayerIDs
        awayAvailablePlayerIDs = try container.decodeIfPresent([UUID].self, forKey: .awayAvailablePlayerIDs) ?? awayOnCourtPlayerIDs
        starterPlayerIDs = try container.decodeIfPresent([UUID].self, forKey: .starterPlayerIDs) ?? []
        isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
        startersRecorded = try container.decodeIfPresent(Bool.self, forKey: .startersRecorded) ?? false
        playingSecondsByPlayerID = try container.decodeIfPresent([UUID: TimeInterval].self, forKey: .playingSecondsByPlayerID) ?? [:]
        activeSinceByPlayerID = try container.decodeIfPresent([UUID: Date].self, forKey: .activeSinceByPlayerID) ?? [:]
        plusMinusByPlayerID = try container.decodeIfPresent([UUID: Int].self, forKey: .plusMinusByPlayerID) ?? [:]
        currentPeriodFoulsBySide = try container.decodeIfPresent([String: Int].self, forKey: .currentPeriodFoulsBySide) ?? [:]
        matchElapsedSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .matchElapsedSeconds) ?? 0
        matchActiveSince = try container.decodeIfPresent(Date.self, forKey: .matchActiveSince)
    }
}

struct SavedGame: Identifiable, Codable, Hashable {
    var id = UUID()
    var savedAt: Date
    var snapshot: GameSnapshot
    var aiSummary: String?
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
        aiSummary: String? = nil,
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
        self.aiSummary = aiSummary
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
        aiSummary = try container.decodeIfPresent(String.self, forKey: .aiSummary)
        previousSnapshot = try container.decodeIfPresent(GameSnapshot.self, forKey: .previousSnapshot)
        undoSnapshots = try container.decodeIfPresent([GameSnapshot].self, forKey: .undoSnapshots) ?? []
        homeTeamName = try container.decodeIfPresent(String.self, forKey: .homeTeamName) ?? "主队"
        awayTeamName = try container.decodeIfPresent(String.self, forKey: .awayTeamName) ?? "客队"
        homePlayerIDs = try container.decodeIfPresent([UUID].self, forKey: .homePlayerIDs) ?? []
        awayPlayerIDs = try container.decodeIfPresent([UUID].self, forKey: .awayPlayerIDs) ?? []
        playerNamesByID = try container.decodeIfPresent([UUID: String].self, forKey: .playerNamesByID) ?? [:]
    }
}

extension SavedGame {
    func didParticipate(_ playerID: UUID) -> Bool {
        if snapshot.starterPlayerIDs.contains(playerID) { return true }
        if snapshot.playingSecondsByPlayerID[playerID, default: 0] > 0 { return true }
        if snapshot.activeSinceByPlayerID[playerID] != nil { return true }
        if snapshot.plusMinusByPlayerID[playerID] != nil { return true }
        if let stats = snapshot.statsByPlayerID[playerID], stats != PlayerStats() { return true }
        return false
    }

    func role(of playerID: UUID) -> PlayerGameRole? {
        if snapshot.starterPlayerIDs.contains(playerID) {
            return .starter
        }

        if didParticipate(playerID) {
            return .bench
        }

        return nil
    }
}
