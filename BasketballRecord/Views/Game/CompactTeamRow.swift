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

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(team?.name ?? side.displayName)
                        .font(.caption.weight(.semibold))
                    Text(side == .home ? LocalizedStringKey("team_home_default") : LocalizedStringKey("team_away_default"))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(score)")
                        .font(.title.monospacedDigit().weight(.bold))
                        .foregroundStyle(isScorePulsing ? GamePalette.period : GamePalette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .layoutPriority(1)
                        .scaleEffect(isScorePulsing ? 1.15 : 1)
                        .animation(.spring(response: 0.2, dampingFraction: 0.72), value: isScorePulsing)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(foulLabel)
                            .font(.caption2)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                        Text("\(fouls)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                    .frame(maxWidth: 48, alignment: .leading)
                    .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            if teamStatsMode {
                Button {
                    if let teamID = team?.id {
                        onSelect(Player(id: teamID, name: team?.name ?? ""), side)
                    }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 52, height: 52)
                                .overlay(Circle().stroke(selectedPlayerID == team?.id && selectedSide == side ? GamePalette.selectedBorder : Color.primary.opacity(0.3), lineWidth: selectedPlayerID == team?.id && selectedSide == side ? 3 : 1.5))
                            Image(systemName: "chart.bar.fill")
                                .font(.title3)
                                .foregroundStyle(GamePalette.text)
                        }
                        Text(team?.name ?? "")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .frame(width: 72)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 7)
            } else if players.isEmpty {
                Text(LocalizedStringKey("text_no_players"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(players) { player in
                            let isSelected = selectedPlayerID == player.id && selectedSide == side
                            let avatarSize: CGFloat = isSelected ? 52 : 42

                            Button {
                                onSelect(player, side)
                            } label: {
                                VStack(spacing: 3) {
                                    ZStack(alignment: .bottomTrailing) {
                                        PlayerAvatarView(player: player, size: avatarSize)
                                            .overlay {
                                                if onCourtPlayerIDs.contains(player.id) {
                                                    Circle().stroke(GamePalette.onCourtBorder, lineWidth: 2)
                                                }
                                                if isSelected {
                                                    Circle().stroke(GamePalette.selectedBorder, lineWidth: 3)
                                                }
                                            }
                                            .animation(.easeInOut(duration: 0.15), value: isSelected)

                                        if onCourtPlayerIDs.contains(player.id) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(.white, GamePalette.make)
                                                .background(Circle().fill(.white))
                                        }
                                    }
                                    Text(player.number.isEmpty ? player.name : "No\(player.number) \(player.name)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(onCourtPlayerIDs.contains(player.id) ? .primary : .secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(7.0 / 12.0)
                                        .frame(width: 64)
                                }
                                .opacity(isSelected ? 1 : 0.6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 7)
                    .padding(.trailing, 8)
                }
            }
        }
        .frame(height: 78)
        .padding(.horizontal, 12)
        .background(GamePalette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.white.opacity(0.85), lineWidth: 1))
        .padding(.horizontal)

    }
}
