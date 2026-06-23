import Foundation

@MainActor
extension AppStore {

    func team(for id: UUID?) -> Team? {
        guard let id else { return nil }
        return teams.first { $0.id == id }
    }

    func addTeam(_ team: Team) {
        teams.append(team)
    }

    func updateTeam(_ team: Team) {
        guard let index = teams.firstIndex(where: { $0.id == team.id }) else { return }
        teams[index] = team
    }

    func deleteTeams(at offsets: IndexSet) {
        teams.remove(atOffsets: offsets)
    }

    @discardableResult
    func upsertTeams(_ incomingTeams: [Team]) -> TeamUpsertSummary {
        guard !incomingTeams.isEmpty else {
            return TeamUpsertSummary(inserted: 0, updated: 0)
        }

        var nextTeams = teams
        var inserted = 0
        var updated = 0

        for incoming in incomingTeams {
            if let existingIndex = nextTeams.firstIndex(where: { $0.id == incoming.id }) {
                nextTeams[existingIndex] = incoming
                updated += 1
            } else {
                nextTeams.append(incoming)
                inserted += 1
            }
        }

        teams = nextTeams
        return TeamUpsertSummary(inserted: inserted, updated: updated)
    }

    func exportTeamBase64(_ team: Team) -> String? {
        let exportedPlayers = team.playerIDs.map { playerID in
            if let player = player(for: playerID) {
                return ExportPlayer(player: player)
            }
            return ExportPlayer(id: playerID, name: NSLocalizedString("player_unknown_default", comment: "Unknown player"))
        }
        let package = ExportedTeamPackage(team: ExportTeam(team: team), players: exportedPlayers)
        return TransferCodec.encode(package)
    }

    @discardableResult
    func importTeamPackage(_ package: ExportedTeamPackage) -> TeamImportSummary {
        var addedPlayers = 0
        var reusedPlayers = 0
        var nextPlayers = players
        var existingPlayerIDs = Set(nextPlayers.map(\.id))

        for exportedPlayer in package.players {
            if existingPlayerIDs.contains(exportedPlayer.id) {
                reusedPlayers += 1
                continue
            }
            nextPlayers.append(exportedPlayer.playerWithoutPhoto)
            existingPlayerIDs.insert(exportedPlayer.id)
            addedPlayers += 1
        }

        for playerID in package.team.playerIDs where !existingPlayerIDs.contains(playerID) {
            nextPlayers.append(Player(id: playerID, name: NSLocalizedString("player_unknown_default", comment: "Unknown player")))
            existingPlayerIDs.insert(playerID)
            addedPlayers += 1
        }
        players = nextPlayers

        var seenPlayerIDs: Set<UUID> = []
        let orderedPlayerIDs = package.team.playerIDs.filter { seenPlayerIDs.insert($0).inserted }
        let importedTeam = Team(id: package.team.id, name: package.team.name, playerIDs: orderedPlayerIDs)

        var addedTeams = 0
        var updatedTeams = 0
        var nextTeams = teams
        if let existingIndex = nextTeams.firstIndex(where: { $0.id == importedTeam.id }) {
            nextTeams[existingIndex] = importedTeam
            updatedTeams = 1
        } else {
            nextTeams.append(importedTeam)
            addedTeams = 1
        }
        teams = nextTeams

        return TeamImportSummary(
            addedPlayers: addedPlayers,
            reusedPlayers: reusedPlayers,
            addedTeams: addedTeams,
            updatedTeams: updatedTeams
        )
    }

    @discardableResult
    func mergeTeam(sourceID: UUID, into targetID: UUID) -> TeamMergeSummary? {
        guard sourceID != targetID else { return nil }
        guard let sourceTeam = teams.first(where: { $0.id == sourceID }),
              var targetTeam = teams.first(where: { $0.id == targetID }) else {
            return nil
        }

        var seenPlayerIDs = Set(targetTeam.playerIDs)
        let addedPlayers = sourceTeam.playerIDs.filter { seenPlayerIDs.insert($0).inserted }
        targetTeam.playerIDs.append(contentsOf: addedPlayers)

        teams = teams.compactMap { team in
            if team.id == sourceID { return nil }
            if team.id == targetID {
                return Team(id: team.id, name: team.name, playerIDs: targetTeam.playerIDs)
            }
            return team
        }

        var updatedGames = 0
        savedGames = savedGames.map { game in
            guard gameContainsTeam(game, sourceID: sourceID) else { return game }
            updatedGames += 1
            return remappedGameForTeamMerge(game, sourceID: sourceID, targetID: targetID, targetName: targetTeam.name)
        }

        return TeamMergeSummary(mergedPlayers: addedPlayers.count, updatedGames: updatedGames)
    }

    func exportTeam(id: UUID?, fallbackName: String, playerIDs: [UUID]) -> ExportTeam? {
        guard let id else { return nil }
        if let team = team(for: id) {
            return ExportTeam(team: team)
        }
        return ExportTeam(id: id, name: fallbackName, playerIDs: playerIDs)
    }

    // MARK: - Private helpers

    private func gameContainsTeam(_ game: SavedGame, sourceID: UUID) -> Bool {
        game.snapshot.homeTeamID == sourceID || game.snapshot.awayTeamID == sourceID
    }

    private func remappedGameForTeamMerge(
        _ game: SavedGame,
        sourceID: UUID,
        targetID: UUID,
        targetName: String
    ) -> SavedGame {
        let snapshot = remappedSnapshotForTeamMerge(game.snapshot, sourceID: sourceID, targetID: targetID)
        let homeChanged = game.snapshot.homeTeamID == sourceID
        let awayChanged = game.snapshot.awayTeamID == sourceID

        return SavedGame(
            id: game.id,
            savedAt: game.savedAt,
            snapshot: snapshot,
            aiSummary: game.aiSummary,
            previousSnapshot: game.previousSnapshot.map { remappedSnapshotForTeamMerge($0, sourceID: sourceID, targetID: targetID) },
            undoSnapshots: game.undoSnapshots.map { remappedSnapshotForTeamMerge($0, sourceID: sourceID, targetID: targetID) },
            homeTeamName: homeChanged ? targetName : game.homeTeamName,
            awayTeamName: awayChanged ? targetName : game.awayTeamName,
            homePlayerIDs: game.homePlayerIDs,
            awayPlayerIDs: game.awayPlayerIDs,
            playerNamesByID: game.playerNamesByID,
            groupIDs: game.groupIDs
        )
    }

    private func remappedSnapshotForTeamMerge(_ snapshot: GameSnapshot, sourceID: UUID, targetID: UUID) -> GameSnapshot {
        var remapped = snapshot
        if remapped.homeTeamID == sourceID { remapped.homeTeamID = targetID }
        if remapped.awayTeamID == sourceID { remapped.awayTeamID = targetID }
        return remapped
    }
}
