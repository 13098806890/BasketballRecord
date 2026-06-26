import Foundation

@MainActor
extension AppStore {

    func saveGame(_ snapshot: GameSnapshot) {
        let game = buildSavedGame(id: UUID(), snapshot: snapshot, savedAt: Date())
        savedGames.insert(game, at: 0)
    }

    @discardableResult
    func autoSaveGame(_ snapshot: GameSnapshot, gameID: UUID?, undoSnapshots: [GameSnapshot] = []) -> UUID {
        let targetID = gameID ?? UUID()
        let ts = snapshot.teamStatsByID
        if !ts.isEmpty || snapshot.homeTeamStatsMode || snapshot.awayTeamStatsMode {
            print("[AutoSave] snapshot teamStats=\(ts.count) pts=\(ts.values.reduce(0){$0+$1.points}) homeMode=\(snapshot.homeTeamStatsMode) awayMode=\(snapshot.awayTeamStatsMode)")
        }
        var game = buildSavedGame(id: targetID, snapshot: snapshot, savedAt: Date())
        let savedTS = game.snapshot.teamStatsByID
        let savedPts = savedTS.values.reduce(0) { $0 + $1.points }
        if savedPts > 0 || game.snapshot.homeTeamStatsMode || game.snapshot.awayTeamStatsMode {
            print("[AutoSave] builtSavedGame teamStats=\(savedTS.count) pts=\(savedPts) homeMode=\(game.snapshot.homeTeamStatsMode) awayMode=\(game.snapshot.awayTeamStatsMode)")
        }
        if let existingGame = savedGames.first(where: { $0.id == targetID }) {
            game.aiSummary = existingGame.aiSummary
        }

        if let existingIndex = savedGames.firstIndex(where: { $0.id == targetID }) {
            savedGames[existingIndex] = game
            if existingIndex != 0 {
                let updated = savedGames.remove(at: existingIndex)
                savedGames.insert(updated, at: 0)
            }
        } else {
            savedGames.insert(game, at: 0)
        }

        return targetID
    }

    func latestUnfinishedGame() -> SavedGame? {
        guard let latest = savedGames.first else { return nil }
        return latest.snapshot.isComplete ? nil : latest
    }

    func exportGameBase64(_ game: SavedGame) -> String? {
        let playerIDs = Array(Set(game.homePlayerIDs + game.awayPlayerIDs + Array(game.snapshot.statsByPlayerID.keys)))
        let exportedPlayers = playerIDs.map { playerID in
            if let player = player(for: playerID) {
                return ExportPlayer(player: player)
            }
            return ExportPlayer(id: playerID, name: game.playerNamesByID[playerID] ?? NSLocalizedString("player_unknown_default", comment: "Unknown player"))
        }

        let exportedTeams = [
            exportTeam(id: game.snapshot.homeTeamID, fallbackName: game.homeTeamName, playerIDs: game.homePlayerIDs),
            exportTeam(id: game.snapshot.awayTeamID, fallbackName: game.awayTeamName, playerIDs: game.awayPlayerIDs)
        ].compactMap { $0 }

        let legacyPackage = ExportedGamePackage(players: exportedPlayers, teams: exportedTeams, game: ExportGameRecord(savedGame: game))
        return TransferCodec.encode(ExportedGamePackageV2(legacy: legacyPackage))
    }

    func decodeGamePackage(from base64: String) -> ExportedGamePackage? {
        guard let decoded = TransferCodec.decode(base64, as: ExportedGamePackageV2.self) else {
            return nil
        }
        return decoded.legacyPackage
    }

