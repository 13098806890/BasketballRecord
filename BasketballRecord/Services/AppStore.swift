import SwiftUI
import Combine

/**
 AppStore - Central data manager for Basketball Record app
 
 ## Game Group Policy (groupID)
 
 The `SavedGame.groupID` field is LOCAL to each device and should NEVER be synced across devices.
 
 ### Rules:
 - **Export**: ExportGameRecord strips groupID - games exported never carry group info
 - **Bluetooth Sync (Send)**: sendStoreSync() removes groupID from all games before transmission
 - **Bluetooth Sync (Receive)**: 
     - New incoming games have groupID set to nil
     - Existing games keep their local groupID (don't let incoming data overwrite it)
 - **Import from Code**: remappedGame() sets groupID to nil for all imported games
 - **Local Merges**: remappedGameForPlayerMerge() and remappedGameForTeamMerge() preserve local groupID
 
 This ensures each device manages its own game organization independently.
 */

@MainActor
final class AppStore: ObservableObject {
    struct TeamImportSummary {
        var addedPlayers: Int
        var reusedPlayers: Int
        var addedTeams: Int
        var updatedTeams: Int
    }

    struct PlayerImportSummary {
        var addedPlayers: Int
        var updatedPlayers: Int
    }

    struct PlayerMergeSummary {
        var updatedTeams: Int
        var updatedGames: Int
    }

    struct TeamMergeSummary {
        var mergedPlayers: Int
        var updatedGames: Int
    }

    struct PlayerUpsertSummary {
        var inserted: Int
        var updated: Int
    }

    struct TeamUpsertSummary {
        var inserted: Int
        var updated: Int
    }

    struct SavedGameUpsertSummary {
        var inserted: Int
        var updated: Int
    }

    enum GameImportDisposition {
        case inserted
        case replacedSameID(existingGameID: UUID)
        case replacedLikelyDuplicate(existingGameID: UUID)

        var isOverwrite: Bool {
            switch self {
            case .inserted:
                return false
            case .replacedSameID, .replacedLikelyDuplicate:
                return true
            }
        }
    }

    @Published var players: [Player] = [] {
        didSet { scheduleSave() }
    }

    @Published var teams: [Team] = [] {
        didSet { scheduleSave() }
    }

    @Published var savedGames: [SavedGame] = [] {
        didSet { scheduleSave() }
    }

    @Published var gameGroups: [GameGroup] = [] {
        didSet { scheduleSave() }
    }

    @Published var playerGroups: [PlayerGroup] = [] {
        didSet { scheduleSave() }
    }

    @Published var hiddenCareerStatItems: Set<CareerStatItem> = [] {
        didSet { scheduleSave() }
    }

    @Published var keepsScreenAwake = true {
        didSet { scheduleSave() }
    }

    var isPro: Bool {
        PurchaseManager.shared.isPro
    }

    @Published var showsBluetoothGamesButton = false {
        didSet { scheduleSave() }
    }

    @Published var showsVoiceButton = false {
        didSet { scheduleSave() }
    }

    @Published var voiceLogEnabled = true {
        didSet { scheduleSave() }
    }

    @Published var customVoiceMappings: [String: String] = [:] {
        didSet { scheduleSave() }
    }

    @Published var voiceLog: [VoiceLogEntry] = [] {
        didSet { scheduleSave() }
    }

    @Published var cloudEnabledGameIDs: Set<UUID> = []

    func downloadFromCloud(_ game: SavedGame) {
        if !savedGames.contains(where: { $0.id == game.id }) {
            savedGames.append(game)
            savedGames.sort { $0.savedAt > $1.savedAt }
        }
        if !cloudEnabledGameIDs.contains(game.id) {
            cloudEnabledGameIDs.insert(game.id)
        }
        saveCloudEnabledGameIDs()
    }

    func toggleCloudStorage(for gameID: UUID) {
        if cloudEnabledGameIDs.contains(gameID) {
            cloudEnabledGameIDs.remove(gameID)
            Task { await CloudKitManager.shared.deleteGame(gameID) }
        } else {
            cloudEnabledGameIDs.insert(gameID)
            if let game = savedGames.first(where: { $0.id == gameID }) {
                Task { await CloudKitManager.shared.uploadGame(game) }
            }
        }
        saveCloudEnabledGameIDs()
    }

    private func saveCloudEnabledGameIDs() {
        let ids = Array(cloudEnabledGameIDs).map(\.uuidString)
        NSUbiquitousKeyValueStore.default.set(ids, forKey: "cloud_enabled_game_ids")
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    private func loadCloudEnabledGameIDs() {
        if let ids = NSUbiquitousKeyValueStore.default.array(forKey: "cloud_enabled_game_ids") as? [String] {
            cloudEnabledGameIDs = Set(ids.compactMap(UUID.init))
        }
    }

    private let storageKey = "basketball-record-store-v1"
    private var saveTask: Task<Void, Never>?
    private let saveDebounceNanoseconds: UInt64 = 500_000_000
    private var cancellables = Set<AnyCancellable>()
    let coreDataStore = CoreDataStore()
    private var hasMigratedToCoreData = false

    // MARK: - Storage keys
    private let metaKey = "store_meta"
    private let gamesIndexKey = "store_games_index"
    private func gameKey(for id: UUID) -> String { "game_\(id.uuidString)" }

    private var photosDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("player_photos", isDirectory: true)
    }

    private func photoFile(for playerID: UUID) -> URL {
        photosDir.appendingPathComponent("\(playerID.uuidString).jpg")
    }

    private struct StoreMeta: Codable {
        var players: [Player]
        var teams: [Team]
        var gameGroups: [GameGroup]
        var playerGroups: [PlayerGroup]
        var hiddenCareerStatItems: Set<CareerStatItem>
        var keepsScreenAwake: Bool
        var showsBluetoothGamesButton: Bool
        var showsVoiceButton: Bool?
        var customVoiceMappings: [String: String]?
        var voiceLog: [VoiceLogEntry]?
        var voiceLogEnabled: Bool?
    }

    init() {
        load()
        loadCloudEnabledGameIDs()
        NotificationCenter.default.addObserver(self, selector: #selector(cloudStoreDidChange), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default)
        Task { await syncCloudGames() }

        // Forward PurchaseManager.isPro changes so all store observers re-render
        PurchaseManager.shared.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func syncCloudGames() async {
        let newGames = await CloudKitManager.shared.sync(cloudEnabledIDs: cloudEnabledGameIDs, localGames: savedGames)
        guard !newGames.isEmpty else { return }
        savedGames.append(contentsOf: newGames)
        savedGames.sort { $0.savedAt > $1.savedAt }
    }

    @objc private func cloudStoreDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.loadCloudEnabledGameIDs()
        }
    }

    func player(for id: UUID) -> Player? {
        players.first { $0.id == id }
    }

    func team(for id: UUID?) -> Team? {
        guard let id else { return nil }
        return teams.first { $0.id == id }
    }

    func addPlayer(_ player: Player) {
        players.append(player)
    }

    func updatePlayer(_ player: Player) {
        guard let index = players.firstIndex(where: { $0.id == player.id }) else { return }
        players[index] = player
    }

    func deletePlayers(at offsets: IndexSet) {
        let removedIDs = offsets.map { players[$0].id }
        for id in removedIDs {
            try? FileManager.default.removeItem(at: photoFile(for: id))
        }
        players.remove(atOffsets: offsets)
        teams = teams.map { team in
            var copy = team
            copy.playerIDs.removeAll { removedIDs.contains($0) }
            return copy
        }
    }

    func addTeam(_ team: Team) {
        teams.append(team)
    }

