import Foundation

struct Player: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var height: String = ""
    var weight: String = ""
    var number: String = ""
    var photoData: Data?
    var playerGroupIDs: [UUID] = []
    var badges: [PlayerBadge] = []

    init(
        id: UUID = UUID(),
        name: String,
        height: String = "",
        weight: String = "",
        number: String = "",
        photoData: Data? = nil,
        playerGroupIDs: [UUID] = [],
        badges: [PlayerBadge] = []
    ) {
        self.id = id
        self.name = name
        self.height = height
        self.weight = weight
        self.number = number
        self.photoData = photoData
        self.playerGroupIDs = playerGroupIDs
        self.badges = badges
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        height = try container.decodeIfPresent(String.self, forKey: .height) ?? ""
        weight = try container.decodeIfPresent(String.self, forKey: .weight) ?? ""
        number = try container.decodeIfPresent(String.self, forKey: .number) ?? ""
        photoData = try container.decodeIfPresent(Data.self, forKey: .photoData)
        playerGroupIDs = try container.decodeIfPresent([UUID].self, forKey: .playerGroupIDs) ?? []
        badges = try container.decodeIfPresent([PlayerBadge].self, forKey: .badges) ?? []
    }
}

struct PlayerGroup: Identifiable, Codable, Hashable {
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
    var photoData: Data?

    init(player: Player) {
        id = player.id
        name = player.name
        height = player.height
        weight = player.weight
        number = player.number
        photoData = player.photoData
    }

