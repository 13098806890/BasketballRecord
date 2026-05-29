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
    var aiSummary: String?
    var previousSnapshot: GameSnapshot?
    var undoSnapshots: [GameSnapshot]
    var homeTeamName: String
    var awayTeamName: String
    var homePlayerIDs: [UUID]
    var awayPlayerIDs: [UUID]
    var playerNamesByID: [UUID: String]

    enum CodingKeys: String, CodingKey {
        case id
        case savedAt
        case snapshot
        case aiSummary
        case previousSnapshot
        case undoSnapshots
        case homeTeamName
        case awayTeamName
        case homePlayerIDs
        case awayPlayerIDs
        case playerNamesByID
    }

    init(savedGame: SavedGame) {
        id = savedGame.id
        savedAt = savedGame.savedAt
        snapshot = savedGame.snapshot
        aiSummary = savedGame.aiSummary
        previousSnapshot = savedGame.previousSnapshot
        undoSnapshots = savedGame.undoSnapshots
        homeTeamName = savedGame.homeTeamName
        awayTeamName = savedGame.awayTeamName
        homePlayerIDs = savedGame.homePlayerIDs
        awayPlayerIDs = savedGame.awayPlayerIDs
        playerNamesByID = savedGame.playerNamesByID
    }

    init(
        id: UUID,
        savedAt: Date,
        snapshot: GameSnapshot,
        aiSummary: String?,
        previousSnapshot: GameSnapshot?,
        undoSnapshots: [GameSnapshot],
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

    var savedGame: SavedGame {
        SavedGame(
            id: id,
            savedAt: savedAt,
            snapshot: snapshot,
            aiSummary: aiSummary,
            previousSnapshot: previousSnapshot,
            undoSnapshots: undoSnapshots,
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

struct ExportedGamePackageV2: Codable, Hashable {
    var players: [ExportPlayerV2]
    var teams: [ExportTeamV2]
    var game: ExportGameRecordV2

    enum CodingKeys: String, CodingKey {
        case players = "p"
        case teams = "t"
        case game = "g"
    }

    init(legacy: ExportedGamePackage) {
        players = legacy.players.map(ExportPlayerV2.init)
        teams = legacy.teams.map(ExportTeamV2.init)
        game = ExportGameRecordV2(legacy: legacy.game)
    }

    var legacyPackage: ExportedGamePackage {
        let legacyPlayers = players.map(\.legacy)
        let legacyTeams = teams.map(\.legacy)
        let legacyGame = game.legacyRecord(playerPool: legacyPlayers)
        return ExportedGamePackage(players: legacyPlayers, teams: legacyTeams, game: legacyGame)
    }
}

struct ExportPlayerV2: Codable, Hashable {
    var id: UUID
    var name: String
    var height: String
    var weight: String
    var number: String

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case name = "n"
        case height = "h"
        case weight = "w"
        case number = "o"
    }

    init(legacy: ExportPlayer) {
        id = legacy.id
        name = legacy.name
        height = legacy.height
        weight = legacy.weight
        number = legacy.number
    }

    var legacy: ExportPlayer {
        ExportPlayer(id: id, name: name, height: height, weight: weight, number: number)
    }
}

struct ExportTeamV2: Codable, Hashable {
    var id: UUID
    var name: String
    var playerIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case name = "n"
        case playerIDs = "p"
    }

    init(legacy: ExportTeam) {
        id = legacy.id
        name = legacy.name
        playerIDs = legacy.playerIDs
    }

    var legacy: ExportTeam {
        ExportTeam(id: id, name: name, playerIDs: playerIDs)
    }
}

struct ExportGameRecordV2: Codable, Hashable {
    var id: UUID
    var savedAt: Date
    var snapshot: TransferGameSnapshotV2
    var aiSummary: String?
    var previousSnapshot: TransferGameSnapshotV2?
    var undoSnapshots: [TransferGameSnapshotV2]
    var homeTeamName: String
    var awayTeamName: String
    var homePlayerIDs: [UUID]
    var awayPlayerIDs: [UUID]
    var playerNamesByID: [UUID: String]

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case savedAt = "d"
        case snapshot = "s"
        case aiSummary = "a"
        case previousSnapshot = "p"
        case undoSnapshots = "u"
        case homeTeamName = "h"
        case awayTeamName = "v"
        case homePlayerIDs = "x"
        case awayPlayerIDs = "y"
        case playerNamesByID = "n"
    }

    init(legacy: ExportGameRecord) {
        id = legacy.id
        savedAt = legacy.savedAt
        snapshot = TransferGameSnapshotV2(legacy: legacy.snapshot)
        aiSummary = legacy.aiSummary
        previousSnapshot = legacy.previousSnapshot.map { TransferGameSnapshotV2(legacy: $0) }
        undoSnapshots = legacy.undoSnapshots.map { TransferGameSnapshotV2(legacy: $0) }
        homeTeamName = legacy.homeTeamName
        awayTeamName = legacy.awayTeamName
        homePlayerIDs = legacy.homePlayerIDs
        awayPlayerIDs = legacy.awayPlayerIDs
        playerNamesByID = legacy.playerNamesByID
    }

    func legacyRecord(playerPool: [ExportPlayer]) -> ExportGameRecord {
        let fallbackNames = Dictionary(uniqueKeysWithValues: playerPool.map { ($0.id, $0.name) })
        return ExportGameRecord(
            id: id,
            savedAt: savedAt,
            snapshot: snapshot.legacy,
            aiSummary: aiSummary,
            previousSnapshot: previousSnapshot?.legacy,
            undoSnapshots: undoSnapshots.map(\.legacy),
            homeTeamName: homeTeamName,
            awayTeamName: awayTeamName,
            homePlayerIDs: homePlayerIDs,
            awayPlayerIDs: awayPlayerIDs,
            playerNamesByID: playerNamesByID.isEmpty ? fallbackNames : playerNamesByID
        )
    }
}

