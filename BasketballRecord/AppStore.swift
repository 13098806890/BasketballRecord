import SwiftUI

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

    @Published var players: [Player] = [] {
        didSet { scheduleSave() }
    }

    @Published var teams: [Team] = [] {
        didSet { scheduleSave() }
    }

    @Published var savedGames: [SavedGame] = [] {
        didSet { scheduleSave() }
    }

    @Published var hiddenCareerStatItems: Set<CareerStatItem> = [] {
        didSet { scheduleSave() }
    }

    @Published var keepsScreenAwake = true {
        didSet { scheduleSave() }
    }

    @Published var showsSimulationButton = false {
        didSet { scheduleSave() }
    }

    private let storageKey = "basketball-record-store-v1"
    private var saveTask: Task<Void, Never>?
    private let saveDebounceNanoseconds: UInt64 = 500_000_000

    init() {
        load()
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
            return ExportPlayer(id: playerID, name: game.playerNamesByID[playerID] ?? "未知球员")
        }

        let exportedTeams = [
            exportTeam(id: game.snapshot.homeTeamID, fallbackName: game.homeTeamName, playerIDs: game.homePlayerIDs),
            exportTeam(id: game.snapshot.awayTeamID, fallbackName: game.awayTeamName, playerIDs: game.awayPlayerIDs)
        ].compactMap { $0 }

        let package = ExportedGamePackage(players: exportedPlayers, teams: exportedTeams, game: ExportGameRecord(savedGame: game))
        return TransferCodec.encode(package)
    }

    func exportTeamBase64(_ team: Team) -> String? {
        let exportedPlayers = team.playerIDs.map { playerID in
            if let player = player(for: playerID) {
                return ExportPlayer(player: player)
            }
            return ExportPlayer(id: playerID, name: "未知球员")
        }
        let package = ExportedTeamPackage(team: ExportTeam(team: team), players: exportedPlayers)
        return TransferCodec.encode(package)
    }

    func exportPlayerBase64(_ player: Player) -> String? {
        let package = ExportedPlayerPackage(player: ExportPlayer(player: player))
        return TransferCodec.encode(package)
    }

    func decodeGamePackage(from base64: String) -> ExportedGamePackage? {
        TransferCodec.decode(base64, as: ExportedGamePackage.self)
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
            nextPlayers.append(Player(id: playerID, name: "未知球员"))
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

    func importGamePackage(
        _ package: ExportedGamePackage,
        playerMapping: [UUID: UUID] = [:],
        teamMapping: [UUID: UUID] = [:],
        importsUnmatchedRoster: Bool = true
    ) {
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
        upsertImportedGame(importedGame)
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

    @discardableResult
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
        let payload = StorePayload(
            players: players,
            teams: teams,
            savedGames: savedGames,
            hiddenCareerStatItems: hiddenCareerStatItems,
            keepsScreenAwake: keepsScreenAwake,
            showsSimulationButton: showsSimulationButton
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
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
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            seedSampleData()
            return
        }

        guard let payload = try? JSONDecoder().decode(StorePayload.self, from: data) else {
            players = []
            teams = []
            savedGames = []
            return
        }

        players = payload.players
        teams = payload.teams
        savedGames = payload.savedGames
        hiddenCareerStatItems = payload.hiddenCareerStatItems
        keepsScreenAwake = payload.keepsScreenAwake
        showsSimulationButton = payload.showsSimulationButton
    }

    private func seedSampleData() {
        let samplePlayers = [
            Player(name: "张三", height: "180", weight: "76", number: "7"),
            Player(name: "李四", height: "186", weight: "82", number: "11"),
            Player(name: "王五", height: "178", weight: "72", number: "23"),
            Player(name: "赵六", height: "192", weight: "88", number: "33")
        ]
        players = samplePlayers
        teams = [
            Team(name: "主队", playerIDs: Array(samplePlayers.prefix(2).map(\.id))),
            Team(name: "客队", playerIDs: Array(samplePlayers.suffix(2).map(\.id)))
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
            homeTeamName: homeTeam?.name ?? "主队",
            awayTeamName: awayTeam?.name ?? "客队",
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
            playerNamesByID: playerNames
        )
    }

    private func remappedSnapshot(_ snapshot: GameSnapshot, playerIDMap: [UUID: UUID], teamIDMap: [UUID: UUID]) -> GameSnapshot {
        var remapped = snapshot
        remapped.homeTeamID = snapshot.homeTeamID.flatMap { teamIDMap[$0] ?? $0 }
        remapped.awayTeamID = snapshot.awayTeamID.flatMap { teamIDMap[$0] ?? $0 }
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
            playerNamesByID: names
        )
    }

    private func remappedSnapshotForPlayerMerge(_ snapshot: GameSnapshot, sourceID: UUID, targetID: UUID) -> GameSnapshot {
        var remapped = snapshot
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
            playerNamesByID: game.playerNamesByID
        )
    }

    private func remappedSnapshotForTeamMerge(_ snapshot: GameSnapshot, sourceID: UUID, targetID: UUID) -> GameSnapshot {
        var remapped = snapshot
        if remapped.homeTeamID == sourceID { remapped.homeTeamID = targetID }
        if remapped.awayTeamID == sourceID { remapped.awayTeamID = targetID }
        return remapped
    }

    private func upsertImportedGame(_ importedGame: SavedGame) {
        if let existingIndex = savedGames.firstIndex(where: { $0.id == importedGame.id }) {
            savedGames[existingIndex] = importedGame
            if existingIndex != 0 {
                let updated = savedGames.remove(at: existingIndex)
                savedGames.insert(updated, at: 0)
            }
            return
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
            return
        }

        savedGames.insert(importedGame, at: 0)
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
    var hiddenCareerStatItems: Set<CareerStatItem>
    var keepsScreenAwake: Bool
    var showsSimulationButton: Bool

    init(
        players: [Player],
        teams: [Team],
        savedGames: [SavedGame] = [],
        hiddenCareerStatItems: Set<CareerStatItem> = [],
        keepsScreenAwake: Bool = true,
        showsSimulationButton: Bool = false
    ) {
        self.players = players
        self.teams = teams
        self.savedGames = savedGames
        self.hiddenCareerStatItems = hiddenCareerStatItems
        self.keepsScreenAwake = keepsScreenAwake
        self.showsSimulationButton = showsSimulationButton
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = try container.decode([Player].self, forKey: .players)
        teams = try container.decode([Team].self, forKey: .teams)
        savedGames = try container.decodeIfPresent([SavedGame].self, forKey: .savedGames) ?? []
        hiddenCareerStatItems = try container.decodeIfPresent(Set<CareerStatItem>.self, forKey: .hiddenCareerStatItems) ?? []
        keepsScreenAwake = try container.decodeIfPresent(Bool.self, forKey: .keepsScreenAwake) ?? true
        showsSimulationButton = try container.decodeIfPresent(Bool.self, forKey: .showsSimulationButton) ?? false
    }
}
