import SwiftUI

@MainActor
final class AppStore: ObservableObject {
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
        let homeTeam = team(for: snapshot.homeTeamID)
        let awayTeam = team(for: snapshot.awayTeamID)
        let gamePlayerIDs = (homeTeam?.playerIDs ?? []) + (awayTeam?.playerIDs ?? [])
        let playerNames = Dictionary(uniqueKeysWithValues: gamePlayerIDs.compactMap { id in
            player(for: id).map { (id, $0.name) }
        })

        let game = SavedGame(
            savedAt: Date(),
            snapshot: snapshot,
            homeTeamName: homeTeam?.name ?? "主队",
            awayTeamName: awayTeam?.name ?? "客队",
            homePlayerIDs: homeTeam?.playerIDs ?? [],
            awayPlayerIDs: awayTeam?.playerIDs ?? [],
            playerNamesByID: playerNames
        )
        savedGames.insert(game, at: 0)
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

    func decodeGamePackage(from base64: String) -> ExportedGamePackage? {
        let trimmed = base64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed) else { return nil }
        return try? JSONDecoder().decode(ExportedGamePackage.self, from: data)
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
