import SwiftUI

struct AISummaryView: View {
    let game: SavedGame
    let store: AppStore
    let periodAnalysis: SavedGamePeriodAnalysis
    
    @Binding var isShowingPurchase: Bool
    
    @State private var isGeneratingAISummary = false
    @State private var aiSummary = ""
    @State private var aiSummaryError: String?
    @State private var showSummaryExistsAlert = false
    @State private var savedToPhotos = false
    
    init(game: SavedGame, store: AppStore, periodAnalysis: SavedGamePeriodAnalysis, isShowingPurchase: Binding<Bool>) {
        self.game = game
        self.store = store
        self.periodAnalysis = periodAnalysis
        self._isShowingPurchase = isShowingPurchase
        let latest = store.savedGames.first(where: { $0.id == game.id })?.aiSummary
        _aiSummary = State(initialValue: latest ?? game.aiSummary ?? "")
    }
    
    var body: some View {
        Section(LocalizedStringKey("section_ai_game_summary")) {
            Button {
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
        .onAppear {
            if aiSummary.isEmpty,
               let currentGame = store.savedGames.first(where: { $0.id == game.id }),
               let savedSummary = currentGame.aiSummary,
               !savedSummary.isEmpty {
                let normalizedSummary = normalizeAISummary(savedSummary)
                aiSummary = normalizedSummary
                if normalizedSummary != savedSummary {
                    store.updateAISummary(normalizedSummary, for: game.id)
                }
            }
        }
        .onChange(of: periodAnalysis.statsByPeriod.isEmpty) { _, isEmpty in
            guard !isEmpty else { return }
        }
        .alert(LocalizedStringKey("alert_ai_summary_exists_title"), isPresented: $showSummaryExistsAlert) {
            Button(LocalizedStringKey("button_ok")) { }
        } message: {
            Text(LocalizedStringKey("alert_ai_summary_exists_message"))
        }
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
    
    @ViewBuilder
    private var aiSummaryContent: some View {
        let sections = aiSummarySections
        if sections.isEmpty {
            Text(stripMarkdownDecorations(from: normalizeAISummary(aiSummary)))
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        } else {
            Group {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    let isMVP = isMVPSection(section.title)
                    let mvpID = isMVP ? mvpPlayerID(in: section.items) : nil
                    
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
        }
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
                    if let updatedGame = store.savedGames.first(where: { $0.id == game.id }) {
                        BadgeAwarder.awardBadges(for: updatedGame, store: store)
                    }
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
        let analysis = periodAnalysis
        let periodCount = game.snapshot.periodCount
        var lines: [String] = []
        
        let maxAnalysisPeriod = analysis.statsByPeriod.keys.max() ?? periodCount
        for period in 1...max(maxAnalysisPeriod, periodCount) {
            let periodLogs = analysis.logs(for: period).filter { log in
                GameLogFormatter.isScoring(log) || log.entry.eventCode == "stat.foul" || log.entry.eventCode == "stat.assist" || log.entry.eventCode == "stat.rebound" || log.entry.eventCode == "stat.block" || log.entry.eventCode == "stat.steal" || log.entry.eventCode == "stat.turnover"
            }
            guard !periodLogs.isEmpty else { continue }
            
            lines.append("- \(game.periodDisplayName(period))：")
            for log in periodLogs.prefix(20) {
                let msg = GameLogFormatter.normalizedMessage(log.entry.message)
                    .replacingOccurrences(of: "\\[event:\\w+(\\.\\w+)*\\]", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                if !msg.isEmpty {
                    lines.append("  - \(msg)")
                }
            }
        }
        
        if lines.isEmpty {
            return NSLocalizedString("ai_prompt_no_events", comment: "No events")
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
    
    private func combinedTimelineText() -> String {
        let scoringCodes = StatAction.scoringEventCodes
        let pointMap = StatAction.pointMap
        var homeIDs = Set(game.homePlayerIDs)
        if game.snapshot.homeTeamStatsMode, let tid = game.snapshot.homeTeamID { homeIDs.insert(tid) }
        let allIDs = allPlayerIDsForSummary()
        let idToName: [UUID: String] = Dictionary(uniqueKeysWithValues: allIDs.compactMap { id in
            game.playerNamesByID[id].map { (id, $0) }
        })
        func resolveTeamID(log: GameLogEntry) -> UUID? {
            game.resolvedTeamID(from: log.message)
        }

        let nonScoringEventCodes: Set<String> = ["stat.foul", "stat.assist", "stat.rebound", "stat.block", "stat.steal", "stat.turnover"]
        let gameStartTime = game.snapshot.logs.first?.timestamp ?? game.savedAt

        struct TimelineEntry {
            let timeStr: String
            let line: String
            let period: Int
            let sortKey: Date
        }
        var entries: [TimelineEntry] = []
        var homeScore = 0, awayScore = 0

        for log in game.snapshot.logs {
            let elapsed = max(0, log.timestamp.timeIntervalSince(gameStartTime))
            let min = Int(elapsed / 60); let sec = Int(elapsed) % 60
            let timeStr = String(format: "%02d:%02d", min, sec)
            let period = log.period ?? 1
            let code = log.eventCode ?? GameLogFormatter.extractEventCode(from: log.message)

            // Scoring event
            if let code, scoringCodes.contains(code), let points = pointMap[code] {
                let resolvedPid = log.playerID ?? resolvedPlayerID(log: log) ?? resolveTeamID(log: log)
                let isCompositeAssist = code == "stat.assistTwoMade" || code == "stat.assistThreeMade"
                let pid = isCompositeAssist ? (log.relatedPlayerID ?? resolvedPid) : resolvedPid
                if let pid {
                    let isHome = homeIDs.contains(pid)
                    let prevHome = homeScore; let prevAway = awayScore
                    if isHome { homeScore += points } else { awayScore += points }
                    let playerName = idToName[pid] ?? (pid == game.snapshot.homeTeamID ? game.homeTeamName : pid == game.snapshot.awayTeamID ? game.awayTeamName : "?")
                    let lead = homeScore - awayScore
                    let leadStr: String
                    if lead > 0 {
                        leadStr = String(format: NSLocalizedString("ai_prompt_lead_format", comment: ""), game.homeTeamName, lead)
                    } else if lead < 0 {
                        leadStr = String(format: NSLocalizedString("ai_prompt_lead_format", comment: ""), game.awayTeamName, -lead)
                    } else {
                        leadStr = NSLocalizedString("ai_prompt_diff_tied", comment: "Tied")
                    }
                    let msg = GameLogFormatter.normalizedMessage(log.message)
                        .replacingOccurrences(of: "\\[event:\\w+(\\.\\w+)*\\]", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespaces)
                    let desc = msg.isEmpty ? "" : " - \(msg)"
                    let line = "  [\(timeStr)] \(playerName) +\(points) (\(game.homeTeamName) \(prevHome):\(prevAway) \(game.awayTeamName)->\(game.homeTeamName) \(homeScore):\(awayScore) \(game.awayTeamName), \(leadStr))\(desc)"
                    entries.append(TimelineEntry(timeStr: timeStr, line: line, period: period, sortKey: log.timestamp))
                }
                continue
            }

            // Non-scoring tracked event
            if let code, nonScoringEventCodes.contains(code) {
                let pid = log.playerID ?? resolvedPlayerID(log: log) ?? resolveTeamID(log: log)
                let playerName: String
                if let pid {
                    playerName = idToName[pid] ?? (pid == game.snapshot.homeTeamID ? game.homeTeamName : pid == game.snapshot.awayTeamID ? game.awayTeamName : "?")
                } else {
                    playerName = "?"
                }
                let msg = GameLogFormatter.normalizedMessage(log.message)
                    .replacingOccurrences(of: "\\[event:\\w+(\\.\\w+)*\\]", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
                let displayMsg = msg.isEmpty ? code : msg
                let line = "  [\(timeStr)] \(playerName) - \(displayMsg)"
                entries.append(TimelineEntry(timeStr: timeStr, line: line, period: period, sortKey: log.timestamp))
            }
        }

        entries.sort { $0.sortKey < $1.sortKey }

        // Merge scoring run events into the timeline
        let runEvents = scoringRunEvents()
        for (ts, period, line) in runEvents {
            let elapsed = max(0, ts.timeIntervalSince(gameStartTime))
            let min = Int(elapsed / 60); let sec = Int(elapsed) % 60
            let timeStr = String(format: "%02d:%02d", min, sec)
            entries.append(TimelineEntry(timeStr: timeStr, line: "  [\(timeStr)]\(line)", period: period, sortKey: ts))
        }

        entries.sort { $0.sortKey < $1.sortKey }

        var lines: [String] = []
        var lastPeriod = 0
        for entry in entries {
            if entry.period != lastPeriod {
                lastPeriod = entry.period
                lines.append("- \(game.periodDisplayName(entry.period)):")
            }
            lines.append(entry.line)
        }
        return lines.isEmpty ? NSLocalizedString("ai_prompt_no_scoring_record", comment: "No scoring") : lines.joined(separator: "\n")
    }
    
    private func scoringRunEvents() -> [(Date, Int, String)] {
        let scoringCodes = StatAction.scoringEventCodes
        let pointMap = StatAction.pointMap
        var homeIDs = Set(game.homePlayerIDs)
        if game.snapshot.homeTeamStatsMode, let tid = game.snapshot.homeTeamID { homeIDs.insert(tid) }
        let allIDs = allPlayerIDsForSummary()
        var idToName: [UUID: String] = Dictionary(uniqueKeysWithValues: allIDs.compactMap { id in
            game.playerNamesByID[id].map { (id, $0) }
        })
        if game.snapshot.homeTeamStatsMode, let tid = game.snapshot.homeTeamID {
            idToName[tid] = game.homeTeamName
        }
        if game.snapshot.awayTeamStatsMode, let tid = game.snapshot.awayTeamID {
            idToName[tid] = game.awayTeamName
        }

        var events: [(Date, Int, String)] = []
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
        var lastTimestamp: Date = game.savedAt
        var lastPeriod: Int = 1

        func resolveTeamID(log: GameLogEntry) -> UUID? {
            game.resolvedTeamID(from: log.message)
        }

        func makeName(for pid: UUID?) -> String {
            guard let pid else { return "?" }
            return idToName[pid] ?? (pid == game.snapshot.homeTeamID ? game.homeTeamName : pid == game.snapshot.awayTeamID ? game.awayTeamName : "?")
        }

        for log in game.snapshot.logs {
            lastTimestamp = log.timestamp
            lastPeriod = log.period ?? 1
            guard let code = log.eventCode ?? GameLogFormatter.extractEventCode(from: log.message) else { continue }
            let rawPlayerID = log.playerID ?? resolvedPlayerID(log: log) ?? resolveTeamID(log: log)
            let isCompositeAssist = code == "stat.assistTwoMade" || code == "stat.assistThreeMade"
            let playerID = isCompositeAssist ? (log.relatedPlayerID ?? rawPlayerID) : rawPlayerID

            if scoringCodes.contains(code), let points = pointMap[code], let pid = playerID {
                let isHome = homeIDs.contains(pid)
                if isHome { homeScore += points } else { awayScore += points }

                // And-one detection
                if code == "stat.bonusMade", let lastCode = lastScoringCode, let lastPid = lastScoringPID, lastPid == pid {
                    let basePoints = lastCode == "stat.threeMade" ? 3 : 2
                    let totalPoints = basePoints + 1
                    let name = makeName(for: pid)
                    events.append((log.timestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_and_one", comment: ""), name, basePoints)))
                }
                if code == "stat.twoMade" || code == "stat.threeMade" {
                    lastScoringCode = code
                    lastScoringPID = pid
                } else if code != "stat.bonusMade" {
                    lastScoringCode = nil
                    lastScoringPID = nil
                }

                // Personal scoring run
                if personalRun?.playerID == pid {
                    personalRun?.count += 1
                    personalRun?.points += points
                } else {
                    if let run = personalRun, run.count >= 2 {
                        let name = makeName(for: run.playerID)
                        events.append((log.timestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_scoring_run", comment: ""), name, run.points, run.count)))
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
                        events.append((log.timestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_scoring_run", comment: ""), tName, run.points, run.count)))
                    }
                    teamRun = (isHome, 1, points)
                }

                // Reset non-scoring streaks
                reboundStreak = nil
                assistStreak = nil
                missedShotStreak = nil
                personalMissStreak = nil
                if bothMissStreak >= 6 {
                    events.append((log.timestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_both_miss_streak", comment: ""), bothMissStreak)))
                }
                bothMissStreak = 0
                continue
            }

            // Consecutive rebounds
            if code == "stat.rebound", let pid = playerID {
                if reboundStreak?.playerID == pid {
                    reboundStreak?.count += 1
                } else {
                    if let rs = reboundStreak, rs.count >= 3 {
                        let name = makeName(for: rs.playerID)
                        events.append((log.timestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_rebound_streak", comment: ""), name, rs.count)))
                    }
                    reboundStreak = (pid, 1)
                }
                continue
            }

            // Consecutive missed shots
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
                        events.append((log.timestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_miss_streak", comment: ""), tName, ms.count)))
                    }
                    missedShotStreak = (isHome, 1)
                }
                // Personal missed streak
                if personalMissStreak?.playerID == pid {
                    personalMissStreak?.count += 1
                } else {
                    if let pm = personalMissStreak, pm.count >= 3 {
                        let name = makeName(for: pm.playerID)
                        events.append((log.timestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_miss_streak", comment: ""), name, pm.count)))
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
                        let name = makeName(for: as_.playerID)
                        events.append((log.timestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_assist_streak", comment: ""), name, as_.count)))
                    }
                    assistStreak = (pid, 1)
                }
                continue
            }

            // Composite steal/turnover resets non-scoring streaks
            if code == "stat.stealTurnover" {
                reboundStreak = nil
                assistStreak = nil
                missedShotStreak = nil
                personalMissStreak = nil
                if bothMissStreak >= 6 {
                    events.append((log.timestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_both_miss_streak", comment: ""), bothMissStreak)))
                }
                bothMissStreak = 0
                continue
            }
        }

        // Flush remaining streaks
        if let run = personalRun, run.count >= 2 {
            let name = makeName(for: run.playerID)
            events.append((lastTimestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_scoring_run", comment: ""), name, run.points, run.count)))
        }
        if let run = teamRun, run.count >= 2, run.points >= 6 {
            let tName = run.isHome ? game.homeTeamName : game.awayTeamName
            events.append((lastTimestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_scoring_run", comment: ""), tName, run.points, run.count)))
        }
        if let rs = reboundStreak, rs.count >= 3 {
            let name = makeName(for: rs.playerID)
            events.append((lastTimestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_rebound_streak", comment: ""), name, rs.count)))
        }
        if let as_ = assistStreak, as_.count >= 3 {
            let name = makeName(for: as_.playerID)
            events.append((lastTimestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_assist_streak", comment: ""), name, as_.count)))
        }
        if let ms = missedShotStreak, ms.count >= 4 {
            let tName = ms.teamIsHome ? game.homeTeamName : game.awayTeamName
            events.append((lastTimestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_miss_streak", comment: ""), tName, ms.count)))
        }
        if let pm = personalMissStreak, pm.count >= 3 {
            let name = makeName(for: pm.playerID)
            events.append((lastTimestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_miss_streak", comment: ""), name, pm.count)))
        }
        if bothMissStreak >= 6 {
            events.append((lastTimestamp, lastPeriod, "  " + String(format: NSLocalizedString("ai_prompt_both_miss_streak", comment: ""), bothMissStreak)))
        }

        return events
    }
    
    private func resolvedPlayerID(log: GameLogEntry) -> UUID? {
        let normalized = GameLogFormatter.normalizedMessage(log.message)
        let candidates = game.playerNamesByID
            .map { (id: $0.key, name: $0.value.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.name.isEmpty }
            .sorted { $0.name.count > $1.name.count }
        for (id, name) in candidates where normalized.contains(name) {
            return id
        }
        return nil
    }
    
    private func summaryPrompt() -> String {
        let homeScore = score(for: game.snapshot.homeTeamID)
        let awayScore = score(for: game.snapshot.awayTeamID)
        let numericFacts = numericFactsText()
        
        // Per-period team & player scores for AI analysis
        let analysis = periodAnalysis
        let periodCount = game.snapshot.periodCount
        let allIDs = allPlayerIDsForSummary()
        var teamIncludedIDs = Set(allIDs)
        if game.snapshot.homeTeamStatsMode, let tid = game.snapshot.homeTeamID {
            teamIncludedIDs.insert(tid)
        }
        if game.snapshot.awayTeamStatsMode, let tid = game.snapshot.awayTeamID {
            teamIncludedIDs.insert(tid)
        }
        var idToName: [UUID: String] = Dictionary(uniqueKeysWithValues: allIDs.compactMap { id in
            game.playerNamesByID[id].map { (id, $0) }
        })
        if game.snapshot.homeTeamStatsMode, let tid = game.snapshot.homeTeamID {
            idToName[tid] = game.homeTeamName
        }
        if game.snapshot.awayTeamStatsMode, let tid = game.snapshot.awayTeamID {
            idToName[tid] = game.awayTeamName
        }
        var periodStatLines: [String] = []
        var runningHome = 0, runningAway = 0
        let maxAnalysisPeriod = analysis.statsByPeriod.keys.max() ?? periodCount
        for period in 1...max(maxAnalysisPeriod, periodCount) {
            let periodStats = analysis.statsByPlayerID(for: period)
            guard !periodStats.isEmpty else { continue }
            var homeIDs = Set(game.homePlayerIDs)
            if game.snapshot.homeTeamStatsMode, let tid = game.snapshot.homeTeamID { homeIDs.insert(tid) }
            let homePeriodPoints = periodStats.filter { homeIDs.contains($0.key) }.values.reduce(0) { $0 + $1.points }
            let awayPeriodPoints = periodStats.filter { !homeIDs.contains($0.key) }.values.reduce(0) { $0 + $1.points }
            runningHome += homePeriodPoints
            runningAway += awayPeriodPoints
            let diff = runningHome - runningAway
            let diffStr: String
            if diff > 0 {
                diffStr = String(format: NSLocalizedString("ai_prompt_lead_format", comment: ""), game.homeTeamName, diff)
            } else if diff < 0 {
                diffStr = String(format: NSLocalizedString("ai_prompt_lead_format", comment: ""), game.awayTeamName, -diff)
            } else {
                diffStr = NSLocalizedString("ai_prompt_diff_tied", comment: "Tied")
            }
            periodStatLines.append(String(format: NSLocalizedString("ai_prompt_period_summary_line", comment: "Period summary"), game.periodDisplayName(period), homePeriodPoints, awayPeriodPoints, runningHome, runningAway, diffStr))
            // Per-player stats for this period
            let sortedPlayers = teamIncludedIDs.filter { periodStats[$0] != nil }.sorted { lhs, rhs in
                (periodStats[lhs]?.points ?? 0) > (periodStats[rhs]?.points ?? 0)
            }
            for pid in sortedPlayers {
                guard let ps = periodStats[pid], ps.points > 0 else { continue }
                let name = idToName[pid] ?? "?"
                periodStatLines.append(String(format: NSLocalizedString("ai_prompt_player_period_stats", comment: "Player period stats"), name, ps.points, ps.totalRebounds, ps.assists))
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
        let mvpFormat = NSLocalizedString("ai_prompt_mvp_format", comment: "MVP format")
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
        let req15 = NSLocalizedString("ai_prompt_req_15", comment: "Req 15")
        let req16 = NSLocalizedString("ai_prompt_req_16", comment: "Req 16")
        let req17 = NSLocalizedString("ai_prompt_req_17", comment: "Req 17")
        let req18 = NSLocalizedString("ai_prompt_req_18", comment: "Req 18")
        
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
        
        \(mvpFormat)
        
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
        \(req15)
        \(req16)
        \(req17)
        \(req18)
        
        \(gameInfoLabel)
        \(dateFormatted)
        \(matchupStr)
        \(scoreStr)
        \(periodsStr)
        \(String(format: NSLocalizedString("ai_prompt_team_stats_mode_line", comment: "Team stats mode"), game.snapshot.homeTeamStatsMode ? NSLocalizedString("bool_yes", comment: "Yes") : NSLocalizedString("bool_no", comment: "No"), game.snapshot.awayTeamStatsMode ? NSLocalizedString("bool_yes", comment: "Yes") : NSLocalizedString("bool_no", comment: "No")))
        \(String(format: NSLocalizedString("ai_prompt_court_player_count", comment: "Court player count"), game.snapshot.courtPlayerCount, game.snapshot.courtPlayerCount))
        \(String(format: NSLocalizedString("ai_prompt_period_end_condition", comment: "Period end condition"), periodEndConditionLabel(game.snapshot.periodEndCondition)))
        \(game.snapshot.periodEndCondition == .byScore ? "" : String(format: NSLocalizedString("ai_prompt_period_time_limit", comment: "Period time limit"), game.snapshot.periodTimeLimit))
        \(String(format: NSLocalizedString("ai_prompt_period_score_limit", comment: "Period score limit"), game.snapshot.periodScoreLimit))
        
        \(playersLabel)
        \(playersText)
        
        \(teamStatsPromptSection())
        
        \(numericFactsLabel)
        \(numericFacts)
        
        \(String(format: NSLocalizedString("ai_prompt_section_score_timeline", comment: "Score timeline header"), game.homeTeamName, game.awayTeamName))
        \(combinedTimelineText())
        
        \(NSLocalizedString("ai_prompt_section_period_scores", comment: "Period scores header"))
        \(periodStatsText)
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
            sections.append(AISummarySection(title: currentTitle ?? NSLocalizedString("ai_prompt_default_section_title", comment: "Default section title"), items: items))
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
            
            if currentTitle == nil, line.range(of: #"^MVP[：:]\s*\S"#, options: [.regularExpression, .caseInsensitive]) != nil {
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
                sections = [AISummarySection(title: NSLocalizedString("ai_prompt_default_section_title", comment: "Default section title"), items: fallbackItems)]
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
    
    private func mvpPlayerID(in items: [String]) -> UUID? {
        let candidates = game.playerNamesByID
            .map { (id: $0.key, name: $0.value.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.name.isEmpty }
        
        // Tier 1: structured "MVP: PlayerName" format
        let mvpPattern = try? NSRegularExpression(pattern: #"^MVP[：:]\s*(.+)"#, options: [.caseInsensitive])
        for item in items {
            let trimmed = item.trimmingCharacters(in: .whitespaces)
            if let match = mvpPattern?.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                let nameRange = Range(match.range(at: 1), in: trimmed)
                let extracted = nameRange.map { String(trimmed[$0]).trimmingCharacters(in: .whitespaces) } ?? ""
                if !extracted.isEmpty {
                    let sorted = candidates.sorted { $0.name.count > $1.name.count }
                    if let found = sorted.first(where: { extracted.contains($0.name) }) {
                        return found.id
                    }
                }
            }
        }
        
        // Tier 2: regex extraction from first item text
        let namePattern = try? NSRegularExpression(pattern: #"^(.+?)[\s\d（(]"#)
        for item in items {
            let trimmed = stripMarkdownDecorations(from: item)
            guard !trimmed.isEmpty else { continue }
            if let match = namePattern?.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                let nameRange = Range(match.range(at: 1), in: trimmed)
                let extracted = nameRange.map { String(trimmed[$0]).trimmingCharacters(in: .whitespaces) } ?? ""
                if !extracted.isEmpty {
                    let sorted = candidates.sorted { $0.name.count > $1.name.count }
                    if let found = sorted.first(where: { extracted.contains($0.name) }) {
                        return found.id
                    }
                }
            }
        }
        
        return nil
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
        if title.localizedCaseInsensitiveContains(NSLocalizedString("ai_prompt_keyword_highlight", comment: "Highlight keyword")) {
            return "sparkles"
        }
        if title.localizedCaseInsensitiveContains(NSLocalizedString("ai_prompt_keyword_summary", comment: "Summary keyword")) {
            return "text.quote"
        }
        return "doc.text"
    }
    
    private func iconForSummaryItem(sectionTitle: String, item: String, index: Int) -> String {
        if sectionTitle.localizedCaseInsensitiveContains("mvp") {
            return "person.crop.circle.badge.checkmark"
        }
        if sectionTitle.localizedCaseInsensitiveContains(NSLocalizedString("ai_prompt_keyword_highlight", comment: "Highlight keyword")) {
            return "bolt.fill"
        }
        if item.localizedCaseInsensitiveContains(NSLocalizedString("ai_prompt_keyword_key", comment: "Key keyword")) {
            return "flag.fill"
        }
        if item.localizedCaseInsensitiveContains(NSLocalizedString("ai_prompt_keyword_score", comment: "Score keyword")) {
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

    private func score(for teamID: UUID?) -> Int {
        guard let teamID else { return 0 }
        return game.score(forTeamID: teamID)
    }

    private func numericFactsText() -> String {
        let participantIDs = allPlayerIDsForSummary().filter { game.didParticipate($0) }
        guard !participantIDs.isEmpty else {
            return NSLocalizedString("ai_prompt_no_participants", comment: "No participants")
        }
        
        let homeScore = score(for: game.snapshot.homeTeamID)
        let awayScore = score(for: game.snapshot.awayTeamID)
        let scoreTotal = homeScore + awayScore
        let playerScoreTotal = participantIDs.reduce(0) { partial, playerID in
            partial + game.snapshot.statsByPlayerID[playerID, default: PlayerStats()].points
        }
        
        var lines: [String] = []
        lines.append(String(format: NSLocalizedString("ai_prompt_score_total_format", comment: "Score total"), homeScore, awayScore, scoreTotal, playerScoreTotal))
        
        lines.append(metricLine(NSLocalizedString("ai_prompt_metric_most_points", comment: "Most points"), among: participantIDs, unit: NSLocalizedString("ai_prompt_unit_points", comment: "Points unit")) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].points
        })
        lines.append(metricLine(NSLocalizedString("ai_prompt_metric_least_points", comment: "Least points"), among: participantIDs, order: .ascending, unit: NSLocalizedString("ai_prompt_unit_points", comment: "Points unit")) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].points
        })
        lines.append(metricLine(NSLocalizedString("ai_prompt_metric_most_rebounds", comment: "Most rebounds"), among: participantIDs, unit: NSLocalizedString("ai_prompt_unit_rebounds", comment: "Rebounds unit"), requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].totalRebounds
        })
        lines.append(metricLine(NSLocalizedString("ai_prompt_metric_most_assists", comment: "Most assists"), among: participantIDs, unit: NSLocalizedString("ai_prompt_unit_count", comment: "Count unit"), requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].assists
        })
        lines.append(metricLine(NSLocalizedString("ai_prompt_metric_most_blocks", comment: "Most blocks"), among: participantIDs, unit: NSLocalizedString("ai_prompt_unit_count", comment: "Count unit"), requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].blocks
        })
        lines.append(metricLine(NSLocalizedString("ai_prompt_metric_most_steals", comment: "Most steals"), among: participantIDs, unit: NSLocalizedString("ai_prompt_unit_count", comment: "Count unit"), requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].steals
        })
        lines.append(metricLine(NSLocalizedString("ai_prompt_metric_most_turnovers", comment: "Most turnovers"), among: participantIDs, unit: NSLocalizedString("ai_prompt_unit_count", comment: "Count unit"), requirePositive: true) {
            game.snapshot.statsByPlayerID[$0, default: PlayerStats()].turnovers
        })
        lines.append(metricLine(NSLocalizedString("ai_prompt_metric_highest_plus_minus", comment: "Highest +/-"), among: participantIDs, unit: "") {
            game.snapshot.plusMinusByPlayerID[$0, default: 0]
        })
        lines.append(metricLine(NSLocalizedString("ai_prompt_metric_lowest_plus_minus", comment: "Lowest +/-"), among: participantIDs, order: .ascending, unit: "") {
            game.snapshot.plusMinusByPlayerID[$0, default: 0]
        })
        
        if let longest = leadingPlayers(
            among: participantIDs,
            metric: { Int(game.snapshot.playingSecondsByPlayerID[$0, default: 0].rounded(.down)) },
            order: .descending,
            requirePositive: true
        ) {
            let duration = GameView.durationFormatter(TimeInterval(longest.value))
            lines.append(String(format: NSLocalizedString("ai_prompt_playing_time_format", comment: "Playing time"), playersText(for: longest.playerIDs), duration))
        } else {
            lines.append(NSLocalizedString("ai_prompt_playing_time_no_data", comment: "Playing time no data"))
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
            return String(format: NSLocalizedString("ai_prompt_metric_no_data_format", comment: "Metric no data"), title)
        }
        
        let valueText = unit.isEmpty
        ? signedNumberText(leader.value)
        : "\(leader.value)\(unit)"
        return String(format: NSLocalizedString("ai_prompt_metric_line_format", comment: "Metric line"), title, playersText(for: leader.playerIDs), valueText)
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
        return String(format: NSLocalizedString("ai_prompt_players_and_more", comment: "Players and more"), shown, names.count, maxCount, names.count - maxCount)
    }
    
    private func signedNumberText(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }
    
    private func periodEndConditionLabel(_ condition: PeriodEndCondition) -> String {
        switch condition {
        case .manual: return NSLocalizedString("period_end_manual", comment: "")
        case .byTime: return NSLocalizedString("period_end_by_time", comment: "")
        case .byScore: return NSLocalizedString("period_end_by_score", comment: "")
        }
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
    
}
