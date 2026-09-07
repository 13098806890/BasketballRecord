import Foundation

struct BasketballExcelReport {
    let fileName: String
    let sheets: [BasketballExcelSheet]

    var data: Data {
        BasketballXLSXWriter(sheets: sheets).data()
    }
}

struct BasketballExcelSheet {
    let name: String
    let rows: [[BasketballExcelCell]]
}

enum BasketballExcelCell: Equatable {
    case text(String)
    case number(Double)
    case integer(Int)
    case date(Date)
    case percentage(Double)
    case duration(TimeInterval)
    case blank
}

struct BasketballExcelStatsAggregator {
    static func sum(_ values: [PlayerStats]) -> PlayerStats {
        var result = PlayerStats()
        for value in values {
            result.twoMade += value.twoMade
            result.twoAttempts += value.twoAttempts
            result.threeMade += value.threeMade
            result.threeAttempts += value.threeAttempts
            result.layupMade += value.layupMade
            result.layupAttempts += value.layupAttempts
            result.midRangeMade += value.midRangeMade
            result.midRangeAttempts += value.midRangeAttempts
            result.paintMade += value.paintMade
            result.paintAttempts += value.paintAttempts
            result.dunkMade += value.dunkMade
            result.dunkAttempts += value.dunkAttempts
            result.bonusFreeThrowMade += value.bonusFreeThrowMade
            result.bonusFreeThrowAttempts += value.bonusFreeThrowAttempts
            result.freeThrowMade += value.freeThrowMade
            result.freeThrowAttempts += value.freeThrowAttempts
            result.rebounds += value.rebounds
            result.offensiveRebounds += value.offensiveRebounds
            result.defensiveRebounds += value.defensiveRebounds
            result.assists += value.assists
            result.fouls += value.fouls
            result.blocks += value.blocks
            result.steals += value.steals
            result.turnovers += value.turnovers
            result.fastBreakPoints += value.fastBreakPoints
        }
        return result
    }
}

struct BasketballExcelReportBuilder {
    static func singleGame(_ game: SavedGame, players: [Player]) -> BasketballExcelReport {
        BasketballExcelReport(
            fileName: fileName("game", game.displayTitle),
            sheets: [
                overviewSheet(for: game),
                playerBoxScoreSheet(games: [game], players: players),
                teamStatsSheet(games: [game]),
                periodSplitsSheet(games: [game], players: players),
                eventLogSheet(games: [game])
            ]
        )
    }

    static func history(_ games: [SavedGame], players: [Player]) -> BasketballExcelReport {
        let sortedGames = games.sorted { $0.savedAt > $1.savedAt }
        return BasketballExcelReport(
            fileName: fileName("history", "BasketballRecord"),
            sheets: [
                gamesSheet(games: sortedGames),
                playerBoxScoreSheet(games: sortedGames, players: players),
                playerSummarySheet(games: sortedGames, players: players),
                teamStatsSheet(games: sortedGames),
                eventLogSheet(games: sortedGames)
            ]
        )
    }

    static func playerProfile(playerID: UUID, games: [SavedGame], players: [Player]) -> BasketballExcelReport {
        let sortedGames = games.sorted { $0.savedAt > $1.savedAt }
        let playerName = players.first(where: { $0.id == playerID })?.name ?? "Player"
        return BasketballExcelReport(
            fileName: fileName("player", playerName),
            sheets: [
                playerProfileSheet(playerID: playerID, games: sortedGames, players: players),
                playerGameByGameSheet(playerID: playerID, games: sortedGames, players: players),
                playerCareerSheet(playerID: playerID, games: sortedGames, players: players),
                playerAverageSheet(playerID: playerID, games: sortedGames, players: players),
                playerEventSheet(playerID: playerID, games: sortedGames)
            ]
        )
    }

    static func teamCareer(teamID: UUID, teamName: String, games: [SavedGame]) -> BasketballExcelReport {
        let relevantGames = games.filter { $0.snapshot.homeTeamID == teamID || $0.snapshot.awayTeamID == teamID }
        return BasketballExcelReport(
            fileName: fileName("team", teamName),
            sheets: [teamCareerSheet(teamID: teamID, teamName: teamName, games: relevantGames)]
        )
    }

    static func career(teams: [Team], players: [Player], games: [SavedGame]) -> BasketballExcelReport {
        BasketballExcelReport(
            fileName: "BasketballRecord_Career",
            sheets: [
                allTeamsCareerSheet(teams: teams, games: games),
                playerSummarySheet(games: games, players: players)
            ]
        )
    }

    static func playerCareer(playerID: UUID, games: [SavedGame], players: [Player]) -> BasketballExcelReport {
        playerProfile(playerID: playerID, games: games, players: players)
    }