    @discardableResult
    func importGamePackage(
        _ package: ExportedGamePackage,
        playerMapping: [UUID: UUID] = [:],
        teamMapping: [UUID: UUID] = [:],
        importsUnmatchedRoster: Bool = true
    ) -> GameImportDisposition {
        var playerIDMap = playerMapping
        var teamIDMap = teamMapping

        if importsUnmatchedRoster {
            for exportedPlayer in package.players where playerIDMap[exportedPlayer.id] == nil {
                if players.contains(where: { $0.id == exportedPlayer.id }) {
                    playerIDMap[exportedPlayer.id] = exportedPlayer.id
                } else {
                    let newPlayer = exportedPlayer.playerWithoutPhoto
                    players.append(newPlayer)
                    playerIDMap[exportedPlayer.id] = newPlayer.id
                }
            }
        }

        if importsUnmatchedRoster {
            for exportedTeam in package.teams where teamIDMap[exportedTeam.id] == nil {
                if teams.contains(where: { $0.id == exportedTeam.id }) {
                    teamIDMap[exportedTeam.id] = exportedTeam.id
                } else {
                    let mappedPlayerIDs = exportedTeam.playerIDs.compactMap { playerIDMap[$0] ?? $0 }
                    let newTeam = Team(id: exportedTeam.id, name: exportedTeam.name, playerIDs: mappedPlayerIDs)
                    teams.append(newTeam)
                    teamIDMap[exportedTeam.id] = newTeam.id
                }
            }
        }

        let importedGame = remappedGame(package.game.savedGame, playerIDMap: playerIDMap, teamIDMap: teamIDMap)
        return upsertImportedGame(importedGame)
    }

    func previewGameImportDisposition(
        _ package: ExportedGamePackage,
        playerMapping: [UUID: UUID] = [:],
        teamMapping: [UUID: UUID] = [:],
        importsUnmatchedRoster: Bool = true
    ) -> GameImportDisposition {
        let playerIDMap = inferredPlayerIDMap(for: package, providedMapping: playerMapping, importsUnmatchedRoster: importsUnmatchedRoster)
        let teamIDMap = inferredTeamIDMap(for: package, providedMapping: teamMapping, importsUnmatchedRoster: importsUnmatchedRoster)
        let importedGame = remappedGame(package.game.savedGame, playerIDMap: playerIDMap, teamIDMap: teamIDMap)
        return gameImportDisposition(for: importedGame)
    }

    func deleteSavedGames(at offsets: IndexSet) {
        savedGames.remove(atOffsets: offsets)
    }

    func deleteSavedGames(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        for id in ids {
            if cloudEnabledGameIDs.contains(id) {
                deletedCloudGameIDs.insert(id)
            }
        }
        saveDeletedCloudGameIDs()
        savedGames.removeAll { ids.contains($0.id) }
    }

    @discardableResult
    func upsertSavedGames(_ incomingGames: [SavedGame]) -> SavedGameUpsertSummary {
        guard !incomingGames.isEmpty else {
            return SavedGameUpsertSummary(inserted: 0, updated: 0)
        }

        var nextGames = savedGames
        var inserted = 0
        var updated = 0

        for incoming in incomingGames {
            if let existingIndex = nextGames.firstIndex(where: { $0.id == incoming.id }) {
                var updatedGame = incoming
                updatedGame.groupIDs = nextGames[existingIndex].groupIDs
                nextGames[existingIndex] = updatedGame
                updated += 1
            } else {
                var newGame = incoming
                newGame.groupIDs = []
                nextGames.append(newGame)
                inserted += 1
            }
        }

        nextGames.sort { $0.savedAt > $1.savedAt }
        savedGames = nextGames
        return SavedGameUpsertSummary(inserted: inserted, updated: updated)
    }

    // MARK: - Private helpers

    private func buildSavedGame(id: UUID, snapshot: GameSnapshot, savedAt: Date) -> SavedGame {
        let homeTeam = team(for: snapshot.homeTeamID)
        let awayTeam = team(for: snapshot.awayTeamID)
        let homeRosterIDs = dedupedPlayerIDs(primary: snapshot.homeAvailablePlayerIDs, fallback: homeTeam?.playerIDs ?? snapshot.homeOnCourtPlayerIDs)
        let awayRosterIDs = dedupedPlayerIDs(primary: snapshot.awayAvailablePlayerIDs, fallback: awayTeam?.playerIDs ?? snapshot.awayOnCourtPlayerIDs)
        let homePlayerIDs = homeRosterIDs
        let awayPlayerIDs = awayRosterIDs

        let gamePlayerIDs = Array(Set(
            homePlayerIDs
                + awayPlayerIDs
                + snapshot.starterPlayerIDs
                + Array(snapshot.statsByPlayerID.keys)
                + Array(snapshot.playingSecondsByPlayerID.keys)
                + Array(snapshot.plusMinusByPlayerID.keys)
        ))
        var playerNames: [UUID: String] = [:]
        for playerID in gamePlayerIDs {
            if let p = player(for: playerID), playerNames[playerID] == nil {
                playerNames[playerID] = p.name
            }
        }

        return SavedGame(
            id: id,
            savedAt: savedAt,
            snapshot: snapshot,
            homeTeamName: homeTeam?.name ?? NSLocalizedString("team_home_default", comment: "Home team"),
            awayTeamName: awayTeam?.name ?? NSLocalizedString("team_away_default", comment: "Away team"),
            homePlayerIDs: homePlayerIDs,
            awayPlayerIDs: awayPlayerIDs,
            playerNamesByID: playerNames
        )
    }

