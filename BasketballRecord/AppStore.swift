import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var players: [Player] = [] {
        didSet { save() }
    }

    @Published var teams: [Team] = [] {
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

    private func save() {
        let payload = StorePayload(players: players, teams: teams)
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
}

private struct StorePayload: Codable {
    var players: [Player]
    var teams: [Team]
}
