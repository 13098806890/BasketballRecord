import SwiftUI

struct GameSetupConfig {
    var homeTeamID: UUID
    var awayTeamID: UUID
    var homeStarterIDs: [UUID]
    var awayStarterIDs: [UUID]
    var homeBenchIDs: [UUID]
    var awayBenchIDs: [UUID]
    var periodCount: Int
    var courtPlayerCount: Int
    var resetsTeamFoulsEachPeriod: Bool
    var showsReboundButton: Bool
    var showsAssistButton: Bool
    var showsFoulButton: Bool
    var showsBlockButton: Bool
    var showsStealButton: Bool
    var showsTurnoverButton: Bool
    var periodEndCondition: PeriodEndCondition
    var periodTimeLimit: Int
    var periodScoreLimit: Int
    var homeTeamStatsMode = false
    var awayTeamStatsMode = false
}

struct NewGameSetupView: View {
    @Environment(\.dismiss) private var dismiss
    var teams: [Team]
    var playersForTeam: (UUID?) -> [Player]
    var initialHomeTeamID: UUID?
    var initialAwayTeamID: UUID?
    var onStart: (GameSetupConfig) -> Void

    @State private var homeTeamID: UUID?
    @State private var awayTeamID: UUID?
    @State private var homeStarterIDs: [UUID] = []
    @State private var awayStarterIDs: [UUID] = []
    @State private var homeBenchIDs: [UUID] = []
    @State private var awayBenchIDs: [UUID] = []
    @State private var homeTeamStatsMode = false
    @State private var awayTeamStatsMode = false
    @AppStorage("setup_period_count") private var periodCount = 4
    @AppStorage("setup_court_player_count") private var courtPlayerCount = 4
    @AppStorage("setup_reset_fouls") private var resetsTeamFoulsEachPeriod = true
    @AppStorage("setup_show_rebound") private var showsReboundButton = true
    @AppStorage("setup_show_assist") private var showsAssistButton = true
    @AppStorage("setup_show_foul") private var showsFoulButton = true
    @AppStorage("setup_show_block") private var showsBlockButton = true
    @AppStorage("setup_show_steal") private var showsStealButton = true
    @AppStorage("setup_show_turnover") private var showsTurnoverButton = true
    @AppStorage("setup_period_end_condition") private var periodEndCondition = PeriodEndCondition.byTime
    @AppStorage("setup_period_time_limit") private var periodTimeLimit = 12
    @AppStorage("setup_period_score_limit") private var periodScoreLimit = 30

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("section_teams")) {
                    Picker(LocalizedStringKey("picker_home_team"), selection: $homeTeamID) {
                        ForEach(teams) { team in
                            Text(team.name).tag(Optional(team.id))
                        }
                    }
                    Picker(LocalizedStringKey("picker_away_team"), selection: $awayTeamID) {
                        ForEach(teams) { team in
                            Text(team.name).tag(Optional(team.id))
                        }
                    }
                }

                Section(LocalizedStringKey("section_team_home")) {
                    if homeTeamID != nil {
                        Toggle(isOn: $homeTeamStatsMode) {
                            HStack(spacing: 10) {
                                Image(systemName: "person.3.fill")
                                    .foregroundColor(.primary)
                                    .frame(width: 28)
                                Text(LocalizedStringKey("label_team_stats_mode"))
                            }
                        }
                        if !homeTeamStatsMode {
                            starterSection(title: NSLocalizedString("starter_home_title", comment: "Home starters"), players: homePlayers, selectedIDs: $homeStarterIDs, requiredCount: requiredHomeCount)
                            benchSection(
                                title: NSLocalizedString("starter_home_bench_title", comment: "Home bench title"),
                                players: homeBenchCandidates,
                                selectedIDs: $homeBenchIDs
                            )
                        }
                    }
                }

                Section(LocalizedStringKey("section_team_away")) {
                    if awayTeamID != nil {
                        Toggle(isOn: $awayTeamStatsMode) {
                            HStack(spacing: 10) {
                                Image(systemName: "person.3.fill")
                                    .foregroundColor(.primary)
                                    .frame(width: 28)
                                Text(LocalizedStringKey("label_team_stats_mode"))
                            }
                        }
                        if !awayTeamStatsMode {
                            starterSection(title: NSLocalizedString("starter_away_title", comment: "Away starters"), players: awayPlayers, selectedIDs: $awayStarterIDs, requiredCount: requiredAwayCount)
                            benchSection(
                                title: NSLocalizedString("starter_away_bench_title", comment: "Away bench title"),
                                players: awayBenchCandidates,
                                selectedIDs: $awayBenchIDs
                            )
                        }
                    }
                }

                Section(LocalizedStringKey("section_game_settings")) {
                    Stepper(value: $periodCount, in: 1...8) {
                        HStack {
                            Text(LocalizedStringKey("label_period_count"))
                            Spacer()
                            Text(String(format: NSLocalizedString("count_periods_format", comment: "Periods count"), periodCount))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Stepper(value: $courtPlayerCount, in: 1...8) {
                        HStack {
                            Text(LocalizedStringKey("label_starter_count"))
                            Spacer()
                            Text(String(format: NSLocalizedString("count_players_format", comment: "Players count"), courtPlayerCount))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(LocalizedStringKey("toggle_reset_team_fouls_each_period"), isOn: $resetsTeamFoulsEachPeriod)

                    Picker(LocalizedStringKey("label_period_end_condition"), selection: $periodEndCondition) {
                        Text(LocalizedStringKey("period_end_manual")).tag(PeriodEndCondition.manual)
                        Text(LocalizedStringKey("period_end_by_time")).tag(PeriodEndCondition.byTime)
                        Text(LocalizedStringKey("period_end_by_score")).tag(PeriodEndCondition.byScore)
                    }

                    if periodEndCondition == .byTime {
                        HStack {
                            Text(LocalizedStringKey("label_period_time_limit"))
                            Spacer()
                            TextField(LocalizedStringKey("label_minutes"), value: $periodTimeLimit, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text(LocalizedStringKey("label_minutes_unit"))
                                .foregroundStyle(.secondary)
                        }
                    } else if periodEndCondition == .byScore {
                        HStack {
                            Text(LocalizedStringKey("label_period_score_limit"))
                            Spacer()
                            TextField(LocalizedStringKey("label_points"), value: $periodScoreLimit, format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                            Text(LocalizedStringKey("label_points_unit"))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(LocalizedStringKey("section_scoring_buttons")) {
                    Toggle(LocalizedStringKey("action_rebound"), isOn: $showsReboundButton)
                    Toggle(LocalizedStringKey("action_assist"), isOn: $showsAssistButton)
                    Toggle(LocalizedStringKey("action_foul"), isOn: $showsFoulButton)
                    Toggle(LocalizedStringKey("action_block"), isOn: $showsBlockButton)
                    Toggle(LocalizedStringKey("action_steal"), isOn: $showsStealButton)
                    Toggle(LocalizedStringKey("action_turnover"), isOn: $showsTurnoverButton)
                }
            }
                .navigationTitle(LocalizedStringKey("nav_new_game"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("button_cancel")) { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(LocalizedStringKey("button_done")) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_start")) {
                        guard let homeTeamID, let awayTeamID else { return }
                        onStart(GameSetupConfig(
                            homeTeamID: homeTeamID,
                            awayTeamID: awayTeamID,
                            homeStarterIDs: homeStarterIDs,
                            awayStarterIDs: awayStarterIDs,
                            homeBenchIDs: homeBenchIDs,
                            awayBenchIDs: awayBenchIDs,
                            periodCount: periodCount,
                            courtPlayerCount: courtPlayerCount,
                            resetsTeamFoulsEachPeriod: resetsTeamFoulsEachPeriod,
                            showsReboundButton: showsReboundButton,
                            showsAssistButton: showsAssistButton,
                            showsFoulButton: showsFoulButton,
                            showsBlockButton: showsBlockButton,
                            showsStealButton: showsStealButton,
                            showsTurnoverButton: showsTurnoverButton,
                            periodEndCondition: periodEndCondition,
                            periodTimeLimit: periodTimeLimit,
                            periodScoreLimit: periodScoreLimit,
                            homeTeamStatsMode: homeTeamStatsMode,
                            awayTeamStatsMode: awayTeamStatsMode
                        ))
                        dismiss()
                    }
                    .disabled(!canStart)
                }
            }
            .onAppear(perform: prepareDefaults)
            .onChange(of: homeTeamID) { _, _ in syncSelections(fillMissingStarters: true) }
            .onChange(of: awayTeamID) { _, _ in syncSelections(fillMissingStarters: true) }
            .onChange(of: courtPlayerCount) { _, _ in syncSelections(fillMissingStarters: true) }
        }
    }

    private var homePlayers: [Player] { playersForTeam(homeTeamID) }
    private var awayPlayers: [Player] { playersForTeam(awayTeamID) }
    private var requiredHomeCount: Int { min(courtPlayerCount, homePlayers.count) }
    private var requiredAwayCount: Int { min(courtPlayerCount, awayPlayers.count) }
    private var homeBenchCandidates: [Player] { homePlayers.filter { !homeStarterIDs.contains($0.id) } }
    private var awayBenchCandidates: [Player] { awayPlayers.filter { !awayStarterIDs.contains($0.id) } }

    private var canStart: Bool {
        return homeTeamID != nil
            && awayTeamID != nil
            && homeTeamID != awayTeamID
            && homeStarterIDs.count == requiredHomeCount
            && awayStarterIDs.count == requiredAwayCount
            && requiredHomeCount > 0
            && requiredAwayCount > 0
    }

    private func starterSection(title: String, players: [Player], selectedIDs: Binding<[UUID]>, requiredCount: Int) -> some View {
        Section(String(format: NSLocalizedString("section_starter_select_format", comment: "Starter section title"), title, requiredCount)) {
            if players.isEmpty {
                Text(LocalizedStringKey("text_team_has_no_players"))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(players) { player in
                            SelectablePlayerAvatarButton(
                                player: player,
                                isSelected: selectedIDs.wrappedValue.contains(player.id),
                                badge: selectedIDs.wrappedValue.contains(player.id) ? NSLocalizedString("badge_starter", comment: "Starter badge") : nil
                            ) {
                                toggle(player.id, in: selectedIDs, limit: requiredCount)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func benchSection(title: String, players: [Player], selectedIDs: Binding<[UUID]>) -> some View {
        Section(String(format: NSLocalizedString("section_bench_optional_format", comment: "Bench section title"), title)) {
            if players.isEmpty {
                Text(LocalizedStringKey("text_no_optional_bench"))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(players) { player in
                            SelectablePlayerAvatarButton(
                                player: player,
                                isSelected: selectedIDs.wrappedValue.contains(player.id),
                                badge: selectedIDs.wrappedValue.contains(player.id) ? NSLocalizedString("badge_bench", comment: "Bench badge") : nil
                            ) {
                                toggleBench(player.id, in: selectedIDs)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func prepareDefaults() {
        homeTeamID = initialHomeTeamID ?? teams.first?.id
        awayTeamID = initialAwayTeamID ?? teams.dropFirst().first?.id
        periodCount = max(periodCount, 1)
        courtPlayerCount = max(courtPlayerCount, 1)
        periodTimeLimit = max(periodTimeLimit, 1)
        periodScoreLimit = max(periodScoreLimit, 1)
        if awayTeamID == homeTeamID {
            awayTeamID = teams.first(where: { $0.id != homeTeamID })?.id
        }
        syncSelections(fillMissingStarters: true)
    }

    private func toggle(_ id: UUID, in selectedIDs: Binding<[UUID]>, limit: Int) {
        if selectedIDs.wrappedValue.contains(id) {
            selectedIDs.wrappedValue.removeAll { $0 == id }
        } else if selectedIDs.wrappedValue.count < limit {
            selectedIDs.wrappedValue.append(id)
        } else if !selectedIDs.wrappedValue.isEmpty {
            selectedIDs.wrappedValue.removeFirst()
            selectedIDs.wrappedValue.append(id)
        }
        syncSelections(fillMissingStarters: false)
    }

    private func toggleBench(_ id: UUID, in selectedIDs: Binding<[UUID]>) {
        if selectedIDs.wrappedValue.contains(id) {
            selectedIDs.wrappedValue.removeAll { $0 == id }
        } else {
            selectedIDs.wrappedValue.append(id)
        }
        syncSelections(fillMissingStarters: false)
    }

    private func syncSelections(fillMissingStarters: Bool) {
        let homePlayerIDs = homePlayers.map(\.id)
        let awayPlayerIDs = awayPlayers.map(\.id)

        homeStarterIDs = Array(homeStarterIDs.filter { homePlayerIDs.contains($0) }.prefix(requiredHomeCount))
        awayStarterIDs = Array(awayStarterIDs.filter { awayPlayerIDs.contains($0) }.prefix(requiredAwayCount))

        if fillMissingStarters, homeStarterIDs.count < requiredHomeCount {
            let candidates = homePlayerIDs.filter { !homeStarterIDs.contains($0) }
            homeStarterIDs.append(contentsOf: candidates.prefix(requiredHomeCount - homeStarterIDs.count))
        }
        if fillMissingStarters, awayStarterIDs.count < requiredAwayCount {
            let candidates = awayPlayerIDs.filter { !awayStarterIDs.contains($0) }
            awayStarterIDs.append(contentsOf: candidates.prefix(requiredAwayCount - awayStarterIDs.count))
        }

        homeBenchIDs = homeBenchIDs.filter { homePlayerIDs.contains($0) && !homeStarterIDs.contains($0) }
        awayBenchIDs = awayBenchIDs.filter { awayPlayerIDs.contains($0) && !awayStarterIDs.contains($0) }
    }
}

