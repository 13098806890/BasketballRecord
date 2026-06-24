import SwiftUI

struct SavedGameDetailView: View {
    enum DisplayMode {
        case history
        case live
    }

    @EnvironmentObject private var store: AppStore
    var game: SavedGame
    var displayMode: DisplayMode = .history
    @State private var isShowingExport = false
    @State private var selectedPeriod: Int? = nil
    @State private var isGeneratingAISummary = false
    @State private var aiSummary = ""
    @State private var aiSummaryError: String?
    @State private var periodAnalysis = SavedGamePeriodAnalysis()
    @State private var selectedGroupID: UUID?
    @State private var editDisplayName = ""
    @State private var isShowingPurchase = false
    @State private var showSummaryExistsAlert = false
    @State private var shareImage: UIImage?
    @State private var savedToPhotos = false
    @State private var isEditing = false
    @State private var showEditSheet = false
    @State private var editingSheetEntry: GameLogEntry?
    @State private var expandedPeriods: Set<Int> = []
    @State private var expandedMinutes: [Int: Set<Int>] = [:]


    init(game: SavedGame, displayMode: DisplayMode = .history) {
        self.game = game
        self.displayMode = displayMode

        _aiSummary = State(initialValue: game.aiSummary ?? "")
        _selectedGroupID = State(initialValue: game.groupIDs.first)

        let initialAnalyzer = SavedGameAnalyzer(game: game) { name in
            game.playerNamesByID.first(where: { $0.value == name })?.key
        }
        _periodAnalysis = State(initialValue: initialAnalyzer.analyze())
    }