struct TransferGameSnapshotV2: Codable, Hashable {
    var statsByPlayerID: [UUID: TransferPlayerStatsV2]?
    var logs: [TransferGameLogEntryV2]?
    var homeTeamID: UUID?
    var awayTeamID: UUID?
    var periodCount: Int?
    var currentPeriod: Int?
    var periodIsRunning: Bool?
    var isComplete: Bool?
    var courtPlayerCount: Int?
    var resetsTeamFoulsEachPeriod: Bool?
    var showsReboundButton: Bool?
    var showsAssistButton: Bool?
    var showsFoulButton: Bool?
    var showsBlockButton: Bool?
    var showsStealButton: Bool?
    var showsTurnoverButton: Bool?
    var homeOnCourtPlayerIDs: [UUID]?
    var awayOnCourtPlayerIDs: [UUID]?
    var homeAvailablePlayerIDs: [UUID]?
    var awayAvailablePlayerIDs: [UUID]?
    var starterPlayerIDs: [UUID]?
    var isPaused: Bool?
    var startersRecorded: Bool?
    var playingSecondsByPlayerID: [UUID: TimeInterval]?
    var activeSinceByPlayerID: [UUID: Date]?
    var plusMinusByPlayerID: [UUID: Int]?
    var currentPeriodFoulsBySide: [String: Int]?
    var matchElapsedSeconds: TimeInterval?
    var matchActiveSince: Date?
    var periodElapsedSeconds: TimeInterval?
    var periodActiveSince: Date?

    enum CodingKeys: String, CodingKey {
        case statsByPlayerID = "a"
        case logs = "b"
        case homeTeamID = "c"
        case awayTeamID = "d"
        case periodCount = "e"
        case currentPeriod = "f"
        case periodIsRunning = "g"
        case isComplete = "h"
        case courtPlayerCount = "i"
        case resetsTeamFoulsEachPeriod = "j"
        case showsReboundButton = "k"
        case showsAssistButton = "l"
        case showsFoulButton = "m"
        case showsBlockButton = "n"
        case showsStealButton = "o"
        case showsTurnoverButton = "p"
        case homeOnCourtPlayerIDs = "q"
        case awayOnCourtPlayerIDs = "r"
        case homeAvailablePlayerIDs = "s"
        case awayAvailablePlayerIDs = "t"
        case starterPlayerIDs = "u"
        case isPaused = "v"
        case startersRecorded = "w"
        case playingSecondsByPlayerID = "x"
        case activeSinceByPlayerID = "y"
        case plusMinusByPlayerID = "z"
        case currentPeriodFoulsBySide = "aa"
        case matchElapsedSeconds = "ab"
        case matchActiveSince = "ac"
        case periodElapsedSeconds = "ad"
        case periodActiveSince = "ae"
    }

