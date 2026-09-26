import SwiftUI

struct CompactTeamRow: View {
    var side: TeamSide
    var team: Team?
    var players: [Player]
    var score: Int
    var isScorePulsing: Bool = false
    var fouls: Int
    var foulLabel: String
    var onCourtPlayerIDs: [UUID]
    var selectedPlayerID: UUID?
    var selectedSide: TeamSide
    var onSelect: (Player, TeamSide) -> Void
    var teamStatsMode: Bool = false

    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var usesRoomyLayout: Bool {
        verticalSizeClass != .compact && UIScreen.main.bounds.height >= 780
    }

    private var scoreHeaderVerticalPadding: CGFloat {
        usesRoomyLayout ? 10 : 7
    }

    private var avatarSize: CGFloat {
        usesRoomyLayout ? 38 : 34
    }

    private var playerRows: [[Player]] {
        guard !players.isEmpty else { return [] }
        if players.count <= 3 {
            return [players]
        }
        if players.count == 4 {
            return [Array(players.prefix(2)), Array(players.dropFirst(2))]
        }

        return stride(from: 0, to: players.count, by: 3).map { start in
            Array(players.dropFirst(start).prefix(3))
        }
    }

    private var scoreboardColor: Color {
        side == .home ? GamePalette.homeScoreboard : GamePalette.awayScoreboard
    }

    private var selectionColor: Color {
        side == .home ? GamePalette.homeScoreboard : GamePalette.selectedBorder
    }

    var body: some View {
        VStack(spacing: usesRoomyLayout ? 7 : 5) {
            scoreHeader

            if teamStatsMode {
                teamStatsButton
            } else if playerRows.isEmpty {
                Text(LocalizedStringKey("text_no_players"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: usesRoomyLayout ? 5 : 3) {
                    ForEach(Array(playerRows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: usesRoomyLayout ? 6 : 4) {
                            ForEach(row) { player in
                                playerButton(player)
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, usesRoomyLayout ? 10 : 7)
        .background(GamePalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.85), lineWidth: 1))
        .padding(.horizontal)
    }

    private var scoreHeader: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(team?.name ?? side.displayName)
                    .font(.system(size: usesRoomyLayout ? 16 : 14, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                Text(side == .home ? LocalizedStringKey("team_home_default") : LocalizedStringKey("team_away_default"))
                    .font(.system(size: usesRoomyLayout ? 11 : 10, weight: .medium))
                    .opacity(0.78)
            }
            .frame(minWidth: 52, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Text("\(score)")
                .font(.system(size: usesRoomyLayout ? 34 : 30, weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(minWidth: usesRoomyLayout ? 52 : 44, alignment: .trailing)
                .layoutPriority(1)
                .scaleEffect(isScorePulsing ? 1.08 : 1)
                .animation(.spring(response: 0.2, dampingFraction: 0.72), value: isScorePulsing)

            VStack(alignment: .leading, spacing: 1) {
                Text(foulLabel)
                    .font(.system(size: usesRoomyLayout ? 10 : 9, weight: .medium))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text("\(fouls)")
                    .font(.system(size: usesRoomyLayout ? 15 : 13, weight: .bold).monospacedDigit())
            }
            .frame(width: usesRoomyLayout ? 46 : 40, alignment: .leading)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, scoreHeaderVerticalPadding)
        .background(scoreboardColor, in: RoundedRectangle(cornerRadius: 10))
    }

    private var teamStatsButton: some View {
        Button {
            if let teamID = team?.id {
                onSelect(Player(id: teamID, name: team?.name ?? ""), side)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: side == .home ? "crown.fill" : "bolt.fill")
                Text(team?.name ?? "")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text(LocalizedStringKey("label_team_stats_mode"))
                    .foregroundStyle(.secondary)
            }
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 30)
            .padding(.horizontal, 10)
            .background(GamePalette.surface, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(GamePalette.text)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(selectedPlayerID == team?.id && selectedSide == side ? GamePalette.selectedBorder : Color.primary.opacity(0.15), lineWidth: selectedPlayerID == team?.id && selectedSide == side ? 2 : 1)
        )
    }

    private func playerButton(_ player: Player) -> some View {
        let isSelected = selectedPlayerID == player.id && selectedSide == side

        return Button {
            onSelect(player, side)
        } label: {
            VStack(spacing: 2) {
                ZStack(alignment: .bottomTrailing) {
                    PlayerAvatarView(player: player, size: avatarSize, isSelected: isSelected)
                        .overlay {
                            Circle().stroke(isSelected ? selectionColor : Color.primary.opacity(0.22), lineWidth: isSelected ? 3 : 1)
                        }

                    if !player.number.isEmpty {
                        Text("#\(player.number)")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 2)
                            .background(scoreboardColor.opacity(0.72), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(.white.opacity(0.45), lineWidth: 0.5)
                            }
                            .padding(2)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    }
                }

                Text(player.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(onCourtPlayerIDs.contains(player.id) ? GamePalette.text : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity, minHeight: usesRoomyLayout ? 58 : 52)
            .padding(.vertical, 3)
            .contentShape(Rectangle())
            .opacity(isSelected ? 1 : 0.72)
        }
        .buttonStyle(.plain)
    }
}
