import SwiftUI

struct PlayerGameDetailView: View {
    var game: SavedGame
    var playerID: UUID
    @State private var selectedPeriod: Int? = nil
    @State private var periodAnalysis = SavedGamePeriodAnalysis()

    private var displayStats: PlayerStats {
        guard let selectedPeriod else {
            return game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
        }
        return periodAnalysis.statsByPeriod[selectedPeriod]?[playerID] ?? PlayerStats()
    }

    private var displayLogs: [PeriodAwareLog] {
        periodAnalysis.playerLogs(for: playerID, period: selectedPeriod)
    }

    var body: some View {
        List {
            if game.snapshot.periodCount > 1 {
                Section(LocalizedStringKey("section_data_range")) {
                    Picker(LocalizedStringKey("picker_period"), selection: $selectedPeriod) {
                        Text(LocalizedStringKey("data_range_full")).tag(Optional<Int>.none)
                        ForEach(1...game.snapshot.periodCount, id: \.self) { period in
                            Text(game.periodDisplayName(period)).tag(Optional(period))
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section {
                HStack {
                    Text(playerName)
                        .font(.headline)
                    Spacer()
                    Text(String(format: NSLocalizedString("career_points_format", comment: "Points format"), displayStats.points))
                        .font(.title2.monospacedDigit().weight(.bold))
                }
                statLine("stat_label_role", roleText)
                statLine("stat_label_playing_time_value", playingTimeText)
            }

            Section(LocalizedStringKey("stats_field_goal")) {
                statLine("stats_field_goal", String(format: NSLocalizedString("stat_format_attempts", comment: "Attempts format"), displayStats.made, displayStats.attempts))
                statLine("stat_label_fg_rate", percent(displayStats.fieldGoalRate))
                statLine("stat_label_2pt", String(format: NSLocalizedString("stat_format_attempts", comment: "Attempts format"), displayStats.twoMade, displayStats.twoAttempts))
                statLine("stat_label_2pt_rate", percent(displayStats.twoPointRate))
                statLine("stat_label_3pt", String(format: NSLocalizedString("stat_format_attempts", comment: "Attempts format"), displayStats.threeMade, displayStats.threeAttempts))
                statLine("stat_label_3pt_rate", percent(displayStats.threePointRate))
            }

            Section(LocalizedStringKey("stats_free_throw")) {
                statLine("stats_free_throw", String(format: NSLocalizedString("stat_format_attempts", comment: "Attempts format"), displayStats.allFreeThrowMade, displayStats.allFreeThrowAttempts))
                statLine("stat_label_fg_rate", percent(displayStats.freeThrowRate))
                statLine("stat_label_bonus", String(format: NSLocalizedString("stat_format_attempts", comment: "Attempts format"), displayStats.bonusFreeThrowMade, displayStats.bonusFreeThrowAttempts))
            }

            Section(LocalizedStringKey("section_other_stats")) {
                statLine("stat_label_full_misc", String(format: NSLocalizedString("stat_format_full_misc", comment: "Full misc format"), displayStats.totalRebounds, displayStats.assists, displayStats.fouls, displayStats.blocks, displayStats.steals, displayStats.turnovers))
            }

            Section(LocalizedStringKey("section_advanced_stats")) {
                statLine("stats_plus_minus", plusMinusText)
                statLine("stat_label_efg_ts", "\(percent(displayStats.effectiveFieldGoalRate)) / \(percent(displayStats.trueShootingRate))")
                statLine("stats_points_per_shot", String(format: "%.2f", displayStats.pointsPerShot))
            }

        }
        .navigationTitle(playerName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: rebuildPeriodAnalysis)
    }

    private var playerName: String {
        game.playerNamesByID[playerID] ?? NSLocalizedString("unknown_player", comment: "Unknown player")
    }

    private func statLine(_ titleKey: String, _ value: String) -> some View {
        HStack {
            Text(LocalizedStringKey(titleKey))
            Spacer()
            Text(value)
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private var playingTimeText: String {
        if let sp = selectedPeriod {
            if let periodTime = game.playingTimeByPeriod()[sp]?[playerID], periodTime > 0 {
                return GameView.durationFormatter(periodTime)
            }
            return "--:--"
        }
        return GameView.durationFormatter(game.snapshot.playingSecondsByPlayerID[playerID, default: 0])
    }

    private var plusMinusText: String {
        guard selectedPeriod == nil else { return "--" }
        let value = game.snapshot.plusMinusByPlayerID[playerID, default: 0]
        return value > 0 ? "+\(value)" : "\(value)"
    }

    private var roleText: String {
        game.role(of: playerID)?.title ?? NSLocalizedString("unrecorded_role", comment: "Unrecorded role")
    }

    private func rebuildPeriodAnalysis() {
        let analyzer = SavedGameAnalyzer(game: game) { name in
            game.playerNamesByID.first(where: { $0.value == name })?.key
        }
        periodAnalysis = analyzer.analyze()
    }
}