    func updateTeam(_ team: Team) {
        guard let index = teams.firstIndex(where: { $0.id == team.id }) else { return }
        teams[index] = team
    }

    @discardableResult
    func upsertPlayers(_ incomingPlayers: [Player]) -> PlayerUpsertSummary {
        guard !incomingPlayers.isEmpty else {
            return PlayerUpsertSummary(inserted: 0, updated: 0)
        }

        var nextPlayers = players
        var inserted = 0
        var updated = 0

        for incoming in incomingPlayers {
            if let existingIndex = nextPlayers.firstIndex(where: { $0.id == incoming.id }) {
                var merged = incoming
                if merged.photoData == nil {
                    merged.photoData = nextPlayers[existingIndex].photoData
                }
                nextPlayers[existingIndex] = merged
                updated += 1
            } else {
                nextPlayers.append(incoming)
                inserted += 1
            }
        }

        players = nextPlayers
        return PlayerUpsertSummary(inserted: inserted, updated: updated)
    }

    @discardableResult
    func upsertTeams(_ incomingTeams: [Team]) -> TeamUpsertSummary {
        guard !incomingTeams.isEmpty else {
            return TeamUpsertSummary(inserted: 0, updated: 0)
        }

        var nextTeams = teams
        var inserted = 0
        var updated = 0

        for incoming in incomingTeams {
            if let existingIndex = nextTeams.firstIndex(where: { $0.id == incoming.id }) {
                nextTeams[existingIndex] = incoming
                updated += 1
            } else {
                nextTeams.append(incoming)
                inserted += 1
            }
        }

        teams = nextTeams
        return TeamUpsertSummary(inserted: inserted, updated: updated)
    }

    @discardableResult
    func upsertSavedGames(_ incomingGames: [SavedGame]) -> SavedGameUpsertSummary {
        guard !incomingGames.isEmpty else {
            return SavedGameUpsertSummary(inserted: 0, updated: 0)
        }

        var nextGames = savedGames
        var inserted = 0
        var updated = 0

        for incoming in incomingGames {
            if let existingIndex = nextGames.firstIndex(where: { $0.id == incoming.id }) {
                // Preserve local groupIDs when upserting - don't overwrite with incoming
                var updatedGame = incoming
                updatedGame.groupIDs = nextGames[existingIndex].groupIDs
                nextGames[existingIndex] = updatedGame
                updated += 1
            } else {
                // New game - strip groupIDs from incoming data to ensure clean sync
                var newGame = incoming
                newGame.groupIDs = []
                nextGames.append(newGame)
                inserted += 1
            }
        }

        nextGames.sort { $0.savedAt > $1.savedAt }
        savedGames = nextGames
        return SavedGameUpsertSummary(inserted: inserted, updated: updated)
    }

    func deleteTeams(at offsets: IndexSet) {
        teams.remove(atOffsets: offsets)
    }

    func saveGame(_ snapshot: GameSnapshot) {
        let game = buildSavedGame(id: UUID(), snapshot: snapshot, savedAt: Date())
        savedGames.insert(game, at: 0)
    }

    @discardableResult
    func autoSaveGame(_ snapshot: GameSnapshot, gameID: UUID?, undoSnapshots: [GameSnapshot] = []) -> UUID {
        let targetID = gameID ?? UUID()
        let ts = snapshot.teamStatsByID
        if !ts.isEmpty || snapshot.homeTeamStatsMode || snapshot.awayTeamStatsMode {
            print("[AutoSave] snapshot teamStats=\(ts.count) pts=\(ts.values.reduce(0){$0+$1.points}) homeMode=\(snapshot.homeTeamStatsMode) awayMode=\(snapshot.awayTeamStatsMode)")
        }
        var game = buildSavedGame(id: targetID, snapshot: snapshot, savedAt: Date())
        let savedTS = game.snapshot.teamStatsByID
        let savedPts = savedTS.values.reduce(0) { $0 + $1.points }
        if savedPts > 0 || game.snapshot.homeTeamStatsMode || game.snapshot.awayTeamStatsMode {
            print("[AutoSave] builtSavedGame teamStats=\(savedTS.count) pts=\(savedPts) homeMode=\(game.snapshot.homeTeamStatsMode) awayMode=\(game.snapshot.awayTeamStatsMode)")
        }
        if let existingGame = savedGames.first(where: { $0.id == targetID }) {
            game.aiSummary = existingGame.aiSummary
        }

        if let existingIndex = savedGames.firstIndex(where: { $0.id == targetID }) {
            savedGames[existingIndex] = game
            if existingIndex != 0 {
                let updated = savedGames.remove(at: existingIndex)
                savedGames.insert(updated, at: 0)
            }
        } else {
            savedGames.insert(game, at: 0)
        }

        return targetID
    }

    func latestUnfinishedGame() -> SavedGame? {
        guard let latest = savedGames.first else { return nil }
        return latest.snapshot.isComplete ? nil : latest
    }

    func isCareerStatVisible(_ item: CareerStatItem) -> Bool {
        !hiddenCareerStatItems.contains(item)
    }

    func setCareerStatVisible(_ item: CareerStatItem, visible: Bool) {
        if visible {
            hiddenCareerStatItems.remove(item)
        } else {
            hiddenCareerStatItems.insert(item)
        }
    }

    func setAllCareerStatVisibility(visible: Bool) {
        hiddenCareerStatItems = visible ? [] : Set(CareerStatItem.allCases)
    }

    func exportGameBase64(_ game: SavedGame) -> String? {
        let playerIDs = Array(Set(game.homePlayerIDs + game.awayPlayerIDs + Array(game.snapshot.statsByPlayerID.keys)))
        let exportedPlayers = playerIDs.map { playerID in
            if let player = player(for: playerID) {
                return ExportPlayer(player: player)
            }
            return ExportPlayer(id: playerID, name: game.playerNamesByID[playerID] ?? NSLocalizedString("player_unknown_default", comment: "Unknown player"))
        }

        let exportedTeams = [
            exportTeam(id: game.snapshot.homeTeamID, fallbackName: game.homeTeamName, playerIDs: game.homePlayerIDs),
            exportTeam(id: game.snapshot.awayTeamID, fallbackName: game.awayTeamName, playerIDs: game.awayPlayerIDs)
        ].compactMap { $0 }

        let legacyPackage = ExportedGamePackage(players: exportedPlayers, teams: exportedTeams, game: ExportGameRecord(savedGame: game))
        return TransferCodec.encode(ExportedGamePackageV2(legacy: legacyPackage))
    }

    func exportTeamBase64(_ team: Team) -> String? {
        let exportedPlayers = team.playerIDs.map { playerID in
            if let player = player(for: playerID) {
                return ExportPlayer(player: player)
            }
            return ExportPlayer(id: playerID, name: NSLocalizedString("player_unknown_default", comment: "Unknown player"))
        }
        let package = ExportedTeamPackage(team: ExportTeam(team: team), players: exportedPlayers)
        return TransferCodec.encode(package)
    }

    func exportPlayerBase64(_ player: Player) -> String? {
        let package = ExportedPlayerPackage(player: ExportPlayer(player: player))
        return TransferCodec.encode(package)
    }

    func decodeGamePackage(from base64: String) -> ExportedGamePackage? {
        guard let decoded = TransferCodec.decode(base64, as: ExportedGamePackageV2.self) else {
            return nil
        }
        return decoded.legacyPackage
    }

    func decodeTeamPackage(from base64: String) -> ExportedTeamPackage? {
        TransferCodec.decode(base64, as: ExportedTeamPackage.self)
    }

