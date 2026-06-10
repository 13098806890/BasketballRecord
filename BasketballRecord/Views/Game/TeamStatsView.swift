import SwiftUI

enum TeamStatsCardStyle {
    case scoreboard
    case record
}

struct TeamStatsDisclosureView: View {
    var homeName: String
    var awayName: String
    var homeStats: PlayerStats
    var awayStats: PlayerStats
    var homeFouls: Int
    var awayFouls: Int
    var style: TeamStatsCardStyle = .scoreboard

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 6) {
                HStack {
                    Text(homeName)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text(String(format: NSLocalizedString("stats_points_format", comment: "Points format"), homeStats.points))
                        .font(.title.monospacedDigit().weight(.bold))
                    Text("vs")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(String(format: NSLocalizedString("stats_points_format", comment: "Points format"), awayStats.points))
                        .font(.title.monospacedDigit().weight(.bold))
                    Spacer()
                    Text(awayName)
                        .font(.caption.weight(.semibold))
                }
                .padding(.bottom, 4)

                compareRow(label: localized("stats_field_goal"),
                           home: "\(homeStats.made)/\(homeStats.attempts)", homePct: percent(homeStats.fieldGoalRate),
                           away: "\(awayStats.made)/\(awayStats.attempts)", awayPct: percent(awayStats.fieldGoalRate))
                compareRow(label: localized("stat_label_2pt"),
                           home: "\(homeStats.twoMade)/\(homeStats.twoAttempts)", homePct: percent(homeStats.twoPointRate),
                           away: "\(awayStats.twoMade)/\(awayStats.twoAttempts)", awayPct: percent(awayStats.twoPointRate))
                compareRow(label: localized("stat_label_3pt"),
                           home: "\(homeStats.threeMade)/\(homeStats.threeAttempts)", homePct: percent(homeStats.threePointRate),
                           away: "\(awayStats.threeMade)/\(awayStats.threeAttempts)", awayPct: percent(awayStats.threePointRate))
                compareRow(label: localized("stat_label_free_throw"),
                           home: "\(homeStats.allFreeThrowMade)/\(homeStats.allFreeThrowAttempts)", homePct: percent(homeStats.freeThrowRate),
                           away: "\(awayStats.allFreeThrowMade)/\(awayStats.allFreeThrowAttempts)", awayPct: percent(awayStats.freeThrowRate))
                compareRow(label: "\(localized("stats_rebound_assist_steal_block")) / \(localized("stats_foul_turnover"))",
                           home: "\(homeStats.rebounds)/\(homeStats.assists)/\(homeStats.steals)/\(homeStats.blocks) · \(homeFouls)/\(homeStats.turnovers)",
                           homePct: nil,
                           away: "\(awayStats.rebounds)/\(awayStats.assists)/\(awayStats.steals)/\(awayStats.blocks) · \(awayFouls)/\(awayStats.turnovers)",
                           awayPct: nil)
                compareRow(label: "eFG / TS",
                           home: "\(percent(homeStats.effectiveFieldGoalRate)) / \(percent(homeStats.trueShootingRate))",
                           homePct: nil,
                           away: "\(percent(awayStats.effectiveFieldGoalRate)) / \(percent(awayStats.trueShootingRate))",
                           awayPct: nil)
                compareRow(label: localized("stats_points_per_shot"),
                           home: String(format: "%.2f", homeStats.pointsPerShot),
                           homePct: nil,
                           away: String(format: "%.2f", awayStats.pointsPerShot),
                           awayPct: nil)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        } label: {
            HStack {
                Text(LocalizedStringKey("label_team_stats"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(homeStats.points)-\(awayStats.points)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func compareRow(label: String, home: String, homePct: String?, away: String, awayPct: String?) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(home)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let homePct {
                    Text(homePct)
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .frame(width: 64)

            VStack(alignment: .leading, spacing: 1) {
                Text(away)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                if let awayPct {
                    Text(awayPct)
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}

private struct CollapsibleStatsView: View {
    var player: Player?
    var stats: PlayerStats
    var plusMinus: Int
    var playingTime: String
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    statTile(NSLocalizedString("stats_field_goal", comment: "Field goal"), "\(stats.made)/\(stats.attempts)", percent(stats.fieldGoalRate))
                    statTile(NSLocalizedString("stats_two_point", comment: "Two-point"), "\(stats.twoMade)/\(stats.twoAttempts)", percent(stats.twoPointRate))
                    statTile(NSLocalizedString("stats_three_point", comment: "Three-point"), "\(stats.threeMade)/\(stats.threeAttempts)", percent(stats.threePointRate))
                }

                HStack(spacing: 8) {
                    statTile(NSLocalizedString("stats_free_throw", comment: "Free throw"), "\(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)", percent(stats.freeThrowRate))
                    statTile(NSLocalizedString("stats_full_misc_format", comment: "Rebounds assists fouls blocks steals turnovers"), "\(stats.rebounds) / \(stats.assists) / \(stats.fouls) / \(stats.blocks) / \(stats.steals) / \(stats.turnovers)", "")
                    statTile(NSLocalizedString("stats_advanced", comment: "Advanced stats"), "eFG \(percent(stats.effectiveFieldGoalRate))", "TS \(percent(stats.trueShootingRate))")
                }

                HStack(spacing: 8) {
                    statTile(NSLocalizedString("stats_points_per_shot", comment: "Points per shot"), pointsPerShotText, "PTS/FGA")
                    statTile(NSLocalizedString("stats_plus_minus", comment: "Plus minus"), plusMinusText, NSLocalizedString("stats_plus_minus_footnote", comment: "Plus minus footnote"))
                    statTile(NSLocalizedString("stats_playing_time", comment: "Playing time"), playingTime, "")
                }
            }
            .padding(.top, 8)
        } label: {
            HStack(spacing: 10) {
                Text(player?.name ?? NSLocalizedString("select_player", comment: "Select player"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: NSLocalizedString("stats_points_format", comment: "Points format"), stats.points))
                Text(playingTime)
                Text(String(format: NSLocalizedString("stats_rebound_short_format", comment: "Rebound short format"), stats.rebounds))
                Text(String(format: NSLocalizedString("stats_assist_short_format", comment: "Assist short format"), stats.assists))
                Text(String(format: NSLocalizedString("stats_foul_short_format", comment: "Foul short format"), stats.fouls))
                Text(String(format: NSLocalizedString("stats_block_short_format", comment: "Block short format"), stats.blocks))
                Text(String(format: NSLocalizedString("stats_steal_short_format", comment: "Steal short format"), stats.steals))
                Text(String(format: NSLocalizedString("stats_turnover_short_format", comment: "Turnover short format"), stats.turnovers))
            }
            .font(.caption.monospacedDigit())
        }
        .padding(10)
        .background(GamePalette.surface, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.white.opacity(0.85), lineWidth: 1))
    }

    private func statTile(_ title: String, _ value: String, _ detail: String, footnote: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.6)
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
            if !detail.isEmpty {
                Text(detail)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private var plusMinusText: String {
        plusMinus > 0 ? "+\(plusMinus)" : "\(plusMinus)"
    }

    private var pointsPerShotText: String {
        String(format: "%.2f", stats.pointsPerShot)
    }
}