    init(legacy: GameSnapshot) {
        statsByPlayerID = legacy.statsByPlayerID.isEmpty
            ? nil
            : Dictionary(uniqueKeysWithValues: legacy.statsByPlayerID.map { ($0.key, TransferPlayerStatsV2(legacy: $0.value)) })
        logs = legacy.logs.isEmpty ? nil : legacy.logs.map { TransferGameLogEntryV2(legacy: $0) }
        homeTeamID = legacy.homeTeamID
        awayTeamID = legacy.awayTeamID
        periodCount = legacy.periodCount == 4 ? nil : legacy.periodCount
        currentPeriod = legacy.currentPeriod == 1 ? nil : legacy.currentPeriod
        periodIsRunning = legacy.periodIsRunning ? true : nil
        isComplete = legacy.isComplete ? true : nil
        courtPlayerCount = legacy.courtPlayerCount == 4 ? nil : legacy.courtPlayerCount
        resetsTeamFoulsEachPeriod = legacy.resetsTeamFoulsEachPeriod ? nil : false
        showsReboundButton = legacy.showsReboundButton ? nil : false
        showsAssistButton = legacy.showsAssistButton ? nil : false
        showsFoulButton = legacy.showsFoulButton ? nil : false
        showsBlockButton = legacy.showsBlockButton ? nil : false
        showsStealButton = legacy.showsStealButton ? nil : false
        showsTurnoverButton = legacy.showsTurnoverButton ? nil : false
        homeOnCourtPlayerIDs = legacy.homeOnCourtPlayerIDs.isEmpty ? nil : legacy.homeOnCourtPlayerIDs
        awayOnCourtPlayerIDs = legacy.awayOnCourtPlayerIDs.isEmpty ? nil : legacy.awayOnCourtPlayerIDs
        homeAvailablePlayerIDs = legacy.homeAvailablePlayerIDs.isEmpty ? nil : legacy.homeAvailablePlayerIDs
        awayAvailablePlayerIDs = legacy.awayAvailablePlayerIDs.isEmpty ? nil : legacy.awayAvailablePlayerIDs
        starterPlayerIDs = legacy.starterPlayerIDs.isEmpty ? nil : legacy.starterPlayerIDs
        isPaused = legacy.isPaused ? true : nil
        startersRecorded = legacy.startersRecorded ? true : nil
        playingSecondsByPlayerID = legacy.playingSecondsByPlayerID.isEmpty ? nil : legacy.playingSecondsByPlayerID
        activeSinceByPlayerID = legacy.activeSinceByPlayerID.isEmpty ? nil : legacy.activeSinceByPlayerID
        plusMinusByPlayerID = legacy.plusMinusByPlayerID.isEmpty ? nil : legacy.plusMinusByPlayerID
        currentPeriodFoulsBySide = legacy.currentPeriodFoulsBySide.isEmpty ? nil : legacy.currentPeriodFoulsBySide
        matchElapsedSeconds = legacy.matchElapsedSeconds == 0 ? nil : legacy.matchElapsedSeconds
        matchActiveSince = legacy.matchActiveSince
        periodElapsedSeconds = legacy.periodElapsedSeconds == 0 ? nil : legacy.periodElapsedSeconds
        periodActiveSince = legacy.periodActiveSince
    }

    var legacy: GameSnapshot {
        GameSnapshot(
            statsByPlayerID: Dictionary(uniqueKeysWithValues: (statsByPlayerID ?? [:]).map { ($0.key, $0.value.legacy) }),
            logs: (logs ?? []).map(\.legacy),
            homeTeamID: homeTeamID,
            awayTeamID: awayTeamID,
            periodCount: periodCount ?? 4,
            currentPeriod: currentPeriod ?? 1,
            periodIsRunning: periodIsRunning ?? false,
            isComplete: isComplete ?? false,
            courtPlayerCount: courtPlayerCount ?? 4,
            resetsTeamFoulsEachPeriod: resetsTeamFoulsEachPeriod ?? true,
            showsReboundButton: showsReboundButton ?? true,
            showsAssistButton: showsAssistButton ?? true,
            showsFoulButton: showsFoulButton ?? true,
            showsBlockButton: showsBlockButton ?? true,
            showsStealButton: showsStealButton ?? true,
            showsTurnoverButton: showsTurnoverButton ?? true,
            homeOnCourtPlayerIDs: homeOnCourtPlayerIDs ?? [],
            awayOnCourtPlayerIDs: awayOnCourtPlayerIDs ?? [],
            homeAvailablePlayerIDs: homeAvailablePlayerIDs ?? [],
            awayAvailablePlayerIDs: awayAvailablePlayerIDs ?? [],
            starterPlayerIDs: starterPlayerIDs ?? [],
            isPaused: isPaused ?? false,
            startersRecorded: startersRecorded ?? false,
            playingSecondsByPlayerID: playingSecondsByPlayerID ?? [:],
            activeSinceByPlayerID: activeSinceByPlayerID ?? [:],
            plusMinusByPlayerID: plusMinusByPlayerID ?? [:],
            currentPeriodFoulsBySide: currentPeriodFoulsBySide ?? [:],
            matchElapsedSeconds: matchElapsedSeconds ?? 0,
            matchActiveSince: matchActiveSince,
            periodElapsedSeconds: periodElapsedSeconds ?? 0,
            periodActiveSince: periodActiveSince
        )
    }
}