    func decodePlayerPackage(from base64: String) -> ExportedPlayerPackage? {
        TransferCodec.decode(base64, as: ExportedPlayerPackage.self)
    }

    @discardableResult
    func importTeamPackage(_ package: ExportedTeamPackage) -> TeamImportSummary {
        var addedPlayers = 0
        var reusedPlayers = 0
        var nextPlayers = players
        var existingPlayerIDs = Set(nextPlayers.map(\.id))

        for exportedPlayer in package.players {
            if existingPlayerIDs.contains(exportedPlayer.id) {
                reusedPlayers += 1
                continue
            }
            nextPlayers.append(exportedPlayer.playerWithoutPhoto)
            existingPlayerIDs.insert(exportedPlayer.id)
            addedPlayers += 1
        }

        for playerID in package.team.playerIDs where !existingPlayerIDs.contains(playerID) {
            nextPlayers.append(Player(id: playerID, name: NSLocalizedString("player_unknown_default", comment: "Unknown player")))
            existingPlayerIDs.insert(playerID)
            addedPlayers += 1
        }
        players = nextPlayers

        var seenPlayerIDs: Set<UUID> = []
        let orderedPlayerIDs = package.team.playerIDs.filter { seenPlayerIDs.insert($0).inserted }
        let importedTeam = Team(id: package.team.id, name: package.team.name, playerIDs: orderedPlayerIDs)

        var addedTeams = 0
        var updatedTeams = 0
        var nextTeams = teams
        if let existingIndex = nextTeams.firstIndex(where: { $0.id == importedTeam.id }) {
            nextTeams[existingIndex] = importedTeam
            updatedTeams = 1
        } else {
            nextTeams.append(importedTeam)
            addedTeams = 1
        }
        teams = nextTeams

        return TeamImportSummary(
            addedPlayers: addedPlayers,
            reusedPlayers: reusedPlayers,
            addedTeams: addedTeams,
            updatedTeams: updatedTeams
        )
    }

    @discardableResult
    func importPlayerPackage(_ package: ExportedPlayerPackage) -> PlayerImportSummary {
        let importedPlayer = package.player.playerWithoutPhoto
        var addedPlayers = 0
        var updatedPlayers = 0

        if let existingIndex = players.firstIndex(where: { $0.id == importedPlayer.id }) {
            players[existingIndex] = importedPlayer
            updatedPlayers = 1
        } else {
            players.append(importedPlayer)
            addedPlayers = 1
        }

        return PlayerImportSummary(addedPlayers: addedPlayers, updatedPlayers: updatedPlayers)
    }

    @discardableResult
    func importGamePackage(
        _ package: ExportedGamePackage,
        playerMapping: [UUID: UUID] = [:],
        teamMapping: [UUID: UUID] = [:],
        importsUnmatchedRoster: Bool = true
    ) -> GameImportDisposition {
        var playerIDMap = playerMapping
        var teamIDMap = teamMapping

        if importsUnmatchedRoster {
            for exportedPlayer in package.players where playerIDMap[exportedPlayer.id] == nil {
                if players.contains(where: { $0.id == exportedPlayer.id }) {
                    playerIDMap[exportedPlayer.id] = exportedPlayer.id
                } else {
                    let newPlayer = exportedPlayer.playerWithoutPhoto
                    players.append(newPlayer)
                    playerIDMap[exportedPlayer.id] = newPlayer.id
                }
            }
        }

        if importsUnmatchedRoster {
            for exportedTeam in package.teams where teamIDMap[exportedTeam.id] == nil {
                if teams.contains(where: { $0.id == exportedTeam.id }) {
                    teamIDMap[exportedTeam.id] = exportedTeam.id
                } else {
                    let mappedPlayerIDs = exportedTeam.playerIDs.compactMap { playerIDMap[$0] ?? $0 }
                    let newTeam = Team(id: exportedTeam.id, name: exportedTeam.name, playerIDs: mappedPlayerIDs)
                    teams.append(newTeam)
                    teamIDMap[exportedTeam.id] = newTeam.id
                }
            }
        }

        let importedGame = remappedGame(package.game.savedGame, playerIDMap: playerIDMap, teamIDMap: teamIDMap)
        return upsertImportedGame(importedGame)
    }

    func previewGameImportDisposition(
        _ package: ExportedGamePackage,
        playerMapping: [UUID: UUID] = [:],
        teamMapping: [UUID: UUID] = [:],
        importsUnmatchedRoster: Bool = true
    ) -> GameImportDisposition {
        let playerIDMap = inferredPlayerIDMap(for: package, providedMapping: playerMapping, importsUnmatchedRoster: importsUnmatchedRoster)
        let teamIDMap = inferredTeamIDMap(for: package, providedMapping: teamMapping, importsUnmatchedRoster: importsUnmatchedRoster)
        let importedGame = remappedGame(package.game.savedGame, playerIDMap: playerIDMap, teamIDMap: teamIDMap)
        return gameImportDisposition(for: importedGame)
    }

    func deleteSavedGames(at offsets: IndexSet) {
        savedGames.remove(atOffsets: offsets)
    }

    func deleteSavedGames(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        for id in ids {
            cloudEnabledGameIDs.remove(id)
        }
        saveCloudEnabledGameIDs()
        savedGames.removeAll { ids.contains($0.id) }
    }

    func updateAISummary(_ summary: String, for gameID: UUID) {
        guard let index = savedGames.firstIndex(where: { $0.id == gameID }) else { return }
        savedGames[index].aiSummary = summary
    }

    // MARK: - Game Group Management

    func addGameGroup(_ name: String, description: String? = nil) -> GameGroup {
        let group = GameGroup(name: name, description: description)
        gameGroups.append(group)
        return group
    }

    func updateGameGroup(_ group: GameGroup) {
        guard let index = gameGroups.firstIndex(where: { $0.id == group.id }) else { return }
        gameGroups[index] = group
    }

    func deleteGameGroup(_ groupID: UUID) {
        gameGroups.removeAll { $0.id == groupID }
    }

    func toggleGameGroup(_ gameID: UUID, groupID: UUID) {
        guard isPro else { return }
        guard let gameIndex = savedGames.firstIndex(where: { $0.id == gameID }) else { return }
        guard let groupIndex = gameGroups.firstIndex(where: { $0.id == groupID }) else { return }

        var savedGamesCopy = savedGames
        var gameGroupsCopy = gameGroups

        if savedGamesCopy[gameIndex].groupIDs.contains(groupID) {
            savedGamesCopy[gameIndex].groupIDs.removeAll { $0 == groupID }
            gameGroupsCopy[groupIndex].gameIDs.removeAll { $0 == gameID }
        } else {
            savedGamesCopy[gameIndex].groupIDs.append(groupID)
            if !gameGroupsCopy[groupIndex].gameIDs.contains(gameID) {
                gameGroupsCopy[groupIndex].gameIDs.append(gameID)
            }
        }

        savedGames = savedGamesCopy
        gameGroups = gameGroupsCopy
    }

    func gamesInGroup(_ groupID: UUID) -> [SavedGame] {
        savedGames.filter { $0.groupIDs.contains(groupID) }
    }

    func groups(for gameID: UUID) -> [GameGroup] {
        guard let game = savedGames.first(where: { $0.id == gameID }) else { return [] }
        return gameGroups.filter { game.groupIDs.contains($0.id) }
    }

    // MARK: - Player Groups

    func addPlayerGroup(_ name: String) -> PlayerGroup {
        let group = PlayerGroup(name: name)
        playerGroups.append(group)
        return group
    }