    static func playerRoster(_ players: [Player]) -> BasketballExcelReport {
        var rows: [[BasketballExcelCell]] = [
            header(["excel_header_name", "excel_header_number", "excel_header_position", "excel_header_height", "excel_header_weight", "excel_header_nicknames"])
        ]
        rows += players.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map {
            [.text($0.name), .text($0.number), .text($0.position), .text($0.height), .text($0.weight), .text($0.nicknames.joined(separator: ", "))]
        }
        return BasketballExcelReport(fileName: "BasketballRecord_Players", sheets: [BasketballExcelSheet(name: localized("excel_sheet_players"), rows: rows)])
    }

    static func teamRoster(_ teams: [Team], players: [Player]) -> BasketballExcelReport {
        var rows: [[BasketballExcelCell]] = [
            header(["excel_header_team", "excel_header_player_count", "excel_header_players"])
        ]
        rows += teams.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }.map { team in
            let names = team.playerIDs.compactMap { playerID in players.first(where: { $0.id == playerID })?.name }
            return [.text(team.name), .integer(team.playerIDs.count), .text(names.joined(separator: ", "))]
        }
        return BasketballExcelReport(fileName: "BasketballRecord_Teams", sheets: [BasketballExcelSheet(name: localized("excel_sheet_teams"), rows: rows)])
    }

    private static func overviewSheet(for game: SavedGame) -> BasketballExcelSheet {
        let homeID = game.snapshot.homeTeamID
        let awayID = game.snapshot.awayTeamID
        let homeScore = homeID.map { game.score(forTeamID: $0) } ?? 0
        let awayScore = awayID.map { game.score(forTeamID: $0) } ?? 0
        let rows: [[BasketballExcelCell]] = [
            header(["excel_header_field", "excel_header_value"]),
            [text("excel_field_game_name"), .text(game.displayName)],
            [text("excel_field_date"), .date(game.savedAt)],
            [text("excel_field_home_team"), .text(game.homeTeamName)],
            [text("excel_field_away_team"), .text(game.awayTeamName)],
            [text("excel_field_final_score"), .text("\(homeScore) - \(awayScore)")],
            [text("excel_field_periods"), .integer(game.snapshot.periodCount)],
            [text("excel_field_status"), .text(game.snapshot.isComplete ? localized("period_summary_finished") : localized("alert_unfinished_game_title"))],
            [text("excel_field_team_stats_mode"), .text(teamStatsModeText(for: game))]
        ]
        return BasketballExcelSheet(name: localized("excel_sheet_overview"), rows: rows)
    }

    private static func gamesSheet(games: [SavedGame]) -> BasketballExcelSheet {
        var rows: [[BasketballExcelCell]] = [
            header(["excel_header_date", "excel_header_game", "excel_header_home_team", "excel_header_away_team", "excel_header_home_score", "excel_header_away_score", "excel_header_periods", "excel_header_status"])
        ]
        rows += games.map { game in
            let homeScore = game.snapshot.homeTeamID.map { game.score(forTeamID: $0) } ?? 0
            let awayScore = game.snapshot.awayTeamID.map { game.score(forTeamID: $0) } ?? 0
            return [.date(game.savedAt), .text(game.displayTitle), .text(game.homeTeamName), .text(game.awayTeamName), .integer(homeScore), .integer(awayScore), .integer(game.snapshot.periodCount), .text(game.snapshot.isComplete ? localized("period_summary_finished") : localized("alert_unfinished_game_title"))]
        }
        return BasketballExcelSheet(name: localized("excel_sheet_games"), rows: rows)
    }

    private static func playerBoxScoreSheet(games: [SavedGame], players: [Player]) -> BasketballExcelSheet {
        var rows: [[BasketballExcelCell]] = [
            header(["excel_header_date", "excel_header_game", "excel_header_player", "excel_header_team", "excel_header_role"] + statHeaders)
        ]
        for game in games.sorted(by: { $0.savedAt > $1.savedAt }) {
            for playerID in playerIDs(in: game) {
                let stats = game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
                rows.append([.date(game.savedAt), .text(game.displayTitle), .text(playerName(playerID, game: game, players: players)), .text(teamName(playerID, game: game)), .text(game.role(of: playerID)?.title ?? localized("unrecorded_role"))] + statCells(stats, seconds: game.snapshot.playingSecondsByPlayerID[playerID, default: 0], plusMinus: game.snapshot.plusMinusByPlayerID[playerID, default: 0]))
            }
        }
        return BasketballExcelSheet(name: localized("excel_sheet_player_box_score"), rows: rows)
    }

    private static func playerSummarySheet(games: [SavedGame], players: [Player]) -> BasketballExcelSheet {
        var rows: [[BasketballExcelCell]] = [
            header(["excel_header_player", "excel_header_games", "excel_header_starts", "excel_header_bench", "excel_header_minutes", "excel_header_wins", "excel_header_losses"] + statHeaders)
        ]
        for player in players.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            let participated = games.filter { $0.didParticipate(player.id) }
            guard !participated.isEmpty else { continue }
            let stats = BasketballExcelStatsAggregator.sum(participated.map { $0.snapshot.statsByPlayerID[player.id, default: PlayerStats()] })
            let seconds = participated.reduce(0) { $0 + $1.snapshot.playingSecondsByPlayerID[player.id, default: 0] }
            let starts = participated.filter { $0.role(of: player.id) == .starter }.count
            let bench = participated.filter { $0.role(of: player.id) == .bench }.count
            let wins = participated.filter { playerWon(player.id, in: $0) }.count
            let losses = participated.filter { playerLost(player.id, in: $0) }.count
            rows.append([.text(player.name), .integer(participated.count), .integer(starts), .integer(bench), .duration(seconds), .integer(wins), .integer(losses)] + statCells(stats, seconds: seconds, plusMinus: participated.reduce(0) { $0 + $1.snapshot.plusMinusByPlayerID[player.id, default: 0] }))
        }
        return BasketballExcelSheet(name: localized("excel_sheet_player_summary"), rows: rows)
    }

    private static func teamStatsSheet(games: [SavedGame]) -> BasketballExcelSheet {
        var rows: [[BasketballExcelCell]] = [
            header(["excel_header_date", "excel_header_game", "excel_header_team", "excel_header_score", "excel_header_win_loss"] + statHeaders)
        ]
        for game in games.sorted(by: { $0.savedAt > $1.savedAt }) {
            for teamID in [game.snapshot.homeTeamID, game.snapshot.awayTeamID].compactMap({ $0 }) {
                let isHome = teamID == game.snapshot.homeTeamID
                let score = game.score(forTeamID: teamID)
                let opponentID = isHome ? game.snapshot.awayTeamID : game.snapshot.homeTeamID
                let opponentScore = opponentID.map { game.score(forTeamID: $0) } ?? 0
                let result = score > opponentScore ? localized("excel_result_win") : score < opponentScore ? localized("excel_result_loss") : localized("excel_result_draw")
                let stats = teamStats(for: teamID, in: game)
                rows.append([.date(game.savedAt), .text(game.displayTitle), .text(isHome ? game.homeTeamName : game.awayTeamName), .integer(score), .text(result)] + statCells(stats, seconds: 0, plusMinus: 0))
            }
        }
        return BasketballExcelSheet(name: localized("excel_sheet_team_stats"), rows: rows)
    }

    private static func periodSplitsSheet(games: [SavedGame], players: [Player]) -> BasketballExcelSheet {
        var rows: [[BasketballExcelCell]] = [
            header(["excel_header_date", "excel_header_game", "excel_header_period", "excel_header_player"] + statHeaders)
        ]
        for game in games.sorted(by: { $0.savedAt > $1.savedAt }) {
            let analysis = SavedGameAnalyzer(game: game) { name in
                game.playerNamesByID.first(where: { $0.value == name })?.key
            }.analyze()
            for period in 1...max(game.snapshot.periodCount, 1) {
                for playerID in playerIDs(in: game) {
                    let stats = analysis.statsByPeriod[period]?[playerID, default: PlayerStats()] ?? PlayerStats()
                    let seconds = game.playingTimeByPeriod()[period]?[playerID] ?? 0
                    rows.append([.date(game.savedAt), .text(game.displayTitle), .integer(period), .text(playerName(playerID, game: game, players: players))] + statCells(stats, seconds: seconds, plusMinus: analysis.plusMinusByPeriod[period]?[playerID] ?? 0))
                }
            }
        }
        return BasketballExcelSheet(name: localized("excel_sheet_period_splits"), rows: rows)
    }

    private static func eventLogSheet(games: [SavedGame]) -> BasketballExcelSheet {
        var rows: [[BasketballExcelCell]] = [
            header(["excel_header_date", "excel_header_game", "excel_header_period", "excel_header_time", "excel_header_event_code", "excel_header_event", "excel_header_player", "excel_header_related_player"])
        ]
        for game in games.sorted(by: { $0.savedAt > $1.savedAt }) {
            for log in game.snapshot.logs {
                rows.append([.date(game.savedAt), .text(game.displayTitle), .integer(log.period ?? 0), .duration(log.periodElapsedSeconds ?? 0), .text(log.eventCode ?? ""), .text(GameLogFormatter.normalizedMessage(log.message)), .text(log.playerID.map { playerName($0, game: game, players: []) } ?? ""), .text(log.relatedPlayerID.map { playerName($0, game: game, players: []) } ?? "")])
            }
        }
        return BasketballExcelSheet(name: localized("excel_sheet_event_log"), rows: rows)
    }

    private static func playerProfileSheet(playerID: UUID, games: [SavedGame], players: [Player]) -> BasketballExcelSheet {
        let player = players.first(where: { $0.id == playerID })
        let rows: [[BasketballExcelCell]] = [
            header(["excel_header_field", "excel_header_value"]),
            [text("excel_field_name"), .text(player?.name ?? "")],
            [text("excel_field_number"), .text(player?.number ?? "")],
            [text("excel_field_position"), .text(player?.position ?? "")],
            [text("excel_field_height"), .text(player?.height ?? "")],
            [text("excel_field_weight"), .text(player?.weight ?? "")],
            [text("excel_field_games_played"), .integer(games.filter { $0.didParticipate(playerID) }.count)]
        ]
        return BasketballExcelSheet(name: localized("excel_sheet_player_profile"), rows: rows)
    }

    private static func playerGameByGameSheet(playerID: UUID, games: [SavedGame], players: [Player]) -> BasketballExcelSheet {
        var rows: [[BasketballExcelCell]] = [header(["excel_header_date", "excel_header_game", "excel_header_team", "excel_header_role"] + statHeaders)]
        for game in games where game.didParticipate(playerID) {
            let stats = game.snapshot.statsByPlayerID[playerID, default: PlayerStats()]
            rows.append([.date(game.savedAt), .text(game.displayTitle), .text(teamName(playerID, game: game)), .text(game.role(of: playerID)?.title ?? localized("unrecorded_role"))] + statCells(stats, seconds: game.snapshot.playingSecondsByPlayerID[playerID, default: 0], plusMinus: game.snapshot.plusMinusByPlayerID[playerID, default: 0]))
        }
        return BasketballExcelSheet(name: localized("excel_sheet_game_by_game"), rows: rows)
    }

    private static func playerCareerSheet(playerID: UUID, games: [SavedGame], players: [Player]) -> BasketballExcelSheet {
        let participated = games.filter { $0.didParticipate(playerID) }
        let stats = BasketballExcelStatsAggregator.sum(participated.map { $0.snapshot.statsByPlayerID[playerID, default: PlayerStats()] })
        let seconds = participated.reduce(0) { $0 + $1.snapshot.playingSecondsByPlayerID[playerID, default: 0] }
        let starts = participated.filter { $0.role(of: playerID) == .starter }.count
        let bench = participated.filter { $0.role(of: playerID) == .bench }.count
        let wins = participated.filter { playerWon(playerID, in: $0) }.count
        let losses = participated.filter { playerLost(playerID, in: $0) }.count
        let plusMinus = participated.reduce(0) { $0 + $1.snapshot.plusMinusByPlayerID[playerID, default: 0] }
        let headerRow = header(["excel_header_player", "excel_header_games", "excel_header_starts", "excel_header_bench", "excel_header_minutes", "excel_header_wins", "excel_header_losses"] + statHeaders)
        let valueRow: [BasketballExcelCell] = [.text(players.first(where: { $0.id == playerID })?.name ?? ""), .integer(participated.count), .integer(starts), .integer(bench), .duration(seconds), .integer(wins), .integer(losses)] + statCells(stats, seconds: seconds, plusMinus: plusMinus)
        let rows: [[BasketballExcelCell]] = [headerRow, valueRow]
        return BasketballExcelSheet(name: localized("excel_sheet_career"), rows: rows)
    }

    private static func playerAverageSheet(playerID: UUID, games: [SavedGame], players: [Player]) -> BasketballExcelSheet {
        let participated = games.filter { $0.didParticipate(playerID) }
        let stats = BasketballExcelStatsAggregator.sum(participated.map { $0.snapshot.statsByPlayerID[playerID, default: PlayerStats()] })
        let count = max(participated.count, 1)
        let seconds = participated.reduce(0) { $0 + $1.snapshot.playingSecondsByPlayerID[playerID, default: 0] }
        return BasketballExcelSheet(name: localized("excel_sheet_average"), rows: [
            header(["excel_header_player", "excel_header_games"] + statHeaders),
            [.text(players.first(where: { $0.id == playerID })?.name ?? ""), .integer(participated.count)] + averageStatCells(stats, count: count, seconds: seconds, plusMinus: participated.reduce(0) { $0 + $1.snapshot.plusMinusByPlayerID[playerID, default: 0] })
        ])
    }

    private static func playerEventSheet(playerID: UUID, games: [SavedGame]) -> BasketballExcelSheet {
        var rows: [[BasketballExcelCell]] = [header(["excel_header_date", "excel_header_game", "excel_header_period", "excel_header_time", "excel_header_event_code", "excel_header_event"])]
        for game in games {
            for log in game.snapshot.logs where log.playerID == playerID || log.relatedPlayerID == playerID {
                rows.append([.date(game.savedAt), .text(game.displayTitle), .integer(log.period ?? 0), .duration(log.periodElapsedSeconds ?? 0), .text(log.eventCode ?? ""), .text(GameLogFormatter.normalizedMessage(log.message))])
            }
        }
        return BasketballExcelSheet(name: localized("excel_sheet_events"), rows: rows)
    }

    private static func teamCareerSheet(teamID: UUID, teamName: String, games: [SavedGame]) -> BasketballExcelSheet {
        var rows: [[BasketballExcelCell]] = [
            header(["excel_header_date", "excel_header_game", "excel_header_team", "excel_header_result", "excel_header_score", "excel_header_opponent_score", "excel_header_margin"])
        ]
        for game in games.sorted(by: { $0.savedAt > $1.savedAt }) {
            let score = game.score(forTeamID: teamID)
            let opponentID = teamID == game.snapshot.homeTeamID ? game.snapshot.awayTeamID : game.snapshot.homeTeamID
            let opponentScore = opponentID.map { game.score(forTeamID: $0) } ?? 0
            let result = score > opponentScore ? localized("excel_result_win") : score < opponentScore ? localized("excel_result_loss") : localized("excel_result_draw")
            rows.append([.date(game.savedAt), .text(game.displayTitle), .text(teamName), .text(result), .integer(score), .integer(opponentScore), .integer(score - opponentScore)])
        }
        return BasketballExcelSheet(name: localized("excel_sheet_team_career"), rows: rows)
    }

    private static func allTeamsCareerSheet(teams: [Team], games: [SavedGame]) -> BasketballExcelSheet {
        var rows: [[BasketballExcelCell]] = [
            header(["excel_header_team", "excel_header_games", "excel_header_wins", "excel_header_losses", "excel_header_win_rate", "excel_header_points_for", "excel_header_points_against", "excel_header_average_margin"])
        ]
        for team in teams.sorted(by: { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }) {
            let relevantGames = games.filter { $0.snapshot.homeTeamID == team.id || $0.snapshot.awayTeamID == team.id }
            guard !relevantGames.isEmpty else { continue }
            var wins = 0
            var losses = 0
            var pointsFor = 0
            var pointsAgainst = 0
            for game in relevantGames {
                let score = game.score(forTeamID: team.id)
                let opponentID = team.id == game.snapshot.homeTeamID ? game.snapshot.awayTeamID : game.snapshot.homeTeamID
                let opponentScore = opponentID.map { game.score(forTeamID: $0) } ?? 0
                pointsFor += score
                pointsAgainst += opponentScore
                if score > opponentScore { wins += 1 }
                if score < opponentScore { losses += 1 }
            }
            rows.append([.text(team.name), .integer(relevantGames.count), .integer(wins), .integer(losses), .percentage(Double(wins) / Double(relevantGames.count)), .integer(pointsFor), .integer(pointsAgainst), .number(Double(pointsFor - pointsAgainst) / Double(relevantGames.count))])
        }
        return BasketballExcelSheet(name: localized("excel_sheet_team_career"), rows: rows)
    }

    private static let statHeaders = [
        "excel_header_minutes", "excel_header_plus_minus", "excel_header_points", "excel_header_two_point", "excel_header_three_point", "excel_header_free_throw", "excel_header_rebounds", "excel_header_offensive_rebounds", "excel_header_defensive_rebounds", "excel_header_assists", "excel_header_steals", "excel_header_blocks", "excel_header_fouls", "excel_header_turnovers", "excel_header_fast_break_points", "excel_header_fg_percent", "excel_header_efg_percent", "excel_header_ts_percent", "excel_header_pps"
    ]

    private static func statCells(_ stats: PlayerStats, seconds: TimeInterval, plusMinus: Int) -> [BasketballExcelCell] {
        [.duration(seconds), .integer(plusMinus), .integer(stats.points), .text("\(stats.twoMade)/\(stats.twoAttempts)"), .text("\(stats.threeMade)/\(stats.threeAttempts)"), .text("\(stats.allFreeThrowMade)/\(stats.allFreeThrowAttempts)"), .integer(stats.totalRebounds), .integer(stats.offensiveRebounds), .integer(stats.defensiveRebounds), .integer(stats.assists), .integer(stats.steals), .integer(stats.blocks), .integer(stats.fouls), .integer(stats.turnovers), .integer(stats.fastBreakPoints), .percentage(stats.fieldGoalRate), .percentage(stats.effectiveFieldGoalRate), .percentage(stats.trueShootingRate), .number(stats.pointsPerShot)]
    }

    private static func averageStatCells(_ stats: PlayerStats, count: Int, seconds: TimeInterval, plusMinus: Int) -> [BasketballExcelCell] {
        [.duration(seconds / Double(count)), .number(Double(plusMinus) / Double(count)), .number(Double(stats.points) / Double(count)), .number(Double(stats.twoMade) / Double(count)), .number(Double(stats.threeMade) / Double(count)), .number(Double(stats.allFreeThrowMade) / Double(count)), .number(Double(stats.totalRebounds) / Double(count)), .number(Double(stats.offensiveRebounds) / Double(count)), .number(Double(stats.defensiveRebounds) / Double(count)), .number(Double(stats.assists) / Double(count)), .number(Double(stats.steals) / Double(count)), .number(Double(stats.blocks) / Double(count)), .number(Double(stats.fouls) / Double(count)), .number(Double(stats.turnovers) / Double(count)), .number(Double(stats.fastBreakPoints) / Double(count)), .percentage(stats.fieldGoalRate), .percentage(stats.effectiveFieldGoalRate), .percentage(stats.trueShootingRate), .number(stats.pointsPerShot)]
    }

    private static func playerIDs(in game: SavedGame) -> [UUID] {
        var ids = game.homePlayerIDs + game.awayPlayerIDs
        if game.snapshot.homeTeamStatsMode { ids = ids.filter { !game.homePlayerIDs.contains($0) } }
        if game.snapshot.awayTeamStatsMode { ids = ids.filter { !game.awayPlayerIDs.contains($0) } }
        return Array(Set(ids)).sorted { playerName($0, game: game, players: []).localizedCaseInsensitiveCompare(playerName($1, game: game, players: [])) == .orderedAscending }
    }

    private static func playerName(_ id: UUID, game: SavedGame, players: [Player]) -> String {
        players.first(where: { $0.id == id })?.name ?? game.playerNamesByID[id] ?? id.uuidString
    }

    private static func teamName(_ playerID: UUID, game: SavedGame) -> String {
        if game.homePlayerIDs.contains(playerID) { return game.homeTeamName }
        if game.awayPlayerIDs.contains(playerID) { return game.awayTeamName }
        return ""
    }

    private static func teamStats(for teamID: UUID, in game: SavedGame) -> PlayerStats {
        if let teamStats = game.snapshot.teamStatsByID[teamID] { return teamStats }
        let ids = teamID == game.snapshot.homeTeamID ? game.homePlayerIDs : game.awayPlayerIDs
        return BasketballExcelStatsAggregator.sum(ids.compactMap { game.snapshot.statsByPlayerID[$0] })
    }

    private static func playerWon(_ playerID: UUID, in game: SavedGame) -> Bool {
        guard let teamID = game.homePlayerIDs.contains(playerID) ? game.snapshot.homeTeamID : game.snapshot.awayTeamID,
              let opponentID = teamID == game.snapshot.homeTeamID ? game.snapshot.awayTeamID : game.snapshot.homeTeamID else { return false }
        return game.score(forTeamID: teamID) > game.score(forTeamID: opponentID)
    }

    private static func playerLost(_ playerID: UUID, in game: SavedGame) -> Bool {
        guard let teamID = game.homePlayerIDs.contains(playerID) ? game.snapshot.homeTeamID : game.snapshot.awayTeamID,
              let opponentID = teamID == game.snapshot.homeTeamID ? game.snapshot.awayTeamID : game.snapshot.homeTeamID else { return false }
        return game.score(forTeamID: teamID) < game.score(forTeamID: opponentID)
    }

    private static func teamStatsModeText(for game: SavedGame) -> String {
        if game.snapshot.homeTeamStatsMode && game.snapshot.awayTeamStatsMode { return localized("excel_team_stats_both") }
        if game.snapshot.homeTeamStatsMode { return localized("excel_team_stats_home") }
        if game.snapshot.awayTeamStatsMode { return localized("excel_team_stats_away") }
        return localized("excel_team_stats_none")
    }

    private static func header(_ keys: [String]) -> [BasketballExcelCell] {
        keys.map { .text(localized($0)) }
    }

    private static func text(_ key: String) -> BasketballExcelCell {
        .text(localized(key))
    }

    private static func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private static func fileName(_ prefix: String, _ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let safe = value.unicodeScalars.map { allowed.contains($0) ? String($0) : "_" }.joined()
        return "BasketballRecord_\(prefix)_\(safe.isEmpty ? "Export" : safe)"
    }
}

