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

    @Published var cloudEnabledGameIDs: Set<UUID> = []

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
    private let storageFileName = "appstore_v2.json"
    private var saveTask: Task<Void, Never>?
    private let saveDebounceNanoseconds: UInt64 = 500_000_000
    private var cancellables = Set<AnyCancellable>()

    private var storageFileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent(storageFileName)
    }

    private var photosDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("player_photos", isDirectory: true)
    }

    private func photoFile(for playerID: UUID) -> URL {
        photosDir.appendingPathComponent("\(playerID.uuidString).jpg")
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
        let existingGame = savedGames.first(where: { $0.id == targetID })
        let previousSnapshot = existingGame?.snapshot
        var game = buildSavedGame(id: targetID, snapshot: snapshot, savedAt: Date())
        game.aiSummary = existingGame?.aiSummary
        game.previousSnapshot = previousSnapshot
        game.undoSnapshots = undoSnapshots

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
        guard let gameIndex = savedGames.firstIndex(where: { $0.id == gameID }) else { return }
        guard let groupIndex = gameGroups.firstIndex(where: { $0.id == groupID }) else { return }

        if savedGames[gameIndex].groupIDs.contains(groupID) {
            savedGames[gameIndex].groupIDs.removeAll { $0 == groupID }
            gameGroups[groupIndex].gameIDs.removeAll { $0 == gameID }
        } else {
            savedGames[gameIndex].groupIDs.append(groupID)
            if !gameGroups[groupIndex].gameIDs.contains(gameID) {
                gameGroups[groupIndex].gameIDs.append(gameID)
            }
        }
    }

    func gamesInGroup(_ groupID: UUID) -> [SavedGame] {
        savedGames.filter { $0.groupIDs.contains(groupID) }
    }

    func groups(for gameID: UUID) -> [GameGroup] {
        guard let game = savedGames.first(where: { $0.id == gameID }) else { return [] }
        return gameGroups.filter { game.groupIDs.contains($0.id) }
    }

    func syncGameGroupMembership(groupID: UUID, gameIDs: [UUID]) {
        guard let groupIndex = gameGroups.firstIndex(where: { $0.id == groupID }) else { return }
        let oldGameIDs = Set(gameGroups[groupIndex].gameIDs)
        let newGameIDs = Set(gameIDs)
        let added = newGameIDs.subtracting(oldGameIDs)
        let removed = oldGameIDs.subtracting(newGameIDs)

        gameGroups[groupIndex].gameIDs = gameIDs

        for gameID in removed {
            if let gameIndex = savedGames.firstIndex(where: { $0.id == gameID }) {
                savedGames[gameIndex].groupIDs.removeAll { $0 == groupID }
            }
        }
        for gameID in added {
            if let gameIndex = savedGames.firstIndex(where: { $0.id == gameID }) {
                if !savedGames[gameIndex].groupIDs.contains(groupID) {
                    savedGames[gameIndex].groupIDs.append(groupID)
                }
            }
        }
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

    private func save() {
        // Strip photoData to keep the main payload small
        var strippedPlayers = players
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        for i in strippedPlayers.indices {
            if let data = strippedPlayers[i].photoData {
                try? data.write(to: photoFile(for: strippedPlayers[i].id), options: .atomic)
                strippedPlayers[i].photoData = nil
            }
        }

        let payload = StorePayload(
            players: strippedPlayers,
            teams: teams,
            savedGames: savedGames,
            gameGroups: gameGroups,
            hiddenCareerStatItems: hiddenCareerStatItems,
            keepsScreenAwake: keepsScreenAwake,
            showsBluetoothGamesButton: showsBluetoothGamesButton
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? data.write(to: storageFileURL, options: .atomic)
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
        // Try file first, fall back to UserDefaults (legacy migration)
        var data = try? Data(contentsOf: storageFileURL)
        var migratedFromUserDefaults = false
        if data == nil {
            data = UserDefaults.standard.data(forKey: storageKey)
            if data != nil {
                migratedFromUserDefaults = true
            }
        }

        guard let storeData = data else {
            seedSampleData()
            return
        }

        guard let payload = try? JSONDecoder().decode(StorePayload.self, from: storeData) else {
            // If UserDefaults data fails to decode, don't clear it - let the user recover
            if migratedFromUserDefaults {
                // Keep old UserDefaults data, try again next launch
                players = []
                teams = []
                savedGames = []
                return
            }
            players = []
            teams = []
            savedGames = []
            return
        }

        // Migrate: write to file and clear UserDefaults only after successful decode
        if migratedFromUserDefaults {
            try? storeData.write(to: storageFileURL, options: .atomic)
            UserDefaults.standard.removeObject(forKey: storageKey)
        }

        // Restore photos from separate files
        var restoredPlayers = payload.players
        for i in restoredPlayers.indices {
            let fileURL = photoFile(for: restoredPlayers[i].id)
            if let photoData = try? Data(contentsOf: fileURL), !photoData.isEmpty {
                restoredPlayers[i].photoData = photoData
            }
        }

        players = restoredPlayers
        teams = payload.teams
        savedGames = payload.savedGames
        gameGroups = payload.gameGroups
        hiddenCareerStatItems = payload.hiddenCareerStatItems
        keepsScreenAwake = payload.keepsScreenAwake
        showsBluetoothGamesButton = payload.showsBluetoothGamesButton
    }

    private func seedSampleData() {
        let samplePlayers = [
            Player(name: NSLocalizedString("sample_player_1", comment: "Sample player 1"), height: "180", weight: "76", number: "7"),
            Player(name: NSLocalizedString("sample_player_2", comment: "Sample player 2"), height: "186", weight: "82", number: "11"),
            Player(name: NSLocalizedString("sample_player_3", comment: "Sample player 3"), height: "178", weight: "72", number: "23"),
            Player(name: NSLocalizedString("sample_player_4", comment: "Sample player 4"), height: "192", weight: "88", number: "33")
        ]
        players = samplePlayers
        teams = [
            Team(name: NSLocalizedString("team_home_default", comment: "Home team"), playerIDs: Array(samplePlayers.prefix(2).map(\.id))),
            Team(name: NSLocalizedString("team_away_default", comment: "Away team"), playerIDs: Array(samplePlayers.suffix(2).map(\.id)))
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
        let playerNames = Dictionary(uniqueKeysWithValues: gamePlayerIDs.compactMap { playerID in
            player(for: playerID).map { (playerID, $0.name) }
        })

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