    func updatePlayerGroup(_ group: PlayerGroup) {
        guard let index = playerGroups.firstIndex(where: { $0.id == group.id }) else { return }
        playerGroups[index] = group
    }

    func deletePlayerGroup(_ groupID: UUID) {
        playerGroups.removeAll { $0.id == groupID }
    }

    func syncPlayerGroupMembership(groupID: UUID, playerIDs: [UUID]) {
        guard let groupIndex = playerGroups.firstIndex(where: { $0.id == groupID }) else { return }
        let oldPlayerIDs = Set(playerGroups[groupIndex].playerIDs)
        let newPlayerIDs = Set(playerIDs)
        let added = newPlayerIDs.subtracting(oldPlayerIDs)
        let removed = oldPlayerIDs.subtracting(newPlayerIDs)

        var playerGroupsCopy = playerGroups
        var playersCopy = players

        playerGroupsCopy[groupIndex].playerIDs = playerIDs

        for playerID in removed {
            if let playerIndex = playersCopy.firstIndex(where: { $0.id == playerID }) {
                playersCopy[playerIndex].playerGroupIDs.removeAll { $0 == groupID }
            }
        }
        for playerID in added {
            if let playerIndex = playersCopy.firstIndex(where: { $0.id == playerID }) {
                if !playersCopy[playerIndex].playerGroupIDs.contains(groupID) {
                    playersCopy[playerIndex].playerGroupIDs.append(groupID)
                }
            }
        }

        playerGroups = playerGroupsCopy
        players = playersCopy
        scheduleSave()
    }

    func syncGameGroupMembership(groupID: UUID, gameIDs: [UUID]) {
        guard let groupIndex = gameGroups.firstIndex(where: { $0.id == groupID }) else { return }
        let oldGameIDs = Set(gameGroups[groupIndex].gameIDs)
        let newGameIDs = Set(gameIDs)
        let added = newGameIDs.subtracting(oldGameIDs)
        let removed = oldGameIDs.subtracting(newGameIDs)

        var gameGroupsCopy = gameGroups
        var savedGamesCopy = savedGames

        gameGroupsCopy[groupIndex].gameIDs = gameIDs

        for gameID in removed {
            if let gameIndex = savedGamesCopy.firstIndex(where: { $0.id == gameID }) {
                savedGamesCopy[gameIndex].groupIDs.removeAll { $0 == groupID }
            }
        }
        for gameID in added {
            if let gameIndex = savedGamesCopy.firstIndex(where: { $0.id == gameID }) {
                if !savedGamesCopy[gameIndex].groupIDs.contains(groupID) {
                    savedGamesCopy[gameIndex].groupIDs.append(gameID)
                }
            }
        }

        gameGroups = gameGroupsCopy
        savedGames = savedGamesCopy
        scheduleSave()
    }

    func mergePlayer(sourceID: UUID, into targetID: UUID) -> PlayerMergeSummary? {
        guard sourceID != targetID else { return nil }
        guard let sourceIndex = players.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = players.firstIndex(where: { $0.id == targetID }) else {
            return nil
        }

        let sourcePlayer = players[sourceIndex]
        var targetPlayer = players[targetIndex]
        if targetPlayer.height.isEmpty { targetPlayer.height = sourcePlayer.height }
        if targetPlayer.weight.isEmpty { targetPlayer.weight = sourcePlayer.weight }
        if targetPlayer.number.isEmpty { targetPlayer.number = sourcePlayer.number }
        if targetPlayer.photoData == nil { targetPlayer.photoData = sourcePlayer.photoData }

        var nextPlayers = players
        nextPlayers[targetIndex] = targetPlayer
        nextPlayers.removeAll { $0.id == sourceID }
        players = nextPlayers

        var updatedTeams = 0
        teams = teams.map { team in
            guard team.playerIDs.contains(sourceID) else { return team }
            var seen: Set<UUID> = []
            let remapped = team.playerIDs.map { $0 == sourceID ? targetID : $0 }
            let deduped = remapped.filter { seen.insert($0).inserted }
            updatedTeams += 1
            return Team(id: team.id, name: team.name, playerIDs: deduped)
        }

        var updatedGames = 0
        savedGames = savedGames.map { game in
            guard gameContainsPlayer(game, sourceID: sourceID) else { return game }
            updatedGames += 1
            return remappedGameForPlayerMerge(game, sourceID: sourceID, targetID: targetID, targetName: targetPlayer.name)
        }

        return PlayerMergeSummary(updatedTeams: updatedTeams, updatedGames: updatedGames)
    }

    @discardableResult
    func mergeTeam(sourceID: UUID, into targetID: UUID) -> TeamMergeSummary? {
        guard sourceID != targetID else { return nil }
        guard let sourceTeam = teams.first(where: { $0.id == sourceID }),
              var targetTeam = teams.first(where: { $0.id == targetID }) else {
            return nil
        }

        var seenPlayerIDs = Set(targetTeam.playerIDs)
        let addedPlayers = sourceTeam.playerIDs.filter { seenPlayerIDs.insert($0).inserted }
        targetTeam.playerIDs.append(contentsOf: addedPlayers)

        teams = teams.compactMap { team in
            if team.id == sourceID { return nil }
            if team.id == targetID {
                return Team(id: team.id, name: team.name, playerIDs: targetTeam.playerIDs)
            }
            return team
        }

        var updatedGames = 0
        savedGames = savedGames.map { game in
            guard gameContainsTeam(game, sourceID: sourceID) else { return game }
            updatedGames += 1
            return remappedGameForTeamMerge(game, sourceID: sourceID, targetID: targetID, targetName: targetTeam.name)
        }

        return TeamMergeSummary(mergedPlayers: addedPlayers.count, updatedGames: updatedGames)
    }

    private func safeWrite<T: Encodable>(_ value: T, forKey key: String) {
        var valueToEncode = value
        // If it's a game with excessive undo snapshots, trim them first
        if key.hasPrefix("game_"), var game = value as? SavedGame {
            let trimmedUndo = game.undoSnapshots.count > 30
            let trimmedPrev = game.previousSnapshot != nil
            if trimmedUndo { game.undoSnapshots = Array(game.undoSnapshots.suffix(30)) }
            if trimmedPrev { game.previousSnapshot = nil }
            if trimmedUndo || trimmedPrev { valueToEncode = game as! T }
        }
        guard let data = try? JSONEncoder().encode(valueToEncode) else {
            print("[Storage] Failed to encode \(key)")
            return
        }
        print("[Storage] Writing \(key): \(data.count) bytes")

        if data.count >= 3_000_000 {
            let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("\(key).json")
            try? data.write(to: fileURL, options: .atomic)
            print("[Storage] Wrote \(key) to file instead of UserDefaults")
            return
        }
        UserDefaults.standard.set(data, forKey: key)
        print("[Storage] Wrote \(key) to UserDefaults OK")
    }