private struct BasketballXLSXWriter {
    let sheets: [BasketballExcelSheet]

    func data() -> Data {
        var entries: [(String, Data)] = []
        entries.append(("[Content_Types].xml", contentTypes()))
        entries.append(("_rels/.rels", rootRelationships()))
        entries.append(("xl/workbook.xml", workbook()))
        entries.append(("xl/_rels/workbook.xml.rels", workbookRelationships()))
        entries.append(("xl/styles.xml", styles()))
        for (index, sheet) in sheets.enumerated() {
            entries.append(("xl/worksheets/sheet\(index + 1).xml", worksheet(sheet)))
        }
        return ZipStore(entries: entries).data()
    }

    private func contentTypes() -> Data {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/><Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/>"
        for index in sheets.indices {
            xml += "<Override PartName=\"/xl/worksheets/sheet\(index + 1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
        }
        xml += "</Types>"
        return xml.data(using: .utf8)!
    }

    private func rootRelationships() -> Data {
        data("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"xl/workbook.xml\"/></Relationships>")
    }

    private func workbook() -> Data {
        let sheetXML = sheets.enumerated().map { index, sheet in
            "<sheet name=\"\(escape(sheet.name))\" sheetId=\"\(index + 1)\" r:id=\"rId\(index + 1)\"/>"
        }.joined()
        return data("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><sheets>\(sheetXML)</sheets></workbook>")
    }