    private func dedupedPlayerIDs(primary: [UUID], fallback: [UUID]) -> [UUID] {
        let source = primary.isEmpty ? fallback : primary
        var seen: Set<UUID> = []
        return source.filter { seen.insert($0).inserted }
    }

    private func remappedGame(_ game: SavedGame, playerIDMap: [UUID: UUID], teamIDMap: [UUID: UUID]) -> SavedGame {
        let snapshot = remappedSnapshot(game.snapshot, playerIDMap: playerIDMap, teamIDMap: teamIDMap)
        let homePlayerIDs = dedupedIDs(game.homePlayerIDs.map { playerIDMap[$0] ?? $0 })
        let awayPlayerIDs = dedupedIDs(game.awayPlayerIDs.map { playerIDMap[$0] ?? $0 })
        var playerNames: [UUID: String] = [:]
        for (oldID, name) in game.playerNamesByID {
            playerNames[playerIDMap[oldID] ?? oldID] = name
        }

        return SavedGame(
            id: game.id,
            savedAt: game.savedAt,
            snapshot: snapshot,
            aiSummary: game.aiSummary,
            previousSnapshot: game.previousSnapshot.map { remappedSnapshot($0, playerIDMap: playerIDMap, teamIDMap: teamIDMap) },
            undoSnapshots: game.undoSnapshots.map { remappedSnapshot($0, playerIDMap: playerIDMap, teamIDMap: teamIDMap) },
            homeTeamName: team(for: snapshot.homeTeamID)?.name ?? game.homeTeamName,
            awayTeamName: team(for: snapshot.awayTeamID)?.name ?? game.awayTeamName,
            homePlayerIDs: homePlayerIDs,
            awayPlayerIDs: awayPlayerIDs,
            playerNamesByID: playerNames,
            groupIDs: []
        )
    }

    private func remappedSnapshot(_ snapshot: GameSnapshot, playerIDMap: [UUID: UUID], teamIDMap: [UUID: UUID]) -> GameSnapshot {
        var remapped = snapshot
        remapped.homeTeamID = snapshot.homeTeamID.flatMap { teamIDMap[$0] ?? $0 }
        remapped.awayTeamID = snapshot.awayTeamID.flatMap { teamIDMap[$0] ?? $0 }
        remapped.logs = snapshot.logs.map { entry in
            var mapped = entry
            if let playerID = entry.playerID {
                mapped.playerID = playerIDMap[playerID] ?? playerID
            }
            return mapped
        }
        remapped.statsByPlayerID = remapStatsDictionary(snapshot.statsByPlayerID, using: playerIDMap)
        remapped.homeOnCourtPlayerIDs = dedupedIDs(snapshot.homeOnCourtPlayerIDs.map { playerIDMap[$0] ?? $0 })
        remapped.awayOnCourtPlayerIDs = dedupedIDs(snapshot.awayOnCourtPlayerIDs.map { playerIDMap[$0] ?? $0 })
        remapped.homeAvailablePlayerIDs = dedupedIDs(snapshot.homeAvailablePlayerIDs.map { playerIDMap[$0] ?? $0 })
        remapped.awayAvailablePlayerIDs = dedupedIDs(snapshot.awayAvailablePlayerIDs.map { playerIDMap[$0] ?? $0 })
        remapped.starterPlayerIDs = dedupedIDs(snapshot.starterPlayerIDs.map { playerIDMap[$0] ?? $0 })
        remapped.playingSecondsByPlayerID = remapDictionary(snapshot.playingSecondsByPlayerID, using: playerIDMap, combine: +)
        remapped.activeSinceByPlayerID = remapDateDictionary(snapshot.activeSinceByPlayerID, using: playerIDMap)
        remapped.plusMinusByPlayerID = remapDictionary(snapshot.plusMinusByPlayerID, using: playerIDMap, combine: +)
        remapped.teamStatsByID = remapStatsDictionary(snapshot.teamStatsByID, using: teamIDMap)
        return remapped
    }

