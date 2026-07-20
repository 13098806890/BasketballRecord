import SwiftUI

struct SubstitutionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var side: TeamSide

    var homeTeamName: String
    var awayTeamName: String
    var homePlayers: [Player]
    var awayPlayers: [Player]
    var homeOnCourtIDs: [UUID]
    var awayOnCourtIDs: [UUID]
    var courtPlayerCount: Int
    var onConfirm: (TeamSide, [UUID]) -> Void

    @State private var editedOnCourtIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker(LocalizedStringKey("picker_team"), selection: $side) {
                        Text(homeTeamName).tag(TeamSide.home)
                        Text(awayTeamName).tag(TeamSide.away)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: side) { _, _ in
                        resetToCurrent()
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("section_on_court", comment: "On court"))
                            .font(.headline)
                        Spacer()
                        Text(String(format: NSLocalizedString("count_on_court_format", comment: "On court count"), editedOnCourtIDs.count, courtPlayerCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if onCourtPlayers.isEmpty {
                        Text(LocalizedStringKey("text_no_players"))
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(onCourtPlayers) { player in
                                    SelectablePlayerAvatarButton(
                                        player: player,
                                        isSelected: true,
                                        badge: NSLocalizedString("badge_on_court", comment: "On-court badge")
                                    ) {
                                        editedOnCourtIDs.remove(player.id)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("section_bench", comment: "Bench"))
                        .font(.headline)

                    if benchPlayers.isEmpty {
                        Text(LocalizedStringKey("text_no_bench_players"))
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(benchPlayers) { player in
                                    SelectablePlayerAvatarButton(
                                        player: player,
                                        isSelected: false
                                    ) {
                                        guard editedOnCourtIDs.count < courtPlayerCount else { return }
                                        editedOnCourtIDs.insert(player.id)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle(LocalizedStringKey("nav_substitution"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_record")) {
                        let sortedIDs = teamPlayers.filter { editedOnCourtIDs.contains($0.id) }.map(\.id)
                        onConfirm(side, sortedIDs)
                        dismiss()
                    }
                    .disabled(editedOnCourtIDs.count != courtPlayerCount)
                }
            }
        }
        .onAppear {
            resetToCurrent()
        }
    }

    private var teamPlayers: [Player] {
        side == .home ? homePlayers : awayPlayers
    }

    private var onCourtPlayers: [Player] {
        teamPlayers.filter { editedOnCourtIDs.contains($0.id) }
    }

    private var benchPlayers: [Player] {
        teamPlayers.filter { !editedOnCourtIDs.contains($0.id) }
    }

    private var currentOnCourtIDs: [UUID] {
        side == .home ? homeOnCourtIDs : awayOnCourtIDs
    }

    private func resetToCurrent() {
        editedOnCourtIDs = Set(currentOnCourtIDs)
    }
}

struct LateArrivalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var side: TeamSide
    @Binding var incomingPlayerID: UUID?

    var homeTeamName: String
    var awayTeamName: String
    var homeUnregisteredPlayers: [Player]
    var awayUnregisteredPlayers: [Player]
    var onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker(LocalizedStringKey("picker_team"), selection: $side) {
                        Text(homeTeamName).tag(TeamSide.home)
                        Text(awayTeamName).tag(TeamSide.away)
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(NSLocalizedString("section_add_to_roster", comment: "Add to roster"), selectedName(for: incomingPlayerID))
                    if incomingPlayers.isEmpty {
                        Text(LocalizedStringKey("text_no_late_arrival_players"))
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(incomingPlayers) { player in
                                    SelectablePlayerAvatarButton(
                                        player: player,
                                        isSelected: incomingPlayerID == player.id,
                                        badge: incomingPlayerID == player.id ? NSLocalizedString("badge_on_court", comment: "On-court badge") : nil
                                    ) {
                                        incomingPlayerID = player.id
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
            .navigationTitle(LocalizedStringKey("nav_late_arrival"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_record")) {
                        onConfirm()
                        dismiss()
                    }
                    .disabled(incomingPlayerID == nil)
                }
            }
        }
    }

    private var incomingPlayers: [Player] {
        side == .home ? homeUnregisteredPlayers : awayUnregisteredPlayers
    }

    private func selectedName(for id: UUID?) -> String {
        guard let id else { return NSLocalizedString("text_not_selected", comment: "Not selected") }
        return incomingPlayers.first(where: { $0.id == id })?.name ?? NSLocalizedString("text_not_selected", comment: "Not selected")
    }

    private func sectionHeader(_ title: String, _ detail: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