    private func workbookRelationships() -> Data {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        for index in sheets.indices {
            xml += "<Relationship Id=\"rId\(index + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(index + 1).xml\"/>"
        }
        xml += "<Relationship Id=\"rId\(sheets.count + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/></Relationships>"
        return data(xml)
    }

    private func styles() -> Data {
        data("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><styleSheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><numFmts count=\"3\"><numFmt numFmtId=\"164\" formatCode=\"yyyy-mm-dd hh:mm\"/><numFmt numFmtId=\"165\" formatCode=\"mm:ss\"/><numFmt numFmtId=\"166\" formatCode=\"0.0%\"/></numFmts><fonts count=\"2\"><font><sz val=\"11\"/><color rgb=\"FF1F2937\"/><name val=\"Aptos\"/></font><font><b/><sz val=\"11\"/><color rgb=\"FFFFFFFF\"/><name val=\"Aptos\"/></font></fonts><fills count=\"3\"><fill><patternFill patternType=\"none\"/></fill><fill><patternFill patternType=\"gray125\"/></fill><fill><patternFill patternType=\"solid\"><fgColor rgb=\"FF12344D\"/><bgColor indexed=\"64\"/></patternFill></fill></fills><borders count=\"1\"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count=\"1\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellStyleXfs><cellXfs count=\"7\"><xf numFmtId=\"0\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/><xf numFmtId=\"0\" fontId=\"1\" fillId=\"2\" borderId=\"0\" applyAlignment=\"1\"><alignment horizontal=\"center\"/></xf><xf numFmtId=\"164\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/><xf numFmtId=\"165\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/><xf numFmtId=\"166\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/><xf numFmtId=\"3\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/><xf numFmtId=\"2\" fontId=\"0\" fillId=\"0\" borderId=\"0\"/></cellXfs></styleSheet>")
    }

