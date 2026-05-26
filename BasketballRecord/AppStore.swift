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
        didSet { save() }
    }

    @Published var teams: [Team] = [] {
        didSet { save() }
    }

    @Published var savedGames: [SavedGame] = [] {
        didSet { save() }
    }

    private let storageKey = "basketball-record-store-v1"

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
    func autoSaveGame(_ snapshot: GameSnapshot, gameID: UUID?) -> UUID {
        let targetID = gameID ?? UUID()
        let game = buildSavedGame(id: targetID, snapshot: snapshot, savedAt: Date())

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

        let package = ExportedGamePackage(players: exportedPlayers, teams: exportedTeams, game: game)
        guard let data = try? JSONEncoder().encode(package) else { return nil }
        return data.base64EncodedString()
    }

    func exportTeamBase64(_ team: Team) -> String? {
        let exportedPlayers = team.playerIDs.map { playerID in
            if let player = player(for: playerID) {
                return ExportPlayer(player: player)
            }
            return ExportPlayer(id: playerID, name: "未知球员")
        }
        let package = ExportedTeamPackage(team: ExportTeam(team: team), players: exportedPlayers)
        guard let data = try? JSONEncoder().encode(package) else { return nil }
        return data.base64EncodedString()
    }

    func exportPlayerBase64(_ player: Player) -> String? {
        let package = ExportedPlayerPackage(player: ExportPlayer(player: player))
        guard let data = try? JSONEncoder().encode(package) else { return nil }
        return data.base64EncodedString()
    }

    func decodeGamePackage(from base64: String) -> ExportedGamePackage? {
        let trimmed = base64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed) else { return nil }
        return try? JSONDecoder().decode(ExportedGamePackage.self, from: data)
    }

    func decodeTeamPackage(from base64: String) -> ExportedTeamPackage? {
        let trimmed = base64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed) else { return nil }
        return try? JSONDecoder().decode(ExportedTeamPackage.self, from: data)
    }

    func decodePlayerPackage(from base64: String) -> ExportedPlayerPackage? {
        let trimmed = base64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed) else { return nil }
        return try? JSONDecoder().decode(ExportedPlayerPackage.self, from: data)
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

        let importedGame = remappedGame(package.game, playerIDMap: playerIDMap, teamIDMap: teamIDMap)
        savedGames.insert(importedGame, at: 0)
    }

    func deleteSavedGames(at offsets: IndexSet) {
        savedGames.remove(atOffsets: offsets)
    }

    func deleteSavedGames(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        savedGames.removeAll { ids.contains($0.id) }
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
        let payload = StorePayload(players: players, teams: teams, savedGames: savedGames)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let payload = try? JSONDecoder().decode(StorePayload.self, from: data) else {
            seedSampleData()
            return
        }
        players = payload.players
        teams = payload.teams
        savedGames = payload.savedGames
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
        let gamePlayerIDs = (homeTeam?.playerIDs ?? []) + (awayTeam?.playerIDs ?? [])
        let playerNames = Dictionary(uniqueKeysWithValues: gamePlayerIDs.compactMap { playerID in
            player(for: playerID).map { (playerID, $0.name) }
        })

        return SavedGame(
            id: id,
            savedAt: savedAt,
            snapshot: snapshot,
            homeTeamName: homeTeam?.name ?? "主队",
            awayTeamName: awayTeam?.name ?? "客队",
            homePlayerIDs: homeTeam?.playerIDs ?? [],
            awayPlayerIDs: awayTeam?.playerIDs ?? [],
            playerNamesByID: playerNames
        )
    }

    private func remappedGame(_ game: SavedGame, playerIDMap: [UUID: UUID], teamIDMap: [UUID: UUID]) -> SavedGame {
        var snapshot = game.snapshot
        snapshot.homeTeamID = snapshot.homeTeamID.flatMap { teamIDMap[$0] ?? $0 }
        snapshot.awayTeamID = snapshot.awayTeamID.flatMap { teamIDMap[$0] ?? $0 }
        snapshot.statsByPlayerID = remapDictionary(snapshot.statsByPlayerID, using: playerIDMap)
        snapshot.homeOnCourtPlayerIDs = game.snapshot.homeOnCourtPlayerIDs.map { playerIDMap[$0] ?? $0 }
        snapshot.awayOnCourtPlayerIDs = game.snapshot.awayOnCourtPlayerIDs.map { playerIDMap[$0] ?? $0 }
        snapshot.playingSecondsByPlayerID = remapDictionary(snapshot.playingSecondsByPlayerID, using: playerIDMap)
        snapshot.activeSinceByPlayerID = remapDictionary(snapshot.activeSinceByPlayerID, using: playerIDMap)
        snapshot.plusMinusByPlayerID = remapDictionary(snapshot.plusMinusByPlayerID, using: playerIDMap)

        let homePlayerIDs = game.homePlayerIDs.map { playerIDMap[$0] ?? $0 }
        let awayPlayerIDs = game.awayPlayerIDs.map { playerIDMap[$0] ?? $0 }
        var playerNames: [UUID: String] = [:]
        for (oldID, name) in game.playerNamesByID {
            playerNames[playerIDMap[oldID] ?? oldID] = name
        }

        return SavedGame(
            id: UUID(),
            savedAt: game.savedAt,
            snapshot: snapshot,
            homeTeamName: team(for: snapshot.homeTeamID)?.name ?? game.homeTeamName,
            awayTeamName: team(for: snapshot.awayTeamID)?.name ?? game.awayTeamName,
            homePlayerIDs: homePlayerIDs,
            awayPlayerIDs: awayPlayerIDs,
            playerNamesByID: playerNames
        )
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
        var snapshot = game.snapshot
        snapshot.statsByPlayerID = mergeStatsDictionary(snapshot.statsByPlayerID, sourceID: sourceID, targetID: targetID)
        snapshot.playingSecondsByPlayerID = mergeSumDictionary(snapshot.playingSecondsByPlayerID, sourceID: sourceID, targetID: targetID)
        snapshot.plusMinusByPlayerID = mergeSumDictionary(snapshot.plusMinusByPlayerID, sourceID: sourceID, targetID: targetID)
        snapshot.activeSinceByPlayerID = mergeDateDictionary(snapshot.activeSinceByPlayerID, sourceID: sourceID, targetID: targetID)
        snapshot.homeOnCourtPlayerIDs = remapDedupedIDs(snapshot.homeOnCourtPlayerIDs, sourceID: sourceID, targetID: targetID)
        snapshot.awayOnCourtPlayerIDs = remapDedupedIDs(snapshot.awayOnCourtPlayerIDs, sourceID: sourceID, targetID: targetID)

        var names = game.playerNamesByID
        names[targetID] = targetName
        names[sourceID] = nil

        return SavedGame(
            id: game.id,
            savedAt: game.savedAt,
            snapshot: snapshot,
            homeTeamName: game.homeTeamName,
            awayTeamName: game.awayTeamName,
            homePlayerIDs: remapDedupedIDs(game.homePlayerIDs, sourceID: sourceID, targetID: targetID),
            awayPlayerIDs: remapDedupedIDs(game.awayPlayerIDs, sourceID: sourceID, targetID: targetID),
            playerNamesByID: names
        )
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
        var snapshot = game.snapshot
        let homeChanged = snapshot.homeTeamID == sourceID
        let awayChanged = snapshot.awayTeamID == sourceID
        if homeChanged { snapshot.homeTeamID = targetID }
        if awayChanged { snapshot.awayTeamID = targetID }

        return SavedGame(
            id: game.id,
            savedAt: game.savedAt,
            snapshot: snapshot,
            homeTeamName: homeChanged ? targetName : game.homeTeamName,
            awayTeamName: awayChanged ? targetName : game.awayTeamName,
            homePlayerIDs: game.homePlayerIDs,
            awayPlayerIDs: game.awayPlayerIDs,
            playerNamesByID: game.playerNamesByID
        )
    }
}

private struct StorePayload: Codable {
    var players: [Player]
    var teams: [Team]
    var savedGames: [SavedGame]

    init(players: [Player], teams: [Team], savedGames: [SavedGame] = []) {
        self.players = players
        self.teams = teams
        self.savedGames = savedGames
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        players = try container.decode([Player].self, forKey: .players)
        teams = try container.decode([Team].self, forKey: .teams)
        savedGames = try container.decodeIfPresent([SavedGame].self, forKey: .savedGames) ?? []
    }
}
