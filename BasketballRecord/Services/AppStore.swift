import SwiftUI
import Combine
import CoreData

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
    static let tutorialPlayerIDs: Set<UUID> = [
        UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!,
        UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E50")!,
        UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E51")!,
        UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E52")!,
    ]

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
        didSet { if !suppressSave { dirtyKeys.insert(.players); scheduleSave() } }
    }

    @Published var teams: [Team] = [] {
        didSet { if !suppressSave { dirtyKeys.insert(.teams); scheduleSave() } }
    }

    @Published var savedGames: [SavedGame] = [] {
        didSet { if !suppressSave { dirtyKeys.insert(.savedGames); scheduleSave() } }
    }

    @Published var gameGroups: [GameGroup] = [] {
        didSet { if !suppressSave { dirtyKeys.insert(.gameGroups); scheduleSave() } }
    }

    @Published var playerGroups: [PlayerGroup] = [] {
        didSet { if !suppressSave { dirtyKeys.insert(.playerGroups); scheduleSave() } }
    }

    @Published var hiddenCareerStatItems: Set<CareerStatItem> = [] {
        didSet { if !suppressSave { scheduleSave() } }
    }

    @Published var keepsScreenAwake = true {
        didSet { if !suppressSave { scheduleSave() } }
    }

    var isPro: Bool {
        PurchaseManager.shared.isPro
    }

    @Published var showsBluetoothGamesButton = false {
        didSet { if !suppressSave { scheduleSave() } }
    }

    @Published var showsVoiceButton = true {
        didSet { if !suppressSave { scheduleSave() } }
    }

    @Published var voiceLogEnabled = true {
        didSet { if !suppressSave { scheduleSave() } }
    }

    @Published var customVoiceMappings: [String: String] = [:] {
        didSet { if !suppressSave { scheduleSave() } }
    }

    @Published var voiceLog: [VoiceLogEntry] = [] {
        didSet { if !suppressSave { scheduleSave() } }
    }

    @Published var cloudEnabledGameIDs: Set<UUID> = []
    var deletedCloudGameIDs: Set<UUID> = []

    private static let deletedCloudGameIDsKey = "deleted_cloud_game_ids"

    func downloadFromCloud(_ game: SavedGame) {
        if !savedGames.contains(where: { $0.id == game.id }) {
            savedGames.append(game)
            savedGames.sort { $0.savedAt > $1.savedAt }
        }
        if !cloudEnabledGameIDs.contains(game.id) {
            cloudEnabledGameIDs.insert(game.id)
        }
        deletedCloudGameIDs.remove(game.id)
        saveDeletedCloudGameIDs()
        saveCloudEnabledGameIDs()
    }

    func toggleCloudStorage(for gameID: UUID) {
        if cloudEnabledGameIDs.contains(gameID) {
            cloudEnabledGameIDs.remove(gameID)
            Task { await CloudKitManager.shared.deleteGame(gameID) }
        } else {
            cloudEnabledGameIDs.insert(gameID)
            deletedCloudGameIDs.remove(gameID)
            saveDeletedCloudGameIDs()
            if let game = savedGames.first(where: { $0.id == gameID }) {
                Task { await CloudKitManager.shared.uploadGame(game) }
            }
        }
        saveCloudEnabledGameIDs()
    }

    private func saveCloudEnabledGameIDs() {
        let ids = Array(cloudEnabledGameIDs).map(\.uuidString)
        UserDefaults.standard.set(ids, forKey: "cloud_enabled_game_ids")
        NSUbiquitousKeyValueStore.default.set(ids, forKey: "cloud_enabled_game_ids")
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    private func loadCloudEnabledGameIDs() {
        let ids = (NSUbiquitousKeyValueStore.default.array(forKey: "cloud_enabled_game_ids") as? [String])
            ?? (UserDefaults.standard.array(forKey: "cloud_enabled_game_ids") as? [String])
        if let ids {
            cloudEnabledGameIDs = Set(ids.compactMap(UUID.init))
        }
        if let data = UserDefaults.standard.data(forKey: Self.deletedCloudGameIDsKey),
           let ids = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            deletedCloudGameIDs = ids
        }
    }

    func saveDeletedCloudGameIDs() {
        if let data = try? JSONEncoder().encode(deletedCloudGameIDs) {
            UserDefaults.standard.set(data, forKey: Self.deletedCloudGameIDsKey)
        }
    }

    private let storageKey = "basketball-record-store-v1"
    private var saveTask: Task<Void, Never>?
    private var saveGeneration = 0
    private let saveDebounceNanoseconds: UInt64 = 500_000_000
    private var cancellables = Set<AnyCancellable>()
    let coreDataStore = CoreDataStore()
    private var hasMigratedToCoreData = false
    private var suppressSave = false
    private var lastSavedGameData: [UUID: Data] = [:]

    private enum DirtyKey: Hashable {
        case players, teams, gameGroups, playerGroups, savedGames
    }
    private var dirtyKeys: Set<DirtyKey> = []

    // MARK: - Storage keys
    private let metaKey = "store_meta"
    private let gamesIndexKey = "store_games_index"
    private func gameKey(for id: UUID) -> String { "game_\(id.uuidString)" }
    private var recoveryDiagnosticsNoWrite: Bool {
        ProcessInfo.processInfo.arguments.contains("-recoveryDiagnosticsNoWrite")
    }

    private var documentsDir: URL {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Documents directory not available")
        }
        return url
    }

    var photosDir: URL {
        documentsDir.appendingPathComponent("player_photos", isDirectory: true)
    }

    func photoFile(for playerID: UUID) -> URL {
        photosDir.appendingPathComponent("\(playerID.uuidString).jpg")
    }

    var teamIconsDir: URL {
        documentsDir.appendingPathComponent("team_icons", isDirectory: true)
    }

    func teamIconFile(for teamID: UUID) -> URL {
        teamIconsDir.appendingPathComponent("\(teamID.uuidString).jpg")
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

    private struct LegacyPayloadProbe: Decodable {
        var players: [Player]
        var teams: [Team]
        var savedGames: [SavedGame]

        private enum CodingKeys: String, CodingKey {
            case players
            case teams
            case savedGames
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            players = try container.decodeIfPresent([Player].self, forKey: .players) ?? []
            teams = try container.decodeIfPresent([Team].self, forKey: .teams) ?? []
            savedGames = try container.decodeIfPresent([SavedGame].self, forKey: .savedGames) ?? []
        }
    }

    init() {
        if recoveryDiagnosticsNoWrite {
            print("[RecoveryCheck] SAFETY no-write mode enabled; migration and screenshot seed writes will be skipped")
        }
        logRecoveryState(phase: "before-load")
        load()
#if DEBUG
        let hasRecoveryArgument = ProcessInfo.processInfo.arguments.contains("-recoverRosterFromGames")
        let hasSuspiciouslySmallRoster = !savedGames.isEmpty && (players.count <= 1 || teams.count <= 1)
        if hasRecoveryArgument || hasSuspiciouslySmallRoster {
            print("[RecoveryCheck] game-roster-recovery trigger=\(hasRecoveryArgument ? "launch-argument" : "small-roster")")
            recoverRosterFromSavedGames()
        }
#endif
        logRecoveryState(phase: "after-load")
        loadCloudEnabledGameIDs()
        NotificationCenter.default.addObserver(self, selector: #selector(cloudStoreDidChange), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default)
        Task { await syncCloudGames() }

        // Forward PurchaseManager.isPro changes so all store observers re-render
        PurchaseManager.shared.$isPro
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

#if DEBUG
    func recoverRosterFromSavedGames() {
        guard !savedGames.isEmpty else {
            print("[RecoveryCheck] game-roster-recovery skipped; savedGames=0")
            return
        }

        let existingPlayerIDs = Set(players.map(\.id))
        let existingTeamIDs = Set(teams.map(\.id))
        let knownTeamIDs = Set(savedGames.flatMap { [$0.snapshot.homeTeamID, $0.snapshot.awayTeamID].compactMap { $0 } })
        var playerNamesByID: [UUID: String] = [:]
        var recoveredPlayerIDs: [UUID] = []

        func appendUnique(_ id: UUID, to ids: inout [UUID]) {
            guard !ids.contains(id) else { return }
            ids.append(id)
        }

        for game in savedGames {
            for (id, name) in game.playerNamesByID where !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                playerNamesByID[id] = name
            }
            for id in game.homePlayerIDs + game.awayPlayerIDs {
                appendUnique(id, to: &recoveredPlayerIDs)
            }
            for id in game.snapshot.statsByPlayerID.keys where !knownTeamIDs.contains(id) {
                appendUnique(id, to: &recoveredPlayerIDs)
            }
            for event in game.snapshot.logs {
                if let playerID = event.playerID, !knownTeamIDs.contains(playerID) {
                    appendUnique(playerID, to: &recoveredPlayerIDs)
                }
                if let playerID = event.relatedPlayerID, !knownTeamIDs.contains(playerID) {
                    appendUnique(playerID, to: &recoveredPlayerIDs)
                }
            }
        }

        var recoveredPlayers = players
        var addedPlayers = 0
        for id in recoveredPlayerIDs where !existingPlayerIDs.contains(id) {
            let photoData = try? Data(contentsOf: photoFile(for: id))
            let name = playerNamesByID[id] ?? NSLocalizedString("player_unknown_default", comment: "Unknown player")
            recoveredPlayers.append(Player(id: id, name: name, photoData: photoData))
            addedPlayers += 1
        }

        var recoveredTeams = teams
        var teamIDByName: [String: UUID] = [:]
        for team in teams {
            teamIDByName[team.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()] = team.id
        }
        var addedTeams = 0
        var updatedTeams = 0

        func recoverTeam(id: UUID?, name: String, playerIDs: [UUID]) {
            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let resolvedID = id ?? teamIDByName[normalizedName] ?? UUID()
            teamIDByName[normalizedName] = resolvedID

            if let index = recoveredTeams.firstIndex(where: { $0.id == resolvedID }) {
                var mergedPlayerIDs = recoveredTeams[index].playerIDs
                for playerID in playerIDs {
                    appendUnique(playerID, to: &mergedPlayerIDs)
                }
                if mergedPlayerIDs != recoveredTeams[index].playerIDs {
                    recoveredTeams[index].playerIDs = mergedPlayerIDs
                    updatedTeams += 1
                }
                return
            }

            recoveredTeams.append(Team(id: resolvedID, name: name, playerIDs: playerIDs))
            addedTeams += 1
        }

        for game in savedGames {
            recoverTeam(id: game.snapshot.homeTeamID, name: game.homeTeamName, playerIDs: game.homePlayerIDs)
            recoverTeam(id: game.snapshot.awayTeamID, name: game.awayTeamName, playerIDs: game.awayPlayerIDs)
        }

        let teamsMissingFromCoreData = recoveredTeams.contains { !existingTeamIDs.contains($0.id) }
        let rosterChanged = addedPlayers > 0 || addedTeams > 0 || updatedTeams > 0 || teamsMissingFromCoreData
        guard rosterChanged else {
            print("[RecoveryCheck] game-roster-recovery no changes players=\(players.count) teams=\(teams.count)")
            return
        }

        players = recoveredPlayers
        teams = recoveredTeams
        dirtyKeys.insert(.players)
        dirtyKeys.insert(.teams)
        print("[RecoveryCheck] game-roster-recovery recovered players-added=\(addedPlayers) teams-added=\(addedTeams) teams-updated=\(updatedTeams) totals players=\(players.count) teams=\(teams.count)")

        if recoveryDiagnosticsNoWrite {
            print("[RecoveryCheck] game-roster-recovery skipped-save because no-write mode is enabled")
        } else {
            saveIfNeeded()
            print("[RecoveryCheck] game-roster-recovery persisted")
        }
    }
#endif

    func syncCloudGames() async {
        let cloudIDs = cloudEnabledGameIDs.subtracting(deletedCloudGameIDs)
        let (newGames, updatedGames, aiSummaryUpdates) = await CloudKitManager.shared.sync(cloudEnabledIDs: cloudIDs, localGames: savedGames)
        for update in updatedGames {
            guard let idx = savedGames.firstIndex(where: { $0.id == update.id }) else { continue }
            savedGames[idx] = update
        }
        for update in aiSummaryUpdates {
            if let idx = savedGames.firstIndex(where: { $0.id == update.id }) {
                savedGames[idx].aiSummary = update.aiSummary
            }
        }
        guard !newGames.isEmpty else { return }
        savedGames.append(contentsOf: newGames)
        savedGames.sort { $0.savedAt > $1.savedAt }
    }

    @objc private func cloudStoreDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.loadCloudEnabledGameIDs()
        }
    }

    // MARK: - Career Stat Visibility

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

    func decodeTeamPackage(from base64: String) -> ExportedTeamPackage? {
        TransferCodec.decode(base64, as: ExportedTeamPackage.self)
    }

    func decodePlayerPackage(from base64: String) -> ExportedPlayerPackage? {
        TransferCodec.decode(base64, as: ExportedPlayerPackage.self)
    }

    func updateAISummary(_ summary: String, for gameID: UUID) {
        guard let index = savedGames.firstIndex(where: { $0.id == gameID }) else { return }
        savedGames[index].aiSummary = summary
        markSavedGameModified(gameID)
    }

    func markSavedGameModified(_ gameID: UUID, at date: Date = Date()) {
        guard let index = savedGames.firstIndex(where: { $0.id == gameID }) else { return }
        savedGames[index].modifiedAt = date
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

        savedGamesCopy[gameIndex].modifiedAt = Date()
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
        let modifiedAt = Date()

        for gameID in removed {
            if let gameIndex = savedGamesCopy.firstIndex(where: { $0.id == gameID }) {
                savedGamesCopy[gameIndex].groupIDs.removeAll { $0 == groupID }
                savedGamesCopy[gameIndex].modifiedAt = modifiedAt
            }
        }
        for gameID in added {
            if let gameIndex = savedGamesCopy.firstIndex(where: { $0.id == gameID }) {
                if !savedGamesCopy[gameIndex].groupIDs.contains(groupID) {
                    savedGamesCopy[gameIndex].groupIDs.append(groupID)
                    savedGamesCopy[gameIndex].modifiedAt = modifiedAt
                }
            }
        }

        gameGroups = gameGroupsCopy
        savedGames = savedGamesCopy
        scheduleSave()
    }



    private func encodeGameForTracking(_ game: SavedGame) -> Data? {
        var tracked = game
        if tracked.undoSnapshots.count > 30 {
            tracked.undoSnapshots = Array(tracked.undoSnapshots.suffix(30))
        }
        tracked.previousSnapshot = nil
        return try? JSONEncoder().encode(tracked)
    }

    private func safeWrite<T: Encodable>(_ value: T, forKey key: String) {
        let data: Data
        if key.hasPrefix("game_"), var game = value as? SavedGame {
            if game.undoSnapshots.count > 30 {
                game.undoSnapshots = Array(game.undoSnapshots.suffix(30))
            }
            game.previousSnapshot = nil
            guard let encoded = try? JSONEncoder().encode(game) else {
                print("[Storage] Failed to encode game for \(key)")
                return
            }
            data = encoded
        } else {
            guard let encoded = try? JSONEncoder().encode(value) else {
                print("[Storage] Failed to encode \(key)")
                return
            }
            data = encoded
        }

        if data.count >= 3_000_000 {
            let fileURL = documentsDir.appendingPathComponent("\(key).json")
            try? data.write(to: fileURL, options: .atomic)
        } else {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func safeRead<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        let data = readRawData(forKey: key)
        guard let data else { return nil }

        if key.hasPrefix("game_") {
            do {
                var game = try JSONDecoder().decode(SavedGame.self, from: data)
                if game.undoSnapshots.count > 30 {
                    print("[Storage] Trimming undo stack on load: \(game.undoSnapshots.count) -> 30")
                    game.undoSnapshots = Array(game.undoSnapshots.suffix(30))
                }
                game.previousSnapshot = nil
                return game as? T
            } catch {
                print("[Storage] Failed to decode game \(key): \(error)")
                return nil
            }
        }

        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("[Storage] Failed to decode \(key): \(error)")
            return nil
        }
    }

    private func readRawData(forKey key: String) -> Data? {
        if let data = UserDefaults.standard.data(forKey: key) {
            return data
        }
        let fileURL = documentsDir.appendingPathComponent("\(key).json")
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            print("[Storage] Failed to read file \(key): \(error)")
            return nil
        }
    }

    func saveIfNeeded() {
        saveTask?.cancel()
        save()
    }

    private func save() {
        // Strip photoData and save as separate files (only if changed)
        var strippedPlayers = players
        if dirtyKeys.contains(.players) {
            try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
            for i in strippedPlayers.indices {
                if let data = strippedPlayers[i].photoData {
                    let fileURL = photoFile(for: strippedPlayers[i].id)
                    let existingData = try? Data(contentsOf: fileURL)
                    if data != existingData {
                        try? data.write(to: fileURL, options: .atomic)
                    }
                }
            }
        }
        for i in strippedPlayers.indices {
            strippedPlayers[i].photoData = nil
        }

        var strippedTeams = teams
        if dirtyKeys.contains(.teams) {
            try? FileManager.default.createDirectory(at: teamIconsDir, withIntermediateDirectories: true)
            for i in strippedTeams.indices {
                let fileURL = teamIconFile(for: strippedTeams[i].id)
                if let data = strippedTeams[i].iconData {
                    let existingData = try? Data(contentsOf: fileURL)
                    if data != existingData {
                        try? data.write(to: fileURL, options: .atomic)
                    }
                } else {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }
        for i in strippedTeams.indices {
            strippedTeams[i].iconData = nil
        }

        // Save meta (players, teams, settings) — always write as single blob
        let meta = StoreMeta(
            players: strippedPlayers,
            teams: strippedTeams,
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

        // Save each game individually (only if games changed)
        var changedGameIDs: Set<UUID> = []
        if dirtyKeys.contains(.savedGames) {
            let gameIDs = savedGames.map(\.id)
            safeWrite(gameIDs, forKey: gamesIndexKey)
            for game in savedGames {
                let key = gameKey(for: game.id)
                let essentialData = encodeGameForTracking(game)
                if lastSavedGameData[game.id] == essentialData {
                    continue
                }
                safeWrite(game, forKey: key)
                if let data = essentialData {
                    lastSavedGameData[game.id] = data
                }
                changedGameIDs.insert(game.id)
            }
            let validIDs = Set(savedGames.map(\.id))
            lastSavedGameData = lastSavedGameData.filter { validIDs.contains($0.key) }
        }

        // Core Data persistence — write only dirty entities
        if dirtyKeys.contains(.players) { coreDataStore.savePlayers(players) }
        if dirtyKeys.contains(.teams) { coreDataStore.saveTeams(teams) }
        if dirtyKeys.contains(.gameGroups) { coreDataStore.saveGameGroups(gameGroups) }
        if dirtyKeys.contains(.playerGroups) { coreDataStore.savePlayerGroups(playerGroups) }
        if dirtyKeys.contains(.savedGames) {
            let existingIDs = coreDataStore.fetchAllSavedGameIDs()
            let newIDs = Set(savedGames.map(\.id))
            let toDelete = existingIDs.subtracting(newIDs)
            let writeIDs = changedGameIDs.isEmpty ? newIDs : changedGameIDs
            for game in savedGames where writeIDs.contains(game.id) {
                coreDataStore.upsertSavedGame(game)
            }
            for id in toDelete {
                coreDataStore.deleteSavedGame(id: id)
            }
        }
        coreDataStore.flush()

        dirtyKeys = []
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveGeneration += 1
        let gen = saveGeneration
        saveTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await Task.sleep(nanoseconds: saveDebounceNanoseconds)
            } catch {
                return
            }
            guard !Task.isCancelled, saveGeneration == gen else { return }
            save()
            guard !Task.isCancelled, saveGeneration == gen else { return }
            dirtyKeys = []
        }
    }

    private func load() {
        suppressSave = true
        defer { suppressSave = false }
        print("[RecoveryCheck] load-start")
        // Try loading from Core Data first
        let coreDataHasData = coreDataStore.hasData()
        print("[RecoveryCheck] branch-decision coreDataHasSavedGames=\(coreDataHasData)")
        if coreDataHasData {
            var restoredPlayers = coreDataStore.fetchAllPlayers()
            var restoredTeams = coreDataStore.fetchAllTeams()
            gameGroups = coreDataStore.fetchAllGameGroups()
            playerGroups = coreDataStore.fetchAllPlayerGroups()
            savedGames = coreDataStore.fetchAllSavedGames()
            let splitMeta: StoreMeta? = safeRead(StoreMeta.self, forKey: metaKey)
            var restoredRosterFromMeta = false
            if let splitMeta {
                print("[RecoveryCheck] split-meta counts players=\(splitMeta.players.count) teams=\(splitMeta.teams.count) gameGroups=\(splitMeta.gameGroups.count) playerGroups=\(splitMeta.playerGroups.count)")
                let restoredPlayerIDs = Set(restoredPlayers.map(\.id))
                let missingPlayers = splitMeta.players.filter { !restoredPlayerIDs.contains($0.id) }
                if !missingPlayers.isEmpty {
                    restoredPlayers.append(contentsOf: missingPlayers)
                    restoredRosterFromMeta = true
                    print("[RecoveryCheck] roster-fallback players-added-from-meta=\(missingPlayers.count) meta-total=\(splitMeta.players.count)")
                }

                let restoredTeamIDs = Set(restoredTeams.map(\.id))
                let missingTeams = splitMeta.teams.filter { !restoredTeamIDs.contains($0.id) }
                if !missingTeams.isEmpty {
                    restoredTeams.append(contentsOf: missingTeams)
                    restoredRosterFromMeta = true
                    print("[RecoveryCheck] roster-fallback teams-added-from-meta=\(missingTeams.count) meta-total=\(splitMeta.teams.count)")
                }
            }
            // Restore photo data from files before final assignment
            for i in restoredPlayers.indices {
                let fileURL = photoFile(for: restoredPlayers[i].id)
                if let photoData = try? Data(contentsOf: fileURL), !photoData.isEmpty {
                    restoredPlayers[i].photoData = photoData
                }
            }
            for i in restoredTeams.indices {
                let fileURL = teamIconFile(for: restoredTeams[i].id)
                if let iconData = try? Data(contentsOf: fileURL), !iconData.isEmpty {
                    restoredTeams[i].iconData = iconData
                }
            }
            players = restoredPlayers
            teams = restoredTeams
            hasMigratedToCoreData = true
            print("[RecoveryCheck] branch=core-data players=\(players.count) teams=\(teams.count) gameGroups=\(gameGroups.count) playerGroups=\(playerGroups.count) savedGames=\(savedGames.count)")
            print("[LoadCheck] CoreData → players=\(players.count) teams=\(teams.count) gameGroups=\(gameGroups.count) playerGroups=\(playerGroups.count) savedGames=\(savedGames.count)")

            // Voice and group metadata is stored in UserDefaults as well
            if let meta = splitMeta {
                if let cm = meta.customVoiceMappings { customVoiceMappings = cm }
                if let vl = meta.voiceLog { voiceLog = vl }
                showsVoiceButton = meta.showsVoiceButton ?? false
                showsBluetoothGamesButton = meta.showsBluetoothGamesButton
                keepsScreenAwake = meta.keepsScreenAwake
                hiddenCareerStatItems = meta.hiddenCareerStatItems
                voiceLogEnabled = meta.voiceLogEnabled ?? true
                if playerGroups.isEmpty, !meta.playerGroups.isEmpty {
                    playerGroups = meta.playerGroups
                    print("[LoadCheck] Fallback UserDefaults → playerGroups=\(meta.playerGroups.count)")
                }
                if gameGroups.isEmpty, !meta.gameGroups.isEmpty {
                    gameGroups = meta.gameGroups
                    print("[LoadCheck] Fallback UserDefaults → gameGroups=\(meta.gameGroups.count)")
                }
            }
            if restoredRosterFromMeta {
                dirtyKeys = [.players, .teams]
                if recoveryDiagnosticsNoWrite {
                    print("[RecoveryCheck] roster-fallback skipped-save because no-write mode is enabled")
                } else {
                    save()
                    print("[RecoveryCheck] roster-fallback persisted-to-core-data")
                }
            }
            awardAllBadges()
            return
        }

        print("[RecoveryCheck] branch=split-or-legacy-fallback")

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
            var restoredTeams = meta.teams
            for i in restoredTeams.indices {
                let fileURL = teamIconFile(for: restoredTeams[i].id)
                if let iconData = try? Data(contentsOf: fileURL), !iconData.isEmpty {
                    restoredTeams[i].iconData = iconData
                }
            }
            teams = restoredTeams
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
        awardAllBadges()
    }

    private func awardAllBadges() {
        guard !savedGames.isEmpty else { return }
        DispatchQueue.main.async { [self] in
            BadgeAwarder.scanAllGames(store: self)
        }
    }

    private func migrateToCoreData() {
        guard !hasMigratedToCoreData else { return }
        hasMigratedToCoreData = true
        dirtyKeys = [.players, .teams, .gameGroups, .playerGroups, .savedGames]
        print("[RecoveryCheck] migrate-to-core-data input players=\(players.count) teams=\(teams.count) gameGroups=\(gameGroups.count) playerGroups=\(playerGroups.count) savedGames=\(savedGames.count)")
        if recoveryDiagnosticsNoWrite {
            print("[RecoveryCheck] migrate-to-core-data skipped-save because no-write mode is enabled")
            return
        }
        save()
    }

    private func logRecoveryState(phase: String) {
        print("[RecoveryCheck] phase=\(phase)")
        let legacyFileURL = documentsDir.appendingPathComponent("appstore_v2.json")
        logRecoverySource("legacy-userdefaults", data: UserDefaults.standard.data(forKey: storageKey))
        logRecoverySource("legacy-file", data: try? Data(contentsOf: legacyFileURL))

        let metaFileURL = documentsDir.appendingPathComponent("\(metaKey).json")
        let gamesIndexFileURL = documentsDir.appendingPathComponent("\(gamesIndexKey).json")
        logRecoverySource("split-meta-userdefaults", data: UserDefaults.standard.data(forKey: metaKey))
        logRecoverySource("split-meta-file", data: try? Data(contentsOf: metaFileURL))
        logRecoverySource("split-games-index-userdefaults", data: UserDefaults.standard.data(forKey: gamesIndexKey))
        logRecoverySource("split-games-index-file", data: try? Data(contentsOf: gamesIndexFileURL))

        logRecoveryDirectory(photosDir, label: "player-photos")
        logRecoveryDirectory(teamIconsDir, label: "team-icons")

        let stores = coreDataStore.stack.container.persistentStoreCoordinator.persistentStores
        print("[RecoveryCheck] core-data-stores count=\(stores.count)")
        for store in stores {
            let storeURL = store.url?.path ?? "nil"
            print("[RecoveryCheck] core-data-store type=\(store.type) url=\(storeURL)")
        }

        for entityName in ["CDPlayer", "CDTeam", "CDGameGroup", "CDPlayerGroup", "CDSavedGame"] {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            if let count = try? coreDataStore.context.count(for: request) {
                print("[RecoveryCheck] core-data-count entity=\(entityName) count=\(count)")
            } else {
                print("[RecoveryCheck] core-data-count entity=\(entityName) unavailable")
            }
        }
    }

    private func logRecoverySource(_ source: String, data: Data?) {
        guard let data else {
            print("[RecoveryCheck] source=\(source) present=false")
            return
        }

        print("[RecoveryCheck] source=\(source) present=true bytes=\(data.count)")
        if source.hasPrefix("legacy-") {
            if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let keys = object.keys.sorted().joined(separator: ",")
                let playerCount = (object["players"] as? [Any])?.count ?? -1
                let teamCount = (object["teams"] as? [Any])?.count ?? -1
                let gameCount = (object["savedGames"] as? [Any])?.count ?? -1
                print("[RecoveryCheck] source=\(source) json-top-level-keys=\(keys) raw-players=\(playerCount) raw-teams=\(teamCount) raw-savedGames=\(gameCount)")
            }

            do {
                let payload = try JSONDecoder().decode(LegacyPayloadProbe.self, from: data)
                print("[RecoveryCheck] source=\(source) legacy-decodable=true players=\(payload.players.count) teams=\(payload.teams.count) savedGames=\(payload.savedGames.count)")
            } catch {
                print("[RecoveryCheck] source=\(source) legacy-decodable=false error=\(error)")
            }
        }
    }

    private func logRecoveryDirectory(_ directory: URL, label: String) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            print("[RecoveryCheck] directory=\(label) present=false")
            return
        }

        let totalBytes = files.reduce(0) { total, fileURL in
            total + ((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        print("[RecoveryCheck] directory=\(label) present=true files=\(files.count) bytes=\(totalBytes)")
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

}
