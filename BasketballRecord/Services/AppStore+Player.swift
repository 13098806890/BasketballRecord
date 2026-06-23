import Foundation

@MainActor
extension AppStore {

    func player(for id: UUID) -> Player? {
        players.first { $0.id == id }
    }

    func addPlayer(_ player: Player) {
        players.append(player)
    }

    func updatePlayer(_ player: Player) {
        guard let index = players.firstIndex(where: { $0.id == player.id }) else { return }
        players[index] = player
    }

    func deletePlayers(at offsets: IndexSet) {
        let removedIDs = offsets.map { players[$0].id }
        for id in removedIDs {
            try? FileManager.default.removeItem(at: photoFile(for: id))
        }
        players.remove(atOffsets: offsets)
        teams = teams.map { team in
            var copy = team
            copy.playerIDs.removeAll { removedIDs.contains($0) }
            return copy
        }
    }

    @discardableResult
    func upsertPlayers(_ incomingPlayers: [Player]) -> PlayerUpsertSummary {
        guard !incomingPlayers.isEmpty else {
            return PlayerUpsertSummary(inserted: 0, updated: 0)
        }

        var nextPlayers = players
        var inserted = 0
        var updated = 0

        for incoming in incomingPlayers {
            if let existingIndex = nextPlayers.firstIndex(where: { $0.id == incoming.id }) {
                var merged = incoming
                if merged.photoData == nil {
                    merged.photoData = nextPlayers[existingIndex].photoData
                }
                nextPlayers[existingIndex] = merged
                updated += 1
            } else {
                nextPlayers.append(incoming)
                inserted += 1
            }
        }

        players = nextPlayers
        return PlayerUpsertSummary(inserted: inserted, updated: updated)
    }

    func exportPlayerBase64(_ player: Player) -> String? {
        let package = ExportedPlayerPackage(player: ExportPlayer(player: player))
        return TransferCodec.encode(package)
    }

    @discardableResult
    func importPlayerPackage(_ package: ExportedPlayerPackage) -> PlayerImportSummary {
        let importedPlayer = package.player.playerWithoutPhoto
        var addedPlayers = 0
        var updatedPlayers = 0

        if let existingIndex = players.firstIndex(where: { $0.id == importedPlayer.id }) {
            players[existingIndex] = importedPlayer
            updatedPlayers = 1
        } else {
            players.append(importedPlayer)
            addedPlayers = 1
        }

        return PlayerImportSummary(addedPlayers: addedPlayers, updatedPlayers: updatedPlayers)
    }

    func mergePlayer(sourceID: UUID, into targetID: UUID) -> PlayerMergeSummary? {
        guard sourceID != targetID else { return nil }
        guard let sourceIndex = players.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = players.firstIndex(where: { $0.id == targetID }) else {
            return nil
        }

        let sourcePlayer = players[sourceIndex]
        var targetPlayer = players[targetIndex]
        if targetPlayer.height.isEmpty { targetPlayer.height = sourcePlayer.height }
        if targetPlayer.weight.isEmpty { targetPlayer.weight = sourcePlayer.weight }
        if targetPlayer.number.isEmpty { targetPlayer.number = sourcePlayer.number }
        if targetPlayer.photoData == nil { targetPlayer.photoData = sourcePlayer.photoData }

        var nextPlayers = players
        nextPlayers[targetIndex] = targetPlayer
        nextPlayers.removeAll { $0.id == sourceID }
        players = nextPlayers

        var updatedTeams = 0
        teams = teams.map { team in
            guard team.playerIDs.contains(sourceID) else { return team }
            var seen: Set<UUID> = []
            let remapped = team.playerIDs.map { $0 == sourceID ? targetID : $0 }
            let deduped = remapped.filter { seen.insert($0).inserted }
            updatedTeams += 1
            return Team(id: team.id, name: team.name, playerIDs: deduped)
        }

        var updatedGames = 0
        savedGames = savedGames.map { game in
            guard gameContainsPlayer(game, sourceID: sourceID) else { return game }
            updatedGames += 1
            return remappedGameForPlayerMerge(game, sourceID: sourceID, targetID: targetID, targetName: targetPlayer.name)
        }

        return PlayerMergeSummary(updatedTeams: updatedTeams, updatedGames: updatedGames)
    }

    // MARK: - Private helpers

    private func gameContainsPlayer(_ game: SavedGame, sourceID: UUID) -> Bool {
        game.homePlayerIDs.contains(sourceID)
            || game.awayPlayerIDs.contains(sourceID)
            || game.snapshot.statsByPlayerID[sourceID] != nil
            || game.snapshot.playingSecondsByPlayerID[sourceID] != nil
            || game.snapshot.activeSinceByPlayerID[sourceID] != nil
            || game.snapshot.plusMinusByPlayerID[sourceID] != nil
            || game.snapshot.homeAvailablePlayerIDs.contains(sourceID)
            || game.snapshot.awayAvailablePlayerIDs.contains(sourceID)
            || game.snapshot.starterPlayerIDs.contains(sourceID)
            || game.snapshot.homeOnCourtPlayerIDs.contains(sourceID)
            || game.snapshot.awayOnCourtPlayerIDs.contains(sourceID)
            || game.snapshot.logs.contains(where: { $0.playerID == sourceID })
            || game.playerNamesByID[sourceID] != nil
    }