    var body: some View {
        let l = List {
            groupAssignmentSection

            Section {
                HStack(spacing: 8) {
                    TextField(LocalizedStringKey("label_game_name"), text: $editDisplayName)
                        .font(.headline)
                        .onSubmit {
                            if let idx = store.savedGames.firstIndex(where: { $0.id == game.id }) {
                                store.savedGames[idx].displayName = editDisplayName
                                if store.cloudEnabledGameIDs.contains(game.id) {
                                    Task {
                                        await CloudKitManager.shared.uploadGame(store.savedGames[idx])
                                    }
                                }
                            }
                        }
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    teamSummary(.home)
                    Spacer()
                    Text(LocalizedStringKey("label_vs"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    teamSummary(.away)
                }
            }

            if game.snapshot.periodCount > 1, !availablePeriodOptions.isEmpty {
                Section(LocalizedStringKey("section_data_range")) {
                    Picker(LocalizedStringKey("picker_period"), selection: $selectedPeriod) {
                        Text(LocalizedStringKey("data_range_full")).tag(Optional<Int>.none)
                        ForEach(availablePeriodOptions, id: \.self) { period in
                            Text(String(format: NSLocalizedString("data_range_period", comment: "Data range period"), period)).tag(Optional(period))
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Section {
                TeamStatsDisclosureView(
                    homeName: game.homeTeamName,
                    awayName: game.awayTeamName,
                    homeStats: aggregateStats(for: game.snapshot.homeTeamID),
                    awayStats: aggregateStats(for: game.snapshot.awayTeamID),
                    homeFouls: fouls(for: game.snapshot.homeTeamID),
                    awayFouls: fouls(for: game.snapshot.awayTeamID),
                    style: .scoreboard
                )
                .padding(.horizontal, 12)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowSeparator(.hidden)
            }

            if !game.snapshot.homeTeamStatsMode { homePlayerSection }
            if !game.snapshot.awayTeamStatsMode { awayPlayerSection }

            if displayMode == .history {
                Section(LocalizedStringKey("section_ai_game_summary")) {
                    Button {
                        if hasSummary && aiConfig == nil {
                            showSummaryExistsAlert = true
                            return
                        }
                        if !store.isPro {
                            isShowingPurchase = true
                        } else {
                            generateAISummary()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            if isGeneratingAISummary {
                                ProgressView()
                            }
                            Label(buttonTitleKey, systemImage: "sparkles")
                        }
                    }
                    .disabled(isGeneratingAISummary || generationBlocked)

                    if !aiSummary.isEmpty {
                        Button {
                            let width = UIScreen.main.bounds.width - 32
                            let renderer = ImageRenderer(content:
                                aiSummaryContent
                                    .frame(width: width)
                                    .background(Color(uiColor: .systemBackground))
                            )
                            renderer.scale = UIScreen.main.scale
                            if let image = renderer.uiImage {
                                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                                savedToPhotos = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { savedToPhotos = false }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: savedToPhotos ? "checkmark.circle.fill" : "photo.badge.arrow.down")
                                    .foregroundStyle(savedToPhotos ? .green : .blue)
                                Text(LocalizedStringKey(savedToPhotos ? "button_saved" : "button_save_to_photos"))
                                    .font(.caption)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if let aiSummaryError {
                        Text(aiSummaryError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if aiSummary.isEmpty {
                        Text(LocalizedStringKey(store.isPro ? "text_ai_pro_hint" : "text_ai_pro_required"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        aiSummaryStyledView
                    }
                }
            }

        }
        .navigationTitle(LocalizedStringKey("nav_game_detail"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if displayMode == .history {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if store.isPro {
                        Button {
                            store.toggleCloudStorage(for: game.id)
                        } label: {
                            Label(LocalizedStringKey("label_cloud"), systemImage: store.cloudEnabledGameIDs.contains(game.id) ? "icloud.fill" : "icloud")
                        }
                    }
                    if store.isPro {
                        GameGroupPicker(store: store, selectedGroupID: $selectedGroupID, iconName: "folder.badge.plus", checkedGroupIDs: Set(store.groups(for: game.id).map(\.id)))
                    }
                    Button {
                        isShowingExport = true
                    } label: {
                        Label(LocalizedStringKey("button_export"), systemImage: TransferSymbol.exportData)
                    }
                    Button {
                        if store.isPro || isEditing {
                            isEditing.toggle()
                        } else {
                            isShowingPurchase = true
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if !store.isPro && !isEditing {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                            }
                            Text(LocalizedStringKey(isEditing ? "button_done" : "button_edit"))
                        }
                        .foregroundStyle(store.isPro || isEditing ? Color.blue : Color.gray)
                    }
                }
            }
        }

        (isEditing ? AnyView(editEventListView) : AnyView(l))
            .onChange(of: store.cloudEnabledGameIDs) { _, _ in
            // UI refreshes automatically via @Published
        }
            .sheet(isPresented: $isShowingPurchase) {
                ProSubscriptionStoreView()
            }
            .alert(LocalizedStringKey("alert_ai_summary_exists_title"), isPresented: $showSummaryExistsAlert) {
                Button(LocalizedStringKey("button_ok")) { }
            } message: {
                Text(LocalizedStringKey("alert_ai_summary_exists_message"))
            }
            .sheet(isPresented: $isShowingExport) {
            ExportGameView(game: game)
        }
        .onChange(of: selectedGroupID) { _, newValue in
            if let groupID = newValue {
                store.toggleGameGroup(game.id, groupID: groupID)
                DispatchQueue.main.async {
                    selectedGroupID = nil
                }
            }
        }
        .onAppear {
            editDisplayName = game.displayName
            sanitizeSelectedPeriod()
            if displayMode == .history,
               aiSummary.isEmpty,
               let savedSummary = game.aiSummary,
               !savedSummary.isEmpty {
                let normalizedSummary = normalizeAISummary(savedSummary)
                aiSummary = normalizedSummary
                if normalizedSummary != savedSummary {
                    store.updateAISummary(normalizedSummary, for: game.id)
                }
            }
        }
    }

    private func teamSummary(_ side: TeamSide) -> some View {
        let teamID = side == .home ? game.snapshot.homeTeamID : game.snapshot.awayTeamID
        let teamName = side == .home ? game.homeTeamName : game.awayTeamName
        return VStack(spacing: 4) {
            Text(teamName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text("\(score(for: teamID))")
                .font(.largeTitle.monospacedDigit().weight(.bold))
            Text(String(format: NSLocalizedString("foul_count_format", comment: "Foul count"), fouls(for: teamID)))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity)
    }

    private func playerStatRow(for playerID: UUID) -> some View {
        let stats = displayStatsByPlayerID[playerID, default: PlayerStats()]
        let playingTime = selectedPeriod == nil
            ? GameView.durationFormatter(game.snapshot.playingSecondsByPlayerID[playerID, default: 0])
            : "--:--"
        let plusMinus = game.snapshot.plusMinusByPlayerID[playerID, default: 0]
        let plusMinusText = plusMinus > 0 ? "+\(plusMinus)" : "\(plusMinus)"

        return NavigationLink {
            if store.player(for: playerID) != nil {
                PlayerProfileView(playerID: playerID, fixedGame: game, selectedGroupID: .constant(nil))
            } else {
                PlayerGameDetailView(game: game, playerID: playerID)
            }
        } label: {
            HStack(spacing: 10) {
                playerAvatar(for: playerID)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(game.playerNamesByID[playerID] ?? NSLocalizedString("unknown_player", comment: "Unknown player"))
                            .font(.subheadline.weight(.semibold))
                        if let role = game.role(of: playerID) {
                            Text(role.title)
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.14), in: Capsule())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(String(format: NSLocalizedString("career_points_format", comment: "Points format"), stats.points))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                    }
                    (Text(String(format: NSLocalizedString("stats_line_format", comment: "Stats line"), playingTime, stats.made, stats.attempts, stats.allFreeThrowMade, stats.allFreeThrowAttempts, stats.totalRebounds, stats.assists, stats.fouls, stats.blocks, stats.steals, stats.turnovers))
                    + Text("  \(NSLocalizedString("stats_plus_minus", comment: "")) \(plusMinusText)  \(NSLocalizedString("stats_points_per_shot", comment: "")) \(String(format: "%.2f", stats.pointsPerShot))"))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var homePlayerSection: some View {
        Section(String(format: NSLocalizedString("section_team_players_data_format", comment: "Team players data"), game.homeTeamName)) {
            ForEach(game.homePlayerIDs, id: \.self) { playerID in
                playerStatRow(for: playerID)
            }
        }
    }

    private var awayPlayerSection: some View {
        Section(String(format: NSLocalizedString("section_team_players_data_format", comment: "Team players data"), game.awayTeamName)) {
            ForEach(game.awayPlayerIDs, id: \.self) { playerID in
                playerStatRow(for: playerID)
            }
        }
    }

    @ViewBuilder
    private var groupAssignmentSection: some View {
        let assignedGroups = store.groups(for: game.id)
        if !assignedGroups.isEmpty, store.isPro {
            Section {
                ForEach(assignedGroups) { group in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("game_group_assigned_label", comment: "Assigned to"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(group.name)
                                .font(.headline)
                        }
                        Spacer()
                        Button(action: {
                            store.toggleGameGroup(game.id, groupID: group.id)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
    }

    private func score(for teamID: UUID?) -> Int {
        guard let teamID else { return 0 }
        return game.score(forTeamID: teamID)
    }

    private func fouls(for teamID: UUID?) -> Int {
        guard let teamID else { return 0 }
        let teamFouls = game.snapshot.teamStatsByID[teamID, default: PlayerStats()].fouls
        let playerFouls = playerIDs(for: teamID).reduce(0) { total, playerID in
            total + displayStatsByPlayerID[playerID, default: PlayerStats()].fouls
        }
        return teamFouls + playerFouls
    }

    private func aggregateStats(for teamID: UUID?) -> PlayerStats {
        guard let teamID else { return PlayerStats() }
        var total = game.snapshot.teamStatsByID[teamID, default: PlayerStats()]
        for playerID in playerIDs(for: teamID) {
            let stats = displayStatsByPlayerID[playerID, default: PlayerStats()]
            total.twoMade += stats.twoMade
            total.twoAttempts += stats.twoAttempts
            total.threeMade += stats.threeMade
            total.threeAttempts += stats.threeAttempts
            total.bonusFreeThrowMade += stats.bonusFreeThrowMade
            total.bonusFreeThrowAttempts += stats.bonusFreeThrowAttempts
            total.freeThrowMade += stats.freeThrowMade
            total.freeThrowAttempts += stats.freeThrowAttempts
            total.rebounds += stats.rebounds
            total.offensiveRebounds += stats.offensiveRebounds
            total.defensiveRebounds += stats.defensiveRebounds
            total.assists += stats.assists
            total.fouls += stats.fouls
            total.blocks += stats.blocks
            total.steals += stats.steals
            total.turnovers += stats.turnovers
        }
        return total
    }

    private func playerIDs(for teamID: UUID?) -> [UUID] {
        teamID == game.snapshot.homeTeamID ? game.homePlayerIDs : game.awayPlayerIDs
    }

    private var displayStatsByPlayerID: [UUID: PlayerStats] {
        guard let selectedPeriod else {
            return game.snapshot.statsByPlayerID
        }
        return statsByPlayerID(for: selectedPeriod)
    }

    private var availablePeriodOptions: [Int] {
        guard maxAvailablePeriod > 0 else { return [] }
        return Array(1...maxAvailablePeriod)
    }

    private var maxAvailablePeriod: Int {
        let maxPeriod = max(game.snapshot.periodCount, 1)
        if game.snapshot.isComplete {
            return maxPeriod
        }

        let reachedByLogs = periodAnalysis.logs.compactMap(\.inferredPeriod).max() ?? 0
        if game.snapshot.periodIsRunning || game.snapshot.periodElapsedSeconds > 0 {
            return min(max(reachedByLogs, game.snapshot.currentPeriod), maxPeriod)
        }
        return min(reachedByLogs, maxPeriod)
    }

    private var eventListMaxHeight: CGFloat {
        20 * 22
    }

    private var periodAwareLogs: [PeriodAwareLog] {
        periodAnalysis.logs
    }

    private var filteredPeriodAwareLogs: [PeriodAwareLog] {
        periodAnalysis.logs(for: selectedPeriod)
    }

    private func statsByPlayerID(for period: Int) -> [UUID: PlayerStats] {
        periodAnalysis.statsByPlayerID(for: period)
    }

    private func rebuildPeriodAnalysis() {
        guard let idx = store.savedGames.firstIndex(where: { $0.id == game.id }) else { return }
        let currentGame = store.savedGames[idx]
        let analyzer = SavedGameAnalyzer(game: currentGame) { name in
            resolvePlayerIDByName(name)
        }
        periodAnalysis = analyzer.analyze()
        rebuildGameSnapshotStats(gameIndex: idx)
        sanitizeSelectedPeriod()
    }

    private func rebuildGameSnapshotStats(gameIndex: Int) {
        let currentGame = store.savedGames[gameIndex]
        let logs = currentGame.snapshot.logs.sorted { $0.timestamp < $1.timestamp }
        let homeIDs = Set(currentGame.homePlayerIDs)
        let awayIDs = Set(currentGame.awayPlayerIDs)
        let allIDs = homeIDs.union(awayIDs)

        var statsByPlayer: [UUID: PlayerStats] = [:]
        var playingSeconds: [UUID: TimeInterval] = [:]
        var plusMinus: [UUID: Int] = [:]
        var homeOnCourt: Set<UUID> = []
        var awayOnCourt: Set<UUID> = []
        var lastTimestamp = logs.first?.timestamp ?? Date()

        // Initialize lineup from starters if set, otherwise empty
        let homeStarters = Set(currentGame.snapshot.starterPlayerIDs.filter { homeIDs.contains($0) })
        let awayStarters = Set(currentGame.snapshot.starterPlayerIDs.filter { awayIDs.contains($0) })

        for log in logs {
            let elapsed = max(0, log.timestamp.timeIntervalSince(lastTimestamp))
            lastTimestamp = log.timestamp

            for pid in homeOnCourt { playingSeconds[pid, default: 0] += elapsed }
            for pid in awayOnCourt { playingSeconds[pid, default: 0] += elapsed }

            guard let code = log.eventCode else { continue }

            if code.hasPrefix("event.period") {
                homeOnCourt = homeStarters
                awayOnCourt = awayStarters
                if code == "event.period_start" {
                    // Period started - ensure lineups are set
                }
            } else if code == "event.substitution", let incoming = log.playerID, let outgoing = log.relatedPlayerID {
                if homeOnCourt.contains(outgoing) { homeOnCourt.remove(outgoing); homeOnCourt.insert(incoming) }
                if awayOnCourt.contains(outgoing) { awayOnCourt.remove(outgoing); awayOnCourt.insert(incoming) }
            } else if code == "event.late_arrival", let pid = log.playerID {
                if homeIDs.contains(pid) { homeOnCourt.insert(pid) }
                if awayIDs.contains(pid) { awayOnCourt.insert(pid) }
            } else if let action = StatAction.allCases.first(where: { $0.eventCode == code }),
                      let pid = log.playerID {
                var stats = statsByPlayer[pid, default: PlayerStats()]
                action.apply(to: &stats)
                statsByPlayer[pid] = stats
                if action.points > 0 {
                    let isHome = homeIDs.contains(pid)
                    for p in awayOnCourt { plusMinus[p, default: 0] -= action.points }
                    for p in homeOnCourt { plusMinus[p, default: 0] += action.points }
                }
            }
        }

        store.savedGames[gameIndex].snapshot.statsByPlayerID = statsByPlayer
        store.savedGames[gameIndex].snapshot.playingSecondsByPlayerID = playingSeconds
        store.savedGames[gameIndex].snapshot.plusMinusByPlayerID = plusMinus
    }

    private func sanitizeSelectedPeriod() {
        guard let selectedPeriod else { return }
        if !availablePeriodOptions.contains(selectedPeriod) {
            self.selectedPeriod = nil
        }
    }

    private func resolvePlayerIDByName(_ name: String) -> UUID? {
        if let existing = game.playerNamesByID.first(where: { $0.value == name })?.key {
            return existing
        }
        return store.players.first(where: { $0.name == name })?.id
    }

    private func logLineText(for item: PeriodAwareLog) -> String {
        GameLogFormatter.lineText(for: item)
    }

    private var aiConfig: (provider: AIProvider, model: AIModel, apiKey: String)? {
        let raw = UserDefaults.standard.string(forKey: "ai_selected_provider") ?? AIProvider.deepseek.rawValue
        let provider = AIProvider(rawValue: raw) ?? .deepseek
        let modelID = UserDefaults.standard.string(forKey: "ai_selected_model_id") ?? AIProvider.defaultModel.id
        let model = provider.models.first { $0.id == modelID } ?? provider.models.first ?? AIProvider.defaultModel
        guard let key = AIKeychain.shared.loadAPIKey(for: provider)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            return nil
        }
        return (provider, model, key)
    }

    private var aiSummaryContent: some View {
        let sections = aiSummarySections
        if sections.isEmpty {
            return AnyView(
                Text(stripMarkdownDecorations(from: normalizeAISummary(aiSummary)))
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            )
        }
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    let isMVP = isMVPSection(section.title)
                    let mvpID = isMVP ? mvpPlayerID(in: section.items.joined(separator: " ")) : nil

                    VStack(alignment: .leading, spacing: 12) {
                        if isMVP {
                            HStack(spacing: 8) {
                                Image(systemName: "trophy.fill").font(.headline).foregroundStyle(Color.yellow)
                                Text(stripMarkdownDecorations(from: section.title)).font(.headline).foregroundStyle(aiSummaryAccentColor)
                                Spacer(minLength: 0)
                                if let mvpID { mvpPlayerAvatar(for: mvpID) }
                            }
                        } else {
                            Label(stripMarkdownDecorations(from: section.title), systemImage: iconForSummarySection(section.title))
                                .font(.headline).foregroundStyle(aiSummaryAccentColor)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(Array(section.items.enumerated()), id: \.offset) { index, item in
                                let cleanedItem = stripMarkdownDecorations(from: item)
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: iconForSummaryItem(sectionTitle: section.title, item: item, index: index))
                                        .font(.caption.weight(.semibold)).foregroundStyle(aiSummaryAccentColor)
                                        .frame(width: 14, height: 14).padding(.top, 2)
                                    Text(cleanedItem).font(.subheadline).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(uiColor: .secondarySystemBackground)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(aiSummaryAccentColor.opacity(0.14), lineWidth: 1))
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = stripMarkdownDecorations(from: ([section.title] + section.items).joined(separator: "\n"))
                        } label: {
                            Label(LocalizedStringKey("voice_log_copy"), systemImage: "doc.on.doc")
                        }
                    }
                }

            }
            .textSelection(.enabled)
        )
    }

    private var aiSummaryStyledView: some View {
        aiSummaryContent
    }

    private var aiSummarySections: [AISummarySection] {
        parseAISummarySections(from: normalizeAISummary(aiSummary))
    }

    private var hasSummary: Bool {
        if !aiSummary.isEmpty { return true }
        let stored = store.savedGames.first { $0.id == game.id }?.aiSummary
        return stored?.isEmpty == false
    }

    private var usingOwnKey: Bool { aiConfig != nil }

    private var generationBlocked: Bool {
        guard !usingOwnKey else { return false }
        if hasSummary { return true }
        return dailyGenerationCount >= 10
    }

    private var dailyGenerationCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let saved = UserDefaults.standard.dictionary(forKey: "ai_gen_records") as? [String: Int] ?? [:]
        let key = "\(today.timeIntervalSince1970)"
        return saved[key] ?? 0
    }

    private func incrementGenerationCount() {
        let today = Calendar.current.startOfDay(for: Date())
        var saved = UserDefaults.standard.dictionary(forKey: "ai_gen_records") as? [String: Int] ?? [:]
        // Clean records older than 7 days
        let weekAgo = today.timeIntervalSince1970 - 7 * 86400
        for (k, _) in saved where Double(k) ?? 0 < weekAgo {
            saved.removeValue(forKey: k)
        }
        let key = "\(today.timeIntervalSince1970)"
        saved[key] = (saved[key] ?? 0) + 1
        UserDefaults.standard.set(saved, forKey: "ai_gen_records")
    }

    private var buttonTitleKey: LocalizedStringKey {
        if isGeneratingAISummary { return LocalizedStringKey("button_ai_generating") }
        if hasSummary { return LocalizedStringKey("button_ai_view_summary") }
        if generationBlocked { return LocalizedStringKey("button_ai_limit_reached") }
        return LocalizedStringKey("button_ai_generate_summary")
    }

    private var aiSummaryAccentColor: Color {
        Color(red: 0.22, green: 0.52, blue: 0.90)
    }

    private func generateAISummary() {
        if hasSummary && usingOwnKey {
            aiSummary = game.aiSummary ?? aiSummary
            return
        }
        if generationBlocked { return }

        let prompt = summaryPrompt()
        let systemRole = NSLocalizedString("ai_system_role", comment: "AI system role")

        isGeneratingAISummary = true
        aiSummaryError = nil

        Task {
            do {
                let summary: String
                if let config = aiConfig {
                    summary = try await AIService.shared.sendChat(
                        model: config.model, apiKey: config.apiKey,
                        systemPrompt: systemRole, userPrompt: prompt
                    )
                } else {
                    summary = try await AIServiceProxy.chat(
                        messages: [["role": "user", "content": prompt]],
                        systemPrompt: systemRole,
                        temperature: 0.6,
                        maxTokens: 2500
                    )
                    await MainActor.run { incrementGenerationCount() }
                }
                let normalizedSummary = normalizeAISummary(summary)
                await MainActor.run {
                    aiSummary = normalizedSummary
                    store.updateAISummary(normalizedSummary, for: game.id)
                    isGeneratingAISummary = false
                }
            } catch {
                await MainActor.run {
                    aiSummaryError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    isGeneratingAISummary = false
                }
            }
        }
    }

    private func periodEventsText() -> String {
        let analyzer = SavedGameAnalyzer(game: game, resolvePlayerIDByName: { name in
            game.playerNamesByID.first(where: { $0.value == name })?.key
        })
        let analysis = analyzer.analyze()
        let periodCount = game.snapshot.periodCount
        var lines: [String] = []

        for period in 1...periodCount {
            let periodLogs = analysis.logs(for: period).filter { log in
                GameLogFormatter.isScoring(log) || log.entry.eventCode == "stat.foul" || log.entry.eventCode == "stat.assist" || log.entry.eventCode == "stat.rebound" || log.entry.eventCode == "stat.block" || log.entry.eventCode == "stat.steal" || log.entry.eventCode == "stat.turnover"
            }
            guard !periodLogs.isEmpty else { continue }

            lines.append("- 第\(period)节事件：")
            for log in periodLogs.prefix(20) {
                let msg = GameLogFormatter.normalizedMessage(log.entry.message)
                    .replacingOccurrences(of: "[event:\\w+\\.\\w+]", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if !msg.isEmpty {
                    lines.append("  - \(msg)")
                }
            }
        }

        if lines.isEmpty {
            return "- 无可用事件记录"
        }
        return lines.joined(separator: "\n")
    }

    private func teamStatsPromptSection() -> String {
        guard let homeID = game.snapshot.homeTeamID, let awayID = game.snapshot.awayTeamID else { return "" }
        let homeTeamStats = game.snapshot.teamStatsByID[homeID, default: PlayerStats()]
        let awayTeamStats = game.snapshot.teamStatsByID[awayID, default: PlayerStats()]
        let hasHome = game.snapshot.homeTeamStatsMode && homeTeamStats.points > 0
        let hasAway = game.snapshot.awayTeamStatsMode && awayTeamStats.points > 0
        guard hasHome || hasAway else { return "" }

        var lines: [String] = ["【Team Stats (system recorded)】"]
        if hasHome {
            let ts = homeTeamStats
            let pts = String(format: NSLocalizedString("stats_points_format", comment: "Points"), ts.points)
            let reb = String(format: NSLocalizedString("stats_rebound_short_format", comment: "Rebounds"), ts.totalRebounds)
            let ast = String(format: NSLocalizedString("stats_assist_short_format", comment: "Assists"), ts.assists)
            let foul = String(format: NSLocalizedString("stats_foul_short_format", comment: "Fouls"), ts.fouls)
            let blk = String(format: NSLocalizedString("stats_block_short_format", comment: "Blocks"), ts.blocks)
            let stl = String(format: NSLocalizedString("stats_steal_short_format", comment: "Steals"), ts.steals)
            let to = String(format: NSLocalizedString("stats_turnover_short_format", comment: "Turnovers"), ts.turnovers)
            lines.append("- \(game.homeTeamName): \(pts) \(reb) \(ast) \(foul) \(blk) \(stl) \(to)")
        }
        if hasAway {
            let ts = awayTeamStats
            let pts = String(format: NSLocalizedString("stats_points_format", comment: "Points"), ts.points)
            let reb = String(format: NSLocalizedString("stats_rebound_short_format", comment: "Rebounds"), ts.totalRebounds)
            let ast = String(format: NSLocalizedString("stats_assist_short_format", comment: "Assists"), ts.assists)
            let foul = String(format: NSLocalizedString("stats_foul_short_format", comment: "Fouls"), ts.fouls)
            let blk = String(format: NSLocalizedString("stats_block_short_format", comment: "Blocks"), ts.blocks)
            let stl = String(format: NSLocalizedString("stats_steal_short_format", comment: "Steals"), ts.steals)
            let to = String(format: NSLocalizedString("stats_turnover_short_format", comment: "Turnovers"), ts.turnovers)
            lines.append("- \(game.awayTeamName): \(pts) \(reb) \(ast) \(foul) \(blk) \(stl) \(to)")
        }
        return lines.joined(separator: "\n")
    }

    private func scoringRunData() -> String {
        let scoringCodes: Set<String> = ["stat.twoMade", "stat.threeMade", "stat.freeThrowMade", "stat.bonusMade"]
        let pointMap: [String: Int] = ["stat.twoMade": 2, "stat.threeMade": 3, "stat.freeThrowMade": 1, "stat.bonusMade": 1]
        var homeIDs = Set(game.homePlayerIDs)
        if game.snapshot.homeTeamStatsMode, let tid = game.snapshot.homeTeamID { homeIDs.insert(tid) }
        let allIDs = allPlayerIDsForSummary()
        let idToName: [UUID: String] = Dictionary(uniqueKeysWithValues: allIDs.compactMap { id in
            game.playerNamesByID[id].map { (id, $0) }
        })

        var events: [String] = []
        var homeScore = 0, awayScore = 0
        var personalRun: (playerID: UUID, count: Int, points: Int)?
        var teamRun: (isHome: Bool, count: Int, points: Int)?
        var reboundStreak: (playerID: UUID, count: Int)?
        var assistStreak: (playerID: UUID, count: Int)?
        var missedShotStreak: (teamIsHome: Bool, count: Int)?
        var personalMissStreak: (playerID: UUID, count: Int)?
        var bothMissStreak = 0
        var lastScoringCode: String?
        var lastScoringPID: UUID?

        // Helper: resolve team ID from log for team stats mode
        func resolveTeamID(log: GameLogEntry) -> UUID? {
            game.resolvedTeamID(from: log.message)
        }

        for log in game.snapshot.logs {
            guard let code = log.eventCode ?? GameLogFormatter.extractEventCode(from: log.message) else { continue }
            let playerID = log.playerID ?? resolvedPlayerID(log: log) ?? resolveTeamID(log: log)
            let playerName: String
            if let pid = playerID {
                playerName = idToName[pid] ?? (pid == game.snapshot.homeTeamID ? game.homeTeamName : pid == game.snapshot.awayTeamID ? game.awayTeamName : "?")
            } else {
                playerName = "?"
            }

            if scoringCodes.contains(code), let points = pointMap[code], let pid = playerID {
                let isHome = homeIDs.contains(pid)
                let prevHome = homeScore
                let prevAway = awayScore
                if isHome { homeScore += points } else { awayScore += points }

                // And-one (2+1 / 3+1) detection
                if code == "stat.bonusMade", let lastCode = lastScoringCode, let lastPid = lastScoringPID, lastPid == pid {
                    let basePoints = lastCode == "stat.threeMade" ? 3 : 2
                    let totalPoints = basePoints + 1
                    events.append("  and_one:\(playerName) \(basePoints)+1 (\(totalPoints)pt play)")
                }
                if code == "stat.twoMade" || code == "stat.threeMade" {
                    lastScoringCode = code
                    lastScoringPID = pid
                } else if code != "stat.bonusMade" {
                    lastScoringCode = nil
                    lastScoringPID = nil
                }

                // Per-scoring-event line with score context
                let leadChars = abs(homeScore - awayScore)
                let diffBefore = prevHome - prevAway
                let diffAfter = homeScore - awayScore
                var context = ""
                if diffBefore == 0 {
                    context = "opening"
                } else if abs(diffAfter) > abs(diffBefore) {
                    context = "extend \(leadChars)"
                } else if diffBefore > 0 && diffAfter <= 0 {
                    context = "tie"
                } else if diffBefore < 0 && diffAfter >= 0 {
                    context = "tie"
                } else {
                    context = "cut \(leadChars)"
                }
                events.append("[\(playerName) +\(points) \(prevHome)：\(prevAway)->\(homeScore)：\(awayScore) \(context)]")

                // Personal scoring run
                if personalRun?.playerID == pid {
                    personalRun?.count += 1
                    personalRun?.points += points
                } else {
                    if let run = personalRun, run.count >= 2 {
                        events.append("  personal_run:\(idToName[run.playerID] ?? "?") +\(run.points)pt in \(run.count)poss")
                    }
                    personalRun = (pid, 1, points)
                }

                // Team scoring run
                if teamRun?.isHome == isHome {
                    teamRun?.count += 1
                    teamRun?.points += points
                } else {
                    if let run = teamRun, run.count >= 2, run.points >= 6 {
                        let tName = run.isHome ? game.homeTeamName : game.awayTeamName
                        events.append("  team_run:\(tName) +\(run.points)pt in \(run.count)poss")
                    }
                    teamRun = (isHome, 1, points)
                }

                    // Reset non-scoring streaks on scoring events
                reboundStreak = nil
                assistStreak = nil
                missedShotStreak = nil
                personalMissStreak = nil
                continue
            }

            // Consecutive rebounds
            if code == "stat.rebound", let pid = playerID {
                if reboundStreak?.playerID == pid {
                    reboundStreak?.count += 1
                } else {
                    if let rs = reboundStreak, rs.count >= 3 {
                        events.append("  rebound_streak:\(idToName[rs.playerID] ?? "?") x\(rs.count)")
                    }
                    reboundStreak = (pid, 1)
                }
                continue
            }

            // Consecutive missed shots (personal and team)
            let missedCodes: Set<String> = ["stat.twoMissed", "stat.threeMissed", "stat.freeThrowMissed", "stat.bonusMissed", "stat.layupMissed", "stat.midRangeMissed", "stat.paintMissed", "stat.dunkMissed", "stat.putbackMissed"]
            if missedCodes.contains(code), let pid = playerID {
                let isHome = homeIDs.contains(pid)
                bothMissStreak += 1
                // Team missed streak
                if missedShotStreak?.teamIsHome == isHome {
                    missedShotStreak?.count += 1
                } else {
                    if let ms = missedShotStreak, ms.count >= 4 {
                        let tName = ms.teamIsHome ? game.homeTeamName : game.awayTeamName
                        events.append("  team_miss_streak:\(tName) x\(ms.count)")
                    }
                    missedShotStreak = (isHome, 1)
                }
                // Personal missed streak
                if personalMissStreak?.playerID == pid {
                    personalMissStreak?.count += 1
                } else {
                    if let pm = personalMissStreak, pm.count >= 3 {
                        events.append("  personal_miss_streak:\(idToName[pm.playerID] ?? "?") x\(pm.count)")
                    }
                    personalMissStreak = (pid, 1)
                }
                continue
            }

            // Consecutive assists
            if code == "stat.assist", let pid = playerID {
                if assistStreak?.playerID == pid {
                    assistStreak?.count += 1
                } else {
                    if let as_ = assistStreak, as_.count >= 3 {
                        events.append("  assist_streak:\(idToName[as_.playerID] ?? "?") x\(as_.count)")
                    }
                    assistStreak = (pid, 1)
                }
                continue
            }
        }

        // Flush remaining streaks
        if let run = personalRun, run.count >= 2 {
            events.append("  personal_run:\(idToName[run.playerID] ?? "?") +\(run.points)pt in \(run.count)poss")
        }
        if let run = teamRun, run.count >= 2, run.points >= 6 {
            let tName = run.isHome ? game.homeTeamName : game.awayTeamName
            events.append("  team_run:\(tName) +\(run.points)pt in \(run.count)poss")
        }
        if let rs = reboundStreak, rs.count >= 3 {
            events.append("  rebound_streak:\(idToName[rs.playerID] ?? "?") x\(rs.count)")
        }
        if let as_ = assistStreak, as_.count >= 3 {
            events.append("  assist_streak:\(idToName[as_.playerID] ?? "?") x\(as_.count)")
        }
        if let ms = missedShotStreak, ms.count >= 4 {
            let tName = ms.teamIsHome ? game.homeTeamName : game.awayTeamName
            events.append("  team_miss_streak:\(tName) x\(ms.count)")
        }
        if let pm = personalMissStreak, pm.count >= 3 {
            events.append("  personal_miss_streak:\(idToName[pm.playerID] ?? "?") x\(pm.count)")
        }
        if bothMissStreak >= 6 {
            events.append("  both_miss_streak:x\(bothMissStreak)")
        }

        return events.isEmpty ? "- No scoring data" : events.joined(separator: "\n")
    }

    private func resolvedPlayerID(log: GameLogEntry) -> UUID? {
        let normalized = GameLogFormatter.normalizedMessage(log.message)
        for (id, name) in game.playerNamesByID where normalized.contains(name) {
            return id
        }
        return nil
    }

    private func summaryPrompt() -> String {
        let homeScore = score(for: game.snapshot.homeTeamID)
        let awayScore = score(for: game.snapshot.awayTeamID)
        let numericFacts = numericFactsText()
        let eventsByPeriod = periodEventsText()

        // Per-period team & player scores for AI analysis
        let analyzer = SavedGameAnalyzer(game: game, resolvePlayerIDByName: { name in
            game.playerNamesByID.first(where: { $0.value == name })?.key
        })
        let analysis = analyzer.analyze()
        let periodCount = game.snapshot.periodCount
        let allIDs = allPlayerIDsForSummary()
        let idToName: [UUID: String] = Dictionary(uniqueKeysWithValues: allIDs.compactMap { id in
            game.playerNamesByID[id].map { (id, $0) }
        })
        var periodStatLines: [String] = []
        var runningHome = 0, runningAway = 0
        for period in 1...periodCount {
            let periodStats = analysis.statsByPlayerID(for: period)
            guard !periodStats.isEmpty else { continue }
            var homeIDs = Set(game.homePlayerIDs)
            if game.snapshot.homeTeamStatsMode, let tid = game.snapshot.homeTeamID { homeIDs.insert(tid) }
            let homePeriodPoints = periodStats.filter { homeIDs.contains($0.key) }.values.reduce(0) { $0 + $1.points }
            let awayPeriodPoints = periodStats.filter { !homeIDs.contains($0.key) }.values.reduce(0) { $0 + $1.points }
            runningHome += homePeriodPoints
            runningAway += awayPeriodPoints
            let diff = runningHome - runningAway
            let diffStr = diff > 0 ? "主队领先\(diff)分" : diff < 0 ? "客队领先\(-diff)分" : "平分"
            periodStatLines.append("- 第\(period)节：主队\(homePeriodPoints)分 vs 客队\(awayPeriodPoints)分 | 累计 \(runningHome)：\(runningAway)（\(diffStr)）")
            // Per-player stats for this period
            let sortedPlayers = allIDs.filter { periodStats[$0] != nil }.sorted { lhs, rhs in
                (periodStats[lhs]?.points ?? 0) > (periodStats[rhs]?.points ?? 0)
            }
            for pid in sortedPlayers {
                guard let ps = periodStats[pid], ps.points > 0 else { continue }
                let name = idToName[pid] ?? "?"
                periodStatLines.append("  · \(name): \(ps.points)分 \(ps.totalRebounds)板 \(ps.assists)助")
            }
        }
        let periodStatsText = periodStatLines.joined(separator: "\n")

        let playerLines = allPlayerIDsForSummary().map { playerID in
            let stats = game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
            let sideKey = game.homePlayerIDs.contains(playerID) ? "ai_prompt_side_home" : "ai_prompt_side_away"
            let side = NSLocalizedString(sideKey, comment: "Side")
            let roleUnmarked = NSLocalizedString("ai_prompt_role_unmarked", comment: "Unmarked role")
            let role = game.role(of: playerID)?.title ?? roleUnmarked
            let plusMinus = game.snapshot.plusMinusByPlayerID[playerID, default: 0]
            let plusMinusText = plusMinus > 0 ? "+\(plusMinus)" : "\(plusMinus)"
            let minutes = GameView.durationFormatter(game.snapshot.playingSecondsByPlayerID[playerID, default: 0])
            let playerUnknown = NSLocalizedString("unknown_player", comment: "Unknown player")
            let name = game.playerNamesByID[playerID] ?? playerUnknown

            let format = NSLocalizedString("ai_prompt_player_line_format", comment: "Player line format")
            return String(format: format, side, name, role, minutes, stats.points, stats.totalRebounds, stats.assists, stats.fouls, stats.blocks, stats.steals, stats.turnovers, stats.made, stats.attempts, stats.threeMade, stats.threeAttempts, stats.allFreeThrowMade, stats.allFreeThrowAttempts, plusMinusText)
        }

        let noPlayerDataKey = "ai_prompt_no_player_data"
        let playersText = playerLines.isEmpty ? NSLocalizedString(noPlayerDataKey, comment: "No player data") : playerLines.joined(separator: "\n")

        let taskDesc = NSLocalizedString("ai_prompt_task_description", comment: "Task description")
        let summaryTitle = NSLocalizedString("ai_prompt_section_summary", comment: "Summary title")
        let summaryDesc = NSLocalizedString("ai_prompt_section_summary_desc", comment: "Summary desc")
        let mvpTitle = NSLocalizedString("ai_prompt_section_mvp", comment: "MVP title")
        let mvpDesc = NSLocalizedString("ai_prompt_section_mvp_desc", comment: "MVP desc")
        let highlightsTitle = NSLocalizedString("ai_prompt_section_highlights", comment: "Highlights title")
        let highlightsDesc = NSLocalizedString("ai_prompt_section_highlights_desc", comment: "Highlights desc")
        let extraReq = NSLocalizedString("ai_prompt_extra_requirements", comment: "Extra requirements")
        let req1 = NSLocalizedString("ai_prompt_req_1", comment: "Req 1")
        let req2 = NSLocalizedString("ai_prompt_req_2", comment: "Req 2")
        let req3 = NSLocalizedString("ai_prompt_req_3", comment: "Req 3")
        let req4 = NSLocalizedString("ai_prompt_req_4", comment: "Req 4")
        let req5 = NSLocalizedString("ai_prompt_req_5", comment: "Req 5")
        let req6 = NSLocalizedString("ai_prompt_req_6", comment: "Req 6")
        let req7 = NSLocalizedString("ai_prompt_req_7", comment: "Req 7")
        let req8 = NSLocalizedString("ai_prompt_req_8", comment: "Req 8")
        let req9 = NSLocalizedString("ai_prompt_req_9", comment: "Req 9")
        let req10 = NSLocalizedString("ai_prompt_req_10", comment: "Req 10")
        let req11 = NSLocalizedString("ai_prompt_req_11", comment: "Req 11")
        let req12 = NSLocalizedString("ai_prompt_req_12", comment: "Req 12")
        let req13 = NSLocalizedString("ai_prompt_req_13", comment: "Req 13")
        let req14 = NSLocalizedString("ai_prompt_req_14", comment: "Req 14")

        let gameInfoLabel = NSLocalizedString("ai_prompt_game_info_label", comment: "Game info label")
        let dateLabel = NSLocalizedString("ai_prompt_date_label", comment: "Date label")
        let matchupLabel = NSLocalizedString("ai_prompt_matchup_label", comment: "Matchup label")
        let scoreLabel = NSLocalizedString("ai_prompt_score_label", comment: "Score label")
        let periodsLabel = NSLocalizedString("ai_prompt_periods_label", comment: "Periods label")
        let playersLabel = NSLocalizedString("ai_prompt_players_label", comment: "Players label")
        let numericFactsLabel = NSLocalizedString("ai_prompt_numeric_facts_label", comment: "Numeric facts label")

        let dateStr = Self.aiPromptDateFormatter.string(from: game.savedAt)
        let matchupStr = String(format: matchupLabel, game.homeTeamName, game.awayTeamName)
        let scoreStr = String(format: scoreLabel, game.homeTeamName, homeScore, awayScore, game.awayTeamName)
        let periodsStr = String(format: periodsLabel, game.snapshot.periodCount)
        let dateFormatted = String(format: dateLabel, dateStr)

        return """
        \(taskDesc)

        ### \(summaryTitle)
        \(summaryDesc)

        ### \(mvpTitle)
        \(mvpDesc)

        ### \(highlightsTitle)
        \(highlightsDesc)

        \(extraReq)
        \(req1)
        \(req2)
        \(req3)
        \(req4)
        \(req5)
        \(req6)
        \(req7)
        \(req8)
        \(req9)
        \(req10)
        \(req11)
        \(req12)
        \(req13)
        \(req14)

        \(gameInfoLabel)
        \(dateFormatted)
        \(matchupStr)
        \(scoreStr)
        \(periodsStr)
        - 球队统计模式：主队=\(game.snapshot.homeTeamStatsMode ? "是" : "否") 客队=\(game.snapshot.awayTeamStatsMode ? "是" : "否")

        \(playersLabel)
        \(playersText)

        \(teamStatsPromptSection())

        \(numericFactsLabel)
        \(numericFacts)

        【事件日志（按节次）】
        \(eventsByPeriod)

        【每节得分汇总】
        \(periodStatsText)

        【连续得分分析（系统预计算）】
        \(scoringRunData())
        """
    }

    private func normalizeAISummary(_ raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        text = stripOuterCodeFenceIfNeeded(text)

        if text.contains("\\n") {
            text = text.replacingOccurrences(of: "\\n", with: "\n")
        }
        if text.contains("\\t") {
            text = text.replacingOccurrences(of: "\\t", with: "\t")
        }

        var normalizedLines: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("###") {
                if normalizedLines.last?.isEmpty == false {
                    normalizedLines.append("")
                }
                normalizedLines.append(trimmed)
                normalizedLines.append("")
                continue
            }

            if trimmed.hasPrefix("• ") {
                normalizedLines.append("- " + String(trimmed.dropFirst(2)))
                continue
            }

            normalizedLines.append(line)
        }

        let normalized = normalizedLines.joined(separator: "\n")
        return collapseExtraBlankLines(normalized)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func stripOuterCodeFenceIfNeeded(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") && trimmed.hasSuffix("```") else {
            return trimmed
        }

        var lines = trimmed.components(separatedBy: "\n")
        guard lines.count >= 2 else { return trimmed }
        lines.removeFirst()
        lines.removeLast()
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func collapseExtraBlankLines(_ text: String) -> String {
        let pattern = "\\n{3,}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "\n\n")
    }

    private func parseAISummarySections(from text: String) -> [AISummarySection] {
        guard !text.isEmpty else { return [] }

        var sections: [AISummarySection] = []
        var currentTitle: String?
        var currentLines: [String] = []

        func flushCurrent() {
            let items = summaryItems(from: currentLines)
            guard !items.isEmpty else {
                currentLines.removeAll()
                return
            }
            sections.append(AISummarySection(title: currentTitle ?? "比赛总结", items: items))
            currentLines.removeAll()
        }

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("###") {
                flushCurrent()
                currentTitle = line
                    .replacingOccurrences(of: "###", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                currentTitle = stripMarkdownDecorations(from: currentTitle ?? "")
                continue
            }

            if !line.isEmpty || !currentLines.isEmpty {
                currentLines.append(line)
            }
        }

        flushCurrent()

        if sections.isEmpty {
            let fallbackItems = summaryItems(from: text.components(separatedBy: "\n"))
            if !fallbackItems.isEmpty {
                sections = [AISummarySection(title: "比赛总结", items: fallbackItems)]
            }
        }

        return sections
    }

    private func summaryItems(from lines: [String]) -> [String] {
        var items: [String] = []
        var paragraph: [String] = []

        func flushParagraph() {
            let content = paragraph
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                items.append(stripMarkdownDecorations(from: content))
            }
            paragraph.removeAll()
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                flushParagraph()
                continue
            }

            if let bullet = summaryBulletText(from: line) {
                flushParagraph()
                items.append(stripMarkdownDecorations(from: bullet))
                continue
            }

            paragraph.append(line)
        }

        flushParagraph()
        return items
    }

    private func summaryBulletText(from line: String) -> String? {
        if line.hasPrefix("- ") {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if line.hasPrefix("• ") {
            return String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let range = line.range(of: #"^\d+[\.、]\s*"#, options: .regularExpression) {
            let content = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return content.isEmpty ? nil : content
        }

        return nil
    }

    private func stripMarkdownDecorations(from text: String) -> String {
        var cleaned = text

        cleaned = replacing(#"(?m)^\s*#{1,6}\s*"#, in: cleaned, with: "")
        cleaned = replacing(#"(?m)^\s*>+\s*"#, in: cleaned, with: "")
        cleaned = replacing(#"!\[[^\]]*\]\([^\)]*\)"#, in: cleaned, with: "")
        cleaned = replacing(#"\[([^\]]+)\]\([^\)]*\)"#, in: cleaned, with: "$1")
        cleaned = replacing(#"`([^`]+)`"#, in: cleaned, with: "$1")
        cleaned = replacing(#"\*\*([^*]+)\*\*"#, in: cleaned, with: "$1")
        cleaned = replacing(#"__([^_]+)__"#, in: cleaned, with: "$1")
        cleaned = replacing(#"\*([^*]+)\*"#, in: cleaned, with: "$1")
        cleaned = replacing(#"_([^_]+)_"#, in: cleaned, with: "$1")
        cleaned = replacing(#"~~([^~]+)~~"#, in: cleaned, with: "$1")
        cleaned = replacing(#"\"([^\"]+)\""#, in: cleaned, with: "$1")
        cleaned = replacing(#"[""]"#, in: cleaned, with: "")
        cleaned = replacing(#"[‘’]"#, in: cleaned, with: "")
        cleaned = replacing(#"(?<![A-Za-z])'([^']+)'(?![A-Za-z])"#, in: cleaned, with: "$1")
        cleaned = replacing(#"\\([\*_`~\[\]\(\)])"#, in: cleaned, with: "$1")

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isMVPSection(_ title: String) -> Bool {
        title.localizedCaseInsensitiveContains("mvp")
    }

    private func mvpPlayerID(in text: String) -> UUID? {
        let normalized = stripMarkdownDecorations(from: text)
        let candidates = game.playerNamesByID
            .map { (id: $0.key, name: $0.value.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.name.isEmpty }
            .sorted { $0.name.count > $1.name.count }

        return candidates.first(where: { normalized.contains($0.name) })?.id
    }

    private func replacing(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }

    private func iconForSummarySection(_ title: String) -> String {
        if title.localizedCaseInsensitiveContains("mvp") {
            return "trophy.fill"
        }
        if title.contains("高亮") {
            return "sparkles"
        }
        if title.contains("总结") {
            return "text.quote"
        }
        return "doc.text"
    }

    private func iconForSummaryItem(sectionTitle: String, item: String, index: Int) -> String {
        if sectionTitle.localizedCaseInsensitiveContains("mvp") {
            return "person.crop.circle.badge.checkmark"
        }
        if sectionTitle.contains("高亮") {
            return "bolt.fill"
        }
        if item.contains("关键") {
            return "flag.fill"
        }
        if item.contains("比分") {
            return "chart.line.uptrend.xyaxis"
        }
        return index == 0 ? "circle.fill" : "smallcircle.filled.circle"
    }

    private struct AISummarySection {
        var title: String
        var items: [String]
    }




    private func side(for playerID: UUID?) -> TeamSide? {
        guard let playerID else { return nil }
        if game.homePlayerIDs.contains(playerID) { return .home }
        if game.awayPlayerIDs.contains(playerID) { return .away }
        return nil
    }

    private func playerName(_ playerID: UUID?) -> String {
        guard let playerID else { return NSLocalizedString("unknown_player", comment: "") }
        return game.playerNamesByID[playerID] ?? store.player(for: playerID)?.name ?? NSLocalizedString("unknown_player", comment: "")
    }

    private func numericFactsText() -> String {
        let participantIDs = allPlayerIDsForSummary().filter { game.didParticipate($0) }
        guard !participantIDs.isEmpty else {
            return "- 未找到可用于校验的出场球员统计。"
        }

        let homeScore = score(for: game.snapshot.homeTeamID)
        let awayScore = score(for: game.snapshot.awayTeamID)
        let scoreTotal = homeScore + awayScore
        let playerScoreTotal = participantIDs.reduce(0) { partial, playerID in
            partial + game.snapshot.statsByPlayerID[playerID, default: PlayerStats()].points
        }

        var lines: [String] = []
        lines.append("比分总分：\(homeScore)+\(awayScore)=\(scoreTotal)，出场球员得分汇总 \(playerScoreTotal)")

        lines.append(metricLine("得分最高", among: participantIDs, unit: "分") {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].points
        })
        lines.append(metricLine("得分最低（出场球员）", among: participantIDs, order: .ascending, unit: "分") {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].points
        })
        lines.append(metricLine("篮板最多", among: participantIDs, unit: "个", requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].totalRebounds
        })
        lines.append(metricLine("助攻最多", among: participantIDs, unit: "次", requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].assists
        })
        lines.append(metricLine("封盖最多", among: participantIDs, unit: "次", requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].blocks
        })
        lines.append(metricLine("抢断最多", among: participantIDs, unit: "次", requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].steals
        })
        lines.append(metricLine("失误最多", among: participantIDs, unit: "次", requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].turnovers
        })
        lines.append(metricLine("正负值最高", among: participantIDs, unit: "") {
            game.snapshot.plusMinusByPlayerID[$0, default: 0]
        })
        lines.append(metricLine("正负值最低", among: participantIDs, order: .ascending, unit: "") {
            game.snapshot.plusMinusByPlayerID[$0, default: 0]
        })

        if let longest = leadingPlayers(
            among: participantIDs,
            metric: { Int(game.snapshot.playingSecondsByPlayerID[$0, default: 0].rounded(.down)) },
            order: .descending,
            requirePositive: true
        ) {
            let duration = GameView.durationFormatter(TimeInterval(longest.value))
            lines.append("出场时间最长：\(playersText(for: longest.playerIDs))（\(duration)）")
        } else {
            lines.append("出场时间最长：暂无有效记录")
        }

        return lines.map { "- \($0)" }.joined(separator: "\n")
    }

    private enum RankingOrder {
        case ascending
        case descending
    }

    private func metricLine(
        _ title: String,
        among playerIDs: [UUID],
        order: RankingOrder = .descending,
        unit: String,
        requirePositive: Bool = false,
        metric: (UUID) -> Int
    ) -> String {
        guard let leader = leadingPlayers(
            among: playerIDs,
            metric: metric,
            order: order,
            requirePositive: requirePositive
        ) else {
            return "\(title)：暂无有效记录"
        }

        let valueText = unit.isEmpty
            ? signedNumberText(leader.value)
            : "\(leader.value)\(unit)"
        return "\(title)：\(playersText(for: leader.playerIDs))（\(valueText)）"
    }

    private func leadingPlayers(
        among playerIDs: [UUID],
        metric: (UUID) -> Int,
        order: RankingOrder,
        requirePositive: Bool
    ) -> (playerIDs: [UUID], value: Int)? {
        var pairs = playerIDs.map { ($0, metric($0)) }
        if requirePositive {
            pairs = pairs.filter { $0.1 > 0 }
        }

        guard !pairs.isEmpty else { return nil }

        let targetValue = order == .descending
            ? pairs.map { $0.1 }.max()
            : pairs.map { $0.1 }.min()

        guard let targetValue else { return nil }

        let leaders = pairs
            .filter { $0.1 == targetValue }
            .map { $0.0 }
            .sorted { playerName($0) < playerName($1) }

        return (leaders, targetValue)
    }

    private func playersText(for playerIDs: [UUID], maxCount: Int = 3) -> String {
        let names = playerIDs.map(playerName).sorted()
        guard names.count > maxCount else {
            return names.joined(separator: " / ")
        }

        let shown = names.prefix(maxCount).joined(separator: " / ")
        return "\(shown) 等\(names.count)人"
    }

    private func signedNumberText(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func allPlayerIDsForSummary() -> [UUID] {
        var excludeIDs = Set<UUID>()
        if game.snapshot.homeTeamStatsMode {
            excludeIDs.formUnion(game.homePlayerIDs)
        }
        if game.snapshot.awayTeamStatsMode {
            excludeIDs.formUnion(game.awayPlayerIDs)
        }
        let allIDs = Array(Set(game.homePlayerIDs + game.awayPlayerIDs + Array(game.snapshot.statsByPlayerID.keys)))
            .filter { !excludeIDs.contains($0) }
        return allIDs.sorted { lhs, rhs in
            let lhsPoints = game.snapshot.statsByPlayerID[lhs, default: PlayerStats()].points
            let rhsPoints = game.snapshot.statsByPlayerID[rhs, default: PlayerStats()].points
            if lhsPoints != rhsPoints { return lhsPoints > rhsPoints }
            return (game.playerNamesByID[lhs] ?? "") < (game.playerNamesByID[rhs] ?? "")
        }
    }

    private static let aiPromptDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    @ViewBuilder
    private func playerAvatar(for playerID: UUID) -> some View {
        if let player = store.player(for: playerID) {
            PlayerAvatarView(player: player, size: 36)
        } else {
            Circle()
                .fill(Color.accentColor.opacity(0.16))
                .frame(width: 36, height: 36)
                .overlay {
                    Text(String((game.playerNamesByID[playerID] ?? "?").prefix(2)))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
        }
    }

    @ViewBuilder
    private func mvpPlayerAvatar(for playerID: UUID) -> some View {
        if let player = store.player(for: playerID) {
            PlayerAvatarView(player: player, size: 24)
        } else {
            Circle()
                .fill(Color.accentColor.opacity(0.16))
                .frame(width: 24, height: 24)
                .overlay {
                    Text(String((game.playerNamesByID[playerID] ?? "?").prefix(2)))
                        .font(.caption2.weight(.semibold))
                         .foregroundStyle(Color.accentColor)
                }
        }
    }

    private var periodStartTimestamps: [Int: Date] {
        var result: [Int: Date] = [:]
        var period = 1
        for log in game.snapshot.logs.sorted(by: { $0.timestamp < $1.timestamp }) {
            if let code = log.eventCode, (code == "event.period_start" || code == "event.period") {
                result[period] = log.timestamp
                period += 1
            }
        }
        return result
    }

    // MARK: - Event Log Editing

    private var editEventListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text(LocalizedStringKey("label_edit_event_log"))
                    .font(.headline)
                Spacer()
                Button {
                    editingSheetEntry = nil
                    showEditSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            List {
                let grouped = Dictionary(grouping: filteredPeriodAwareLogs, by: { $0.inferredPeriod ?? 0 })
                let sortedPeriods = grouped.keys.sorted()
                ForEach(sortedPeriods, id: \.self) { period in
                    Section {
                        Button {
                            if expandedPeriods.contains(period) { expandedPeriods.remove(period) }
                            else { expandedPeriods.insert(period) }
                        } label: {
                            HStack {
                                Text(String(format: NSLocalizedString("data_range_period", comment: ""), period))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: expandedPeriods.contains(period) ? "chevron.down" : "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if expandedPeriods.contains(period) {
                            let periodStart = periodStartTimestamps[period] ?? game.snapshot.logs.first?.timestamp ?? Date()
                            let minuteGrouped = Dictionary(grouping: grouped[period] ?? [], by: { log in
                                let elapsed = log.entry.timestamp.timeIntervalSince(periodStart)
                                return Int(elapsed / 60)
                            })
                            let sortedMinutes = minuteGrouped.keys.sorted()
                            ForEach(sortedMinutes, id: \.self) { minute in
                                let isExpanded = expandedMinutes[period, default: []].contains(minute)
                                Button {
                                    if isExpanded { expandedMinutes[period, default: []].remove(minute) }
                                    else { expandedMinutes[period, default: []].insert(minute) }
                                } label: {
                                    HStack {
                                        Text("\(String(format: NSLocalizedString("data_range_period", comment: ""), period)) \(minute)\u{2019}")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .padding(.leading, 16)

                                if isExpanded {
                                    ForEach(minuteGrouped[minute] ?? []) { log in
                                        editEventRow(log: log)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .sheet(isPresented: $showEditSheet) {
            let events = game.snapshot.logs
            let firstTS = events.first?.timestamp ?? game.savedAt
            let lastTS = events.last?.timestamp ?? game.savedAt
            let gameStart = min(firstTS, lastTS)
            let editingEntry = editingSheetEntry
            let existingEntry = editingEntry.flatMap { e in events.first { $0.id == e.id } } ?? editingEntry
            let homeStarters = game.snapshot.starterPlayerIDs.filter { game.homePlayerIDs.contains($0) }
            let awayStarters = game.snapshot.starterPlayerIDs.filter { game.awayPlayerIDs.contains($0) }
            return EventLogEditSheet(
                allPlayers: game.homePlayerIDs.compactMap { store.player(for: $0) }
                    + game.awayPlayerIDs.compactMap { store.player(for: $0) },
                homePlayerIDs: game.homePlayerIDs,
                awayPlayerIDs: game.awayPlayerIDs,
                logs: events,
                homeStarterIDs: homeStarters,
                awayStarterIDs: awayStarters,
                gameStartTime: gameStart,
                gameEndTime: max(firstTS, lastTS),
                defaultNewTimestamp: editingEntry == nil ? gameStart : nil,
                existingEntry: existingEntry,
                onSave: { timestamp, playerID, action in
                    if let existing = editingEntry.flatMap({ e in game.snapshot.logs.first { $0.id == e.id } }) {
                        modifyEvent(existing, timestamp: timestamp, playerID: playerID, action: action)
                    } else {
                        addEvent(timestamp: timestamp, playerID: playerID, action: action)
                    }
                    editingSheetEntry = nil
                }
            )
        }
    }

    private func editEventRow(log: PeriodAwareLog) -> some View {
        let code = log.entry.eventCode ?? ""
        let isProtected = ["event.period_start", "event.period_end", "event.game_end", "event.starters_home", "event.starters_away"].contains(code)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(logLineText(for: log))
                    .font(.caption)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(log.entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let code = log.entry.eventCode {
                        Text(code)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !isProtected {
                Button(NSLocalizedString("button_edit", comment: "")) {
                    editingSheetEntry = log.entry
                    showEditSheet = true
                }
                .tint(.blue)
                Button(NSLocalizedString("label_delete", comment: "")) {
                    deleteEvent(log.entry)
                }
                .tint(.red)
            }
        }
    }

    private func addEvent(timestamp: Date, playerID: UUID, action: StatAction) {
        let eventCode = action.eventCode
        let entry = GameLogEntry(
            timestamp: timestamp,
            message: "\(store.player(for: playerID)?.name ?? "?") \(action.message) [event:\(eventCode)]",
            eventCode: eventCode,
            playerID: playerID
        )
        guard let gameIndex = store.savedGames.firstIndex(where: { $0.id == game.id }) else { return }
        store.savedGames[gameIndex].snapshot.logs.append(entry)
        store.savedGames[gameIndex].snapshot.logs.sort { $0.timestamp < $1.timestamp }
        rebuildPeriodAnalysis()
        sanitizeSelectedPeriod()
    }

    private func modifyEvent(_ entry: GameLogEntry, timestamp: Date, playerID: UUID, action: StatAction) {
        let eventCode = action.eventCode
        guard let logIndex = game.snapshot.logs.firstIndex(where: { $0.id == entry.id }),
              let gameIndex = store.savedGames.firstIndex(where: { $0.id == game.id }) else { return }
        store.savedGames[gameIndex].snapshot.logs[logIndex].playerID = playerID
        store.savedGames[gameIndex].snapshot.logs[logIndex].eventCode = eventCode
        store.savedGames[gameIndex].snapshot.logs[logIndex].message = "\(store.player(for: playerID)?.name ?? "?") \(action.message) [event:\(eventCode)]"
        rebuildPeriodAnalysis()
        sanitizeSelectedPeriod()
    }

    private func deleteEvent(_ entry: GameLogEntry) {
        guard let logIndex = game.snapshot.logs.firstIndex(where: { $0.id == entry.id }),
              let gameIndex = store.savedGames.firstIndex(where: { $0.id == game.id }) else { return }
        store.savedGames[gameIndex].snapshot.logs.remove(at: logIndex)
        rebuildPeriodAnalysis()
        sanitizeSelectedPeriod()
    }
}

private struct ExportGameView: View {
    @EnvironmentObject private var store: AppStore
    @EnvironmentObject private var bluetooth: BluetoothSyncManager
    @Environment(\.dismiss) private var dismiss
    var game: SavedGame

    @State private var base64 = ""
    @State private var transferID = GameShareChunkCodec.generateTransferID()
    @State private var segmentCount = 4
    @State private var chunkLines: [String] = []
    @State private var isGenerating = true
    @State private var copiedChunkIndex: Int?
    @State private var copiedChunkFeedbackTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                if isGenerating {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text(LocalizedStringKey("transfer_generating_compressed"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                } else if base64.isEmpty {
                    Section {
                        Text(LocalizedStringKey("transfer_generate_failed_retry"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section(LocalizedStringKey("section_bluetooth_transfer")) {
                        if bluetooth.connectedPeers.isEmpty {
                            Text(LocalizedStringKey("transfer_no_connected_devices_hint"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            NavigationLink {
                                BluetoothStoreSyncComposerView(preset: .game(game.id))
                                    .environmentObject(store)
                                    .environmentObject(bluetooth)
                            } label: {
                                Label(LocalizedStringKey("transfer_send_current_game_bluetooth"), systemImage: "dot.radiowaves.left.and.right")
                            }

                            Text(LocalizedStringKey("transfer_open_to_pick_device_progress_hint"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section(LocalizedStringKey("section_export_settings")) {
                        Stepper(value: $segmentCount, in: 1...8) {
                            HStack {
                                Text(LocalizedStringKey("label_segment_count"))
                                Spacer(minLength: 8)
                                Text(String(format: NSLocalizedString("segment_count_value_format", comment: "Segment count value"), segmentCount))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Text(String(format: NSLocalizedString("transfer_total_segments_hint_format", comment: "Total segments hint"), chunkLines.count))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Section(LocalizedStringKey("section_game_share_code")) {
                        ForEach(Array(chunkLines.enumerated()), id: \.offset) { index, line in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(String(format: NSLocalizedString("segment_progress_format", comment: "Segment progress"), index + 1, chunkLines.count))
                                    .font(.subheadline.weight(.semibold))

                                TransferCodePreview(text: line)

                                Button {
                                    UIPasteboard.general.string = line
                                    showChunkCopyFeedback(index)
                                } label: {
                                    Label(
                                        copiedChunkIndex == index ? NSLocalizedString("status_copied", comment: "Copied") : String(format: NSLocalizedString("button_copy_segment_format", comment: "Copy segment"), index + 1),
                                        systemImage: copiedChunkIndex == index ? "checkmark.circle.fill" : "doc.on.doc"
                                    )
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(AppSoftProminentButtonStyle())
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    Section {
                        ShareLink(item: chunkLines.joined(separator: "\n")) {
                            Label(LocalizedStringKey("button_share_all_segments"), systemImage: TransferSymbol.exportData)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppSoftProminentButtonStyle())
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("nav_export_game"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_done")) { dismiss() }
                }
            }
            .task(id: game.id) {
                await generateBase64()
            }
            .onChange(of: segmentCount) { _, _ in
                rebuildChunkLines()
            }
            .onDisappear {
                copiedChunkFeedbackTask?.cancel()
            }
        }
    }

    private func generateBase64() async {
        isGenerating = true
        base64 = ""
        chunkLines = []
        transferID = GameShareChunkCodec.generateTransferID()
        await Task.yield()
        base64 = store.exportGameBase64(game) ?? ""
        rebuildChunkLines()
        isGenerating = false
    }

    private func rebuildChunkLines() {
        chunkLines = GameShareChunkCodec.makeChunkLines(
            payload: base64,
            preferredParts: segmentCount,
            transferID: transferID
        )
    }

    private func showChunkCopyFeedback(_ index: Int) {
        copiedChunkIndex = index
        copiedChunkFeedbackTask?.cancel()
        copiedChunkFeedbackTask = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            copiedChunkIndex = nil
        }
    }

}