    private func worksheet(_ sheet: BasketballExcelSheet) -> Data {
        let rows = sheet.rows.enumerated().map { rowIndex, row in
            let cells = row.enumerated().map { columnIndex, cell in cellXML(cell, row: rowIndex + 1, column: columnIndex + 1, isHeader: rowIndex == 0) }.joined()
            return "<row r=\"\(rowIndex + 1)\">\(cells)</row>"
        }.joined()
        return data("<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?><worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\"><sheetViews><sheetView workbookViewId=\"0\"><pane ySplit=\"1\" topLeftCell=\"A2\" activePane=\"bottomLeft\" state=\"frozen\"/></sheetView></sheetViews><sheetData>\(rows)</sheetData></worksheet>")
    }

    private func cellXML(_ cell: BasketballExcelCell, row: Int, column: Int, isHeader: Bool) -> String {
        let ref = "\(columnName(column))\(row)"
        let style = isHeader ? 1 : styleIndex(for: cell)
        switch cell {
        case .blank:
            return "<c r=\"\(ref)\" s=\"\(style)\"/>"
        case let .text(value):
            return "<c r=\"\(ref)\" s=\"\(style)\" t=\"inlineStr\"><is><t>\(escape(value))</t></is></c>"
        case let .number(value):
            return numericCell(ref: ref, style: style, value: value)
        case let .integer(value):
            return numericCell(ref: ref, style: style, value: Double(value))
        case let .date(value):
            return numericCell(ref: ref, style: 2, value: excelDate(value))
        case let .percentage(value):
            return numericCell(ref: ref, style: 4, value: value)
        case let .duration(value):
            return numericCell(ref: ref, style: 3, value: value / 86400)
        }
    }

