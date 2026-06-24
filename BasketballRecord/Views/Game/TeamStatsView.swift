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
                HStack(spacing: 0) {
                    Text(homeName)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    VStack(alignment: .center, spacing: 0) {
                        Text("\(homeStats.points)")
                            .font(.title2.monospacedDigit().weight(.bold))
                        Text(LocalizedStringKey("stats_points_format_short"))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    Text("vs")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    VStack(alignment: .center, spacing: 0) {
                        Text("\(awayStats.points)")
                            .font(.title2.monospacedDigit().weight(.bold))
                        Text(LocalizedStringKey("stats_points_format_short"))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(awayName)
                        .font(.caption.weight(.semibold))
                }
                .padding(.bottom, 4)

                compareRow(label: localized("stats_field_goal"),
                           home: {
                               VStack(alignment: .trailing, spacing: 1) {
                                   HStack(spacing: 0) {
                                       c("\(homeStats.made)", homeStats.made > awayStats.made)
                                           .font(.caption.monospacedDigit())
                                       Text("/\(homeStats.attempts)")
                                           .font(.caption.monospacedDigit())
                                           .foregroundStyle(.secondary)
                                   }
                                   boldC(percent(homeStats.fieldGoalRate), homeStats.fieldGoalRate > awayStats.fieldGoalRate)
                               }
                           },
                           away: {
                               VStack(alignment: .leading, spacing: 1) {
                                   HStack(spacing: 0) {
                                       c("\(awayStats.made)", awayStats.made > homeStats.made)
                                           .font(.caption.monospacedDigit())
                                       Text("/\(awayStats.attempts)")
                                           .font(.caption.monospacedDigit())
                                           .foregroundStyle(.secondary)
                                   }
                                   boldC(percent(awayStats.fieldGoalRate), awayStats.fieldGoalRate > homeStats.fieldGoalRate)
                               }
                           })
                compareRow(label: localized("stat_label_2pt"),
                           home: {
                               VStack(alignment: .trailing, spacing: 1) {
                                   HStack(spacing: 0) {
                                       c("\(homeStats.twoMade)", homeStats.twoMade > awayStats.twoMade)
                                           .font(.caption.monospacedDigit())
                                       Text("/\(homeStats.twoAttempts)")
                                           .font(.caption.monospacedDigit())
                                           .foregroundStyle(.secondary)
                                   }
                                   boldC(percent(homeStats.twoPointRate), homeStats.twoPointRate > awayStats.twoPointRate)
                               }
                           },
                           away: {
                               VStack(alignment: .leading, spacing: 1) {
                                   HStack(spacing: 0) {
                                       c("\(awayStats.twoMade)", awayStats.twoMade > homeStats.twoMade)
                                           .font(.caption.monospacedDigit())
                                       Text("/\(awayStats.twoAttempts)")
                                           .font(.caption.monospacedDigit())
                                           .foregroundStyle(.secondary)
                                   }
                                   boldC(percent(awayStats.twoPointRate), awayStats.twoPointRate > homeStats.twoPointRate)
                               }
                           })
                compareRow(label: localized("stat_label_3pt"),
                           home: {
                               VStack(alignment: .trailing, spacing: 1) {
                                   HStack(spacing: 0) {
                                       c("\(homeStats.threeMade)", homeStats.threeMade > awayStats.threeMade)
                                           .font(.caption.monospacedDigit())
                                       Text("/\(homeStats.threeAttempts)")
                                           .font(.caption.monospacedDigit())
                                           .foregroundStyle(.secondary)
                                   }
                                   boldC(percent(homeStats.threePointRate), homeStats.threePointRate > awayStats.threePointRate)
                               }
                           },
                           away: {
                               VStack(alignment: .leading, spacing: 1) {
                                   HStack(spacing: 0) {
                                       c("\(awayStats.threeMade)", awayStats.threeMade > homeStats.threeMade)
                                           .font(.caption.monospacedDigit())
                                       Text("/\(awayStats.threeAttempts)")
                                           .font(.caption.monospacedDigit())
                                           .foregroundStyle(.secondary)
                                   }
                                   boldC(percent(awayStats.threePointRate), awayStats.threePointRate > homeStats.threePointRate)
                               }
                           })
                compareRow(label: localized("stat_label_free_throw"),
                           home: {
                               VStack(alignment: .trailing, spacing: 1) {
                                   HStack(spacing: 0) {
                                       c("\(homeStats.allFreeThrowMade)", homeStats.allFreeThrowMade > awayStats.allFreeThrowMade)
                                           .font(.caption.monospacedDigit())
                                       Text("/\(homeStats.allFreeThrowAttempts)")
                                           .font(.caption.monospacedDigit())
                                           .foregroundStyle(.secondary)
                                   }
                                   boldC(percent(homeStats.freeThrowRate), homeStats.freeThrowRate > awayStats.freeThrowRate)
                               }
                           },
                           away: {
                               VStack(alignment: .leading, spacing: 1) {
                                   HStack(spacing: 0) {
                                       c("\(awayStats.allFreeThrowMade)", awayStats.allFreeThrowMade > homeStats.allFreeThrowMade)
                                           .font(.caption.monospacedDigit())
                                       Text("/\(awayStats.allFreeThrowAttempts)")
                                           .font(.caption.monospacedDigit())
                                           .foregroundStyle(.secondary)
                                   }
                                   boldC(percent(awayStats.freeThrowRate), awayStats.freeThrowRate > homeStats.freeThrowRate)
                               }
                           })
                compareRow(label: localized("stats_rebound_detail"),
                           home: {
                               HStack(spacing: 0) {
                                   c("\(homeStats.totalRebounds)", homeStats.totalRebounds > awayStats.totalRebounds)
                                       .font(.caption.monospacedDigit())
                                   Text("/")
                                       .font(.caption.monospacedDigit())
                                       .foregroundStyle(.secondary)
                                   c("\(homeStats.offensiveRebounds)", homeStats.offensiveRebounds > awayStats.offensiveRebounds)
                                       .font(.caption.monospacedDigit())
                                   Text("/")
                                       .font(.caption.monospacedDigit())
                                       .foregroundStyle(.secondary)
                                   c("\(homeStats.defensiveRebounds)", homeStats.defensiveRebounds > awayStats.defensiveRebounds)
                                       .font(.caption.monospacedDigit())
                               }
                           },
                           away: {
                               HStack(spacing: 0) {
                                   c("\(awayStats.totalRebounds)", awayStats.totalRebounds > homeStats.totalRebounds)
                                       .font(.caption.monospacedDigit())
                                   Text("/")
                                       .font(.caption.monospacedDigit())
                                       .foregroundStyle(.secondary)
                                   c("\(awayStats.offensiveRebounds)", awayStats.offensiveRebounds > homeStats.offensiveRebounds)
                                       .font(.caption.monospacedDigit())
                                   Text("/")
                                       .font(.caption.monospacedDigit())
                                       .foregroundStyle(.secondary)
                                   c("\(awayStats.defensiveRebounds)", awayStats.defensiveRebounds > homeStats.defensiveRebounds)
                                       .font(.caption.monospacedDigit())
                               }
                           })
                compareRow(label: localized("stats_assist_steal_block"),
                           home: {
                               HStack(spacing: 0) {
                                   c("\(homeStats.assists)", homeStats.assists > awayStats.assists)
                                       .font(.caption.monospacedDigit())
                                   Text("/")
                                       .font(.caption.monospacedDigit())
                                       .foregroundStyle(.secondary)
                                   c("\(homeStats.steals)", homeStats.steals > awayStats.steals)
                                       .font(.caption.monospacedDigit())
                                   Text("/")
                                       .font(.caption.monospacedDigit())
                                       .foregroundStyle(.secondary)
                                   c("\(homeStats.blocks)", homeStats.blocks > awayStats.blocks)
                                       .font(.caption.monospacedDigit())
                               }
                           },
                           away: {
                               HStack(spacing: 0) {
                                   c("\(awayStats.assists)", awayStats.assists > homeStats.assists)
                                       .font(.caption.monospacedDigit())
                                   Text("/")
                                       .font(.caption.monospacedDigit())
                                       .foregroundStyle(.secondary)
                                   c("\(awayStats.steals)", awayStats.steals > homeStats.steals)
                                       .font(.caption.monospacedDigit())
                                   Text("/")
                                       .font(.caption.monospacedDigit())
                                       .foregroundStyle(.secondary)
                                   c("\(awayStats.blocks)", awayStats.blocks > homeStats.blocks)
                                       .font(.caption.monospacedDigit())
                               }
                           })
                compareRow(label: localized("stats_foul_turnover"),
                           home: {
                               HStack(spacing: 0) {
                                   c("\(homeFouls)", homeFouls < awayFouls)
                                       .font(.caption.monospacedDigit())
                                   Text("/")
                                       .font(.caption.monospacedDigit())
                                       .foregroundStyle(.secondary)
                                   c("\(homeStats.turnovers)", homeStats.turnovers < awayStats.turnovers)
                                       .font(.caption.monospacedDigit())
                               }
                           },
                           away: {
                               HStack(spacing: 0) {
                                   c("\(awayFouls)", awayFouls < homeFouls)
                                       .font(.caption.monospacedDigit())
                                   Text("/")
                                       .font(.caption.monospacedDigit())
                                       .foregroundStyle(.secondary)
                                   c("\(awayStats.turnovers)", awayStats.turnovers < homeStats.turnovers)
                                       .font(.caption.monospacedDigit())
                               }
                           })
                compareRow(label: "eFG / TS",
                           home: {
                               HStack(spacing: 0) {
                                   c(percent(homeStats.effectiveFieldGoalRate), homeStats.effectiveFieldGoalRate > awayStats.effectiveFieldGoalRate)
                                   Text(" / ")
                                       .foregroundStyle(.secondary)
                                   c(percent(homeStats.trueShootingRate), homeStats.trueShootingRate > awayStats.trueShootingRate)
                               }
                               .font(.caption.monospacedDigit())
                           },
                           away: {
                               HStack(spacing: 0) {
                                   c(percent(awayStats.effectiveFieldGoalRate), awayStats.effectiveFieldGoalRate > homeStats.effectiveFieldGoalRate)
                                   Text(" / ")
                                       .foregroundStyle(.secondary)
                                   c(percent(awayStats.trueShootingRate), awayStats.trueShootingRate > homeStats.trueShootingRate)
                               }
                               .font(.caption.monospacedDigit())
                           })
                compareRow(label: localized("stats_points_per_shot"),
                           home: {
                               c(String(format: "%.2f", homeStats.pointsPerShot), homeStats.pointsPerShot > awayStats.pointsPerShot)
                                   .font(.caption.monospacedDigit())
                           },
                           away: {
                               c(String(format: "%.2f", awayStats.pointsPerShot), awayStats.pointsPerShot > homeStats.pointsPerShot)
                                   .font(.caption.monospacedDigit())
                           })
            }
            .padding(10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            .padding(.leading, -20)
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

    private func compareRow<Home: View, Away: View>(
        label: String,
        @ViewBuilder home: () -> Home,
        @ViewBuilder away: () -> Away
    ) -> some View {
        HStack(spacing: 0) {
            home()
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .frame(width: 80)
            away()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func c(_ text: String, _ isBetter: Bool) -> Text {
        Text(text).foregroundStyle(isBetter ? .blue : .secondary)
    }

    private func boldC(_ text: String, _ isBetter: Bool) -> Text {
        Text(text).font(.caption2.monospacedDigit().weight(.bold)).foregroundStyle(isBetter ? .blue : .primary)
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
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
                    statTile(NSLocalizedString("stats_full_misc_format", comment: "Rebounds assists fouls blocks steals turnovers"), "\(stats.totalRebounds)(\(stats.offensiveRebounds)-\(stats.defensiveRebounds)) / \(stats.assists) / \(stats.fouls) / \(stats.blocks) / \(stats.steals) / \(stats.turnovers)", "")
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
                Text(String(format: NSLocalizedString("stats_rebound_short_format", comment: "Rebound short format"), stats.totalRebounds))
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
        String(format: "%.1f%%", value * 100)
    }

    private var plusMinusText: String {
        plusMinus > 0 ? "+\(plusMinus)" : "\(plusMinus)"
    }

    private var pointsPerShotText: String {
        String(format: "%.2f", stats.pointsPerShot)
    }
}

