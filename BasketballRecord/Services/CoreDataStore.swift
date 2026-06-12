import CoreData
import UIKit

@MainActor
struct CoreDataStore {
    let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    var context: NSManagedObjectContext { stack.context }

    // MARK: - Player

    func fetchAllPlayers() -> [Player] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDPlayer")
        guard let results = try? context.fetch(request) else { return [] }
        return results.compactMap { obj -> Player? in
            guard let id = obj.value(forKey: "id") as? UUID,
                  let name = obj.value(forKey: "name") as? String else { return nil }
            return Player(
                id: id,
                name: name,
                height: obj.value(forKey: "height") as? String ?? "",
                weight: obj.value(forKey: "weight") as? String ?? "",
                number: obj.value(forKey: "number") as? String ?? "",
                photoData: nil
            )
        }
    }

    func savePlayers(_ players: [Player]) {
        deleteAll("CDPlayer")
        for player in players {
            let obj = NSEntityDescription.insertNewObject(forEntityName: "CDPlayer", into: context)
            obj.setValue(player.id, forKey: "id")
            obj.setValue(player.name, forKey: "name")
            obj.setValue(player.height, forKey: "height")
            obj.setValue(player.weight, forKey: "weight")
            obj.setValue(player.number, forKey: "number")
        }
        stack.save()
    }

    // MARK: - Team

    func fetchAllTeams() -> [Team] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDTeam")
        guard let results = try? context.fetch(request) else { return [] }
        return results.compactMap { obj -> Team? in
            guard let id = obj.value(forKey: "id") as? UUID,
                  let name = obj.value(forKey: "name") as? String else { return nil }
            let idsData = obj.value(forKey: "playerIDsData") as? Data
            let playerIDs = idsData.flatMap { try? JSONDecoder().decode([UUID].self, from: $0) } ?? []
            return Team(id: id, name: name, playerIDs: playerIDs)
        }
    }

    func saveTeams(_ teams: [Team]) {
        deleteAll("CDTeam")
        for team in teams {
            let obj = NSEntityDescription.insertNewObject(forEntityName: "CDTeam", into: context)
            obj.setValue(team.id, forKey: "id")
            obj.setValue(team.name, forKey: "name")
            obj.setValue(try? JSONEncoder().encode(team.playerIDs), forKey: "playerIDsData")
        }
        stack.save()
    }

    // MARK: - GameGroup

    func fetchAllGameGroups() -> [GameGroup] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDGameGroup")
        guard let results = try? context.fetch(request) else { return [] }
        return results.compactMap { obj -> GameGroup? in
            guard let id = obj.value(forKey: "id") as? UUID,
                  let name = obj.value(forKey: "name") as? String,
                  let createdAt = obj.value(forKey: "createdAt") as? Date else { return nil }
            return GameGroup(
                id: id,
                name: name,
                description: obj.value(forKey: "desc") as? String,
                createdAt: createdAt,
                color: obj.value(forKey: "colorValue") as? String
            )
        }
    }

    func saveGameGroups(_ groups: [GameGroup]) {
        deleteAll("CDGameGroup")
        for group in groups {
            let obj = NSEntityDescription.insertNewObject(forEntityName: "CDGameGroup", into: context)
            obj.setValue(group.id, forKey: "id")
            obj.setValue(group.name, forKey: "name")
            obj.setValue(group.description, forKey: "desc")
            obj.setValue(group.color, forKey: "colorValue")
            obj.setValue(group.createdAt, forKey: "createdAt")
        }
        stack.save()
    }

    // MARK: - SavedGame

    func fetchAllSavedGames() -> [SavedGame] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSavedGame")
        request.sortDescriptors = [NSSortDescriptor(key: "savedAt", ascending: false)]
        guard let results = try? context.fetch(request) else { return [] }
        return results.compactMap { obj -> SavedGame? in
            guard let id = obj.value(forKey: "id") as? UUID,
                  let savedAt = obj.value(forKey: "savedAt") as? Date else { return nil }
            let snapshotData = obj.value(forKey: "snapshotData") as? Data
            let snapshot = snapshotData.flatMap { try? JSONDecoder().decode(GameSnapshot.self, from: $0) } ?? GameSnapshot()
            let homePlayerIDsData = obj.value(forKey: "homePlayerIDsData") as? Data
            let awayPlayerIDsData = obj.value(forKey: "awayPlayerIDsData") as? Data
            let playerNamesData = obj.value(forKey: "playerNamesData") as? Data
            let groupIDsData = obj.value(forKey: "groupIDsData") as? Data
            let undoData = obj.value(forKey: "undoSnapshotsData") as? Data
            return SavedGame(
                id: id,
                savedAt: savedAt,
                snapshot: snapshot,
                aiSummary: obj.value(forKey: "aiSummary") as? String,
                undoSnapshots: undoData.flatMap { try? JSONDecoder().decode([GameSnapshot].self, from: $0) } ?? [],
                homeTeamName: obj.value(forKey: "homeTeamName") as? String ?? "",
                awayTeamName: obj.value(forKey: "awayTeamName") as? String ?? "",
                homePlayerIDs: homePlayerIDsData.flatMap { try? JSONDecoder().decode([UUID].self, from: $0) } ?? [],
                awayPlayerIDs: awayPlayerIDsData.flatMap { try? JSONDecoder().decode([UUID].self, from: $0) } ?? [],
                playerNamesByID: playerNamesData.flatMap { try? JSONDecoder().decode([UUID: String].self, from: $0) } ?? [:],
                groupIDs: groupIDsData.flatMap { try? JSONDecoder().decode([UUID].self, from: $0) } ?? [],
                displayName: obj.value(forKey: "displayName") as? String ?? ""
            )
        }
    }

    func upsertSavedGame(_ game: SavedGame) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSavedGame")
        request.predicate = NSPredicate(format: "id == %@", game.id as CVarArg)
        request.fetchLimit = 1
        let existing = try? context.fetch(request).first
        let obj = existing ?? NSEntityDescription.insertNewObject(forEntityName: "CDSavedGame", into: context)
        obj.setValue(game.id, forKey: "id")
        obj.setValue(game.savedAt, forKey: "savedAt")
        obj.setValue(try? JSONEncoder().encode(game.snapshot), forKey: "snapshotData")
        obj.setValue(game.homeTeamName, forKey: "homeTeamName")
        obj.setValue(game.awayTeamName, forKey: "awayTeamName")
        obj.setValue(try? JSONEncoder().encode(game.homePlayerIDs), forKey: "homePlayerIDsData")
        obj.setValue(try? JSONEncoder().encode(game.awayPlayerIDs), forKey: "awayPlayerIDsData")
        obj.setValue(try? JSONEncoder().encode(game.playerNamesByID), forKey: "playerNamesData")
        obj.setValue(try? JSONEncoder().encode(game.groupIDs), forKey: "groupIDsData")
        obj.setValue(game.isLocked, forKey: "isLocked")
        obj.setValue(game.displayName.isEmpty ? nil : game.displayName, forKey: "displayName")
        obj.setValue(game.aiSummary, forKey: "aiSummary")
        obj.setValue(try? JSONEncoder().encode(game.undoSnapshots), forKey: "undoSnapshotsData")
        stack.save()
    }

    func deleteSavedGame(id: UUID) {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSavedGame")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let obj = try? context.fetch(request).first {
            context.delete(obj)
            stack.save()
        }
    }

    // MARK: - Query

    func savedGames(containingPlayer playerID: UUID) -> [SavedGame] {
        let all = fetchAllSavedGames()
        return all.filter { game in
            game.homePlayerIDs.contains(playerID) || game.awayPlayerIDs.contains(playerID)
        }
    }

    // MARK: - Migration

    func hasData() -> Bool {
        let request = NSFetchRequest<NSManagedObject>(entityName: "CDSavedGame")
        return (try? context.count(for: request)) ?? 0 > 0
    }

    func deleteAllSavedGames() {
        deleteAll("CDSavedGame")
    }

    func clearAll() {
        deleteAll("CDPlayer")
        deleteAll("CDTeam")
        deleteAll("CDGameGroup")
        deleteAll("CDSavedGame")
    }

    // MARK: - Private

    private func deleteAll(_ entity: String) {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
        let batch = NSBatchDeleteRequest(fetchRequest: request)
        batch.resultType = .resultTypeObjectIDs
        guard let result = try? context.execute(batch) as? NSBatchDeleteResult,
              let ids = result.result as? [NSManagedObjectID] else { return }
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: ids], into: [context])
    }
}
