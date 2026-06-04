import CoreData
import UIKit

struct CoreDataStack {
    static let shared = CoreDataStack()

    let container: NSPersistentContainer

    init() {
        container = NSPersistentContainer(name: "BasketballRecord", managedObjectModel: Self.model)
        container.loadPersistentStores { _, error in
            if let error {
                print("[CoreData] Load error: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    var context: NSManagedObjectContext {
        container.viewContext
    }

    func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("[CoreData] Save error: \(error)")
        }
    }

    private static let model: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let player = NSEntityDescription()
        player.name = "CDPlayer"
        player.managedObjectClassName = "NSManagedObject"

        let team = NSEntityDescription()
        team.name = "CDTeam"
        team.managedObjectClassName = "NSManagedObject"

        let gameGroup = NSEntityDescription()
        gameGroup.name = "CDGameGroup"
        gameGroup.managedObjectClassName = "NSManagedObject"

        let savedGame = NSEntityDescription()
        savedGame.name = "CDSavedGame"
        savedGame.managedObjectClassName = "NSManagedObject"

        // Player attributes
        let playerID = NSAttributeDescription()
        playerID.name = "id"
        playerID.attributeType = .UUIDAttributeType
        playerID.isOptional = false

        let playerName = NSAttributeDescription()
        playerName.name = "name"
        playerName.attributeType = .stringAttributeType
        playerName.isOptional = false

        let playerHeight = NSAttributeDescription()
        playerHeight.name = "height"
        playerHeight.attributeType = .stringAttributeType
        playerHeight.isOptional = true

        let playerWeight = NSAttributeDescription()
        playerWeight.name = "weight"
        playerWeight.attributeType = .stringAttributeType
        playerWeight.isOptional = true

        let playerNumber = NSAttributeDescription()
        playerNumber.name = "number"
        playerNumber.attributeType = .stringAttributeType
        playerNumber.isOptional = true

        let playerPhotoPath = NSAttributeDescription()
        playerPhotoPath.name = "photoPath"
        playerPhotoPath.attributeType = .stringAttributeType
        playerPhotoPath.isOptional = true

        player.properties = [playerID, playerName, playerHeight, playerWeight, playerNumber, playerPhotoPath]

        // Team attributes
        let teamID = NSAttributeDescription()
        teamID.name = "id"
        teamID.attributeType = .UUIDAttributeType
        teamID.isOptional = false

        let teamName = NSAttributeDescription()
        teamName.name = "name"
        teamName.attributeType = .stringAttributeType
        teamName.isOptional = false

        let teamPlayerIDs = NSAttributeDescription()
        teamPlayerIDs.name = "playerIDsData"
        teamPlayerIDs.attributeType = .binaryDataAttributeType
        teamPlayerIDs.isOptional = true

        team.properties = [teamID, teamName, teamPlayerIDs]

        // GameGroup attributes
        let groupID = NSAttributeDescription()
        groupID.name = "id"
        groupID.attributeType = .UUIDAttributeType
        groupID.isOptional = false

        let groupName = NSAttributeDescription()
        groupName.name = "name"
        groupName.attributeType = .stringAttributeType
        groupName.isOptional = false

        let groupDesc = NSAttributeDescription()
        groupDesc.name = "desc"
        groupDesc.attributeType = .stringAttributeType
        groupDesc.isOptional = true

        let groupColorValue = NSAttributeDescription()
        groupColorValue.name = "colorValue"
        groupColorValue.attributeType = .stringAttributeType
        groupColorValue.isOptional = true

        let groupCreatedAt = NSAttributeDescription()
        groupCreatedAt.name = "createdAt"
        groupCreatedAt.attributeType = .dateAttributeType
        groupCreatedAt.isOptional = false

        gameGroup.properties = [groupID, groupName, groupDesc, groupColorValue, groupCreatedAt]

        // SavedGame attributes
        let gameID = NSAttributeDescription()
        gameID.name = "id"
        gameID.attributeType = .UUIDAttributeType
        gameID.isOptional = false

        let gameSavedAt = NSAttributeDescription()
        gameSavedAt.name = "savedAt"
        gameSavedAt.attributeType = .dateAttributeType
        gameSavedAt.isOptional = false

        let gameSnapshotData = NSAttributeDescription()
        gameSnapshotData.name = "snapshotData"
        gameSnapshotData.attributeType = .binaryDataAttributeType
        gameSnapshotData.isOptional = true

        let gameHomeTeamName = NSAttributeDescription()
        gameHomeTeamName.name = "homeTeamName"
        gameHomeTeamName.attributeType = .stringAttributeType
        gameHomeTeamName.isOptional = false

        let gameAwayTeamName = NSAttributeDescription()
        gameAwayTeamName.name = "awayTeamName"
        gameAwayTeamName.attributeType = .stringAttributeType
        gameAwayTeamName.isOptional = false

        let gameHomePlayerIDs = NSAttributeDescription()
        gameHomePlayerIDs.name = "homePlayerIDsData"
        gameHomePlayerIDs.attributeType = .binaryDataAttributeType
        gameHomePlayerIDs.isOptional = true

        let gameAwayPlayerIDs = NSAttributeDescription()
        gameAwayPlayerIDs.name = "awayPlayerIDsData"
        gameAwayPlayerIDs.attributeType = .binaryDataAttributeType
        gameAwayPlayerIDs.isOptional = true

        let gamePlayerNamesData = NSAttributeDescription()
        gamePlayerNamesData.name = "playerNamesData"
        gamePlayerNamesData.attributeType = .binaryDataAttributeType
        gamePlayerNamesData.isOptional = true

        let gameGroupIDsData = NSAttributeDescription()
        gameGroupIDsData.name = "groupIDsData"
        gameGroupIDsData.attributeType = .binaryDataAttributeType
        gameGroupIDsData.isOptional = true

        let gameIsLocked = NSAttributeDescription()
        gameIsLocked.name = "isLocked"
        gameIsLocked.attributeType = .booleanAttributeType
        gameIsLocked.isOptional = false
        gameIsLocked.defaultValue = false

        let gameDisplayName = NSAttributeDescription()
        gameDisplayName.name = "displayName"
        gameDisplayName.attributeType = .stringAttributeType
        gameDisplayName.isOptional = true

        let gameAISummary = NSAttributeDescription()
        gameAISummary.name = "aiSummary"
        gameAISummary.attributeType = .stringAttributeType
        gameAISummary.isOptional = true

        let gameCloudEnabled = NSAttributeDescription()
        gameCloudEnabled.name = "cloudEnabled"
        gameCloudEnabled.attributeType = .booleanAttributeType
        gameCloudEnabled.isOptional = false
        gameCloudEnabled.defaultValue = false

        let gameUndoData = NSAttributeDescription()
        gameUndoData.name = "undoSnapshotsData"
        gameUndoData.attributeType = .binaryDataAttributeType
        gameUndoData.isOptional = true

        savedGame.properties = [
            gameID, gameSavedAt, gameSnapshotData,
            gameHomeTeamName, gameAwayTeamName,
            gameHomePlayerIDs, gameAwayPlayerIDs, gamePlayerNamesData,
            gameGroupIDsData, gameIsLocked, gameDisplayName,
            gameAISummary, gameCloudEnabled, gameUndoData
        ]

        model.entities = [player, team, gameGroup, savedGame]
        return model
    }()
}