    private func safeRead<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        if let data = UserDefaults.standard.data(forKey: key) {
            if let value = try? JSONDecoder().decode(type, from: data) {
                return value
            }
        }
        // Fallback: try file
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("\(key).json")
        if let data = try? Data(contentsOf: fileURL),
           let value = try? JSONDecoder().decode(type, from: data) {
            // Trim oversized game on load
            if key.hasPrefix("game_"), var game = value as? SavedGame {
                if game.undoSnapshots.count > 30 {
                    print("[Storage] Trimming undo stack on load: \(game.undoSnapshots.count) -> 30")
                    game.undoSnapshots = Array(game.undoSnapshots.suffix(30))
                }
                game.previousSnapshot = nil
                return game as? T
            }
            return value
        }
        return nil
    }

    func saveIfNeeded() {
        saveTask?.cancel()
        save()
    }

    private func save() {
        // Strip photoData and save as separate files
        var strippedPlayers = players
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        for i in strippedPlayers.indices {
            if let data = strippedPlayers[i].photoData {
                print("[Storage] Photo for \(strippedPlayers[i].name): \(data.count) bytes")
                try? data.write(to: photoFile(for: strippedPlayers[i].id), options: .atomic)
                strippedPlayers[i].photoData = nil
            }
        }

        // Save meta (players, teams, settings)
        let meta = StoreMeta(
            players: strippedPlayers,
            teams: teams,
            gameGroups: gameGroups,
            playerGroups: playerGroups,
            hiddenCareerStatItems: hiddenCareerStatItems,
            keepsScreenAwake: keepsScreenAwake,
            showsBluetoothGamesButton: showsBluetoothGamesButton,
            showsVoiceButton: showsVoiceButton,
            customVoiceMappings: customVoiceMappings,
            voiceLog: voiceLog,
            voiceLogEnabled: voiceLogEnabled
        )
        safeWrite(meta, forKey: metaKey)

        // Save each game individually (legacy UserDefaults)
        let gameIDs = savedGames.map(\.id)
        safeWrite(gameIDs, forKey: gamesIndexKey)
        for game in savedGames {
            let ts = game.snapshot.teamStatsByID
            let teamPts = ts.values.reduce(0) { $0 + $1.points }
            if teamPts > 0 || game.snapshot.homeTeamStatsMode || game.snapshot.awayTeamStatsMode {
                print("[Storage] Saving game \(game.id): teamStats=\(ts.count) keys=\(Array(ts.keys)) pts=\(teamPts) homeMode=\(game.snapshot.homeTeamStatsMode) awayMode=\(game.snapshot.awayTeamStatsMode)")
                // Verify encoding includes the new fields
                if let data = try? JSONEncoder().encode(game.snapshot),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("[Storage] Encoded keys: \(Array(json.keys))")
                    print("[Storage] Has homeTeamStatsMode=\(json["homeTeamStatsMode"] != nil) awayTeamStatsMode=\(json["awayTeamStatsMode"] != nil) teamStatsByID=\(json["teamStatsByID"] != nil)")
                }
            }
            safeWrite(game, forKey: gameKey(for: game.id))
        }

        // Core Data persistence — delete stale records first to avoid zombie data
        coreDataStore.savePlayers(players)
        coreDataStore.saveTeams(teams)
        coreDataStore.saveGameGroups(gameGroups)
        coreDataStore.savePlayerGroups(playerGroups)
        coreDataStore.deleteAllSavedGames()
        for game in savedGames {
            coreDataStore.upsertSavedGame(game)
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: saveDebounceNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private func load() {
        // Try loading from Core Data first
        if coreDataStore.hasData() {
            players = coreDataStore.fetchAllPlayers()
            teams = coreDataStore.fetchAllTeams()
            gameGroups = coreDataStore.fetchAllGameGroups()
            playerGroups = coreDataStore.fetchAllPlayerGroups()
            savedGames = coreDataStore.fetchAllSavedGames()
            // Restore photo data from files
            for i in players.indices {
                let fileURL = photoFile(for: players[i].id)
                if let photoData = try? Data(contentsOf: fileURL), !photoData.isEmpty {
                    players[i].photoData = photoData
                }
            }
            hasMigratedToCoreData = true
            for game in savedGames {
                let ts = game.snapshot.teamStatsByID
                let teamPts = ts.values.reduce(0) { $0 + $1.points }
                if teamPts > 0 || game.snapshot.homeTeamStatsMode || game.snapshot.awayTeamStatsMode || true {
                    print("[LoadCheck] Game \(game.id): teamStats=\(ts.count) pts=\(teamPts) homeMode=\(game.snapshot.homeTeamStatsMode) awayMode=\(game.snapshot.awayTeamStatsMode)")
                }
            }

            // Voice metadata is stored only in UserDefaults, not Core Data
            if let meta: StoreMeta = safeRead(StoreMeta.self, forKey: metaKey) {
                if let cm = meta.customVoiceMappings { customVoiceMappings = cm }
                if let vl = meta.voiceLog { voiceLog = vl }
                showsVoiceButton = meta.showsVoiceButton ?? false
                voiceLogEnabled = meta.voiceLogEnabled ?? true
            }
            return
        }

        // Try loading from the old monolithic format first (migration)
        if UserDefaults.standard.data(forKey: metaKey) == nil, migrateFromLegacyStorage() {
            // Safe to clean up old storage only after migration fully succeeded
            UserDefaults.standard.removeObject(forKey: storageKey)
            let oldFile = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("appstore_v2.json")
            try? FileManager.default.removeItem(at: oldFile)
            migrateToCoreData()
            return
        }

        // Load meta (players, teams, settings)
        if let meta: StoreMeta = safeRead(StoreMeta.self, forKey: metaKey) {

            var restoredPlayers = meta.players
            for i in restoredPlayers.indices {
                let fileURL = photoFile(for: restoredPlayers[i].id)
                if let photoData = try? Data(contentsOf: fileURL), !photoData.isEmpty {
                    restoredPlayers[i].photoData = photoData
                }
            }

            players = restoredPlayers
            teams = meta.teams
            gameGroups = meta.gameGroups
            playerGroups = meta.playerGroups
            hiddenCareerStatItems = meta.hiddenCareerStatItems
            keepsScreenAwake = meta.keepsScreenAwake
            showsBluetoothGamesButton = meta.showsBluetoothGamesButton
            showsVoiceButton = meta.showsVoiceButton ?? true
            voiceLogEnabled = meta.voiceLogEnabled ?? true
            if let cm = meta.customVoiceMappings { customVoiceMappings = cm }
            if let vl = meta.voiceLog { voiceLog = vl }
        } else if UserDefaults.standard.data(forKey: storageKey) == nil {
            // Only seed sample data if no old storage exists (corrupt or not)
            seedSampleData()
        }

        // Load games individually
        if let gameIDs: [UUID] = safeRead([UUID].self, forKey: gamesIndexKey) {
            var loaded: [SavedGame] = []
            for id in gameIDs {
                if let game: SavedGame = safeRead(SavedGame.self, forKey: gameKey(for: id)) {
                    // Strip any leftover undo snapshots from old storage
                    var clean = game
                    clean.undoSnapshots = []
                    clean.previousSnapshot = nil
                    loaded.append(clean)
                }
            }
            savedGames = loaded
        }

        // Migrate loaded data to Core Data
        migrateToCoreData()
    }

    private func migrateToCoreData() {
        guard !hasMigratedToCoreData else { return }
        hasMigratedToCoreData = true
        save()
    }

    /// Migrate from old monolithic UserDefaults or file storage to split keys
    private func migrateFromLegacyStorage() -> Bool {
        // Check for old file-based storage first
        let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("appstore_v2.json")
        var data = try? Data(contentsOf: fileURL)
        var source = "file"
        if data == nil {
            data = UserDefaults.standard.data(forKey: storageKey)
            source = "userdefaults"
        }
        guard let storeData = data else {
            print("[Migration] No legacy data found")
            return false
        }

        print("[Migration] Found \(source) data: \(storeData.count) bytes")
        guard let payload = try? JSONDecoder().decode(StorePayload.self, from: storeData) else {
            print("[Migration] Failed to decode legacy data (may be corrupted)")
            // Keep old data around for debugging, but don't use it
            return false
        }
        print("[Migration] Decoded \(payload.savedGames.count) games, \(payload.players.count) players")

        // Migrate to new split format
        var restoredPlayers = payload.players
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        for i in restoredPlayers.indices {
            if let photoData = restoredPlayers[i].photoData {
                try? photoData.write(to: photoFile(for: restoredPlayers[i].id), options: .atomic)
                restoredPlayers[i].photoData = nil
            }
        }

        let meta = StoreMeta(
            players: restoredPlayers,
            teams: payload.teams,
            gameGroups: payload.gameGroups,
            playerGroups: [],
            hiddenCareerStatItems: payload.hiddenCareerStatItems,
            keepsScreenAwake: payload.keepsScreenAwake,
            showsBluetoothGamesButton: payload.showsBluetoothGamesButton
        )
        if let data = try? JSONEncoder().encode(meta) {
            UserDefaults.standard.set(data, forKey: metaKey)
        }

        let gameIDs = payload.savedGames.map(\.id)
        if let data = try? JSONEncoder().encode(gameIDs) {
            UserDefaults.standard.set(data, forKey: gamesIndexKey)
        }
        for game in payload.savedGames {
            if let data = try? JSONEncoder().encode(game) {
                UserDefaults.standard.set(data, forKey: gameKey(for: game.id))
            }
        }

        print("[Migration] Migration complete: \(payload.savedGames.count) games, \(payload.players.count) players")

        // Set loaded data
        players = restoredPlayers
        teams = payload.teams
        savedGames = payload.savedGames
        gameGroups = payload.gameGroups
        hiddenCareerStatItems = payload.hiddenCareerStatItems
        keepsScreenAwake = payload.keepsScreenAwake
        showsBluetoothGamesButton = payload.showsBluetoothGamesButton

        // Clean up old storage
        if source == "file" {
            try? FileManager.default.removeItem(at: fileURL)
        }
        UserDefaults.standard.removeObject(forKey: storageKey)

        return true
    }

    private func seedSampleData() {
        func loadPhoto(_ name: String) -> Data? {
            guard let url = Bundle.main.url(forResource: name, withExtension: "png") else { return nil }
            return try? Data(contentsOf: url)
        }

        let samplePlayers = [
            Player(name: NSLocalizedString("demo_player_haruko", comment: "Haruko Akagi"), height: "163", weight: "52", number: "10", photoData: loadPhoto("赤木晴子")),
            Player(name: NSLocalizedString("demo_player_sakuragi", comment: "Hanamichi Sakuragi"), height: "189", weight: "83", number: "11", photoData: loadPhoto("樱木花道")),
            Player(name: NSLocalizedString("demo_player_rukawa", comment: "Kaede Rukawa"), height: "187", weight: "75", number: "14", photoData: loadPhoto("流川枫")),
            Player(name: NSLocalizedString("demo_player_sendoh", comment: "Sendoh"), height: "190", weight: "79", number: "7", photoData: loadPhoto("仙道")),
            Player(name: NSLocalizedString("demo_player_ayako", comment: "Ayako"), height: "168", weight: "55", number: "5", photoData: loadPhoto("彩子")),
            Player(name: NSLocalizedString("demo_player_maki", comment: "Shinichi Maki"), height: "184", weight: "78", number: "4", photoData: loadPhoto("牧绅一")),
        ]
        players = samplePlayers
        teams = [
            Team(name: NSLocalizedString("demo_team_shohoku", comment: "Shohoku"), playerIDs: Array(samplePlayers[0...2].map(\.id))),
            Team(name: NSLocalizedString("demo_team_ryonan", comment: "Ryonan"), playerIDs: Array(samplePlayers[3...5].map(\.id)))
        ]
    }

    private func exportTeam(id: UUID?, fallbackName: String, playerIDs: [UUID]) -> ExportTeam? {
        guard let id else { return nil }
        if let team = team(for: id) {
            return ExportTeam(team: team)
        }
        return ExportTeam(id: id, name: fallbackName, playerIDs: playerIDs)
    }

    private func buildSavedGame(id: UUID, snapshot: GameSnapshot, savedAt: Date) -> SavedGame {
        let homeTeam = team(for: snapshot.homeTeamID)
        let awayTeam = team(for: snapshot.awayTeamID)
        let homeRosterIDs = dedupedPlayerIDs(primary: snapshot.homeAvailablePlayerIDs, fallback: homeTeam?.playerIDs ?? snapshot.homeOnCourtPlayerIDs)
        let awayRosterIDs = dedupedPlayerIDs(primary: snapshot.awayAvailablePlayerIDs, fallback: awayTeam?.playerIDs ?? snapshot.awayOnCourtPlayerIDs)
        let homePlayerIDs = homeRosterIDs
        let awayPlayerIDs = awayRosterIDs

        let gamePlayerIDs = Array(Set(
            homePlayerIDs
                + awayPlayerIDs
                + snapshot.starterPlayerIDs
                + Array(snapshot.statsByPlayerID.keys)
                + Array(snapshot.playingSecondsByPlayerID.keys)
                + Array(snapshot.plusMinusByPlayerID.keys)
        ))
        var playerNames: [UUID: String] = [:]
        for playerID in gamePlayerIDs {
            if let p = player(for: playerID), playerNames[playerID] == nil {
                playerNames[playerID] = p.name
            }
        }

        return SavedGame(
            id: id,
            savedAt: savedAt,
            snapshot: snapshot,
            homeTeamName: homeTeam?.name ?? NSLocalizedString("team_home_default", comment: "Home team"),
            awayTeamName: awayTeam?.name ?? NSLocalizedString("team_away_default", comment: "Away team"),
            homePlayerIDs: homePlayerIDs,
            awayPlayerIDs: awayPlayerIDs,
            playerNamesByID: playerNames
        )
    }

    private func dedupedPlayerIDs(primary: [UUID], fallback: [UUID]) -> [UUID] {
        let source = primary.isEmpty ? fallback : primary
        var seen: Set<UUID> = []
        return source.filter { seen.insert($0).inserted }
    }

    private func remappedGame(_ game: SavedGame, playerIDMap: [UUID: UUID], teamIDMap: [UUID: UUID]) -> SavedGame {
        let snapshot = remappedSnapshot(game.snapshot, playerIDMap: playerIDMap, teamIDMap: teamIDMap)
        let homePlayerIDs = dedupedIDs(game.homePlayerIDs.map { playerIDMap[$0] ?? $0 })
        let awayPlayerIDs = dedupedIDs(game.awayPlayerIDs.map { playerIDMap[$0] ?? $0 })
        var playerNames: [UUID: String] = [:]
        for (oldID, name) in game.playerNamesByID {
            playerNames[playerIDMap[oldID] ?? oldID] = name
        }

        return SavedGame(
            id: game.id,
            savedAt: game.savedAt,
            snapshot: snapshot,
            aiSummary: game.aiSummary,
            previousSnapshot: game.previousSnapshot.map { remappedSnapshot($0, playerIDMap: playerIDMap, teamIDMap: teamIDMap) },
            undoSnapshots: game.undoSnapshots.map { remappedSnapshot($0, playerIDMap: playerIDMap, teamIDMap: teamIDMap) },
            homeTeamName: team(for: snapshot.homeTeamID)?.name ?? game.homeTeamName,
            awayTeamName: team(for: snapshot.awayTeamID)?.name ?? game.awayTeamName,
            homePlayerIDs: homePlayerIDs,
            awayPlayerIDs: awayPlayerIDs,
            playerNamesByID: playerNames,
            groupIDs: []  // Always strip groupIDs on import - it's local to each device
        )
    }

    private func remappedSnapshot(_ snapshot: GameSnapshot, playerIDMap: [UUID: UUID], teamIDMap: [UUID: UUID]) -> GameSnapshot {
        var remapped = snapshot
        remapped.homeTeamID = snapshot.homeTeamID.flatMap { teamIDMap[$0] ?? $0 }
        remapped.awayTeamID = snapshot.awayTeamID.flatMap { teamIDMap[$0] ?? $0 }
        remapped.logs = snapshot.logs.map { entry in
            var mapped = entry
            if let playerID = entry.playerID {
                mapped.playerID = playerIDMap[playerID] ?? playerID
            }
            return mapped
        }
        remapped.statsByPlayerID = remapDictionary(snapshot.statsByPlayerID, using: playerIDMap)
        remapped.homeOnCourtPlayerIDs = dedupedIDs(snapshot.homeOnCourtPlayerIDs.map { playerIDMap[$0] ?? $0 })
        remapped.awayOnCourtPlayerIDs = dedupedIDs(snapshot.awayOnCourtPlayerIDs.map { playerIDMap[$0] ?? $0 })
        remapped.homeAvailablePlayerIDs = dedupedIDs(snapshot.homeAvailablePlayerIDs.map { playerIDMap[$0] ?? $0 })
        remapped.awayAvailablePlayerIDs = dedupedIDs(snapshot.awayAvailablePlayerIDs.map { playerIDMap[$0] ?? $0 })
        remapped.starterPlayerIDs = dedupedIDs(snapshot.starterPlayerIDs.map { playerIDMap[$0] ?? $0 })
        remapped.playingSecondsByPlayerID = remapDictionary(snapshot.playingSecondsByPlayerID, using: playerIDMap)
        remapped.activeSinceByPlayerID = remapDictionary(snapshot.activeSinceByPlayerID, using: playerIDMap)
        remapped.plusMinusByPlayerID = remapDictionary(snapshot.plusMinusByPlayerID, using: playerIDMap)
        return remapped
    }

    private func remapDictionary<Value>(_ dictionary: [UUID: Value], using map: [UUID: UUID]) -> [UUID: Value] {
        var result: [UUID: Value] = [:]
        for (oldID, value) in dictionary {
            result[map[oldID] ?? oldID] = value
        }
        return result
    }

    private func gameContainsPlayer(_ game: SavedGame, sourceID: UUID) -> Bool {
        game.homePlayerIDs.contains(sourceID)
            || game.awayPlayerIDs.contains(sourceID)
            || game.snapshot.statsByPlayerID[sourceID] != nil
            || game.snapshot.playingSecondsByPlayerID[sourceID] != nil
            || game.snapshot.activeSinceByPlayerID[sourceID] != nil
            || game.snapshot.plusMinusByPlayerID[sourceID] != nil
            || game.snapshot.homeAvailablePlayerIDs.contains(sourceID)
            || game.snapshot.awayAvailablePlayerIDs.contains(sourceID)
            || game.snapshot.starterPlayerIDs.contains(sourceID)
            || game.snapshot.homeOnCourtPlayerIDs.contains(sourceID)
            || game.snapshot.awayOnCourtPlayerIDs.contains(sourceID)
            || game.snapshot.logs.contains(where: { $0.playerID == sourceID })
            || game.playerNamesByID[sourceID] != nil
    }

    private func remappedGameForPlayerMerge(
        _ game: SavedGame,
        sourceID: UUID,
        targetID: UUID,
        targetName: String
    ) -> SavedGame {
        let snapshot = remappedSnapshotForPlayerMerge(game.snapshot, sourceID: sourceID, targetID: targetID)

        var names = game.playerNamesByID
        names[targetID] = targetName
        names[sourceID] = nil

        return SavedGame(
            id: game.id,
            savedAt: game.savedAt,
            snapshot: snapshot,
            aiSummary: game.aiSummary,
            previousSnapshot: game.previousSnapshot.map { remappedSnapshotForPlayerMerge($0, sourceID: sourceID, targetID: targetID) },
            undoSnapshots: game.undoSnapshots.map { remappedSnapshotForPlayerMerge($0, sourceID: sourceID, targetID: targetID) },
            homeTeamName: game.homeTeamName,
            awayTeamName: game.awayTeamName,
            homePlayerIDs: remapDedupedIDs(game.homePlayerIDs, sourceID: sourceID, targetID: targetID),
            awayPlayerIDs: remapDedupedIDs(game.awayPlayerIDs, sourceID: sourceID, targetID: targetID),
            playerNamesByID: names,
            groupIDs: game.groupIDs  // Preserve groupIDs for local merges
        )
    }

    private func remappedSnapshotForPlayerMerge(_ snapshot: GameSnapshot, sourceID: UUID, targetID: UUID) -> GameSnapshot {
        var remapped = snapshot
        remapped.logs = snapshot.logs.map { entry in
            var mapped = entry
            if mapped.playerID == sourceID {
                mapped.playerID = targetID
            }
            return mapped
        }
        remapped.statsByPlayerID = mergeStatsDictionary(snapshot.statsByPlayerID, sourceID: sourceID, targetID: targetID)
        remapped.playingSecondsByPlayerID = mergeSumDictionary(snapshot.playingSecondsByPlayerID, sourceID: sourceID, targetID: targetID)
        remapped.plusMinusByPlayerID = mergeSumDictionary(snapshot.plusMinusByPlayerID, sourceID: sourceID, targetID: targetID)
        remapped.activeSinceByPlayerID = mergeDateDictionary(snapshot.activeSinceByPlayerID, sourceID: sourceID, targetID: targetID)
        remapped.homeAvailablePlayerIDs = remapDedupedIDs(snapshot.homeAvailablePlayerIDs, sourceID: sourceID, targetID: targetID)
        remapped.awayAvailablePlayerIDs = remapDedupedIDs(snapshot.awayAvailablePlayerIDs, sourceID: sourceID, targetID: targetID)
        remapped.starterPlayerIDs = remapDedupedIDs(snapshot.starterPlayerIDs, sourceID: sourceID, targetID: targetID)
        remapped.homeOnCourtPlayerIDs = remapDedupedIDs(snapshot.homeOnCourtPlayerIDs, sourceID: sourceID, targetID: targetID)
        remapped.awayOnCourtPlayerIDs = remapDedupedIDs(snapshot.awayOnCourtPlayerIDs, sourceID: sourceID, targetID: targetID)
        return remapped
    }

    private func mergeStatsDictionary(
        _ dictionary: [UUID: PlayerStats],
        sourceID: UUID,
        targetID: UUID
    ) -> [UUID: PlayerStats] {
        var result = dictionary
        guard let source = result[sourceID] else { return result }
        let target = result[targetID] ?? PlayerStats()
        result[targetID] = mergedStats(lhs: target, rhs: source)
        result[sourceID] = nil
        return result
    }

    private func mergeSumDictionary<T: AdditiveArithmetic>(
        _ dictionary: [UUID: T],
        sourceID: UUID,
        targetID: UUID
    ) -> [UUID: T] {
        var result = dictionary
        guard let source = result[sourceID] else { return result }
        result[targetID] = (result[targetID] ?? .zero) + source
        result[sourceID] = nil
        return result
    }

    private func mergeDateDictionary(
        _ dictionary: [UUID: Date],
        sourceID: UUID,
        targetID: UUID
    ) -> [UUID: Date] {
        var result = dictionary
        guard let source = result[sourceID] else { return result }
        if let target = result[targetID] {
            result[targetID] = min(target, source)
        } else {
            result[targetID] = source
        }
        result[sourceID] = nil
        return result
    }

    private func remapDedupedIDs(_ ids: [UUID], sourceID: UUID, targetID: UUID) -> [UUID] {
        var seen: Set<UUID> = []
        return ids
            .map { $0 == sourceID ? targetID : $0 }
            .filter { seen.insert($0).inserted }
    }

    private func mergedStats(lhs: PlayerStats, rhs: PlayerStats) -> PlayerStats {
        var total = lhs
        total.twoMade += rhs.twoMade
        total.twoAttempts += rhs.twoAttempts
        total.threeMade += rhs.threeMade
        total.threeAttempts += rhs.threeAttempts
        total.bonusFreeThrowMade += rhs.bonusFreeThrowMade
        total.bonusFreeThrowAttempts += rhs.bonusFreeThrowAttempts
        total.freeThrowMade += rhs.freeThrowMade
        total.freeThrowAttempts += rhs.freeThrowAttempts
        total.rebounds += rhs.rebounds
        total.assists += rhs.assists
        total.fouls += rhs.fouls
        total.blocks += rhs.blocks
        total.steals += rhs.steals
        total.turnovers += rhs.turnovers
        return total
    }

    private func gameContainsTeam(_ game: SavedGame, sourceID: UUID) -> Bool {
        game.snapshot.homeTeamID == sourceID || game.snapshot.awayTeamID == sourceID
    }

    private func remappedGameForTeamMerge(
        _ game: SavedGame,
        sourceID: UUID,
        targetID: UUID,
        targetName: String
    ) -> SavedGame {
        let snapshot = remappedSnapshotForTeamMerge(game.snapshot, sourceID: sourceID, targetID: targetID)
        let homeChanged = game.snapshot.homeTeamID == sourceID
        let awayChanged = game.snapshot.awayTeamID == sourceID

        return SavedGame(
            id: game.id,
            savedAt: game.savedAt,
            snapshot: snapshot,
            aiSummary: game.aiSummary,
            previousSnapshot: game.previousSnapshot.map { remappedSnapshotForTeamMerge($0, sourceID: sourceID, targetID: targetID) },
            undoSnapshots: game.undoSnapshots.map { remappedSnapshotForTeamMerge($0, sourceID: sourceID, targetID: targetID) },
            homeTeamName: homeChanged ? targetName : game.homeTeamName,
            awayTeamName: awayChanged ? targetName : game.awayTeamName,
            homePlayerIDs: game.homePlayerIDs,
            awayPlayerIDs: game.awayPlayerIDs,
            playerNamesByID: game.playerNamesByID,
            groupIDs: game.groupIDs  // Preserve groupIDs for local merges
        )
    }

    private func remappedSnapshotForTeamMerge(_ snapshot: GameSnapshot, sourceID: UUID, targetID: UUID) -> GameSnapshot {
        var remapped = snapshot
        if remapped.homeTeamID == sourceID { remapped.homeTeamID = targetID }
        if remapped.awayTeamID == sourceID { remapped.awayTeamID = targetID }
        return remapped
    }

    private func upsertImportedGame(_ importedGame: SavedGame) -> GameImportDisposition {
        if let existingIndex = savedGames.firstIndex(where: { $0.id == importedGame.id }) {
            let existingID = savedGames[existingIndex].id
            savedGames[existingIndex] = importedGame
            if existingIndex != 0 {
                let updated = savedGames.remove(at: existingIndex)
                savedGames.insert(updated, at: 0)
            }
            return .replacedSameID(existingGameID: existingID)
        }

        if let duplicateIndex = savedGames.firstIndex(where: { isLikelyDuplicateGame($0, importedGame) }) {
            let existingID = savedGames[duplicateIndex].id
            var replacement = importedGame
            replacement.id = existingID
            savedGames[duplicateIndex] = replacement
            if duplicateIndex != 0 {
                let updated = savedGames.remove(at: duplicateIndex)
                savedGames.insert(updated, at: 0)
            }
            return .replacedLikelyDuplicate(existingGameID: existingID)
        }

        savedGames.insert(importedGame, at: 0)
        return .inserted
    }

    private func gameImportDisposition(for importedGame: SavedGame) -> GameImportDisposition {
        if let existing = savedGames.first(where: { $0.id == importedGame.id }) {
            return .replacedSameID(existingGameID: existing.id)
        }

        if let duplicate = savedGames.first(where: { isLikelyDuplicateGame($0, importedGame) }) {
            return .replacedLikelyDuplicate(existingGameID: duplicate.id)
        }

        return .inserted
    }

    private func inferredPlayerIDMap(
        for package: ExportedGamePackage,
        providedMapping: [UUID: UUID],
        importsUnmatchedRoster: Bool
    ) -> [UUID: UUID] {
        guard importsUnmatchedRoster else { return providedMapping }

        var mapping = providedMapping
        for exportedPlayer in package.players where mapping[exportedPlayer.id] == nil {
            mapping[exportedPlayer.id] = exportedPlayer.id
        }
        return mapping
    }

    private func inferredTeamIDMap(
        for package: ExportedGamePackage,
        providedMapping: [UUID: UUID],
        importsUnmatchedRoster: Bool
    ) -> [UUID: UUID] {
        guard importsUnmatchedRoster else { return providedMapping }

        var mapping = providedMapping
        for exportedTeam in package.teams where mapping[exportedTeam.id] == nil {
            mapping[exportedTeam.id] = exportedTeam.id
        }
        return mapping
    }

    private func isLikelyDuplicateGame(_ lhs: SavedGame, _ rhs: SavedGame) -> Bool {
        lhs.savedAt == rhs.savedAt
            && lhs.homeTeamName == rhs.homeTeamName
            && lhs.awayTeamName == rhs.awayTeamName
            && lhs.snapshot == rhs.snapshot
    }

    private func dedupedIDs(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }
}