    init(id: UUID, name: String, height: String = "", weight: String = "", number: String = "", photoData: Data? = nil) {
        self.id = id
        self.name = name
        self.height = height
        self.weight = weight
        self.number = number
        self.photoData = photoData
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

// MARK: - GameGroup

struct GameGroup: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var description: String? = nil
    var gameIDs: [UUID] = []
    var createdAt: Date = Date()
    var color: String? = nil

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        gameIDs: [UUID] = [],
        createdAt: Date = Date(),
        color: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.gameIDs = gameIDs
        self.createdAt = createdAt
        self.color = color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        gameIDs = try container.decodeIfPresent([UUID].self, forKey: .gameIDs) ?? []
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        color = try container.decodeIfPresent(String.self, forKey: .color)
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
        homeTeamName = try container.decodeIfPresent(String.self, forKey: .homeTeamName) ?? NSLocalizedString("team_home_default", comment: "Home")
        awayTeamName = try container.decodeIfPresent(String.self, forKey: .awayTeamName) ?? NSLocalizedString("team_away_default", comment: "Away")
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

struct CloudShareBundle: Codable {
    var players: [ExportPlayer]
    var teams: [ExportTeam]
    var games: [ExportedGamePackageV2]
}

struct CloudShareRecord: Codable {
    let uuid: String
    let playerIDs: [UUID]
    let teamIDs: [UUID]
    let gameIDs: [UUID]
}

enum BadgeType: String, Codable, CaseIterable {
    case scoringKing
    case mvp
    case ironKing
    case reboundKing
    case assistKing
    case threeKing
    case efficiencyKing
    case threeStreak
    case turnoverKing
    case blockKing

    var title: String {
        switch self {
        case .scoringKing: return NSLocalizedString("badge_scoring_king", comment: "")
        case .mvp: return NSLocalizedString("badge_mvp", comment: "")
        case .ironKing: return NSLocalizedString("badge_iron_king", comment: "")
        case .reboundKing: return NSLocalizedString("badge_rebound_king", comment: "")
        case .assistKing: return NSLocalizedString("badge_assist_king", comment: "")
        case .threeKing: return NSLocalizedString("badge_three_king", comment: "")
        case .efficiencyKing: return NSLocalizedString("badge_efficiency_king", comment: "")
        case .threeStreak: return NSLocalizedString("badge_three_streak", comment: "")
        case .turnoverKing: return NSLocalizedString("badge_turnover_king", comment: "")
        case .blockKing: return NSLocalizedString("badge_block_king", comment: "")
        }
    }

    var assetName: String {
        switch self {
        case .scoringKing: return "badge_scoring_king"
        case .mvp: return "badge_mvp"
        case .ironKing: return "badge_iron_king"
        case .reboundKing: return "badge_rebound_king"
        case .assistKing: return "badge_assist_king"
        case .threeKing: return "badge_three_king"
        case .efficiencyKing: return "badge_efficiency_king"
        case .threeStreak: return "badge_three_streak"
        case .turnoverKing: return "badge_turnover_king"
        case .blockKing: return "badge_block_king"
        }
    }
}

struct PlayerBadge: Identifiable, Codable, Hashable {
    let id: UUID
    let type: BadgeType
    let gameID: UUID
    let awardedAt: Date

    init(type: BadgeType, gameID: UUID) {
        self.id = UUID()
        self.type = type
        self.gameID = gameID
        self.awardedAt = Date()
    }
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
    var photoData: Data?

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case name = "n"
        case height = "h"
        case weight = "w"
        case number = "o"
        case photoData = "f"
    }

    init(legacy: ExportPlayer) {
        id = legacy.id
        name = legacy.name
        height = legacy.height
        weight = legacy.weight
        number = legacy.number
        photoData = legacy.photoData
    }

    var legacy: ExportPlayer {
        ExportPlayer(id: id, name: name, height: height, weight: weight, number: number, photoData: photoData)
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
    var homeTeamStatsMode: Bool?
    var awayTeamStatsMode: Bool?
    var teamStatsByID: [UUID: TransferPlayerStatsV2]?
    var wasBluetoothCollaborated: Bool?
    var showsOffensiveDefensiveRebound: Bool?
    var editHistory: [GameLogEditRecord]?

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
        case homeTeamStatsMode = "af"
        case awayTeamStatsMode = "ag"
        case teamStatsByID = "ah"
        case wasBluetoothCollaborated = "ai"
        case showsOffensiveDefensiveRebound = "aj"
        case editHistory = "ak"
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
        homeTeamStatsMode = legacy.homeTeamStatsMode ? true : nil
        awayTeamStatsMode = legacy.awayTeamStatsMode ? true : nil
        teamStatsByID = legacy.teamStatsByID.isEmpty
            ? nil
            : Dictionary(uniqueKeysWithValues: legacy.teamStatsByID.map { ($0.key, TransferPlayerStatsV2(legacy: $0.value)) })
        wasBluetoothCollaborated = legacy.wasBluetoothCollaborated ? true : nil
        showsOffensiveDefensiveRebound = legacy.showsOffensiveDefensiveRebound ? true : nil
        editHistory = legacy.editHistory.isEmpty ? nil : legacy.editHistory
    }

    var legacy: GameSnapshot {
        let s = statsByPlayerID ?? [:]
        let l = logs ?? []
        let ts = teamStatsByID ?? [:]
        var snap = GameSnapshot(
            statsByPlayerID: Dictionary(uniqueKeysWithValues: s.map { ($0.key, $0.value.legacy) }),
            logs: l.map(\.legacy),
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
        snap.homeTeamStatsMode = homeTeamStatsMode ?? false
        snap.awayTeamStatsMode = awayTeamStatsMode ?? false
        snap.teamStatsByID = Dictionary(uniqueKeysWithValues: ts.map { ($0.key, $0.value.legacy) })
        snap.wasBluetoothCollaborated = wasBluetoothCollaborated ?? false
        snap.showsOffensiveDefensiveRebound = showsOffensiveDefensiveRebound ?? false
        snap.editHistory = editHistory ?? []
        return snap
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
    var offensiveRebounds: Int?
    var defensiveRebounds: Int?
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
        case offensiveRebounds = "o"
        case defensiveRebounds = "p"
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
        offensiveRebounds = legacy.offensiveRebounds == 0 ? nil : legacy.offensiveRebounds
        defensiveRebounds = legacy.defensiveRebounds == 0 ? nil : legacy.defensiveRebounds
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
        value.offensiveRebounds = offensiveRebounds ?? 0
        value.defensiveRebounds = defensiveRebounds ?? 0
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
    var eventCode: String?
    var relatedPlayerID: UUID?

    enum CodingKeys: String, CodingKey {
        case id = "i"
        case timestamp = "t"
        case message = "m"
        case playerID = "p"
        case period = "q"
        case periodElapsedSeconds = "e"
        case eventCode = "r"
        case relatedPlayerID = "s"
    }

    init(legacy: GameLogEntry) {
        id = legacy.id
        timestamp = legacy.timestamp
        message = legacy.message
        playerID = legacy.playerID
        period = legacy.period
        periodElapsedSeconds = legacy.periodElapsedSeconds
        eventCode = legacy.eventCode
        relatedPlayerID = legacy.relatedPlayerID
    }

    var legacy: GameLogEntry {
        GameLogEntry(
            id: id,
            timestamp: timestamp,
            message: message,
            eventCode: eventCode,
            playerID: playerID,
            relatedPlayerID: relatedPlayerID,
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
    var layupMade = 0
    var layupAttempts = 0
    var midRangeMade = 0
    var midRangeAttempts = 0
    var paintMade = 0
    var paintAttempts = 0
    var dunkMade = 0
    var dunkAttempts = 0
    var bonusFreeThrowMade = 0
    var bonusFreeThrowAttempts = 0
    var freeThrowMade = 0
    var freeThrowAttempts = 0
    var rebounds = 0
    var offensiveRebounds = 0
    var defensiveRebounds = 0
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
        case offensiveRebounds
        case defensiveRebounds
        case assists
        case fouls
        case blocks
        case steals
        case turnovers
        case layupMade, layupAttempts
        case midRangeMade, midRangeAttempts
        case paintMade, paintAttempts
        case dunkMade, dunkAttempts
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
        offensiveRebounds = try container.decodeIfPresent(Int.self, forKey: .offensiveRebounds) ?? 0
        defensiveRebounds = try container.decodeIfPresent(Int.self, forKey: .defensiveRebounds) ?? 0
        assists = try container.decodeIfPresent(Int.self, forKey: .assists) ?? 0
        fouls = try container.decodeIfPresent(Int.self, forKey: .fouls) ?? 0
        blocks = try container.decodeIfPresent(Int.self, forKey: .blocks) ?? 0
        steals = try container.decodeIfPresent(Int.self, forKey: .steals) ?? 0
        turnovers = try container.decodeIfPresent(Int.self, forKey: .turnovers) ?? 0
        layupMade = try container.decodeIfPresent(Int.self, forKey: .layupMade) ?? 0
        layupAttempts = try container.decodeIfPresent(Int.self, forKey: .layupAttempts) ?? 0
        midRangeMade = try container.decodeIfPresent(Int.self, forKey: .midRangeMade) ?? 0
        midRangeAttempts = try container.decodeIfPresent(Int.self, forKey: .midRangeAttempts) ?? 0
        paintMade = try container.decodeIfPresent(Int.self, forKey: .paintMade) ?? 0
        paintAttempts = try container.decodeIfPresent(Int.self, forKey: .paintAttempts) ?? 0
        dunkMade = try container.decodeIfPresent(Int.self, forKey: .dunkMade) ?? 0
        dunkAttempts = try container.decodeIfPresent(Int.self, forKey: .dunkAttempts) ?? 0
    }

    var totalRebounds: Int { rebounds + offensiveRebounds + defensiveRebounds }
    var made: Int { twoMade + threeMade }
    var attempts: Int { twoAttempts + threeAttempts }
    var allShotsMade: Int { twoMade + threeMade + layupMade + midRangeMade + paintMade + dunkMade }
    var allShotAttempts: Int { twoAttempts + threeAttempts + layupAttempts + midRangeAttempts + paintAttempts + dunkAttempts }
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

    var gameScore: Double {
        let fgm = twoMade + threeMade
        let fga = twoAttempts + threeAttempts
        let ftm = allFreeThrowMade
        let fta = allFreeThrowAttempts
        return Double(points)
            + 0.4 * Double(fgm) - 0.7 * Double(fga)
            - 0.4 * Double(fta - ftm)
            + 0.5 * Double(totalRebounds)
            + Double(steals)
            + 0.7 * Double(assists)
            + 0.7 * Double(blocks)
            - 0.4 * Double(fouls)
            - Double(turnovers)
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
    var eventCode: String?
    var playerID: UUID?
    var relatedPlayerID: UUID?
    var period: Int?
    var periodElapsedSeconds: TimeInterval?

    init(
        id: UUID = UUID(),
        timestamp: Date,
        message: String,
        eventCode: String? = nil,
        playerID: UUID? = nil,
        relatedPlayerID: UUID? = nil,
        period: Int? = nil,
        periodElapsedSeconds: TimeInterval? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.message = message
        self.eventCode = eventCode
        self.playerID = playerID
        self.relatedPlayerID = relatedPlayerID
        self.period = period
        self.periodElapsedSeconds = periodElapsedSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        message = try container.decode(String.self, forKey: .message)
        eventCode = try container.decodeIfPresent(String.self, forKey: .eventCode)
        playerID = try container.decodeIfPresent(UUID.self, forKey: .playerID)
        relatedPlayerID = try container.decodeIfPresent(UUID.self, forKey: .relatedPlayerID)
        period = try container.decodeIfPresent(Int.self, forKey: .period)
        periodElapsedSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .periodElapsedSeconds)

        // Backward compatibility: extract eventCode from message if not stored separately
        if eventCode == nil, let code = GameLogFormatter.extractEventCode(from: message) {
            eventCode = code
        }
    }
}

enum PlayerGameRole: String, Codable, Hashable {
    case starter
    case bench

    var title: String {
        switch self {
        case .starter:
            return NSLocalizedString("stat_label_starter", comment: "Starter")
        case .bench:
            return NSLocalizedString("stat_label_bench", comment: "Bench")
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
            return NSLocalizedString("stat_section_total", comment: "Total")
        case .average:
            return NSLocalizedString("stat_section_average", comment: "Average")
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
            return NSLocalizedString("stat_label_points", comment: "Points")
        case .totalRebounds:
            return NSLocalizedString("stat_label_rebounds", comment: "Rebounds")
        case .totalAssists:
            return NSLocalizedString("stat_label_assists", comment: "Assists")
        case .totalFouls:
            return NSLocalizedString("stat_label_fouls", comment: "Fouls")
        case .totalBlocks:
            return NSLocalizedString("stat_label_blocks", comment: "Blocks")
        case .totalSteals:
            return NSLocalizedString("stat_label_steals", comment: "Steals")
        case .totalTurnovers:
            return NSLocalizedString("stat_label_turnovers", comment: "Turnovers")
        case .totalStarterGames:
            return NSLocalizedString("stat_label_starter_games", comment: "Starter games")
        case .totalBenchGames:
            return NSLocalizedString("stat_label_bench_games", comment: "Bench games")
        case .totalMinutes:
            return NSLocalizedString("stat_label_minutes", comment: "Minutes")
        case .totalPlusMinus:
            return NSLocalizedString("stats_plus_minus", comment: "Plus/minus")
        case .totalTwoPoint:
            return NSLocalizedString("stat_label_2pt_attempts", comment: "2PT attempts")
        case .totalThreePoint:
            return NSLocalizedString("stat_label_3pt_attempts", comment: "3PT attempts")
        case .totalFreeThrow:
            return NSLocalizedString("stat_label_free_throw", comment: "Free throw")
        case .averagePoints:
            return NSLocalizedString("stat_label_avg_points", comment: "Avg points")
        case .averageRebounds:
            return NSLocalizedString("stat_label_avg_rebounds", comment: "Avg rebounds")
        case .averageAssists:
            return NSLocalizedString("stat_label_avg_assists", comment: "Avg assists")
        case .averageFouls:
            return NSLocalizedString("stat_label_avg_fouls", comment: "Avg fouls")
        case .averageBlocks:
            return NSLocalizedString("stat_label_avg_blocks", comment: "Avg blocks")
        case .averageSteals:
            return NSLocalizedString("stat_label_avg_steals", comment: "Avg steals")
        case .averageTurnovers:
            return NSLocalizedString("stat_label_avg_turnovers", comment: "Avg turnovers")
        case .averageMinutes:
            return NSLocalizedString("stat_label_avg_minutes", comment: "Avg minutes")
        case .averagePlusMinus:
            return NSLocalizedString("stat_label_avg_plus_minus", comment: "Avg plus/minus")
        case .averageTwoMade:
            return NSLocalizedString("stat_label_avg_2pt_made", comment: "Avg 2PT made")
        case .averageThreeMade:
            return NSLocalizedString("stat_label_avg_3pt_made", comment: "Avg 3PT made")
        case .averageFreeThrowMade:
            return NSLocalizedString("stat_label_avg_free_throw_made", comment: "Avg FT made")
        case .averageThreePointRate:
            return NSLocalizedString("stat_label_3pt_rate", comment: "3PT rate")
        case .averageFreeThrowRate:
            return NSLocalizedString("stat_label_free_throw_rate", comment: "FT rate")
        }
    }
}

enum PeriodEndCondition: String, Codable, CaseIterable, Identifiable {
    case manual
    case byTime
    case byScore
    var id: String { rawValue }
}

struct GameLogEditRecord: Codable, Hashable, Identifiable {
    var id = UUID()
    var timestamp: Date
    var action: String  // "add", "modify", "delete"
    var eventID: UUID
    var previousMessage: String?
    var previousEventCode: String?
    var previousPlayerID: UUID?
    var previousTimestamp: Date?
    var previousPeriod: Int?
    var currentMessage: String?
    var currentEventCode: String?
    var currentPlayerID: UUID?
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
    var wasBluetoothCollaborated = false
    var courtPlayerCount = 4
    var periodEndCondition: PeriodEndCondition = .byTime
    var periodTimeLimit: Int = 12
    var periodScoreLimit: Int = 30
    var resetsTeamFoulsEachPeriod = true
    var showsReboundButton = true 
    var showsOffensiveDefensiveRebound = false
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
    var homeTeamStatsMode = false
    var awayTeamStatsMode = false
    var teamStatsByID: [UUID: PlayerStats] = [:]
    var editHistory: [GameLogEditRecord] = []

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
        showsOffensiveDefensiveRebound: Bool = false,
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
        periodActiveSince: Date? = nil,
        periodEndCondition: PeriodEndCondition = .byTime,
        periodTimeLimit: Int = 12,
        periodScoreLimit: Int = 30,
        homeTeamStatsMode: Bool = false,
        awayTeamStatsMode: Bool = false,
        editHistory: [GameLogEditRecord] = []
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
        self.periodEndCondition = periodEndCondition
        self.periodTimeLimit = periodTimeLimit
        self.periodScoreLimit = periodScoreLimit
        self.resetsTeamFoulsEachPeriod = resetsTeamFoulsEachPeriod
        self.showsReboundButton = showsReboundButton
        self.showsOffensiveDefensiveRebound = showsOffensiveDefensiveRebound
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
        self.homeTeamStatsMode = homeTeamStatsMode
        self.awayTeamStatsMode = awayTeamStatsMode
        self.editHistory = editHistory
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
        showsOffensiveDefensiveRebound = try container.decodeIfPresent(Bool.self, forKey: .showsOffensiveDefensiveRebound) ?? false
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
        periodEndCondition = try container.decodeIfPresent(PeriodEndCondition.self, forKey: .periodEndCondition) ?? .byTime
        periodTimeLimit = try container.decodeIfPresent(Int.self, forKey: .periodTimeLimit) ?? 12
        periodScoreLimit = try container.decodeIfPresent(Int.self, forKey: .periodScoreLimit) ?? 30
        wasBluetoothCollaborated = try container.decodeIfPresent(Bool.self, forKey: .wasBluetoothCollaborated) ?? false
        homeTeamStatsMode = try container.decodeIfPresent(Bool.self, forKey: .homeTeamStatsMode) ?? false
        awayTeamStatsMode = try container.decodeIfPresent(Bool.self, forKey: .awayTeamStatsMode) ?? false
        teamStatsByID = try container.decodeIfPresent([UUID: PlayerStats].self, forKey: .teamStatsByID) ?? [:]
        editHistory = try container.decodeIfPresent([GameLogEditRecord].self, forKey: .editHistory) ?? []
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
    var groupIDs: [UUID] = []
    var isLocked = false
    var displayName: String = ""

    /// Resolve a team UUID from a log message for team stats mode.
    func resolvedTeamID(from message: String) -> UUID? {
        guard snapshot.homeTeamStatsMode || snapshot.awayTeamStatsMode else { return nil }
        let msg = message.lowercased()
        if snapshot.homeTeamStatsMode, let tid = snapshot.homeTeamID,
           msg.contains(homeTeamName.lowercased()) || msg.contains("主队") || msg.contains("zhudui") { return tid }
        if snapshot.awayTeamStatsMode, let tid = snapshot.awayTeamID,
           msg.contains(awayTeamName.lowercased()) || msg.contains("客队") || msg.contains("kedui") { return tid }
        return nil
    }

    /// Total score for a team, including both player-level and team-level stats.
    func score(forTeamID teamID: UUID) -> Int {
        let isHome = teamID == snapshot.homeTeamID
        let ids = isHome ? homePlayerIDs : awayPlayerIDs
        let playerPts = ids.reduce(0) { $0 + (snapshot.statsByPlayerID[$1]?.points ?? 0) }
        return playerPts + (snapshot.teamStatsByID[teamID]?.points ?? 0)
    }

    func playingTimeByPeriod() -> [Int: [UUID: TimeInterval]] {
        let relevantCodes: Set<String> = ["event.substitution", "event.period_start", "event.period_end"]
        let events = snapshot.logs.filter { $0.eventCode.map(relevantCodes.contains) ?? false }
            .sorted { ($0.period ?? 0, $0.periodElapsedSeconds ?? 0) < ($1.period ?? 0, $1.periodElapsedSeconds ?? 0) }
        guard !events.isEmpty else { return [:] }

        var result: [Int: [UUID: TimeInterval]] = [:]
        let allPlayerIDs = Set(homePlayerIDs + awayPlayerIDs)
        let initialCourt: Set<UUID>
        if snapshot.startersRecorded {
            initialCourt = Set(snapshot.starterPlayerIDs).intersection(allPlayerIDs)
        } else {
            initialCourt = allPlayerIDs
        }
        var onCourt = initialCourt
        var currentPeriod = events[0].period ?? 1
        var lastElapsed: TimeInterval = 0

        for event in events {
            let eventPeriod = event.period ?? currentPeriod
            let eventElapsed = event.periodElapsedSeconds ?? 0

            if eventPeriod == currentPeriod {
                let elapsed = eventElapsed - lastElapsed
                if elapsed > 0 {
                    for pid in onCourt {
                        result[currentPeriod, default: [:]][pid, default: 0] += elapsed
                    }
                }
            }

            if event.eventCode == "event.period_start" {
                currentPeriod = eventPeriod
                onCourt = initialCourt
                lastElapsed = 0
            } else if event.eventCode == "event.substitution" {
                if let incoming = event.playerID { onCourt.insert(incoming) }
                if let outgoing = event.relatedPlayerID { onCourt.remove(outgoing) }
                lastElapsed = eventElapsed
            } else if event.eventCode == "event.period_end" {
                lastElapsed = 0
            }
        }

        return result
    }

    var displayTitle: String {
        if displayName.isEmpty {
            return "\(homeTeamName) vs \(awayTeamName)"
        }
        return "\(displayName)（\(homeTeamName) vs \(awayTeamName)）"
    }

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
        playerNamesByID: [UUID: String],
        groupIDs: [UUID] = [],
        displayName: String = ""
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
        self.groupIDs = groupIDs
        self.displayName = displayName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        savedAt = try container.decode(Date.self, forKey: .savedAt)
        snapshot = try container.decode(GameSnapshot.self, forKey: .snapshot)
        aiSummary = try container.decodeIfPresent(String.self, forKey: .aiSummary)
        previousSnapshot = try container.decodeIfPresent(GameSnapshot.self, forKey: .previousSnapshot)
        undoSnapshots = try container.decodeIfPresent([GameSnapshot].self, forKey: .undoSnapshots) ?? []
        homeTeamName = try container.decodeIfPresent(String.self, forKey: .homeTeamName) ?? NSLocalizedString("team_home_default", comment: "Home")
        awayTeamName = try container.decodeIfPresent(String.self, forKey: .awayTeamName) ?? NSLocalizedString("team_away_default", comment: "Away")
        homePlayerIDs = try container.decodeIfPresent([UUID].self, forKey: .homePlayerIDs) ?? []
        awayPlayerIDs = try container.decodeIfPresent([UUID].self, forKey: .awayPlayerIDs) ?? []
        playerNamesByID = try container.decodeIfPresent([UUID: String].self, forKey: .playerNamesByID) ?? [:]
        groupIDs = try container.decodeIfPresent([UUID].self, forKey: .groupIDs) ?? []
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? ""

        // Backward compat: decode legacy single groupID
        if groupIDs.isEmpty, let legacy = try? decoder.container(keyedBy: AnyCodingKey.self)
            .decodeIfPresent(UUID.self, forKey: AnyCodingKey(stringValue: "groupID")) {
            groupIDs = [legacy]
        }
    }
}

struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    init(stringValue: String) { self.stringValue = stringValue; self.intValue = nil }
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
}

extension SavedGame {
    /// Returns a copy with transfer-irrelevant fields stripped (snapshots, local-only metadata)
    func strippedForTransfer() -> SavedGame {
        var copy = self
        copy.undoSnapshots = []
        copy.previousSnapshot = nil
        copy.groupIDs = []
        return copy
    }

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