    private func remapDictionary<Value>(_ dictionary: [UUID: Value], using map: [UUID: UUID], combine: ((Value, Value) -> Value)? = nil) -> [UUID: Value] {
        var result: [UUID: Value] = [:]
        for (oldID, value) in dictionary {
            let newID = map[oldID] ?? oldID
            if let existing = result[newID], let combine {
                result[newID] = combine(existing, value)
            } else {
                result[newID] = value
            }
        }
        return result
    }

    private func remapStatsDictionary(_ dictionary: [UUID: PlayerStats], using map: [UUID: UUID]) -> [UUID: PlayerStats] {
        var result: [UUID: PlayerStats] = [:]
        for (oldID, value) in dictionary {
            let newID = map[oldID] ?? oldID
            if let existing = result[newID] {
                result[newID] = mergedStats(lhs: existing, rhs: value)
            } else {
                result[newID] = value
            }
        }
        return result
    }

    private func remapDateDictionary(_ dictionary: [UUID: Date], using map: [UUID: UUID]) -> [UUID: Date] {
        var result: [UUID: Date] = [:]
        for (oldID, value) in dictionary {
            let newID = map[oldID] ?? oldID
            if let existing = result[newID] {
                result[newID] = min(existing, value)
            } else {
                result[newID] = value
            }
        }
        return result
    }

    private func upsertImportedGame(_ importedGame: SavedGame) -> GameImportDisposition {
        if let existingIndex = savedGames.firstIndex(where: { $0.id == importedGame.id }) {
            let existingID = savedGames[existingIndex].id
            savedGames[existingIndex] = importedGame
            if existingIndex != 0 {
                let updated = savedGames.remove(at: existingIndex)
                savedGames.insert(updated, at: 0)
            }
            return .replacedSameID(existingGameID: existingID)
        }

        if let duplicateIndex = savedGames.firstIndex(where: { isLikelyDuplicateGame($0, importedGame) }) {
            let existingID = savedGames[duplicateIndex].id
            var replacement = importedGame
            replacement.id = existingID
            savedGames[duplicateIndex] = replacement
            if duplicateIndex != 0 {
                let updated = savedGames.remove(at: duplicateIndex)
                savedGames.insert(updated, at: 0)
            }
            return .replacedLikelyDuplicate(existingGameID: existingID)
        }

        savedGames.insert(importedGame, at: 0)
        return .inserted
    }

    private func gameImportDisposition(for importedGame: SavedGame) -> GameImportDisposition {
        if let existing = savedGames.first(where: { $0.id == importedGame.id }) {
            return .replacedSameID(existingGameID: existing.id)
        }

        if let duplicate = savedGames.first(where: { isLikelyDuplicateGame($0, importedGame) }) {
            return .replacedLikelyDuplicate(existingGameID: duplicate.id)
        }

        return .inserted
    }

    private func inferredPlayerIDMap(
        for package: ExportedGamePackage,
        providedMapping: [UUID: UUID],
        importsUnmatchedRoster: Bool
    ) -> [UUID: UUID] {
        guard importsUnmatchedRoster else { return providedMapping }

        var mapping = providedMapping
        for exportedPlayer in package.players where mapping[exportedPlayer.id] == nil {
            mapping[exportedPlayer.id] = exportedPlayer.id
        }
        return mapping
    }

    private func inferredTeamIDMap(
        for package: ExportedGamePackage,
        providedMapping: [UUID: UUID],
        importsUnmatchedRoster: Bool
    ) -> [UUID: UUID] {
        guard importsUnmatchedRoster else { return providedMapping }

        var mapping = providedMapping
        for exportedTeam in package.teams where mapping[exportedTeam.id] == nil {
            mapping[exportedTeam.id] = exportedTeam.id
        }
        return mapping
    }

    private func isLikelyDuplicateGame(_ lhs: SavedGame, _ rhs: SavedGame) -> Bool {
        lhs.savedAt == rhs.savedAt
            && lhs.homeTeamName == rhs.homeTeamName
            && lhs.awayTeamName == rhs.awayTeamName
            && lhs.snapshot == rhs.snapshot
    }

    private func dedupedIDs(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }
}