private struct StorePayload: Codable {
    var players: [Player]
    var teams: [Team]
    var savedGames: [SavedGame]
    var gameGroups: [GameGroup]
    var hiddenCareerStatItems: Set<CareerStatItem>
    var keepsScreenAwake: Bool
    var showsBluetoothGamesButton: Bool

    init(
        players: [Player],
        teams: [Team],
        savedGames: [SavedGame] = [],
        gameGroups: [GameGroup] = [],
        hiddenCareerStatItems: Set<CareerStatItem> = [],
        keepsScreenAwake: Bool = true,
        showsBluetoothGamesButton: Bool = false
    ) {
        self.players = players
        self.teams = teams
        self.savedGames = savedGames
        self.gameGroups = gameGroups
        self.hiddenCareerStatItems = hiddenCareerStatItems
        self.keepsScreenAwake = keepsScreenAwake
        self.showsBluetoothGamesButton = showsBluetoothGamesButton
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = try container.decode([Player].self, forKey: .players)
        teams = try container.decode([Team].self, forKey: .teams)
        savedGames = try container.decodeIfPresent([SavedGame].self, forKey: .savedGames) ?? []
        gameGroups = try container.decodeIfPresent([GameGroup].self, forKey: .gameGroups) ?? []
        hiddenCareerStatItems = try container.decodeIfPresent(Set<CareerStatItem>.self, forKey: .hiddenCareerStatItems) ?? []
        keepsScreenAwake = try container.decodeIfPresent(Bool.self, forKey: .keepsScreenAwake) ?? true
        showsBluetoothGamesButton = try container.decodeIfPresent(Bool.self, forKey: .showsBluetoothGamesButton) ?? false
        // Backward compat: ignore legacy showsSimulationButton
        let legacyContainer = try decoder.container(keyedBy: AnyCodingKey.self)
        _ = try? legacyContainer.decodeIfPresent(Bool.self, forKey: AnyCodingKey(stringValue: "showsSimulationButton"))
    }
}
