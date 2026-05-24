import SwiftUI

struct RosterView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showingPlayerEditor = false
    @State private var showingTeamEditor = false
    @State private var editingPlayer: Player?
    @State private var editingTeam: Team?

    var body: some View {
        NavigationStack {
            List {
                Section("球员") {
                    if store.players.isEmpty {
                        ContentUnavailableView("还没有球员", systemImage: "person.crop.circle.badge.plus")
                    }

                    ForEach(store.players) { player in
                        Button {
                            editingPlayer = player
                        } label: {
                            HStack(spacing: 12) {
                                PlayerAvatarView(player: player, size: 44)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(player.name)
                                        .font(.headline)
                                    Text(playerSubtitle(player))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete(perform: store.deletePlayers)
                }

                Section("球队") {
                    if store.teams.isEmpty {
                        ContentUnavailableView("还没有球队", systemImage: "person.3.fill")
                    }

                    ForEach(store.teams) { team in
                        Button {
                            editingTeam = team
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(team.name)
                                    .font(.headline)
                                Text(team.playerIDs.compactMap { store.player(for: $0)?.name }.joined(separator: "、"))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .onDelete(perform: store.deleteTeams)
                }
            }
            .navigationTitle("配置")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingTeamEditor = true
                    } label: {
                        Label("新建球队", systemImage: "person.3.fill")
                    }

                    Button {
                        showingPlayerEditor = true
                    } label: {
                        Label("新建球员", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showingPlayerEditor) {
                PlayerEditorView(player: nil)
            }
            .sheet(item: $editingPlayer) { player in
                PlayerEditorView(player: player)
            }
            .sheet(isPresented: $showingTeamEditor) {
                TeamEditorView(team: nil)
            }
            .sheet(item: $editingTeam) { team in
                TeamEditorView(team: team)
            }
        }
    }

    private func playerSubtitle(_ player: Player) -> String {
        var parts: [String] = []
        if !player.number.isEmpty { parts.append("#\(player.number)") }
        if !player.height.isEmpty { parts.append("\(player.height)cm") }
        if !player.weight.isEmpty { parts.append("\(player.weight)kg") }
        return parts.isEmpty ? "未填写号码、身高、体重" : parts.joined(separator: " · ")
    }
}
