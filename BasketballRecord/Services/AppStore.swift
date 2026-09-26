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
        NSUbiquitousKeyValueStore.default.set(ids, forKey: "cloud_enabled_game_ids")
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    private func loadCloudEnabledGameIDs() {
        if let ids = NSUbiquitousKeyValueStore.default.array(forKey: "cloud_enabled_game_ids") as? [String] {
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

    init() {
        load()
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-seedScreenshotData") {
            seedScreenshotData()
        }
#endif
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
        savedGames[index].modifiedAt = Date()
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
                    savedGamesCopy[gameIndex].groupIDs.append(groupID)
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
        // Try loading from Core Data first
        if coreDataStore.hasData() {
            var restoredPlayers = coreDataStore.fetchAllPlayers()
            var restoredTeams = coreDataStore.fetchAllTeams()
            gameGroups = coreDataStore.fetchAllGameGroups()
            playerGroups = coreDataStore.fetchAllPlayerGroups()
            savedGames = coreDataStore.fetchAllSavedGames()
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
            print("[LoadCheck] CoreData → players=\(players.count) teams=\(teams.count) gameGroups=\(gameGroups.count) playerGroups=\(playerGroups.count) savedGames=\(savedGames.count)")

            // Voice and group metadata is stored in UserDefaults as well
            if let meta: StoreMeta = safeRead(StoreMeta.self, forKey: metaKey) {
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
            awardAllBadges()
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
        save()
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

#if DEBUG
    private func seedScreenshotData() {
        let marker = "UI Audit Demo"
        guard !savedGames.contains(where: { $0.displayName.hasPrefix(marker) }) else { return }

        if players.count < 6 || teams.count < 2 {
            seedSampleData()
        }

        guard players.count >= 6, teams.count >= 2 else { return }

        let homeTeam = teams[0]
        let awayTeam = teams[1]
        let homePlayerIDs = Array(players.prefix(3).map(\.id))
        let awayPlayerIDs = Array(players.dropFirst(3).prefix(3).map(\.id))
        teams[0].playerIDs = homePlayerIDs
        teams[1].playerIDs = awayPlayerIDs

        let playerNames = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0.name) })
        let calendar = Calendar(identifier: .gregorian)
        let dates = [
            calendar.date(from: DateComponents(year: 2025, month: 3, day: 8, hour: 10, minute: 0))!,
            calendar.date(from: DateComponents(year: 2025, month: 2, day: 22, hour: 14, minute: 30))!,
            calendar.date(from: DateComponents(year: 2025, month: 1, day: 18, hour: 16, minute: 0))!
        ]
        let scorePairs = [(78, 62), (65, 70), (81, 75)]

        func stats(_ points: Int, rebounds: Int, assists: Int, steals: Int, blocks: Int, turnovers: Int) -> PlayerStats {
            var value = PlayerStats()
            value.twoMade = points / 2
            value.twoAttempts = value.twoMade + 2
            value.threeMade = points % 2
            value.threeAttempts = value.threeMade + 1
            value.rebounds = rebounds
            value.assists = assists
            value.steals = steals
            value.blocks = blocks
            value.turnovers = turnovers
            value.fouls = 1
            return value
        }

        func makeGame(index: Int, date: Date, score: (Int, Int)) -> SavedGame {
            let homeStats = [
                stats(score.0 / 3, rebounds: 7, assists: 4, steals: 2, blocks: 1, turnovers: 2),
                stats(score.0 / 3, rebounds: 5, assists: 6, steals: 1, blocks: 0, turnovers: 1),
                stats(score.0 - (score.0 / 3) * 2, rebounds: 8, assists: 3, steals: 1, blocks: 2, turnovers: 2)
            ]
            let awayStats = [
                stats(score.1 / 3, rebounds: 6, assists: 3, steals: 1, blocks: 0, turnovers: 2),
                stats(score.1 / 3, rebounds: 4, assists: 5, steals: 2, blocks: 1, turnovers: 2),
                stats(score.1 - (score.1 / 3) * 2, rebounds: 7, assists: 2, steals: 1, blocks: 1, turnovers: 3)
            ]
            var statsByPlayerID: [UUID: PlayerStats] = [:]
            for (id, value) in zip(homePlayerIDs, homeStats) { statsByPlayerID[id] = value }
            for (id, value) in zip(awayPlayerIDs, awayStats) { statsByPlayerID[id] = value }

            var logs: [GameLogEntry] = []
            for period in 1...4 {
                logs.append(GameLogEntry(timestamp: date.addingTimeInterval(Double(period) * 60), message: "Period \(period) started", eventCode: "event.period_start", period: period, periodElapsedSeconds: 0))
                let homeID = homePlayerIDs[(period - 1) % homePlayerIDs.count]
                let awayID = awayPlayerIDs[(period - 1) % awayPlayerIDs.count]
                logs.append(GameLogEntry(timestamp: date.addingTimeInterval(Double(period) * 120), message: "\(playerNames[homeID] ?? "Player") scored", eventCode: "stat.twoMade", playerID: homeID, period: period, periodElapsedSeconds: 120))
                logs.append(GameLogEntry(timestamp: date.addingTimeInterval(Double(period) * 180), message: "\(playerNames[awayID] ?? "Player") assisted", eventCode: "stat.assist", playerID: awayID, period: period, periodElapsedSeconds: 180))
                logs.append(GameLogEntry(timestamp: date.addingTimeInterval(Double(period) * 600), message: "Period \(period) ended", eventCode: "event.period_end", period: period, periodElapsedSeconds: 600))
            }

            var snapshot = GameSnapshot(
                statsByPlayerID: statsByPlayerID,
                logs: logs,
                homeTeamID: homeTeam.id,
                awayTeamID: awayTeam.id,
                periodCount: 4,
                originalPeriodCount: 4,
                currentPeriod: 4,
                isComplete: true,
                homeOnCourtPlayerIDs: homePlayerIDs,
                awayOnCourtPlayerIDs: awayPlayerIDs,
                homeAvailablePlayerIDs: homePlayerIDs,
                awayAvailablePlayerIDs: awayPlayerIDs,
                starterPlayerIDs: homePlayerIDs + awayPlayerIDs,
                startersRecorded: true,
                playingSecondsByPlayerID: Dictionary(uniqueKeysWithValues: (homePlayerIDs + awayPlayerIDs).map { ($0, 1_920) }),
                plusMinusByPlayerID: Dictionary(uniqueKeysWithValues: homePlayerIDs.map { ($0, 16) } + awayPlayerIDs.map { ($0, -16) })
            )
            snapshot.matchElapsedSeconds = 3_600
            snapshot.periodElapsedSeconds = 600

            return SavedGame(
                savedAt: date,
                modifiedAt: date,
                snapshot: snapshot,
                aiSummary: "A balanced game with strong ball movement and active defense.",
                homeTeamName: homeTeam.name,
                awayTeamName: awayTeam.name,
                homePlayerIDs: homePlayerIDs,
                awayPlayerIDs: awayPlayerIDs,
                playerNamesByID: playerNames,
                displayName: "\(marker) \(index + 1)"
            )
        }

        savedGames = zip(dates, scorePairs).enumerated().map { index, pair in
            makeGame(index: index, date: pair.0, score: pair.1)
        }.sorted { $0.savedAt > $1.savedAt }
        saveIfNeeded()
    }
#endif

}