struct TransferPlayerStatsV2: Codable, Hashable {
    var twoMade: Int?
    var twoAttempts: Int?
    var threeMade: Int?
    var threeAttempts: Int?
    var bonusFreeThrowMade: Int?
    var bonusFreeThrowAttempts: Int?
    var freeThrowMade: Int?
    var freeThrowAttempts: Int?
    var rebounds: Int?
    var assists: Int?
    var fouls: Int?
    var blocks: Int?
    var steals: Int?
    var turnovers: Int?

    enum CodingKeys: String, CodingKey {
        case twoMade = "a"
        case twoAttempts = "b"
        case threeMade = "c"
        case threeAttempts = "d"
        case bonusFreeThrowMade = "e"
        case bonusFreeThrowAttempts = "f"
        case freeThrowMade = "g"
        case freeThrowAttempts = "h"
        case rebounds = "i"
        case assists = "j"
        case fouls = "k"
        case blocks = "l"
        case steals = "m"
        case turnovers = "n"
    }

    init(legacy: PlayerStats) {
        twoMade = legacy.twoMade == 0 ? nil : legacy.twoMade
        twoAttempts = legacy.twoAttempts == 0 ? nil : legacy.twoAttempts
        threeMade = legacy.threeMade == 0 ? nil : legacy.threeMade
        threeAttempts = legacy.threeAttempts == 0 ? nil : legacy.threeAttempts
        bonusFreeThrowMade = legacy.bonusFreeThrowMade == 0 ? nil : legacy.bonusFreeThrowMade
        bonusFreeThrowAttempts = legacy.bonusFreeThrowAttempts == 0 ? nil : legacy.bonusFreeThrowAttempts
        freeThrowMade = legacy.freeThrowMade == 0 ? nil : legacy.freeThrowMade
        freeThrowAttempts = legacy.freeThrowAttempts == 0 ? nil : legacy.freeThrowAttempts
        rebounds = legacy.rebounds == 0 ? nil : legacy.rebounds
        assists = legacy.assists == 0 ? nil : legacy.assists
        fouls = legacy.fouls == 0 ? nil : legacy.fouls
        blocks = legacy.blocks == 0 ? nil : legacy.blocks
        steals = legacy.steals == 0 ? nil : legacy.steals
        turnovers = legacy.turnovers == 0 ? nil : legacy.turnovers
    }

    var legacy: PlayerStats {
        var value = PlayerStats()
        value.twoMade = twoMade ?? 0
        value.twoAttempts = twoAttempts ?? 0
        value.threeMade = threeMade ?? 0
        value.threeAttempts = threeAttempts ?? 0
        value.bonusFreeThrowMade = bonusFreeThrowMade ?? 0
        value.bonusFreeThrowAttempts = bonusFreeThrowAttempts ?? 0
        value.freeThrowMade = freeThrowMade ?? 0
        value.freeThrowAttempts = freeThrowAttempts ?? 0
        value.rebounds = rebounds ?? 0
        value.assists = assists ?? 0
        value.fouls = fouls ?? 0
        value.blocks = blocks ?? 0
        value.steals = steals ?? 0
        value.turnovers = turnovers ?? 0
        return value
    }
}

