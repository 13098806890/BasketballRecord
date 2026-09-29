import SwiftUI
import WebKit

enum PlayerProfileDebugLog {
    static func log(_ message: @autoclosure () -> String) {
#if DEBUG
        print(message())
#endif
    }
}

private enum PlayerProfileScrollAnchor {
    static let gameHistoryHeader = "player-profile-game-history-header"
    static let gameHistoryBottom = "player-profile-game-history-bottom"

    static func statHeader(_ sectionID: String) -> String {
        "player-profile-stat-header-\(sectionID)"
    }

    static func statBottom(_ sectionID: String) -> String {
        "player-profile-stat-bottom-\(sectionID)"
    }
}

struct PlayerProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var store: AppStore
    var playerID: UUID
    var fixedGame: SavedGame? = nil
    @Binding var selectedGroupID: UUID?
    @State private var selectedPeriod: Int? = nil
    @State private var fixedGameAnalysis = SavedGamePeriodAnalysis()
    @State private var showingELOHistory = false
    @State private var isGameHistoryExpanded = true
    @State var expandedStatSections: Set<String> = ["game", "career", "average"]
    @State private var selectedTrendIndex: Int?

    var player: Player? { store.player(for: playerID) }
    var body: some View {
        ZStack {
            profileScrollContent
                .background(profileBackground)
        }
        .navigationTitle(LocalizedStringKey("settings_players"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            if fixedGame == nil {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    BasketballExcelExportButton {
                        BasketballExcelReportBuilder.playerProfile(playerID: playerID, games: filteredGames, players: store.players).exportFile
                    }
                }
            }
        }
        .sheet(isPresented: $showingELOHistory) {
            ELOHistoryView(playerID: playerID, playerName: player?.name ?? "", games: filteredGames)
        }
        .onAppear {
            PlayerProfileDebugLog.log("xdz PlayerProfileView appeared playerID=\(playerID) fixedGame=\(fixedGame?.id.uuidString ?? "nil") games=\(allPlayerGames.count)")
            rebuildFixedGameAnalysisIfNeeded()
        }
        .onDisappear {
            PlayerProfileDebugLog.log("xdz PlayerProfileView disappeared playerID=\(playerID) fixedGame=\(fixedGame?.id.uuidString ?? "nil")")
        }
        .onChange(of: store.savedGames) { _, _ in
            rebuildFixedGameAnalysisIfNeeded()
        }
    }

    @ViewBuilder
    private var profileScrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView {
                standardProfileContent(scrollProxy: proxy)
            }
        }
    }

    private var profileBackground: some View {
        EditorialBackground()
    }

    private func standardProfileContent(scrollProxy: ScrollViewProxy) -> some View {
        VStack(spacing: 12) {
            if let fixedGame {
                Text(LocalizedStringKey("nav_player_detail"))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(EditorialDesign.navy)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                header

                if fixedGame.snapshot.periodCount > 1 {
                    fixedGamePeriodCard(fixedGame)
                }

                fixedGameStatSection(scrollProxy: scrollProxy)
                eventSection
            } else {
                careerEditorialContent(scrollProxy: scrollProxy)
            }
        }
        .padding(.vertical)
    }

    private func careerEditorialContent(scrollProxy: ScrollViewProxy) -> some View {
        VStack(spacing: 12) {
            Text(LocalizedStringKey("nav_player_detail"))
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(EditorialDesign.navy)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            header

            if store.isPro, let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(EditorialDesign.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(NSLocalizedString("game_group_selected_filter", comment: "Filtering by"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(group.name)
                            .font(.headline)
                    }
                    Spacer()
                    Button { selectedGroupID = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                    }
                }
                .padding(12)
                .editorialCard(tint: EditorialDesign.paleOrange, radius: 16)
                .padding(.horizontal)
            }

            metricSummaryCard(
                titleKey: "nav_career",
                icon: .system("chart.bar.fill"),
                metrics: careerMetricValues,
                headerMetrics: careerHeaderMetrics,
                sectionID: "career",
                rows: buildClassicCareerStatRows(),
                scrollProxy: scrollProxy
            )
            metricSummaryCard(
                titleKey: "stat_section_average",
                icon: .average,
                metrics: averageMetricValues,
                headerMetrics: averageHeaderMetrics,
                sectionID: "average",
                rows: buildClassicAverageStatRows(),
                scrollProxy: scrollProxy
            )
            eloHistoryCard
            playerGameHistoryCard(scrollProxy: scrollProxy)
        }
    }

    private func fixedGamePeriodCard(_ fixedGame: SavedGame) -> some View {
        VStack(spacing: 0) {
            Picker(LocalizedStringKey("picker_period"), selection: $selectedPeriod) {
                Text(LocalizedStringKey("label_full_game")).tag(Optional<Int>.none)
                ForEach(1...fixedGame.snapshot.periodCount, id: \.self) { period in
                    Text(fixedGame.periodDisplayName(period)).tag(Optional(period))
                }
            }
            .pickerStyle(.segmented)
            .tint(EditorialDesign.orange)
        }
        .padding(4)
        .editorialCard(tint: EditorialDesign.card, radius: 18)
        .padding(.horizontal)
    }

    private func fixedGameStatSection(scrollProxy: ScrollViewProxy) -> some View {
        metricSummaryCard(
            titleKey: "label_this_game_stats",
            icon: .system("basketball.fill"),
            metrics: fixedGameMetricValues,
            headerMetrics: fixedGameHeaderMetrics,
            sectionID: "game",
            rows: buildClassicGameStatRows(),
            scrollProxy: scrollProxy
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let player {
                if let fixedGame {
                    HStack(alignment: .top, spacing: 16) {
                        PlayerAvatarView(player: player, size: 76)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .center, spacing: 8) {
                                Text(player.name)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(EditorialDesign.navy)
                                if let role = fixedGame.role(of: playerID) {
                                    Text(role.title)
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(.ultraThinMaterial, in: Capsule())
                                }
                            }
                            if !player.position.isEmpty {
                                Text(player.position)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            Text(profileSubtitle(player) ?? NSLocalizedString("player_profile_missing_basic", comment: "Missing player details"))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(teamName(for: fixedGame))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                } else {
                    HStack(alignment: .top, spacing: 14) {
                        PlayerAvatarView(player: player, size: 72)
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(alignment: .center, spacing: 6) {
                                Text(player.name)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(EditorialDesign.navy)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                    .layoutPriority(1)
                            }
                            HStack(spacing: 8) {
                                playerIdentityMetadata(player)
                                    .layoutPriority(1)
                                Spacer(minLength: 4)
                                careerELOBadge
                            }
                            careerParticipationSummary
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EditorialPlayerPanelBackground())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(EditorialDesign.divider.opacity(0.42), lineWidth: 1)
        }
        .padding(.horizontal)
    }

    private var careerELOBadge: some View {
        Button {
            showingELOHistory = true
        } label: {
            Text(String(format: NSLocalizedString("elo_format", comment: "ELO value"), Int(playerELO)))
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(EditorialDesign.orange)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(EditorialDesign.paleOrange.opacity(0.7), in: Capsule())
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }

    @ViewBuilder
    private func playerIdentityMetadata(_ player: Player) -> some View {
        if !player.position.isEmpty || profileSubtitle(player) != nil {
            HStack(spacing: 7) {
                if !player.position.isEmpty {
                    Text(player.position)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(EditorialDesign.blue)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(EditorialDesign.paleBlue, in: Capsule())
                }
                if let subtitle = profileSubtitle(player) {
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(EditorialDesign.navy.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
    }

    private enum MetricSummaryIcon {
        case system(String)
        case average
    }

    private func metricSummaryCard(titleKey: String, icon: MetricSummaryIcon, metrics: [(String, String)], headerMetrics: [(String, String)] = [], sectionID: String, rows: [StatRow], scrollProxy: ScrollViewProxy) -> some View {
        Button {
            toggleStatSection(sectionID, scrollProxy: scrollProxy)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    metricSummaryIcon(icon)
                    Text(LocalizedStringKey(titleKey))
                        .font(.headline.weight(.bold))
                        .foregroundStyle(EditorialDesign.navy)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    if !headerMetrics.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(Array(headerMetrics.enumerated()), id: \.offset) { _, metric in
                                HStack(spacing: 2) {
                                    Text("\(metric.0):")
                                        .foregroundStyle(.secondary)
                                    Text(metric.1)
                                        .foregroundStyle(metricValueColor(label: metric.0, value: metric.1))
                                }
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                            }
                        }
                    }
                    Image(systemName: expandedStatSections.contains(sectionID) ? "chevron.up" : "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .id(PlayerProfileScrollAnchor.statHeader(sectionID))

                HStack(spacing: 0) {
                    ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                        VStack(spacing: 5) {
                            Text(metric.1)
                                .font(.headline.monospacedDigit().weight(.bold))
                                .foregroundStyle(index == 0 ? EditorialDesign.orange : EditorialDesign.navy)
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                            Text(metric.0)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .trailing) {
                            if index < metrics.count - 1 {
                                Rectangle()
                                    .fill(EditorialDesign.divider.opacity(0.45))
                                    .frame(width: 1, height: 36)
                            }
                        }
                    }
                }

                if expandedStatSections.contains(sectionID) {
                    Divider()
                        .overlay(EditorialDesign.divider.opacity(0.45))
                    statRowsContent(rows)
                        .transition(accordionTransition)
                }

                Color.clear
                    .frame(height: 1)
                    .id(PlayerProfileScrollAnchor.statBottom(sectionID))
            }
            .padding(14)
            .editorialCard(tint: EditorialDesign.card, radius: 18)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    private func toggleStatSection(_ sectionID: String, scrollProxy: ScrollViewProxy) {
        let isExpanded = expandedStatSections.contains(sectionID)
        withAnimation(accordionAnimation) {
            if isExpanded {
                expandedStatSections.remove(sectionID)
                scrollProxy.scrollTo(PlayerProfileScrollAnchor.statHeader(sectionID), anchor: .top)
            } else {
                expandedStatSections.insert(sectionID)
                scrollProxy.scrollTo(PlayerProfileScrollAnchor.statBottom(sectionID), anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func metricSummaryIcon(_ icon: MetricSummaryIcon) -> some View {
        switch icon {
        case .system(let name):
            Image(systemName: name)
                .foregroundStyle(EditorialDesign.blue)
        case .average:
            Text(LocalizedStringKey("label_average_short"))
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(EditorialDesign.blue)
                .frame(width: 28, height: 20)
                .background(EditorialDesign.paleBlue, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    @ViewBuilder
    private func statRowsContent(_ rows: [StatRow]) -> some View {
        VStack(spacing: 8) {
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    if row.leftSplit == nil, row.right == nil, row.rightSplit == nil {
                        makeStatCard(row.left)
                            .frame(maxWidth: .infinity)
                    } else if let split = row.leftSplit {
                        HStack(spacing: 8) {
                            makeStatCard(row.left)
                            makeStatCard(split)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        makeStatCard(row.left)
                            .frame(maxWidth: .infinity)
                    }
                    if row.leftSplit != nil || row.right != nil || row.rightSplit != nil {
                        if let split = row.rightSplit {
                            HStack(spacing: 8) {
                                makeStatCard(split)
                                if let right = row.right {
                                    makeStatCard(right)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        } else if let right = row.right {
                            makeStatCard(right)
                                .frame(maxWidth: .infinity)
                        } else {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private var careerMetricValues: [(String, String)] {
        let stats = totalStats
        return [
            (localized("stats_points_format_short"), "\(stats.points)"),
                (localized("stats_rebound_short"), "\(stats.totalRebounds)"),
            (localized("stats_assists_short"), "\(stats.assists)"),
            (localized("stats_steals_short"), "\(stats.steals)"),
            (localized("stats_blocks_short"), "\(stats.blocks)"),
            (localized("stats_turnovers_short"), "\(stats.turnovers)")
        ]
    }

    private var fixedGameMetricValues: [(String, String)] {
        careerMetricValues
    }

    private var fixedGameHeaderMetrics: [(String, String)] {
        let plusMinus = isFixedPeriodMode ? "--" : (totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)")
        return [
            (localized("stats_minutes"), GameView.durationFormatter(totalMinutes * 60)),
            (localized("stats_plus_minus_short"), plusMinus)
        ]
    }

    private var careerHeaderMetrics: [(String, String)] {
        let plusMinus = totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)"
        return [
            (localized("stats_minutes"), GameView.durationFormatter(totalMinutes * 60)),
            (localized("stats_plus_minus_short"), plusMinus)
        ]
    }

    private var averageMetricValues: [(String, String)] {
        let stats = totalStats
        let games = max(1, filteredGames.count)
        return [
            (localized("stats_points_format_short"), average(stats.points, games)),
            (localized("stats_rebound_short"), average(stats.totalRebounds, games)),
            (localized("stats_assists_short"), average(stats.assists, games)),
            (localized("stats_steals_short"), average(stats.steals, games)),
            (localized("stats_blocks_short"), average(stats.blocks, games)),
            (localized("stats_turnovers_short"), average(stats.turnovers, games))
        ]
    }

    private var averageHeaderMetrics: [(String, String)] {
        let games = max(1, filteredGames.count)
        let plusMinus = Double(totalPlusMinus) / Double(games)
        let plusMinusText = plusMinus > 0 ? String(format: "+%.1f", plusMinus) : String(format: "%.1f", plusMinus)
        return [
            (localized("stats_minutes"), GameView.durationFormatter(totalMinutes / Double(games) * 60)),
            (localized("stats_plus_minus_short"), plusMinusText)
        ]
    }

    private var eloHistoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundStyle(EditorialDesign.blue)
                Text(LocalizedStringKey("label_player_performance_trend"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(EditorialDesign.navy)
                Spacer()
            }

            if performanceTrendHistory.count > 1 {
                performanceTrendLegend
                performanceTrendChart
            } else {
                Text(LocalizedStringKey("text_no_data"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .editorialCard(tint: EditorialDesign.card, radius: 18)
        .padding(.horizontal)
        .contentShape(Rectangle())
    }

    private func playerGameHistoryCard(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(EditorialDesign.orange)
                    .frame(width: 5, height: 20)
                Text(LocalizedStringKey("nav_history"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(EditorialDesign.navy)
                Spacer()

                if !filteredGames.isEmpty {
                    Button {
                        toggleGameHistory(scrollProxy: scrollProxy)
                    } label: {
                        HStack(spacing: 5) {
                            Text(LocalizedStringKey(isGameHistoryExpanded ? "button_show_less" : "button_show_all"))
                                .font(.caption.weight(.semibold))
                            Image(systemName: isGameHistoryExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.bold))
                        }
                        .foregroundStyle(EditorialDesign.blue)
                        .padding(.vertical, 6)
                        .padding(.leading, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .id(PlayerProfileScrollAnchor.gameHistoryHeader)

            if filteredGames.isEmpty {
                Text(LocalizedStringKey("empty_no_game_history"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else if isGameHistoryExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(filteredGames.enumerated()), id: \.element.id) { index, game in
                        NavigationLink {
                            if store.player(for: playerID) != nil {
                                PlayerProfileView(playerID: playerID, fixedGame: game, selectedGroupID: .constant(nil))
                            } else {
                                PlayerGameDetailView(game: game, playerID: playerID)
                            }
                        } label: {
                            playerGameHistoryRow(game)
                        }
                        .buttonStyle(.plain)

                        if index < filteredGames.count - 1 {
                            Divider()
                                .overlay(EditorialDesign.divider.opacity(0.45))
                                .padding(.leading, 14)
                        }
                    }
                }
                .transition(accordionTransition)
            }

            Color.clear
                .frame(height: 1)
                .id(PlayerProfileScrollAnchor.gameHistoryBottom)
        }
        .padding(14)
        .editorialCard(tint: EditorialDesign.card, radius: 18)
        .padding(.horizontal)
    }

    private func toggleGameHistory(scrollProxy: ScrollViewProxy) {
        withAnimation(accordionAnimation) {
            if isGameHistoryExpanded {
                isGameHistoryExpanded = false
                scrollProxy.scrollTo(PlayerProfileScrollAnchor.gameHistoryHeader, anchor: .top)
            } else {
                isGameHistoryExpanded = true
                scrollProxy.scrollTo(PlayerProfileScrollAnchor.gameHistoryBottom, anchor: .bottom)
            }
        }
    }

    private var accordionAnimation: Animation {
        reduceMotion
            ? .easeOut(duration: 0.15)
            : .timingCurve(0.23, 1, 0.32, 1, duration: 0.24)
    }

    private var accordionTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .move(edge: .top))
    }

    private func playerGameHistoryRow(_ game: SavedGame) -> some View {
        let stats = game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
        let isHome = game.homePlayerIDs.contains(playerID)
        let myScore = playerGameScore(for: game, isHome: isHome)
        let opponentScore = playerGameScore(for: game, isHome: !isHome)
        let resultColor: Color = myScore > opponentScore ? EditorialDesign.orange : .secondary
        let resultText = myScore > opponentScore
            ? localized("elo_outcome_win")
            : (myScore < opponentScore ? localized("elo_outcome_loss") : localized("elo_outcome_draw"))
        let opponentName = isHome ? game.awayTeamName : game.homeTeamName
        let plusMinus = plusMinusText(for: game)

        return HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(resultColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(opponentName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EditorialDesign.navy)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(resultText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(resultColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(resultColor.opacity(0.12), in: Capsule())
                    Text(game.savedAt, format: .dateTime.year().month().day())
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(String(format: "%d - %d", myScore, opponentScore))
                        .font(.headline.monospacedDigit().weight(.bold))
                        .foregroundStyle(EditorialDesign.navy)
                }

                HStack(spacing: 0) {
                    playerGameHistoryMetric(label: localized("stats_points_format_short"), value: String(stats.points))
                    playerGameHistoryMetric(label: localized("stats_rebound_short"), value: String(stats.totalRebounds))
                    playerGameHistoryMetric(label: localized("stats_assists_short"), value: String(stats.assists))
                    playerGameHistoryMetric(
                        label: localized("stats_plus_minus_short"),
                        value: plusMinus,
                        valueColor: plusMinusColor(plusMinus)
                    )
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    private func playerGameHistoryMetric(label: String, value: String, valueColor: Color = EditorialDesign.navy) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func playerGameScore(for game: SavedGame, isHome: Bool) -> Int {
        let teamID = isHome ? game.snapshot.homeTeamID : game.snapshot.awayTeamID
        if let teamID {
            return game.score(forTeamID: teamID)
        }

        let playerIDs = isHome ? game.homePlayerIDs : game.awayPlayerIDs
        return playerIDs.reduce(0) { total, id in
            total + (game.snapshot.statsByPlayerID[id]?.points ?? 0)
        }
    }

    private func plusMinusText(for game: SavedGame) -> String {
        let value = game.snapshot.plusMinusByPlayerID[playerID, default: 0]
        return value > 0 ? "+" + String(value) : String(value)
    }

    private func metricValueColor(label: String, value: String) -> Color {
        guard label == localized("stats_plus_minus_short") else {
            return EditorialDesign.navy
        }
        return plusMinusColor(value)
    }

    private func plusMinusColor(_ value: String) -> Color {
        if value.hasPrefix("+") {
            return EditorialDesign.orange
        }
        if value.hasPrefix("-") {
            return .secondary
        }
        return .secondary
    }

    private var performanceTrendLegend: some View {
        let selectedPoint = selectedTrendIndex.flatMap { index in
            performanceTrendHistory.indices.contains(index) ? performanceTrendHistory[index] : nil
        }
        return HStack(spacing: 6) {
            trendLegendItem(
                label: localized("label_elo"),
                value: selectedPoint.map { formattedELO($0.elo) },
                color: EditorialDesign.orange
            )
            trendLegendItem(
                label: localized("stats_points_format_short"),
                value: selectedPoint.map { formattedPoints($0.points) },
                color: EditorialDesign.blue
            )
            trendLegendItem(
                label: localized("label_field_goal_percentage"),
                value: selectedPoint.map { formattedFieldGoalRate($0.fieldGoalRate) },
                color: fieldGoalTrendColor
            )
        }
    }

    private func trendLegendItem(label: String, value: String?, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let value {
                Text(value)
                    .font(.caption2.monospacedDigit().weight(.bold))
                    .foregroundStyle(EditorialDesign.navy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var performanceTrendChart: some View {
        GeometryReader { proxy in
            let points = performanceTrendHistory
            ZStack {
                Path { path in
                    for row in 1..<4 {
                        let y = proxy.size.height * CGFloat(row) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                }
                .stroke(EditorialDesign.divider.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 4]))

                trendPath(values: points.map(\.elo), size: proxy.size)
                    .stroke(EditorialDesign.orange, style: trendLineStyle)
                trendPath(values: points.map(\.points), size: proxy.size)
                    .stroke(EditorialDesign.blue, style: trendLineStyle)
                trendPath(values: points.map(\.fieldGoalRate), size: proxy.size)
                    .stroke(fieldGoalTrendColor, style: trendLineStyle)

                if let selectedTrendIndex, points.indices.contains(selectedTrendIndex) {
                    let x = proxy.size.width * CGFloat(selectedTrendIndex) / CGFloat(max(points.count - 1, 1))
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    }
                    .stroke(EditorialDesign.navy.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))

                    Circle()
                        .fill(EditorialDesign.orange)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .frame(width: 9, height: 9)
                        .position(x: x, y: trendY(value: points[selectedTrendIndex].elo, values: points.map(\.elo), height: proxy.size.height))
                    Circle()
                        .fill(EditorialDesign.blue)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .frame(width: 9, height: 9)
                        .position(x: x, y: trendY(value: points[selectedTrendIndex].points, values: points.map(\.points), height: proxy.size.height))
                    Circle()
                        .fill(fieldGoalTrendColor)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .frame(width: 9, height: 9)
                        .position(x: x, y: trendY(value: points[selectedTrendIndex].fieldGoalRate, values: points.map(\.fieldGoalRate), height: proxy.size.height))
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        guard points.count > 1 else { return }
                        let ratio = min(max(value.location.x / proxy.size.width, 0), 1)
                        selectedTrendIndex = min(max(Int((ratio * CGFloat(points.count - 1)).rounded()), 0), points.count - 1)
                    }
            )
        }
        .frame(height: 92)
        .padding(.horizontal, 4)
    }

    private var trendLineStyle: StrokeStyle {
        StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
    }

    private var fieldGoalTrendColor: Color {
        Color(red: 0.18, green: 0.62, blue: 0.34)
    }

    private func formattedELO(_ value: Double) -> String {
        String(format: "%d", Int(value))
    }

    private func formattedPoints(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    private func formattedFieldGoalRate(_ value: Double) -> String {
        percent(value)
    }

    private func trendY(value: Double, values: [Double], height: CGFloat) -> CGFloat {
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let span = maxValue - minValue
        let normalizedValue = span > 0 ? (value - minValue) / span : 0.5
        return height - height * CGFloat(normalizedValue)
    }

    private func trendPath(values: [Double], size: CGSize) -> Path {
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let span = maxValue - minValue
        return Path { path in
            for (index, value) in values.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                let normalizedValue = span > 0 ? (value - minValue) / span : 0.5
                let y = size.height - size.height * CGFloat(normalizedValue)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func teamName(for game: SavedGame) -> String {
        if game.homePlayerIDs.contains(playerID) {
            return game.homeTeamName
        }
        return game.awayTeamName
    }

    private var careerParticipationSummary: some View {
        let totalGames = filteredGames.count
        let winRate = totalGames > 0 ? String(format: "%.1f%%", Double(statsGroup.winCount) / Double(totalGames) * 100) : "--"
        let items: [(String, String)] = [
            (localized("stats_games"), "\(totalGames)"),
            (localized("stat_label_starter_short"), "\(starterGameCount)"),
            (localized("stats_win_rate_short"), winRate)
        ]

        return HStack(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 {
                    Text("·")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 3) {
                    Text(item.0)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(item.1)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(item.0 == localized("stats_win_rate_short") ? EditorialDesign.orange : EditorialDesign.navy)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.65)
    }

    var playerELO: Double {
        ELOEngine.computeELO(for: playerID, from: filteredGames)
    }

    private var eloHistory: [ELOGameEntry] {
        ELOEngine.computeELOHistory(for: playerID, from: filteredGames)
    }

    private var performanceTrendHistory: [PerformanceTrendPoint] {
        return eloHistory.map { entry in
            let stats = entry.game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
            return PerformanceTrendPoint(
                id: entry.id,
                elo: entry.postELO,
                points: Double(stats.points),
                fieldGoalRate: stats.fieldGoalRate
            )
        }
    }

    private struct PerformanceTrendPoint: Identifiable {
        let id: UUID
        let elo: Double
        let points: Double
        let fieldGoalRate: Double
    }

    struct StatCell: Identifiable {
        var id: String { label }
        var label: String
        var value: String
    }

    struct StatRow: Identifiable {
        var id: String
        var left: StatCell
        var leftSplit: StatCell? = nil
        var right: StatCell? = nil
        var rightSplit: StatCell? = nil
    }

    private func makeStatCard(_ cell: StatCell) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(cell.label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(cell.value)
                .font(.caption.monospacedDigit().weight(.bold))
                .foregroundStyle(EditorialDesign.navy.opacity(0.88))
                .lineLimit(2)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(EditorialDesign.divider.opacity(0.32), lineWidth: 1))
    }

    private enum StatCardStyle {
        case game, career, average
    }

    private func buildStatRows(style: StatCardStyle) -> [StatRow] {
        let s = totalStats
        let games = max(1, filteredGames.count)
        let pct = { percent($0) }

        let mins: String
        let pm: String
        let avg: ((Int) -> String)?

        switch style {
        case .game:
            mins = GameView.durationFormatter(totalMinutes * 60)
            pm = isFixedPeriodMode ? "--" : (totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)")
            avg = nil
        case .career:
            mins = GameView.durationFormatter(totalMinutes * 60)
            pm = totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)"
            avg = nil
        case .average:
            mins = GameView.durationFormatter(totalMinutes / Double(games) * 60)
            pm = String(format: "%.1f", Double(totalPlusMinus) / Double(games))
            avg = { v in String(format: "%.1f", Double(v) / Double(games)) }
        }

        let pts = StatCell(label: localized("stats_points_format_short"), value: avg?(s.points) ?? "\(s.points)")
        let min = StatCell(label: localized("stats_minutes"), value: mins)
        let reb = StatCell(label: localized("stats_rebound_detail_short"), value: "\(avg?(s.totalRebounds) ?? "\(s.totalRebounds)") / \(avg?(s.offensiveRebounds) ?? "\(s.offensiveRebounds)") / \(avg?(s.defensiveRebounds) ?? "\(s.defensiveRebounds)")")
        let astStlBlk = StatCell(label: localized("stats_assist_steal_block_short"), value: "\(avg?(s.assists) ?? "\(s.assists)") / \(avg?(s.steals) ?? "\(s.steals)") / \(avg?(s.blocks) ?? "\(s.blocks)")")
        let foul = StatCell(label: localized("stats_foul_turnover_short") + " / " + localized("stats_plus_minus_short"), value: "\(avg?(s.fouls) ?? "\(s.fouls)") / \(avg?(s.turnovers) ?? "\(s.turnovers)") / \(pm)")
        let fg = StatCell(label: localized("stats_shooting"), value: "\(avg?(s.made) ?? "\(s.made)")/\(avg?(s.attempts) ?? "\(s.attempts)")\n\(pct(s.fieldGoalRate))")
        let ft = StatCell(label: localized("stat_label_free_throw_short"), value: "\(avg?(s.allFreeThrowMade) ?? "\(s.allFreeThrowMade)")/\(avg?(s.allFreeThrowAttempts) ?? "\(s.allFreeThrowAttempts)")\n\(pct(s.freeThrowRate))")
        let two = StatCell(label: localized("stat_label_2pt_short"), value: "\(avg?(s.twoMade) ?? "\(s.twoMade)")/\(avg?(s.twoAttempts) ?? "\(s.twoAttempts)")\n\(pct(s.twoPointRate))")
        let three = StatCell(label: localized("stat_label_3pt_short"), value: "\(avg?(s.threeMade) ?? "\(s.threeMade)")/\(avg?(s.threeAttempts) ?? "\(s.threeAttempts)")\n\(pct(s.threePointRate))")
        let efg = StatCell(label: "eFG / TS", value: "\(pct(s.effectiveFieldGoalRate)) / \(pct(s.trueShootingRate))")
        let pps = StatCell(label: NSLocalizedString("stats_points_per_shot_short", comment: "PTS/FGA"), value: String(format: "%.2f", s.pointsPerShot))

        switch style {
        case .game:
            return [
                StatRow(id: "row1", left: pts, leftSplit: min, right: reb),
                StatRow(id: "row2", left: astStlBlk, leftSplit: foul),
                StatRow(id: "row3", left: fg, leftSplit: ft, right: three, rightSplit: two),
                StatRow(id: "row4", left: pps, rightSplit: efg),
            ]
        case .career:
            let totalGames = filteredGames.count
            let winRate = totalGames > 0 ? String(format: "%.1f%%", Double(statsGroup.winCount) / Double(totalGames) * 100) : "--"
            let sb = StatCell(label: "\(localized("stats_games")) / \(localized("stat_label_starter_short")) / \(localized("stat_label_bench_short")) / \(localized("stats_win_rate_short"))", value: "\(totalGames) / \(starterGameCount) / \(benchGameCount) / \(winRate)")
            return [
                StatRow(id: "row1", left: pts, leftSplit: min, rightSplit: sb),
                StatRow(id: "row2", left: fg, leftSplit: ft, right: three, rightSplit: two),
                StatRow(id: "row3", left: reb, right: astStlBlk),
                StatRow(id: "row4", left: foul, right: efg, rightSplit: pps),
            ]
        case .average:
            let sb = StatCell(label: "\(localized("stats_games")) / \(localized("stat_label_starter_short")) / \(localized("stat_label_bench_short"))", value: "\(filteredGames.count) / \(starterGameCount) / \(benchGameCount)")
            return [
                StatRow(id: "row1", left: pts, leftSplit: min, rightSplit: sb),
                StatRow(id: "row2", left: fg, leftSplit: ft, right: three, rightSplit: two),
                StatRow(id: "row3", left: reb, right: astStlBlk),
                StatRow(id: "row4", left: foul, right: pps, rightSplit: efg),
            ]
        }
    }

    private func buildGameStatRows() -> [StatRow] { buildStatRows(style: .game) }
    func buildCareerStatRows() -> [StatRow] { buildStatRows(style: .career) }
    func buildAverageStatRows() -> [StatRow] { buildStatRows(style: .average) }

    private func buildClassicCareerStatRows() -> [StatRow] {
        let rows = buildCareerStatRows()
        guard rows.count == 4,
              let efficiency = rows[3].right,
              let pointsPerShot = rows[3].rightSplit else { return rows }
        let rebounds = rows[2].left
        let fouls = rows[3].left
        return [
            rows[1],
            StatRow(id: rows[2].id, left: rebounds, right: fouls),
            StatRow(id: rows[3].id, left: efficiency, right: pointsPerShot)
        ]
    }

    private func buildClassicAverageStatRows() -> [StatRow] {
        let rows = buildAverageStatRows()
        guard rows.count == 4,
              let efficiency = rows[3].rightSplit,
              let pointsPerShot = rows[3].right else { return rows }
        let rebounds = rows[2].left
        let fouls = rows[3].left
        return [
            rows[1],
            StatRow(id: rows[2].id, left: rebounds, right: fouls),
            StatRow(id: rows[3].id, left: efficiency, right: pointsPerShot)
        ]
    }

    private func buildClassicGameStatRows() -> [StatRow] {
        let rows = buildGameStatRows()
        guard rows.count == 4,
              let rebounds = rows[0].right,
              let fouls = rows[1].leftSplit,
              let efficiency = rows[3].rightSplit else { return rows }
        return [
            rows[2],
            StatRow(id: rows[1].id, left: rebounds, right: fouls),
            StatRow(id: rows[3].id, left: efficiency, right: rows[3].left)
        ]
    }

    private var eventSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(EditorialDesign.orange)
                Text(LocalizedStringKey("label_events"))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(EditorialDesign.navy)
                Spacer()
            }

            if filteredPlayerLogs.isEmpty {
                Text(LocalizedStringKey("text_no_player_events_for_range"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredPlayerLogs) { log in
                            let eid = log.entry.id
                            let history = fixedGame?.snapshot.editHistory ?? []
                            let isNew = history.contains(where: { $0.eventID == eid && $0.action == "add" })
                            let isEdited = history.contains(where: { $0.eventID == eid && $0.action == "modify" })
                            let isDel = history.contains(where: { $0.eventID == eid && $0.action == "delete" })
                            let isRest = history.contains(where: { $0.eventID == eid && $0.action == "restore" })
                            let isDeleted = isDel && !isRest
                            if isNew && isDeleted { }
                            else {
                                HStack(spacing: 6) {
                                    if isNew && !isDeleted { Text(LocalizedStringKey("game_event_status_new")).font(.caption2.weight(.bold)).foregroundStyle(.green) }
                                    if isEdited { Text(LocalizedStringKey("game_event_status_edited")).font(.caption2.weight(.bold)).foregroundStyle(.orange) }
                                    if isDeleted { Text(LocalizedStringKey("game_event_status_deleted")).font(.caption2.weight(.bold)).foregroundStyle(.red) }
                                    Text(GameLogFormatter.lineText(for: log, originalPeriodCount: fixedGame?.snapshot.originalPeriodCount ?? 4))
                                        .font(.caption.monospacedDigit())
                                        .fixedSize(horizontal: false, vertical: true)
                                        .foregroundStyle(isDeleted ? Color.secondary : (GameLogFormatter.isScoring(log) ? Color.blue : Color.primary))
                                        .strikethrough(isDeleted)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 12)
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(14)
        .editorialCard(tint: EditorialDesign.card, radius: 18)
        .padding(.horizontal)
    }

    var allPlayerGames: [SavedGame] {
        let games = store.savedGames
            .filter { containsPlayer(in: $0) }
            .sorted { $0.savedAt > $1.savedAt }

        if store.isPro, let selectedGroupID = selectedGroupID {
            return games.filter { $0.groupIDs.contains(selectedGroupID) }
        }
        return games
    }

    var filteredGames: [SavedGame] {
        if let fixedGame {
            let participates = containsPlayer(in: fixedGame)
            return participates ? [fixedGame] : []
        }

        return allPlayerGames
    }

    var isFixedPeriodMode: Bool {
        fixedGame != nil && selectedPeriod != nil
    }

    private var filteredPlayerLogs: [PeriodAwareLog] {
        guard fixedGame != nil else { return [] }
        return fixedGameAnalysis.playerLogs(for: playerID, period: selectedPeriod).reversed()
    }

    struct PlayerStatsGroup {
        let totalStats: PlayerStats
        let totalMinutes: Double
        let totalPlusMinus: Int
        let starterGameCount: Int
        let benchGameCount: Int
        let winCount: Int
        let lossCount: Int
        let drawCount: Int
    }

    var statsGroup: PlayerStatsGroup {
        computeStatsGroup(for: filteredGames)
    }

    private func computeStatsGroup(for games: [SavedGame]) -> PlayerStatsGroup {
        if let sp = selectedPeriod, let fg = fixedGame {
            let stats = fixedGameAnalysis.statsByPlayerID(for: sp)[playerID, default: PlayerStats()]
            let periodSeconds = fg.playingTimeByPeriod()[sp]?[playerID] ?? 0
            return PlayerStatsGroup(totalStats: stats, totalMinutes: periodSeconds / 60, totalPlusMinus: 0, starterGameCount: 0, benchGameCount: 0, winCount: 0, lossCount: 0, drawCount: 0)
        }

        var total = PlayerStats()
        var minutes: Double = 0
        var plusMinus: Int = 0
        var starter = 0
        var bench = 0
        var wins = 0
        var losses = 0
        var draws = 0

        for game in games {
            guard !playerDidNotPlay(in: game) else { continue }
            let isHome = game.homePlayerIDs.contains(playerID)
            let myScore: Int
            let oppScore: Int
            if let myTeamID = (isHome ? game.snapshot.homeTeamID : game.snapshot.awayTeamID),
               let oppTeamID = (isHome ? game.snapshot.awayTeamID : game.snapshot.homeTeamID) {
                myScore = game.score(forTeamID: myTeamID)
                oppScore = game.score(forTeamID: oppTeamID)
            } else {
                let isHomePts = game.homePlayerIDs.reduce(0) { $0 + (game.snapshot.statsByPlayerID[$1]?.points ?? 0) }
                let isAwayPts = game.awayPlayerIDs.reduce(0) { $0 + (game.snapshot.statsByPlayerID[$1]?.points ?? 0) }
                myScore = isHome ? isHomePts : isAwayPts
                oppScore = isHome ? isAwayPts : isHomePts
            }
            if myScore > oppScore { wins += 1 }
            else if myScore < oppScore { losses += 1 }
            else { draws += 1 }

            let raw = game.snapshot.statsByPlayerID[playerID] ?? PlayerStats()
            total.twoMade += raw.twoMade
            total.twoAttempts += raw.twoAttempts
            total.threeMade += raw.threeMade
            total.threeAttempts += raw.threeAttempts
            total.bonusFreeThrowMade += raw.bonusFreeThrowMade
            total.bonusFreeThrowAttempts += raw.bonusFreeThrowAttempts
            total.freeThrowMade += raw.freeThrowMade
            total.freeThrowAttempts += raw.freeThrowAttempts
            total.rebounds += raw.rebounds
            total.offensiveRebounds += raw.offensiveRebounds
            total.defensiveRebounds += raw.defensiveRebounds
            total.assists += raw.assists
            total.fouls += raw.fouls
            total.blocks += raw.blocks
            total.steals += raw.steals
            total.turnovers += raw.turnovers
            minutes += game.snapshot.playingSecondsByPlayerID[playerID, default: 0] / 60
            plusMinus += game.snapshot.plusMinusByPlayerID[playerID, default: 0]
            let role = game.role(of: playerID)
            if role == .starter { starter += 1 }
            else if role == .bench { bench += 1 }
        }

        return PlayerStatsGroup(totalStats: total, totalMinutes: minutes, totalPlusMinus: plusMinus, starterGameCount: starter, benchGameCount: bench, winCount: wins, lossCount: losses, drawCount: draws)
    }

    private func playerDidNotPlay(in game: SavedGame) -> Bool {
        let stats = game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
        guard game.snapshot.playingSecondsByPlayerID[playerID, default: 0] == 0 else { return false }
        return stats.twoMade == 0 && stats.twoAttempts == 0 && stats.threeMade == 0 && stats.threeAttempts == 0
            && stats.freeThrowMade == 0 && stats.freeThrowAttempts == 0 && stats.bonusFreeThrowMade == 0 && stats.bonusFreeThrowAttempts == 0
            && stats.assists == 0 && stats.rebounds == 0 && stats.offensiveRebounds == 0 && stats.defensiveRebounds == 0
            && stats.blocks == 0 && stats.steals == 0 && stats.fouls == 0 && stats.turnovers == 0
    }

    var totalStats: PlayerStats { statsGroup.totalStats }
    var totalMinutes: Double { statsGroup.totalMinutes }
    var totalPlusMinus: Int { isFixedPeriodMode ? 0 : statsGroup.totalPlusMinus }
    var starterGameCount: Int { statsGroup.starterGameCount }
    var benchGameCount: Int { statsGroup.benchGameCount }

    private var totalValues: [(String, String)] {
        let stats = totalStats
        let rebLine = "\(stats.totalRebounds) / \(stats.offensiveRebounds) / \(stats.defensiveRebounds)"
        let astStlBlkLine = "\(stats.assists) / \(stats.steals) / \(stats.blocks)"
        let fouls = "\(stats.fouls) / \(stats.turnovers)"
        let mins = GameView.durationFormatter(totalMinutes * 60)
        let items: [(String, String)] = [
            (localized("stats_pts_min"), "\(stats.points) / \(mins)"),
            (localized("stats_rebound_detail"), rebLine),
            (localized("stats_assist_steal_block"), astStlBlkLine),
            (localized("stats_foul_turnover"), fouls),
            (localized("stats_starter_bench"), "\(starterGameCount) / \(benchGameCount)"),
            (localized("stats_plus_minus"), isFixedPeriodMode ? "--" : (totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)")),
            (localized("stats_shooting"), "\(stats.made)/\(stats.attempts)  \(percent(stats.fieldGoalRate))"),
            (localized("stat_label_2pt"), "\(stats.twoMade)/\(stats.twoAttempts)  \(percent(stats.twoPointRate))"),
            (localized("stat_label_3pt"), "\(stats.threeMade)/\(stats.threeAttempts)  \(percent(stats.threePointRate))"),
            (localized("stat_label_free_throw"), "\(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)  \(percent(stats.freeThrowRate))"),
            ("eFG / TS", "\(percent(stats.effectiveFieldGoalRate)) / \(percent(stats.trueShootingRate))"),
        ]
        return items
    }

    private var careerSummaryValues: [(String, String)] {
        let stats = totalStats
        let games = filteredGames.count
        let mins = GameView.durationFormatter(totalMinutes * 60)
        let pmText = totalPlusMinus > 0 ? "+\(totalPlusMinus)" : "\(totalPlusMinus)"
        return [
            ("\(localized("label_games_count"))", "\(games) (\(localized("stat_label_starter")) \(starterGameCount)/\(localized("stat_label_bench")) \(benchGameCount))"),
            ("\(localized("stats_pts_min"))", "\(stats.points) / \(mins)"),
            ("\(localized("stats_field_goal"))", "\(stats.made)/\(stats.attempts)  \(percent(stats.fieldGoalRate))"),
            ("\(localized("stat_label_2pt"))", "\(stats.twoMade)/\(stats.twoAttempts)  \(percent(stats.twoPointRate))"),
            ("\(localized("stat_label_3pt"))", "\(stats.threeMade)/\(stats.threeAttempts)  \(percent(stats.threePointRate))"),
            ("\(localized("stat_label_free_throw"))", "\(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)  \(percent(stats.freeThrowRate))"),
            ("\(localized("stats_plus_minus"))", pmText),
            ("\(localized("stats_rebound_detail"))", "\(stats.totalRebounds) / \(stats.offensiveRebounds) / \(stats.defensiveRebounds)"),
            ("\(localized("stats_assist_steal_block"))", "\(stats.assists) / \(stats.steals) / \(stats.blocks)"),
            ("\(localized("stats_foul_turnover"))", "\(stats.fouls) / \(stats.turnovers)"),
        ]
    }

    private var averageValues: [(String, String)] {
        let games = max(1, filteredGames.count)
        let stats = totalStats
        let items: [(CareerStatItem, String)] = [
            (.averagePoints, average(stats.points, games)),
            (.averageRebounds, average(stats.totalRebounds, games)),
            (.averageAssists, average(stats.assists, games)),
            (.averageFouls, average(stats.fouls, games)),
            (.averageBlocks, average(stats.blocks, games)),
            (.averageSteals, average(stats.steals, games)),
            (.averageTurnovers, average(stats.turnovers, games)),
            (.averageMinutes, GameView.durationFormatter(totalMinutes / Double(games) * 60)),
            (.averagePlusMinus, String(format: "%.1f", Double(totalPlusMinus) / Double(games))),
            (.averageTwoMade, average(stats.twoMade, games)),
            (.averageThreeMade, average(stats.threeMade, games)),
            (.averageFreeThrowMade, average(stats.allFreeThrowMade, games)),
            (.averageThreePointRate, percent(stats.threePointRate)),
            (.averageFreeThrowRate, percent(stats.freeThrowRate))
        ]
        return items.compactMap { item, value in
            store.isCareerStatVisible(item) ? (item.title, value) : nil
        }
    }

    private var averageCardValues: [(String, String)] {
        let stats = totalStats
        let games = max(1, filteredGames.count)
        let avg = { (val: Int) -> String in String(format: "%.1f", Double(val) / Double(games)) }
        let rebLine = "\(avg(stats.totalRebounds)) / \(avg(stats.offensiveRebounds)) / \(avg(stats.defensiveRebounds))"
        let astStlBlkLine = "\(avg(stats.assists)) / \(avg(stats.steals)) / \(avg(stats.blocks))"
        let fouls = "\(avg(stats.fouls)) / \(avg(stats.turnovers))"
        let avgMin = GameView.durationFormatter(totalMinutes / Double(games) * 60)
        return [
            (localized("stats_pts_min"), "\(avg(stats.points)) / \(avgMin)"),
            (localized("stats_rebound_detail"), rebLine),
            (localized("stats_assist_steal_block"), astStlBlkLine),
            (localized("stats_foul_turnover"), fouls),
            (localized("stats_shooting"), "\(avg(stats.made))/\(avg(stats.attempts))  \(percent(stats.fieldGoalRate))"),
            (localized("stat_label_2pt"), "\(avg(stats.twoMade))/\(avg(stats.twoAttempts))  \(percent(stats.twoPointRate))"),
            (localized("stat_label_3pt"), "\(avg(stats.threeMade))/\(avg(stats.threeAttempts))  \(percent(stats.threePointRate))"),
            (localized("stat_label_free_throw"), "\(avg(stats.allFreeThrowMade))/\(avg(stats.allFreeThrowAttempts))  \(percent(stats.freeThrowRate))"),
            (localized("stats_plus_minus"), String(format: "%.1f", Double(totalPlusMinus) / Double(games))),
        ]
    }

    private var advancedValues: [(String, String)] {
        let stats = totalStats
        let efg = percent(stats.effectiveFieldGoalRate)
        let ts = percent(stats.trueShootingRate)
        return [
            ("eFG / TS", "\(efg) / \(ts)"),
            (NSLocalizedString("stats_points_per_shot", comment: "PTS/FGA"), String(format: "%.2f", stats.pointsPerShot))
        ]
    }

    private func madeAttemptRate(made: Int, attempts: Int, rate: Double) -> String {
        "\(made)/\(attempts)  \(percent(rate))"
    }

    private func average(_ value: Int, _ games: Int) -> String {
        String(format: "%.1f", Double(value) / Double(games))
    }

    func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    func profileSubtitle(_ player: Player, includesNumber: Bool = true) -> String? {
        var parts: [String] = []
        if includesNumber, !player.number.isEmpty { parts.append("No. \(player.number)") }
        if !player.height.isEmpty { parts.append(UnitSettings.displayHeight(player.height, unit: player.heightUnit)) }
        if !player.weight.isEmpty { parts.append(UnitSettings.displayWeight(player.weight, unit: player.weightUnit)) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func containsPlayer(in game: SavedGame) -> Bool {
        game.didParticipate(playerID)
    }

    private func rebuildFixedGameAnalysisIfNeeded() {
        guard let fixedGame else {
            fixedGameAnalysis = SavedGamePeriodAnalysis()
            selectedPeriod = nil
            return
        }

        let currentGame = store.savedGames.first(where: { $0.id == fixedGame.id }) ?? fixedGame
        let analyzer = SavedGameAnalyzer(game: currentGame) { name in
            if let localID = currentGame.playerNamesByID.first(where: { $0.value == name })?.key {
                return localID
            }
            return store.players.first(where: { $0.name == name })?.id
        }
        fixedGameAnalysis = analyzer.analyze()
    }
}

struct PlayerGameSelectionView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    var games: [SavedGame]
    @Binding var selectedIDs: Set<UUID>
    var onDone: (() -> Void)? = nil
    var doneTitle: LocalizedStringKey = LocalizedStringKey("button_done")
    var isLoadingGames: Binding<Bool>? = nil
    var loadsAllGamesFromStore = false
    var refreshGames: (() -> [SavedGame])? = nil
    var onGamesRefreshed: (([SavedGame]) -> Void)? = nil
    @State private var refreshedGames: [SavedGame]?
    @State private var selectedGroupID: UUID? = nil

    private var currentGames: [SavedGame] {
        refreshedGames ?? games
    }

    var body: some View {
        List {
            if isLoadingGames?.wrappedValue == true {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(LocalizedStringKey("loading_games"))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowSeparator(.hidden)
            } else if currentGames.isEmpty {
                ContentUnavailableView(LocalizedStringKey("text_no_selectable_games"), systemImage: "clock.badge.questionmark")
            }

            if store.isPro, let groupID = selectedGroupID, let group = store.gameGroups.first(where: { $0.id == groupID }) {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("game_group_selected_filter", comment: "Filtering by"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(group.name)
                                .font(.headline)
                        }
                        Spacer()
                        Button(action: { selectedGroupID = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
            }

            ForEach(monthGroups) { group in
                DisclosureGroup {
                    HStack {
                        Button(allSelected(in: group.games) ? localized("button_clear_month") : localized("button_select_month")) {
                            toggleMonthSelection(for: group.games)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Spacer()
                        Text("\(selectedCount(in: group.games))/\(group.games.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)

                    ForEach(group.games) { game in
                        Button {
                            toggle(game.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selectedIDs.contains(game.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIDs.contains(game.id) ? Color.accentColor : .secondary)

                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text("\(game.homeTeamName) vs \(game.awayTeamName)")
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(1)
                                        Spacer()
                                        Text(scoreLine(for: game))
                                            .font(.subheadline.monospacedDigit().weight(.semibold))
                                    }

                                    Text(Self.dateFormatter.string(from: game.savedAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } label: {
                    HStack {
                        Text(group.title)
                            .font(.headline)
                        Spacer()
                        Text("\(selectedCount(in: group.games))/\(group.games.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("button_choose_games"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.isPro {
                ToolbarItem(placement: .topBarLeading) {
                    GameGroupPicker(store: store, selectedGroupID: $selectedGroupID)
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                Button(LocalizedStringKey("button_clear_all")) {
                    selectedIDs.removeAll()
                }
                .disabled(selectedIDs.isEmpty)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(LocalizedStringKey("button_select_all")) {
                    selectedIDs = Set(currentGames.map(\.id))
                }
                .disabled(currentGames.isEmpty || selectedIDs.count == currentGames.count)
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(doneTitle) {
                    onDone?()
                    dismiss()
                }
                .disabled(onDone != nil && selectedIDs.isEmpty)
            }
        }
        .onAppear {
            PlayerProfileDebugLog.log("xdz PlayerGameSelectionView body appeared games=\(currentGames.count) selected=\(selectedIDs.count) loadsAllGames=\(loadsAllGamesFromStore)")
            guard loadsAllGamesFromStore || refreshGames != nil else { return }
            refreshCurrentGames()
        }
        .onChange(of: isLoadingGames?.wrappedValue ?? false) { _, isLoading in
            guard !isLoading, loadsAllGamesFromStore || refreshGames != nil else { return }
            refreshCurrentGames()
        }
    }

    private func refreshCurrentGames() {
        let games = loadsAllGamesFromStore
            ? store.savedGames.sorted { $0.savedAt > $1.savedAt }
            : refreshGames?() ?? self.games
        refreshedGames = games
        selectedIDs = Set(games.map(\.id))
        onGamesRefreshed?(games)
    }

    private var monthGroups: [PlayerGameMonthGroup] {
        let calendar = Calendar.current
        
        // Filter games by selected group if any (Pro only)
        let filteredGames = (store.isPro ? selectedGroupID.map { groupID in
            currentGames.filter { $0.groupIDs.contains(groupID) }
        } : nil) ?? currentGames
        
        let grouped = Dictionary(grouping: filteredGames) { game in
            let components = calendar.dateComponents([.year, .month], from: game.savedAt)
            return PlayerGameMonthKey(year: components.year ?? 0, month: components.month ?? 0)
        }

        return grouped.keys.sorted(by: >).map { key in
            PlayerGameMonthGroup(key: key, games: grouped[key, default: []].sorted { $0.savedAt > $1.savedAt })
        }
    }

    private func toggle(_ id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }

    private func toggleMonthSelection(for games: [SavedGame]) {
        if allSelected(in: games) {
            games.forEach { selectedIDs.remove($0.id) }
        } else {
            games.forEach { selectedIDs.insert($0.id) }
        }
    }

    private func allSelected(in games: [SavedGame]) -> Bool {
        !games.isEmpty && games.allSatisfy { selectedIDs.contains($0.id) }
    }

    private func selectedCount(in games: [SavedGame]) -> Int {
        games.reduce(0) { count, game in
            count + (selectedIDs.contains(game.id) ? 1 : 0)
        }
    }

    private func scoreLine(for game: SavedGame) -> String {
        "\(score(for: game.snapshot.homeTeamID, in: game)) - \(score(for: game.snapshot.awayTeamID, in: game))"
    }

    private func score(for teamID: UUID?, in game: SavedGame) -> Int {
        guard let teamID else { return 0 }
        return game.score(forTeamID: teamID)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}

private struct PlayerGameMonthKey: Hashable, Comparable {
    var year: Int
    var month: Int

    static func < (lhs: PlayerGameMonthKey, rhs: PlayerGameMonthKey) -> Bool {
        lhs.year == rhs.year ? lhs.month < rhs.month : lhs.year < rhs.year
    }
}

private struct PlayerGameMonthGroup: Identifiable {
    var key: PlayerGameMonthKey
    var games: [SavedGame]
    var id: String { "\(key.year)-\(key.month)" }
    var title: String { localizedFormat("month_title_format", key.year, key.month) }
}


struct CollaborativeGameListView: View {
    @EnvironmentObject private var store: AppStore

    private var games: [SavedGame] {
        store.savedGames.filter { $0.snapshot.wasBluetoothCollaborated }
            .sorted { $0.savedAt > $1.savedAt }
    }

    var body: some View {
        List {
            if games.isEmpty {
                ContentUnavailableView(LocalizedStringKey("empty_no_bluetooth_games"), systemImage: "dot.radiowaves.left.and.right")
            }
            ForEach(games) { game in
                NavigationLink {
                    SavedGameDetailView(game: game)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(game.homeTeamName) vs \(game.awayTeamName)")
                            .font(.headline)
                        Text(Self.dateFormatter.string(from: game.savedAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(LocalizedStringKey("settings_bluetooth_games"))
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
}

struct CloudStorageView: View {
    @EnvironmentObject private var store: AppStore
    @StateObject private var cloudKit = CloudKitManager.shared
    @State private var isSyncing = false
    @State private var expandedCloudSections: Set<String> = []
    @State private var expandedLocalSections: Set<String> = []
    @State private var cloudOnlyGames: [SavedGame] = []

    private var cloudGames: [SavedGame] {
        store.savedGames.filter { store.cloudEnabledGameIDs.contains($0.id) }
            .sorted { $0.savedAt > $1.savedAt }
    }

    private var localOnlyGames: [SavedGame] {
        store.savedGames.filter { !store.cloudEnabledGameIDs.contains($0.id) }
            .sorted { $0.savedAt > $1.savedAt }
    }

    private var allGroups: [GameGroup] { store.gameGroups }

    var body: some View {
        List {
            Section {
                Text(LocalizedStringKey("cloud_storage_description"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    sync()
                } label: {
                    HStack {
                        if isSyncing || cloudKit.isSyncing {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text(LocalizedStringKey(isSyncing ? "cloud_syncing" : "cloud_sync_now"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isSyncing || cloudKit.isSyncing)

                if let error = cloudKit.lastSyncError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            let cloudSubs = buildGroupedSections(games: cloudGames)
            if !cloudSubs.isEmpty {
                Section(LocalizedStringKey("section_cloud_enabled")) {
                    ForEach(cloudSubs, id: \.name) { sub in
                        DisclosureGroup(sub.name, isExpanded: Binding(
                            get: { expandedCloudSections.contains(sub.name) },
                            set: { if $0 { expandedCloudSections.insert(sub.name) } else { expandedCloudSections.remove(sub.name) } }
                        )) {
                            ForEach(sub.games) { game in
                                gameRow(game: game, isCloud: true)
                            }
                        }
                    }
                }
            }

            let localSubs = buildGroupedSections(games: localOnlyGames)
            if !localSubs.isEmpty {
                Section(LocalizedStringKey("section_local_only")) {
                    ForEach(localSubs, id: \.name) { sub in
                        DisclosureGroup(sub.name, isExpanded: Binding(
                            get: { expandedLocalSections.contains(sub.name) },
                            set: { if $0 { expandedLocalSections.insert(sub.name) } else { expandedLocalSections.remove(sub.name) } }
                        )) {
                            ForEach(sub.games) { game in
                                gameRow(game: game, isCloud: false)
                            }
                        }
                    }
                }
            }

            if let error = cloudKit.lastSyncError, cloudOnlyGames.isEmpty {
                Section(LocalizedStringKey("section_cloud_only")) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text(LocalizedStringKey("cloud_unavailable_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !cloudOnlyGames.isEmpty {
                Section(LocalizedStringKey("section_cloud_only")) {
                    ForEach(cloudOnlyGames) { game in
                        HStack {
                            gameRow(game: game, isCloud: true)
                            Button {
                                store.downloadFromCloud(game)
                                refreshCloudOnly()
                            } label: {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .editorialSettingsListStyle()
        .navigationTitle(LocalizedStringKey("settings_cloud_storage"))
        .onAppear { refreshCloudOnly() }
        .onChange(of: store.savedGames.count) { _, _ in refreshCloudOnly() }
    }

    private func refreshCloudOnly() {
        Task {
            let allCloud = await CloudKitManager.shared.fetchGames(ids: store.cloudEnabledGameIDs)
            let localIDs = Set(store.savedGames.map(\.id))
            cloudOnlyGames = allCloud.filter { !localIDs.contains($0.id) }
        }
    }

    private struct GameSubSection {
        var name: String
        var games: [SavedGame]
    }

    private func buildGroupedSections(games: [SavedGame]) -> [GameSubSection] {
        var remaining = Set(games.map(\.id))
        var subs: [GameSubSection] = []

        for group in allGroups {
            let groupGames = games.filter { $0.groupIDs.contains(group.id) }
            if !groupGames.isEmpty {
                subs.append(GameSubSection(name: group.name, games: groupGames))
                for g in groupGames { remaining.remove(g.id) }
            }
        }

        let ungrouped = games.filter { remaining.contains($0.id) }
        if !ungrouped.isEmpty {
            subs.append(GameSubSection(name: NSLocalizedString("game_group_ungrouped", comment: "Ungrouped"), games: ungrouped))
        }

        return subs
    }

    private func gameRow(game: SavedGame, isCloud: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(game.displayTitle)
                    .font(.subheadline)
                HStack(spacing: 6) {
                    Text(Self.dateFormatter.string(from: game.savedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(scoreLine(for: game))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: isCloud ? "icloud.fill" : "icloud.slash")
                .foregroundStyle(isCloud ? .blue : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.toggleCloudStorage(for: game.id)
        }
    }

    private func scoreLine(for game: SavedGame) -> String {
        let homeScore = game.score(forTeamID: game.snapshot.homeTeamID ?? UUID())
        let awayScore = game.score(forTeamID: game.snapshot.awayTeamID ?? UUID())
        return "\(homeScore) - \(awayScore)"
    }

    private func sync() {
        isSyncing = true
        Task {
            await store.syncCloudGames()
            refreshCloudOnly()
            isSyncing = false
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()
}

private struct ELOHistoryView: View {
    let playerID: UUID
    let playerName: String
    let games: [SavedGame]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDetail: ELOComputationDetail?

    private var history: [ELOGameEntry] {
        ELOEngine.computeELOHistory(for: playerID, from: games)
    }

    var body: some View {
        NavigationStack {
            List {
                if history.isEmpty {
                    ContentUnavailableView(
                        LocalizedStringKey("text_no_data"),
                        systemImage: "chart.line.downtrend.xyaxis"
                    )
                } else {
                    ForEach(history) { entry in
                        ELOGameRow(entry: entry)
                            .contentShape(Rectangle())
                            .onTapGesture { selectedDetail = entry.detail }
                    }
                }
            }
            .navigationTitle(String(format: NSLocalizedString("elo_title_format", comment: "ELO title"), playerName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_done")) { dismiss() }
                }
            }
            .sheet(item: $selectedDetail) { detail in
                ELOComputationView(detail: detail)
            }
        }
    }
}

private struct ELOGameRow: View {
    let entry: ELOGameEntry

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(entry.game.homeTeamName) vs \(entry.game.awayTeamName)")
                        .font(.subheadline.weight(.semibold))
                    Text(dateFormatter.string(from: entry.game.savedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: entry.won ? "trophy.fill" : "hand.thumbsdown.fill")
                    .foregroundStyle(entry.won ? .yellow : .secondary)
            }

            HStack(spacing: 8) {
                Text("\(Int(entry.preELO))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.forward.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("\(Int(entry.postELO))")
                    .font(.headline.monospacedDigit().weight(.bold))
                Text(entry.delta >= 0 ? "+\(String(format: "%.1f", entry.delta))" : "\(String(format: "%.1f", entry.delta))")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(entry.delta >= 0 ? .green : .red)
            }

            HStack {
                Text("GS: \(String(format: "%.1f", entry.gameScore))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ELOComputationView: View {
    let detail: ELOComputationDetail

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(NSLocalizedString("elo_section_result", comment: "Game Result")) {
                    row("elo_label_score", "\(detail.myScore) – \(detail.opponentScore)")
                    row("elo_label_outcome", detail.won
                        ? NSLocalizedString("elo_outcome_win", comment: "Win")
                        : (detail.isDraw
                            ? NSLocalizedString("elo_outcome_draw", comment: "Draw")
                            : NSLocalizedString("elo_outcome_loss", comment: "Loss")))
                }

                Section(NSLocalizedString("elo_section_elo", comment: "ELO Parameters")) {
                    row("elo_label_pre_elo", "\(Int(detail.preELO))")
                    row("elo_label_avg_opponent_elo", String(format: "%.1f", detail.avgOpponentELO))
                    row("elo_label_expected", String(format: "%.4f", detail.expected))
                    row("elo_label_actual", String(format: "%.1f", detail.actual))
                }

                Section(NSLocalizedString("elo_section_gs", comment: "Game Score Adjustment")) {
                    Text("GS = PTS + 0.4\u{00d7}FGM \u{2212} 0.7\u{00d7}FGA \u{2212} 0.4\u{00d7}(FTA\u{2212}FTM) + 0.5\u{00d7}REB + STL + 0.7\u{00d7}AST + 0.7\u{00d7}BLK \u{2212} 0.4\u{00d7}PF \u{2212} TOV")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    row("elo_label_player_gs", String(format: "%.1f", detail.playerGS))
                    row("elo_label_avg_gs", String(format: "%.1f", detail.avgGS))
                    Text("Relative = \(String(format: "%.1f", detail.playerGS)) - \(String(format: "%.1f", detail.avgGS)) = \(String(format: "%.1f", detail.relativeGS))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("perf = tanh(\(String(format: "%.1f", detail.relativeGS)) / 15) = \(String(format: "%.3f", detail.perf))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text(detail.won
                         ? "GS_Factor = 1 + \(String(format: "%.3f", detail.perf)) \u{00d7} 0.5 = \(String(format: "%.3f", detail.gsFactorRaw))"
                         : "GS_Factor = 1 - \(String(format: "%.3f", detail.perf)) \u{00d7} 0.5 = \(String(format: "%.3f", detail.gsFactorRaw))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if detail.gsFactorClamped != detail.gsFactorRaw {
                        Text("clamped to [0.3, 2.0] \u{2192} \(String(format: "%.3f", detail.gsFactorClamped))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    row("elo_label_gs_factor", String(format: "%.3f", detail.gsFactorClamped))
                }

                Section(NSLocalizedString("elo_section_formula", comment: "Formula")) {
                    Text("ELO = K \u{00d7} (Actual - Expected) \u{00d7} GS_Factor")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\u{0394} = \(String(format: "%.0f", detail.K)) \u{00d7} (\(String(format: "%.4f", detail.actual)) - \(String(format: "%.4f", detail.expected))) \u{00d7} \(String(format: "%.3f", detail.gsFactorClamped))")
                        .font(.caption.monospacedDigit())
                    Text("= \(String(format: "%.1f", detail.K * (detail.actual - detail.expected) * detail.gsFactorClamped))")
                        .font(.caption.monospacedDigit().weight(.semibold))
                }
            }
            .navigationTitle(NSLocalizedString("elo_computation_title", comment: "ELO Calculation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("button_done")) { dismiss() }
                }
            }
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(LocalizedStringKey(key))
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.semibold))
        }
    }
}

struct SafariWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let wk = WKWebView()
        wk.load(URLRequest(url: url))
        return wk
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }
}