    private func numericCell(ref: String, style: Int, value: Double) -> String {
        "<c r=\"\(ref)\" s=\"\(style)\"><v>\(String(format: "%.10f", locale: Locale(identifier: "en_US_POSIX"), value))</v></c>"
    }

    private func styleIndex(for cell: BasketballExcelCell) -> Int {
        switch cell {
        case .date: return 2
        case .duration: return 3
        case .percentage: return 4
        case .number: return 6
        default: return 5
        }
    }

    private func excelDate(_ date: Date) -> Double {
        date.timeIntervalSince1970 / 86400 + 25569
    }

    private func columnName(_ value: Int) -> String {
        var number = value
        var name = ""
        while number > 0 {
            let remainder = (number - 1) % 26
            name = String(UnicodeScalar(65 + remainder)!) + name
            number = (number - 1) / 26
        }
        return name
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&apos;")
    }

    private func data(_ value: String) -> Data {
        value.data(using: .utf8)!
    }
}

private struct ZipStore {
    let entries: [(String, Data)]

    func data() -> Data {
        var output = Data()
        var centralDirectory = Data()
        var offset: UInt32 = 0
        for (name, content) in entries {
            let nameData = name.data(using: .utf8)!
            let crc = CRC32.checksum(content)
            output.append(contentsOf: uint32(0x04034b50))
            output.append(contentsOf: uint16(20))
            output.append(contentsOf: uint16(0x0800))
            output.append(contentsOf: uint16(0))
            output.append(contentsOf: uint16(0))
            output.append(contentsOf: uint16(0))
            output.append(contentsOf: uint32(crc))
            output.append(contentsOf: uint32(UInt32(content.count)))
            output.append(contentsOf: uint32(UInt32(content.count)))
            output.append(contentsOf: uint16(UInt16(nameData.count)))
            output.append(contentsOf: uint16(0))
            output.append(nameData)
            output.append(content)

            centralDirectory.append(contentsOf: uint32(0x02014b50))
            centralDirectory.append(contentsOf: uint16(20))
            centralDirectory.append(contentsOf: uint16(20))
            centralDirectory.append(contentsOf: uint16(0x0800))
            centralDirectory.append(contentsOf: uint16(0))
            centralDirectory.append(contentsOf: uint16(0))
            centralDirectory.append(contentsOf: uint16(0))
            centralDirectory.append(contentsOf: uint32(crc))
            centralDirectory.append(contentsOf: uint32(UInt32(content.count)))
            centralDirectory.append(contentsOf: uint32(UInt32(content.count)))
            centralDirectory.append(contentsOf: uint16(UInt16(nameData.count)))
            centralDirectory.append(contentsOf: uint16(0))
            centralDirectory.append(contentsOf: uint16(0))
            centralDirectory.append(contentsOf: uint16(0))
            centralDirectory.append(contentsOf: uint16(0))
            centralDirectory.append(contentsOf: uint32(0))
            centralDirectory.append(contentsOf: uint32(offset))
            centralDirectory.append(nameData)
            offset = UInt32(output.count)
        }
        let directoryOffset = UInt32(output.count)
        output.append(centralDirectory)
        output.append(contentsOf: uint32(0x06054b50))
        output.append(contentsOf: uint16(0))
        output.append(contentsOf: uint16(0))
        output.append(contentsOf: uint16(UInt16(entries.count)))
        output.append(contentsOf: uint16(UInt16(entries.count)))
        output.append(contentsOf: uint32(UInt32(centralDirectory.count)))
        output.append(contentsOf: uint32(directoryOffset))
        output.append(contentsOf: uint16(0))
        return output
    }

    private func uint16(_ value: UInt16) -> Data {
        Data([UInt8(value & 0xff), UInt8(value >> 8)])
    }

    private func uint32(_ value: UInt32) -> Data {
        Data([UInt8(value & 0xff), UInt8((value >> 8) & 0xff), UInt8((value >> 16) & 0xff), UInt8(value >> 24)])
    }
}

private enum CRC32 {
    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                crc = (crc & 1) == 1 ? (crc >> 1) ^ 0xedb88320 : crc >> 1
            }
        }
        return crc ^ 0xffffffff
    }
}