    private func remappedGameForPlayerMerge(
        _ game: SavedGame,
        sourceID: UUID,
        targetID: UUID,
        targetName: String
    ) -> SavedGame {
        let snapshot = remappedSnapshotForPlayerMerge(game.snapshot, sourceID: sourceID, targetID: targetID)

        var names = game.playerNamesByID
        names[targetID] = targetName
        names[sourceID] = nil

        return SavedGame(
            id: game.id,
            savedAt: game.savedAt,
            snapshot: snapshot,
            aiSummary: game.aiSummary,
            previousSnapshot: game.previousSnapshot.map { remappedSnapshotForPlayerMerge($0, sourceID: sourceID, targetID: targetID) },
            undoSnapshots: game.undoSnapshots.map { remappedSnapshotForPlayerMerge($0, sourceID: sourceID, targetID: targetID) },
            homeTeamName: game.homeTeamName,
            awayTeamName: game.awayTeamName,
            homePlayerIDs: remapDedupedIDs(game.homePlayerIDs, sourceID: sourceID, targetID: targetID),
            awayPlayerIDs: remapDedupedIDs(game.awayPlayerIDs, sourceID: sourceID, targetID: targetID),
            playerNamesByID: names,
            groupIDs: game.groupIDs
        )
    }

    private func remappedSnapshotForPlayerMerge(_ snapshot: GameSnapshot, sourceID: UUID, targetID: UUID) -> GameSnapshot {
        var remapped = snapshot
        remapped.logs = snapshot.logs.map { entry in
            var mapped = entry
            if mapped.playerID == sourceID {
                mapped.playerID = targetID
            }
            return mapped
        }
        remapped.statsByPlayerID = mergeStatsDictionary(snapshot.statsByPlayerID, sourceID: sourceID, targetID: targetID)
        remapped.playingSecondsByPlayerID = mergeSumDictionary(snapshot.playingSecondsByPlayerID, sourceID: sourceID, targetID: targetID)
        remapped.plusMinusByPlayerID = mergeSumDictionary(snapshot.plusMinusByPlayerID, sourceID: sourceID, targetID: targetID)
        remapped.activeSinceByPlayerID = mergeDateDictionary(snapshot.activeSinceByPlayerID, sourceID: sourceID, targetID: targetID)
        remapped.homeAvailablePlayerIDs = remapDedupedIDs(snapshot.homeAvailablePlayerIDs, sourceID: sourceID, targetID: targetID)
        remapped.awayAvailablePlayerIDs = remapDedupedIDs(snapshot.awayAvailablePlayerIDs, sourceID: sourceID, targetID: targetID)
        remapped.starterPlayerIDs = remapDedupedIDs(snapshot.starterPlayerIDs, sourceID: sourceID, targetID: targetID)
        remapped.homeOnCourtPlayerIDs = remapDedupedIDs(snapshot.homeOnCourtPlayerIDs, sourceID: sourceID, targetID: targetID)
        remapped.awayOnCourtPlayerIDs = remapDedupedIDs(snapshot.awayOnCourtPlayerIDs, sourceID: sourceID, targetID: targetID)
        return remapped
    }

    private func mergeStatsDictionary(
        _ dictionary: [UUID: PlayerStats],
        sourceID: UUID,
        targetID: UUID
    ) -> [UUID: PlayerStats] {
        var result = dictionary
        guard let source = result[sourceID] else { return result }
        let target = result[targetID] ?? PlayerStats()
        result[targetID] = mergedStats(lhs: target, rhs: source)
        result[sourceID] = nil
        return result
    }

    private func mergeSumDictionary<T: AdditiveArithmetic>(
        _ dictionary: [UUID: T],
        sourceID: UUID,
        targetID: UUID
    ) -> [UUID: T] {
        var result = dictionary
        guard let source = result[sourceID] else { return result }
        result[targetID] = (result[targetID] ?? .zero) + source
        result[sourceID] = nil
        return result
    }

    private func mergeDateDictionary(
        _ dictionary: [UUID: Date],
        sourceID: UUID,
        targetID: UUID
    ) -> [UUID: Date] {
        var result = dictionary
        guard let source = result[sourceID] else { return result }
        if let target = result[targetID] {
            result[targetID] = min(target, source)
        } else {
            result[targetID] = source
        }
        result[sourceID] = nil
        return result
    }

    private func remapDedupedIDs(_ ids: [UUID], sourceID: UUID, targetID: UUID) -> [UUID] {
        var seen: Set<UUID> = []
        return ids
            .map { $0 == sourceID ? targetID : $0 }
            .filter { seen.insert($0).inserted }
    }

    func mergedStats(lhs: PlayerStats, rhs: PlayerStats) -> PlayerStats {
        var total = lhs
        total.twoMade += rhs.twoMade
        total.twoAttempts += rhs.twoAttempts
        total.threeMade += rhs.threeMade
        total.threeAttempts += rhs.threeAttempts
        total.bonusFreeThrowMade += rhs.bonusFreeThrowMade
        total.bonusFreeThrowAttempts += rhs.bonusFreeThrowAttempts
        total.freeThrowMade += rhs.freeThrowMade
        total.freeThrowAttempts += rhs.freeThrowAttempts
        total.rebounds += rhs.rebounds
        total.offensiveRebounds += rhs.offensiveRebounds
        total.defensiveRebounds += rhs.defensiveRebounds
        total.assists += rhs.assists
        total.fouls += rhs.fouls
        total.blocks += rhs.blocks
        total.steals += rhs.steals
        total.turnovers += rhs.turnovers
        total.layupMade += rhs.layupMade
        total.layupAttempts += rhs.layupAttempts
        total.midRangeMade += rhs.midRangeMade
        total.midRangeAttempts += rhs.midRangeAttempts
        total.paintMade += rhs.paintMade
        total.paintAttempts += rhs.paintAttempts
        return total
    }
}
