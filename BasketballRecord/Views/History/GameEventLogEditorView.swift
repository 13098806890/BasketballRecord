import SwiftUI

struct GameEventLogEditorView: View {
    let game: SavedGame
    let periodAnalysis: SavedGamePeriodAnalysis
    let selectedPeriod: Int?
    @EnvironmentObject private var store: AppStore
    @Binding var isEditing: Bool
    let onRebuildAnalysis: () -> Void
    
    @State private var editingSheetEntry: GameLogEntry?
    @State private var expandedPeriods: Set<Int> = []
    @State private var expandedMinutes: [Int: Set<Int>] = [:]
    @State private var lastExpandedPeriod = 1
   @State private var lastExpandedMinute = 0

    var body: some View {
        editEventListView
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

   private func logLineText(for item: PeriodAwareLog) -> String {
       GameLogFormatter.lineText(for: item, originalPeriodCount: game.snapshot.originalPeriodCount)
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
                    var entry = GameLogEntry(timestamp: Date(), message: "", eventCode: nil, playerID: nil)
                    entry.period = lastExpandedPeriod
                    entry.periodElapsedSeconds = TimeInterval(lastExpandedMinute * 60)
                    editingSheetEntry = entry
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            List {
                let storeEditHistory = (store.savedGames.first { $0.id == game.id })?.snapshot.editHistory ?? game.snapshot.editHistory
                let addedIDs = Set(storeEditHistory.filter { $0.action == "add" }.map(\.eventID))
                let deletedIDs = Set(storeEditHistory.filter { $0.action == "delete" }.map(\.eventID))
                let restoredIDs = Set(storeEditHistory.filter { $0.action == "restore" }.map(\.eventID))
                let addedThenDeletedIDs = addedIDs.intersection(deletedIDs).subtracting(restoredIDs)
                let visibleLogs = filteredPeriodAwareLogs.filter { !addedThenDeletedIDs.contains($0.entry.id) }
                let grouped = Dictionary(grouping: visibleLogs, by: { $0.inferredPeriod ?? 0 })
                let sortedPeriods = grouped.keys.sorted()
                ForEach(sortedPeriods, id: \.self) { period in
                    Section {
                        Button {
                            if expandedPeriods.contains(period) { expandedPeriods.remove(period) }
                            else { expandedPeriods.insert(period); lastExpandedPeriod = period }
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
                                    else { expandedMinutes[period, default: []].insert(minute); lastExpandedPeriod = period; lastExpandedMinute = minute }
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
        .sheet(item: $editingSheetEntry) { entry in
            let events = game.snapshot.logs
            let firstTS = events.first?.timestamp ?? game.savedAt
            let lastTS = events.last?.timestamp ?? game.savedAt
            let gameStart = min(firstTS, lastTS)
            let isRealEntry = events.contains(where: { $0.id == entry.id })
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
                defaultNewTimestamp: isRealEntry ? nil : gameStart,
                existingEntry: isRealEntry ? entry : nil,
                onSave: { timestamp, playerID, action, period in
                    if let existing = events.first(where: { $0.id == entry.id }) {
                        modifyEvent(existing, timestamp: timestamp, playerID: playerID, action: action)
                    } else {
                        addEvent(timestamp: timestamp, playerID: playerID, action: action, period: period)
                    }
                }
            )
        }
    }

    private var addedThenDeletedIDs: Set<UUID> {
        guard let snapshot = store.savedGames.first(where: { $0.id == game.id })?.snapshot else { return [] }
        let added = Set(snapshot.editHistory.filter { $0.action == "add" }.map(\.eventID))
        let deleted = Set(snapshot.editHistory.filter { $0.action == "delete" }.map(\.eventID))
        let restored = Set(snapshot.editHistory.filter { $0.action == "restore" }.map(\.eventID))
        return added.intersection(deleted).subtracting(restored)
    }

    private var deletedEventIDs: Set<UUID> {
        guard let snapshot = store.savedGames.first(where: { $0.id == game.id })?.snapshot else { return [] }
        let addedIDs = Set(snapshot.editHistory.filter { $0.action == "add" }.map(\.eventID))
        let deleteIDs = Set(snapshot.editHistory.filter { $0.action == "delete" }.map(\.eventID))
        let restoreIDs = Set(snapshot.editHistory.filter { $0.action == "restore" }.map(\.eventID))
        return deleteIDs.subtracting(restoreIDs).subtracting(addedIDs)
    }
    private func editEventRow(log: PeriodAwareLog) -> some View {
        let code = log.entry.eventCode ?? ""
        let isProtected = ["event.period_start", "event.period_end", "event.game_end", "event.starters_home", "event.starters_away"].contains(code)
        let storeSnapshot = store.savedGames.first { $0.id == game.id }?.snapshot
        let editHistory = storeSnapshot?.editHistory ?? game.snapshot.editHistory
        let isNew = editHistory.contains(where: { $0.eventID == log.entry.id && $0.action == "add" })
        let isEdited = editHistory.contains(where: { $0.eventID == log.entry.id && $0.action == "modify" })
        let isDeleted = deletedEventIDs.contains(log.entry.id)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isNew {
                        Text("NEW")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.green)
                    }
                    if isEdited {
                        Text("EDITED")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                    if isDeleted {
                        Text("DELETED")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.red)
                    }
                    Text(logLineText(for: log))
                        .font(.caption)
                        .lineLimit(2)
                        .foregroundStyle(isDeleted ? .secondary : .primary)
                        .strikethrough(isDeleted)
                }
                HStack(spacing: 4) {
                    Text(log.entry.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let period = log.inferredPeriod {
                        let start = periodStartTimestamps[period] ?? log.entry.timestamp
                        let elapsed = Int(log.entry.timestamp.timeIntervalSince(start))
                        if elapsed >= 0 {
                            Text(" | \(String(format: NSLocalizedString("data_range_period", comment: ""), period)) \(elapsed / 60):\(String(format: "%02d", elapsed % 60))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
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
            if !isProtected && !isDeleted {
                Button(NSLocalizedString("button_edit", comment: "")) {
                    editingSheetEntry = log.entry
                }
                .tint(.blue)
                Button(NSLocalizedString("label_delete", comment: "")) {
                    deleteEvent(log.entry)
                }
                .tint(.red)
            }
            if isEdited {
                Button(NSLocalizedString("button_undo", comment: "")) {
                    restoreEditedEvent(for: log.entry.id)
                }
                .tint(.green)
            }
            if isDeleted {
                Button(NSLocalizedString("button_undo", comment: "")) {
                    restoreDeletedEvent(for: log.entry.id)
                }
                .tint(.green)
            }
        }
    }

    private func addEvent(timestamp: Date, playerID: UUID, action: StatAction, period: Int? = nil) {
        let eventCode = action.eventCode
        let entry = GameLogEntry(
            timestamp: timestamp,
            message: "\(store.player(for: playerID)?.name ?? "?") \(action.message) [event:\(eventCode)]",
            eventCode: eventCode,
            playerID: playerID,
            period: period
        )
        guard let gameIndex = store.savedGames.firstIndex(where: { $0.id == game.id }) else { return }
        var savedGame = store.savedGames[gameIndex]
        savedGame.snapshot.logs.append(entry)
        savedGame.snapshot.logs.sort { $0.timestamp < $1.timestamp }
        savedGame.snapshot.editHistory.append(GameLogEditRecord(
            timestamp: Date(),
            action: "add",
            eventID: entry.id,
            previousMessage: nil,
            previousEventCode: nil,
            previousPlayerID: nil,
            currentMessage: entry.message,
            currentEventCode: entry.eventCode,
            currentPlayerID: entry.playerID
        ))
        store.savedGames[gameIndex] = savedGame
        onRebuildAnalysis()
    }

    private func modifyEvent(_ entry: GameLogEntry, timestamp: Date, playerID: UUID, action: StatAction) {
        let eventCode = action.eventCode
        guard let logIndex = game.snapshot.logs.firstIndex(where: { $0.id == entry.id }),
              let gameIndex = store.savedGames.firstIndex(where: { $0.id == game.id }) else { return }
        var savedGame = store.savedGames[gameIndex]
        let oldMsg = savedGame.snapshot.logs[logIndex].message
        let oldCode = savedGame.snapshot.logs[logIndex].eventCode
        let oldPID = savedGame.snapshot.logs[logIndex].playerID
        savedGame.snapshot.logs[logIndex].playerID = playerID
        savedGame.snapshot.logs[logIndex].eventCode = eventCode
        savedGame.snapshot.logs[logIndex].message = "\(store.player(for: playerID)?.name ?? "?") \(action.message) [event:\(eventCode)]"
        savedGame.snapshot.editHistory.append(GameLogEditRecord(
            timestamp: Date(),
            action: "modify",
            eventID: entry.id,
            previousMessage: oldMsg,
            previousEventCode: oldCode,
            previousPlayerID: oldPID,
            currentMessage: savedGame.snapshot.logs[logIndex].message,
            currentEventCode: eventCode,
            currentPlayerID: playerID
        ))
        store.savedGames[gameIndex] = savedGame
        onRebuildAnalysis()
    }

    private func deleteEvent(_ entry: GameLogEntry) {
        guard let gameIndex = store.savedGames.firstIndex(where: { $0.id == game.id }) else { return }
        var savedGame = store.savedGames[gameIndex]
        savedGame.snapshot.editHistory.append(GameLogEditRecord(
            timestamp: Date(),
            action: "delete",
            eventID: entry.id,
            previousMessage: entry.message,
            previousEventCode: entry.eventCode,
            previousPlayerID: entry.playerID,
            previousTimestamp: entry.timestamp,
            previousPeriod: entry.period,
            currentMessage: nil,
            currentEventCode: nil,
            currentPlayerID: nil
        ))
        store.savedGames[gameIndex] = savedGame
        onRebuildAnalysis()
    }

    private func restoreEditedEvent(for eventID: UUID) {
        guard let gameIndex = store.savedGames.firstIndex(where: { $0.id == game.id }),
              let logIndex = store.savedGames[gameIndex].snapshot.logs.firstIndex(where: { $0.id == eventID }),
              let firstRecord = store.savedGames[gameIndex].snapshot.editHistory.first(where: { $0.eventID == eventID && $0.action == "modify" }),
              let origMsg = firstRecord.previousMessage else { return }
        var savedGame = store.savedGames[gameIndex]
        savedGame.snapshot.logs[logIndex].message = origMsg
        savedGame.snapshot.logs[logIndex].eventCode = firstRecord.previousEventCode
        savedGame.snapshot.logs[logIndex].playerID = firstRecord.previousPlayerID
        savedGame.snapshot.editHistory.removeAll { $0.eventID == eventID && $0.action == "modify" }
        store.savedGames[gameIndex] = savedGame
        onRebuildAnalysis()
    }

    private func restoreDeletedEvent(for eventID: UUID) {
        guard let gameIndex = store.savedGames.firstIndex(where: { $0.id == game.id }) else { return }
        var savedGame = store.savedGames[gameIndex]
        savedGame.snapshot.editHistory.append(GameLogEditRecord(
            timestamp: Date(), action: "restore", eventID: eventID,
            previousMessage: nil, previousEventCode: nil, previousPlayerID: nil,
            previousTimestamp: nil, previousPeriod: nil,
            currentMessage: nil, currentEventCode: nil, currentPlayerID: nil
        ))
        store.savedGames[gameIndex] = savedGame
        onRebuildAnalysis()
    }
}