struct TransferGameLogEntryV2: Codable, Hashable {
    var id: UUID
    var timestamp: Date
    var message: String
    var playerID: UUID?
    var period: Int?
    var periodElapsedSeconds: TimeInterval?

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case timestamp = "t"
        case message = "m"
        case playerID = "p"
        case period = "q"
        case periodElapsedSeconds = "e"
    }

    init(legacy: GameLogEntry) {
        id = legacy.id
        timestamp = legacy.timestamp
        message = legacy.message
        playerID = legacy.playerID
        period = legacy.period
        periodElapsedSeconds = legacy.periodElapsedSeconds
    }

    var legacy: GameLogEntry {
        GameLogEntry(
            id: id,
            timestamp: timestamp,
            message: message,
            playerID: playerID,
            period: period,
            periodElapsedSeconds: periodElapsedSeconds
        )
    }
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
    var blocks = 0
    var steals = 0
    var turnovers = 0

    enum CodingKeys: String, CodingKey {
        case twoMade
        case twoAttempts
        case threeMade
        case threeAttempts
        case bonusFreeThrowMade
        case bonusFreeThrowAttempts
        case freeThrowMade
        case freeThrowAttempts
        case rebounds
        case assists
        case fouls
        case blocks
        case steals
        case turnovers
    }

    init() { }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        twoMade = try container.decodeIfPresent(Int.self, forKey: .twoMade) ?? 0
        twoAttempts = try container.decodeIfPresent(Int.self, forKey: .twoAttempts) ?? 0
        threeMade = try container.decodeIfPresent(Int.self, forKey: .threeMade) ?? 0
        threeAttempts = try container.decodeIfPresent(Int.self, forKey: .threeAttempts) ?? 0
        bonusFreeThrowMade = try container.decodeIfPresent(Int.self, forKey: .bonusFreeThrowMade) ?? 0
        bonusFreeThrowAttempts = try container.decodeIfPresent(Int.self, forKey: .bonusFreeThrowAttempts) ?? 0
        freeThrowMade = try container.decodeIfPresent(Int.self, forKey: .freeThrowMade) ?? 0
        freeThrowAttempts = try container.decodeIfPresent(Int.self, forKey: .freeThrowAttempts) ?? 0
        rebounds = try container.decodeIfPresent(Int.self, forKey: .rebounds) ?? 0
        assists = try container.decodeIfPresent(Int.self, forKey: .assists) ?? 0
        fouls = try container.decodeIfPresent(Int.self, forKey: .fouls) ?? 0
        blocks = try container.decodeIfPresent(Int.self, forKey: .blocks) ?? 0
        steals = try container.decodeIfPresent(Int.self, forKey: .steals) ?? 0
        turnovers = try container.decodeIfPresent(Int.self, forKey: .turnovers) ?? 0
    }

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
    var playerID: UUID?
    var period: Int?
    var periodElapsedSeconds: TimeInterval?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        message: String,
        playerID: UUID? = nil,
        period: Int? = nil,
        periodElapsedSeconds: TimeInterval? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
        self.playerID = playerID
        self.period = period
        self.periodElapsedSeconds = periodElapsedSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        message = try container.decode(String.self, forKey: .message)
        playerID = try container.decodeIfPresent(UUID.self, forKey: .playerID)
        period = try container.decodeIfPresent(Int.self, forKey: .period)
        periodElapsedSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .periodElapsedSeconds)
    }
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
    case totalBlocks
    case totalSteals
    case totalTurnovers
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
    case averageBlocks
    case averageSteals
    case averageTurnovers
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
             .totalBlocks,
             .totalSteals,
             .totalTurnovers,
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
             .averageBlocks,
             .averageSteals,
             .averageTurnovers,
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
        case .totalBlocks:
            return "封盖"
        case .totalSteals:
            return "抢断"
        case .totalTurnovers:
            return "失误"
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
        case .averageBlocks:
            return "场均封盖"
        case .averageSteals:
            return "场均抢断"
        case .averageTurnovers:
            return "场均失误"
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
    var showsBlockButton = true
    var showsStealButton = true
    var showsTurnoverButton = true
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
    var periodElapsedSeconds: TimeInterval = 0
    var periodActiveSince: Date?

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
        showsBlockButton: Bool = true,
        showsStealButton: Bool = true,
        showsTurnoverButton: Bool = true,
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
        matchActiveSince: Date? = nil,
        periodElapsedSeconds: TimeInterval = 0,
        periodActiveSince: Date? = nil
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
        self.showsBlockButton = showsBlockButton
        self.showsStealButton = showsStealButton
        self.showsTurnoverButton = showsTurnoverButton
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
        self.periodElapsedSeconds = periodElapsedSeconds
        self.periodActiveSince = periodActiveSince
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
        showsBlockButton = try container.decodeIfPresent(Bool.self, forKey: .showsBlockButton) ?? true
        showsStealButton = try container.decodeIfPresent(Bool.self, forKey: .showsStealButton) ?? true
        showsTurnoverButton = try container.decodeIfPresent(Bool.self, forKey: .showsTurnoverButton) ?? true
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
        periodElapsedSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .periodElapsedSeconds) ?? 0
        periodActiveSince = try container.decodeIfPresent(Date.self, forKey: .periodActiveSince)
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
