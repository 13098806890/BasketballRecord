import SwiftUI

struct EventLogEditSheet: View {
    let allPlayers: [Player]
    let homePlayerIDs: [UUID]
    let awayPlayerIDs: [UUID]
    let logs: [GameLogEntry]
    let homeStarterIDs: [UUID]
    let awayStarterIDs: [UUID]
    let gameStartTime: Date
    let gameEndTime: Date
    let defaultNewTimestamp: Date
    let onSave: (Date, UUID, StatAction, Int?) -> Void

    var existingEntry: GameLogEntry?
    @State private var selectedPlayerID: UUID
    @State private var selectedAction: StatAction
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date
    @State private var selectedHour: Int
    @State private var selectedMinute: Int
    @State private var selectedSecond: Int
    @State private var usePeriodTime = false
    @State private var selectedPeriodNumber: Int
    @State private var selectedPeriodMinute: Int
    @State private var selectedPeriodSecond: Int
    @State private var showTimeError = false

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.timeZone = TimeZone.current
        f.locale = Locale.current
        f.calendar = Calendar.current
        return f
    }()

    private let shotActions: [StatAction] = [
        .twoMade, .twoMissed, .threeMade, .threeMissed,
        .layupMade, .layupMissed, .midRangeMade, .midRangeMissed, .paintMade, .paintMissed,
        .dunkMade, .dunkMissed, .putbackMade, .putbackMissed, .bonusMade, .bonusMissed,
        .freeThrowMade, .freeThrowMissed
    ]

    private let statActions: [StatAction] = [
        .assist, .rebound, .offensiveRebound, .defensiveRebound,
        .block, .steal, .turnover, .foul
    ]

    private var eventTimestamps: [Date] { logs.map(\.timestamp) }
    private var availableDates: [Date] { Array(Set(eventTimestamps.map { Calendar.current.startOfDay(for: $0) })).sorted() }
    private var availableHours: [Int] { Array(Set(eventTimestamps.filter { Calendar.current.startOfDay(for: $0) == selectedDate }.map { Calendar.current.component(.hour, from: $0) })).sorted() }
    private var availableMinutes: [Int] {
        let mins = eventTimestamps.filter {
            Calendar.current.startOfDay(for: $0) == selectedDate &&
            Calendar.current.component(.hour, from: $0) == selectedHour
        }.map { Calendar.current.component(.minute, from: $0) }
        guard let min = mins.min(), let max = mins.max() else { return [] }
        return Array(min...max)
    }
    private var availableSeconds: [Int] { Array(0...59) }

    private var onCourtPlayerIDs: [UUID] {
        let ts = builtTimestamp
        var homeOnCourt = Set(homeStarterIDs)
        var awayOnCourt = Set(awayStarterIDs)
        for log in logs.filter({ $0.timestamp <= ts }).sorted(by: { $0.timestamp < $1.timestamp }) {
            guard let code = log.eventCode else { continue }
            if code == "event.substitution" {
                if let incoming = log.playerID, let outgoing = log.relatedPlayerID {
                    if homeOnCourt.contains(outgoing) { homeOnCourt.remove(outgoing); homeOnCourt.insert(incoming) }
                    if awayOnCourt.contains(outgoing) { awayOnCourt.remove(outgoing); awayOnCourt.insert(incoming) }
                }
            } else if code == "event.late_arrival", let pid = log.playerID {
                if homeStarterIDs.contains(pid) || homeOnCourt.contains(pid) { homeOnCourt.insert(pid) }
                if awayStarterIDs.contains(pid) || awayOnCourt.contains(pid) { awayOnCourt.insert(pid) }
            } else if code.hasPrefix("event.period") {
                homeOnCourt = Set(homeStarterIDs)
                awayOnCourt = Set(awayStarterIDs)
            }
        }
        return Array(homeOnCourt) + Array(awayOnCourt)
    }

    private var builtTimestamp: Date {
        if usePeriodTime {
            let start = periodStartTimestamps[selectedPeriodNumber] ?? gameStartTime
            return start.addingTimeInterval(TimeInterval(selectedPeriodMinute * 60 + selectedPeriodSecond))
        }
        var dc = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        dc.hour = selectedHour
        dc.minute = selectedMinute
        dc.second = selectedSecond
        return Calendar.current.date(from: dc) ?? selectedDate
    }

    init(allPlayers: [Player], homePlayerIDs: [UUID], awayPlayerIDs: [UUID],
         logs: [GameLogEntry], homeStarterIDs: [UUID], awayStarterIDs: [UUID],
         gameStartTime: Date, gameEndTime: Date, defaultNewTimestamp: Date? = nil,
         existingEntry: GameLogEntry? = nil, onSave: @escaping (Date, UUID, StatAction, Int?) -> Void) {
        self.allPlayers = allPlayers
        self.homePlayerIDs = homePlayerIDs
        self.awayPlayerIDs = awayPlayerIDs
        self.logs = logs
        self.homeStarterIDs = homeStarterIDs
        self.awayStarterIDs = awayStarterIDs
        self.gameStartTime = gameStartTime
        self.gameEndTime = gameEndTime
        self.defaultNewTimestamp = defaultNewTimestamp ?? gameStartTime
        self.existingEntry = existingEntry
        self.onSave = onSave

        let ts = existingEntry?.timestamp ?? self.defaultNewTimestamp
        _selectedPlayerID = State(initialValue: existingEntry?.playerID ?? allPlayers.first?.id ?? UUID())
        let action = StatAction.allCases.first(where: { $0.eventCode == existingEntry?.eventCode }) ?? .twoMade
        _selectedAction = State(initialValue: action)
        _selectedDate = State(initialValue: Calendar.current.startOfDay(for: ts))
        _selectedHour = State(initialValue: Calendar.current.component(.hour, from: ts))
        _selectedMinute = State(initialValue: Calendar.current.component(.minute, from: ts))
        _selectedSecond = State(initialValue: Calendar.current.component(.second, from: ts))
        _selectedPeriodNumber = State(initialValue: existingEntry?.period ?? 1)
        let defaultMin: Int
        if let elapsed = existingEntry?.periodElapsedSeconds, elapsed > 0 {
            defaultMin = Int(elapsed) / 60
        } else {
            defaultMin = Calendar.current.component(.minute, from: ts) % 60
        }
        _selectedPeriodMinute = State(initialValue: defaultMin)
        _selectedPeriodSecond = State(initialValue: Calendar.current.component(.second, from: ts) % 60)
    }

    private var periodStartTimestamps: [Int: Date] {
        var result: [Int: Date] = [:]
        var period = 1
        for log in logs.sorted(by: { $0.timestamp < $1.timestamp }) {
            if let code = log.eventCode, (code == "event.period_start" || code == "event.period") {
                result[period] = log.timestamp
                period += 1
            }
        }
        return result
    }

    private var maxPeriod: Int { max(periodStartTimestamps.keys.max() ?? 1, logs.compactMap { $0.period }.max() ?? 1) }

    private var periodMaxTotalSec: Int {
        guard let start = periodStartTimestamps[selectedPeriodNumber] else { return 3599 }
        let end = periodStartTimestamps[selectedPeriodNumber + 1] ?? gameEndTime
        let duration = end.timeIntervalSince(start)
        guard duration > 0 else { return 3599 }
        return min(Int(duration), 3599)
    }

    private var periodMaxMinute: Int { periodMaxTotalSec / 60 }

    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("label_time")) {
                    if let entry = existingEntry {
                        HStack {
                            Text(LocalizedStringKey("label_time"))
                            Spacer()
                            Text(timeFormatter.string(from: entry.timestamp))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text(NSLocalizedString("label_period_time", comment: ""))
                            Spacer()
                            let period = entry.period ?? 1
                            let start = periodStartTimestamps[period] ?? entry.timestamp
                            let elapsed = Int(entry.timestamp.timeIntervalSince(start))
                            let min = elapsed / 60
                            let sec = elapsed % 60
                            Text("\(String(format: NSLocalizedString("data_range_period", comment: ""), period)) \(min):\(String(format: "%02d", sec))")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Picker("", selection: Binding(
                            get: { usePeriodTime ? 1 : 0 },
                            set: { usePeriodTime = $0 == 1 }
                        )) {
                            Text(NSLocalizedString("label_exact_time", comment: "")).tag(0)
                            Text(NSLocalizedString("label_period_time", comment: "")).tag(1)
                        }
                        .pickerStyle(.segmented)

                        if usePeriodTime {
                            Picker(NSLocalizedString("label_period_count", comment: ""), selection: $selectedPeriodNumber) {
                                ForEach(1...maxPeriod, id: \.self) { p in
                                    Text(verbatim: String(format: NSLocalizedString("data_range_period", comment: ""), p)).tag(p)
                                }
                            }
                            .onChange(of: selectedPeriodNumber) { _, _ in
                                if selectedPeriodMinute > periodMaxMinute {
                                    selectedPeriodMinute = periodMaxMinute
                                }
                            }
                            HStack {
                                Picker(NSLocalizedString("label_minute", comment: ""), selection: $selectedPeriodMinute) {
                                    ForEach(0...periodMaxMinute, id: \.self) { m in
                                        Text(String(format: "%02d", m)).tag(m)
                                    }
                                }
                                .pickerStyle(.menu)
                                Text(":")
                                    .font(.title3)
                                Picker(NSLocalizedString("label_second", comment: ""), selection: $selectedPeriodSecond) {
                                    ForEach(0..<60, id: \.self) { s in
                                        Text(String(format: "%02d", s)).tag(s)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        } else {
                            Picker(LocalizedStringKey("label_date"), selection: $selectedDate) {
                                ForEach(availableDates, id: \.self) { date in
                                    Text(date, style: .date).tag(date)
                                }
                            }
                            Picker(LocalizedStringKey("label_hour"), selection: $selectedHour) {
                                ForEach(availableHours, id: \.self) { h in
                                    Text(String(format: "%02d", h)).tag(h)
                                }
                            }
                            .onChange(of: selectedDate) { _, _ in
                                if !availableHours.contains(selectedHour), let first = availableHours.first { selectedHour = first }
                                if !availableMinutes.contains(selectedMinute), let first = availableMinutes.first { selectedMinute = first }
                            }
                            Picker(LocalizedStringKey("label_minute"), selection: $selectedMinute) {
                                ForEach(availableMinutes, id: \.self) { m in
                                    Text(String(format: "%02d", m)).tag(m)
                                }
                            }
                            .onChange(of: selectedHour) { _, _ in
                                if !availableMinutes.contains(selectedMinute), let first = availableMinutes.first { selectedMinute = first }
                            }
                            Picker(LocalizedStringKey("label_second"), selection: $selectedSecond) {
                                ForEach(availableSeconds, id: \.self) { s in
                                    Text(String(format: "%02d", s)).tag(s)
                                }
                            }
                        }
                    }
                }

                Section(LocalizedStringKey("label_action")) {
                    Picker(LocalizedStringKey("label_type"), selection: $selectedAction) {
                        Section(LocalizedStringKey("stats_shooting")) {
                            ForEach(shotActions, id: \.self) { action in
                                Text(NSLocalizedString(action.messageKey, comment: "")).tag(action)
                            }
                        }
                        Section(LocalizedStringKey("stats_other")) {
                            ForEach(statActions, id: \.self) { action in
                                Text(NSLocalizedString(action.messageKey, comment: "")).tag(action)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section(LocalizedStringKey("label_player")) {
                    let isFoul = selectedAction == .foul
                    let filteredHome = isFoul ? homePlayerIDs : homePlayerIDs.filter { onCourtPlayerIDs.contains($0) }
                    let filteredAway = isFoul ? awayPlayerIDs : awayPlayerIDs.filter { onCourtPlayerIDs.contains($0) }
                    VStack(spacing: 8) {
                        if !filteredHome.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(filteredHome, id: \.self) { pid in
                                        playerButton(pid: pid, isHome: true)
                                    }
                                }
                            }
                        }
                        if !filteredAway.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(filteredAway, id: \.self) { pid in
                                        playerButton(pid: pid, isHome: false)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(existingEntry != nil
                ? NSLocalizedString("label_edit_event", comment: "")
                : NSLocalizedString("label_add_event", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button_cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button_save", comment: "")) {
                        let ts = existingEntry?.timestamp ?? builtTimestamp
                        if usePeriodTime {
                            let chosenSec = selectedPeriodMinute * 60 + selectedPeriodSecond
                            guard chosenSec <= periodMaxTotalSec else {
                                showTimeError = true
                                return
                            }
                        }
                        let minTime = usePeriodTime ? (periodStartTimestamps[selectedPeriodNumber] ?? gameStartTime) : gameStartTime
                        let maxTime = usePeriodTime ? (periodStartTimestamps[selectedPeriodNumber + 1] ?? gameEndTime) : gameEndTime
                        guard ts >= minTime && ts <= maxTime else {
                            showTimeError = true
                            return
                        }
                        onSave(ts, selectedPlayerID, selectedAction, usePeriodTime ? selectedPeriodNumber : nil)
                        dismiss()
                    }
                }
            }
        }
        .alert(NSLocalizedString("label_time_error", comment: ""), isPresented: $showTimeError) {
            Button(NSLocalizedString("button_ok", comment: "")) { }
        } message: {
            Text(NSLocalizedString("message_time_out_of_range", comment: ""))
        }
    }

    private func playerButton(pid: UUID, isHome: Bool) -> some View {
        let player = allPlayers.first { $0.id == pid }
        let name = player?.name ?? "?"
        let isSelected = selectedPlayerID == pid
        return Button {
            selectedPlayerID = pid
        } label: {
            VStack(spacing: 4) {
                if let photo = player?.photoData, let uiImage = UIImage(data: photo) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2))
                } else {
                    ZStack {
                        Circle()
                            .fill(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                            .frame(width: 44, height: 44)
                        Text(name.prefix(1).uppercased())
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(isSelected ? .blue : .secondary)
                    }
                    .overlay(Circle().stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: 2))
                }
                Text(name)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(isSelected ? .blue : .primary)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
    }
}
