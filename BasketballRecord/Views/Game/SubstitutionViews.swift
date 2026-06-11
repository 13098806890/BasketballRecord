import SwiftUI

struct SubstitutionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var side: TeamSide
    @Binding var outgoingPlayerID: UUID?
    @Binding var incomingPlayerID: UUID?

    var homeTeamName: String
    var awayTeamName: String
    var homeOnCourtPlayers: [Player]
    var homeBenchPlayers: [Player]
    var awayOnCourtPlayers: [Player]
    var awayBenchPlayers: [Player]
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
                    .onChange(of: side) { _, _ in
                        outgoingPlayerID = nil
                        incomingPlayerID = nil
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(NSLocalizedString("section_substitute_out", comment: "Substitute out"), selectedName(for: outgoingPlayerID))
                    if onCourtPlayers.isEmpty {
                        Text(LocalizedStringKey("text_no_on_court_players"))
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                            ForEach(onCourtPlayers) { player in
                                    SelectablePlayerAvatarButton(
                                        player: player,
                                        isSelected: outgoingPlayerID == player.id,
                                        badge: outgoingPlayerID == player.id ? NSLocalizedString("badge_sub_out", comment: "Substitute out badge") : nil
                                    ) {
                                        outgoingPlayerID = player.id
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(NSLocalizedString("section_substitute_in", comment: "Substitute in"), selectedName(for: incomingPlayerID))
                    if benchPlayers.isEmpty {
                        Text(LocalizedStringKey("text_no_bench_to_sub_in"))
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                            ForEach(benchPlayers) { player in
                                    SelectablePlayerAvatarButton(
                                        player: player,
                                        isSelected: incomingPlayerID == player.id,
                                        badge: incomingPlayerID == player.id ? NSLocalizedString("badge_sub_in", comment: "Substitute in badge") : nil
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
            .navigationTitle(LocalizedStringKey("nav_substitution"))
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
                    .disabled(outgoingPlayerID == nil || incomingPlayerID == nil || outgoingPlayerID == incomingPlayerID)
                }
            }
        }
    }

    private var onCourtPlayers: [Player] {
        side == .home ? homeOnCourtPlayers : awayOnCourtPlayers
    }

    private var benchPlayers: [Player] {
        side == .home ? homeBenchPlayers : awayBenchPlayers
    }

    private func selectedName(for id: UUID?) -> String {
        guard let id else { return NSLocalizedString("text_not_selected", comment: "Not selected") }
        return (onCourtPlayers + benchPlayers).first(where: { $0.id == id })?.name ?? NSLocalizedString("text_not_selected", comment: "Not selected")
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
