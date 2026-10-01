import AVFoundation
import Foundation
import Speech
import XCTest
@testable import BasketballRecord

@MainActor
final class VoiceASRFileTranscriptionTests: XCTestCase {
    func testConfiguredWAVCorpusIsReadable() throws {
        let corpus = try evaluationCorpus()

        for row in try loadManifest(at: corpus.manifestURL) {
            let audioURL = corpus.audioDirectory.appendingPathComponent(row.wavFile)
            let audioFile = try AVAudioFile(forReading: audioURL)
            XCTAssertGreaterThan(audioFile.length, 0, row.caseID)
        }
    }

    func testConfiguredTranscriptReplay() async throws {
        guard let scorePath = ProcessInfo.processInfo.environment["VOICE_ASR_EVAL_SCORE_JSON"] else {
            throw XCTSkip("VOICE_ASR_EVAL_SCORE_JSON is not configured")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: scorePath))
        let score = try JSONDecoder().decode(TranscriptReplayScore.self, from: data)
        var total = 0
        var matched = 0
        var byLocale: [String: (matched: Int, total: Int)] = [:]
        for row in score.rows where !row.transcript.isEmpty {
            total += 1
            var counts = byLocale[row.locale] ?? (0, 0)
            counts.total += 1
            let store = replayStore(player: row.expectedPlayer, relatedPlayer: row.expectedRelatedPlayer)
            let recognizer = VoiceRecognizer()
            recognizer.configureForFileEvaluation(store: store, engine: .speechTranscriber)
            recognizer.currentSnapshot = replaySnapshot(store: store)
            recognizer.updateRules(for: Locale(identifier: row.locale))
            var events: [String] = []
            recognizer.onAction = { action, _, _, _ in
                events.append(action.eventCode)
            }
            recognizer.onDualAction = { first, _, _, second, _, _ in
                events.append(first.eventCode)
                events.append(second.eventCode)
            }
            recognizer.onCommand = { command in
                switch command {
                case .startPeriod: events.append("event.period")
                case .togglePause: events.append("event.pause")
                case .finishGame: events.append("event.game_end")
                case .substitution: events.append("event.substitution")
                case .undo: events.append("event.undo")
                case .redo: events.append("event.redo")
                }
            }
            recognizer.simulateText(row.transcript)
            await Task.yield()
            if replayEventMatches(events: events, expected: row.expectedEvent) {
                matched += 1
                counts.matched += 1
            }
            byLocale[row.locale] = counts
        }
        let summary = byLocale.keys.sorted().map { locale in
            let value = byLocale[locale]!
            return "\(locale)=\(value.matched)/\(value.total)"
        }.joined(separator: " ")
        print("VOICE_TRANSCRIPT_REPLAY matched=\(matched)/\(total) \(summary)")
        if let outputPath = ProcessInfo.processInfo.environment["VOICE_ASR_EVAL_REPLAY_OUTPUT"] {
            try? summary.write(toFile: outputPath, atomically: true, encoding: .utf8)
        }
    }

    func testConfiguredFileCorpus() async throws {
        let corpus = try evaluationCorpus()
        let allRows = try loadManifest(at: corpus.manifestURL)
        let localeFilter = Set((ProcessInfo.processInfo.environment["VOICE_ASR_EVAL_LOCALES"] ?? "")
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })
        let rows = localeFilter.isEmpty ? allRows : allRows.filter { localeFilter.contains($0.locale) }
        let engineNames = (ProcessInfo.processInfo.environment["VOICE_ASR_EVAL_ENGINES"] ?? VoiceASREngine.speechTranscriber.rawValue)
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if #available(iOS 26.0, *),
           engineNames.contains(VoiceASREngine.speechTranscriber.rawValue),
           ProcessInfo.processInfo.environment["VOICE_ASR_EVAL_RELEASE_ALL_LOCALES"] == "1" {
            for locale in await AssetInventory.reservedLocales {
                _ = await AssetInventory.release(reservedLocale: locale)
            }
        }
        var resultRows: [String] = []

        for engineName in engineNames {
            guard let engine = VoiceASREngine(rawValue: engineName) else {
                XCTFail("Unknown voice ASR engine: \(engineName)")
                continue
            }

            for row in rows {
                let audioURL = corpus.audioDirectory.appendingPathComponent(row.wavFile)
                let result: VoiceASRFileTranscriptionResult
                do {
                    switch engine {
                    case .legacySpeech:
                        result = try await VoiceASRFileTranscriber.transcribeLegacy(url: audioURL, locale: Locale(identifier: row.locale))
                    case .speechTranscriber:
                        guard #available(iOS 26.0, *) else {
                            throw XCTSkip("SpeechTranscriber requires iOS 26 or later")
                        }
                        let rules = VoiceRules.forLocale(Locale(identifier: row.locale))
                        let names = orderedNames(for: row, in: allRows)
                        let context = rules.contextualStrings(playerNames: names, playerNumbers: names.indices.map { String($0 + 1) })
                        result = try await VoiceASRFileTranscriber.transcribeSpeechTranscriber(url: audioURL, locale: Locale(identifier: row.locale), contextualStrings: context)
                    }
                } catch let error as VoiceASRFileTranscriberError {
                    switch error {
                    case .speechAuthorizationDenied, .recognizerUnavailable, .localeUnsupported, .modelUnavailable:
                        resultRows.append(csvRow(
                            engine: engine.rawValue,
                            row: row,
                            transcript: "",
                            firstResultMilliseconds: nil,
                            finalResultMilliseconds: nil,
                            eventCode: "",
                            playerMatch: false,
                            relatedPlayerMatch: false,
                            error: error.localizedDescription,
                            recognitionStatus: "asr_unavailable"
                        ))
                        print("VOICE_ASR_UNAVAILABLE,\(engine.rawValue),\(row.locale),\(error.localizedDescription)")
                        continue
                    case .noResult, .emptyAudio:
                        resultRows.append(csvRow(
                            engine: engine.rawValue,
                            row: row,
                            transcript: "",
                            firstResultMilliseconds: nil,
                            finalResultMilliseconds: nil,
                            eventCode: "",
                            playerMatch: false,
                            relatedPlayerMatch: false,
                            error: error.localizedDescription,
                            recognitionStatus: "asr_no_result"
                        ))
                        continue
                    }
                } catch {
                    resultRows.append(csvRow(
                        engine: engine.rawValue,
                        row: row,
                        transcript: "",
                        firstResultMilliseconds: nil,
                        finalResultMilliseconds: nil,
                        eventCode: "",
                        playerMatch: false,
                        relatedPlayerMatch: false,
                        error: error.localizedDescription,
                        recognitionStatus: "asr_error"
                    ))
                    continue
                }

                let parsed = await parsedResult(for: row, in: rows, engine: engine, transcript: result.transcript, alternatives: result.alternatives)
                resultRows.append(csvRow(
                    engine: engine.rawValue,
                    row: row,
                    transcript: result.transcript,
                    firstResultMilliseconds: result.firstResultMilliseconds,
                    finalResultMilliseconds: result.finalResultMilliseconds,
                    eventCode: parsed.eventCode,
                    playerMatch: parsed.playerMatch,
                    relatedPlayerMatch: parsed.relatedPlayerMatch,
                    recognitionStatus: parsed.eventCode.isEmpty ? "parser_no_action" : "parser_action",
                    candidates: [result.transcript] + result.alternatives,
                    voiceLogTrace: parsed.voiceLogTrace
                ))
            }
        }

        guard !resultRows.isEmpty else {
            throw XCTSkip("No ASR evaluation rows were produced")
        }

        print("VOICE_ASR_HEADER,engine,case_id,transcript,first_result_ms,final_result_ms,event_code,player_match,related_player_match,error,recognition_status,candidates,voice_log")
        for row in resultRows {
            print("VOICE_ASR_RESULT,\(row)")
        }
    }

    private struct EvaluationCorpus {
        let audioDirectory: URL
        let manifestURL: URL
    }

    private struct ManifestRow {
        let caseID: String
        let locale: String
        let category: String
        let expectedEvent: String
        let expectedPlayer: String
        let expectedRelatedPlayer: String
        let wavFile: String
    }

    private struct ParsedResult {
        let eventCode: String
        let playerMatch: Bool
        let relatedPlayerMatch: Bool
        let voiceLogTrace: String
    }

    private func evaluationCorpus() throws -> EvaluationCorpus {
        if let audioDirectoryPath = ProcessInfo.processInfo.environment["VOICE_ASR_EVAL_AUDIO_DIR"],
           let manifestPath = ProcessInfo.processInfo.environment["VOICE_ASR_EVAL_MANIFEST"] {
            let audioDirectory = URL(fileURLWithPath: audioDirectoryPath)
            let manifestURL = URL(fileURLWithPath: manifestPath)
            if FileManager.default.fileExists(atPath: audioDirectory.path),
               FileManager.default.fileExists(atPath: manifestURL.path) {
                return EvaluationCorpus(audioDirectory: audioDirectory, manifestURL: manifestURL)
            }
        }

        guard let manifestURL = Bundle(for: Self.self).url(forResource: "manifest", withExtension: "tsv") else {
            throw XCTSkip("Set VOICE_ASR_EVAL_AUDIO_DIR and VOICE_ASR_EVAL_MANIFEST or bundle evaluation fixtures")
        }
        return EvaluationCorpus(
            audioDirectory: manifestURL.deletingLastPathComponent(),
            manifestURL: manifestURL
        )
    }

    private func loadManifest(at url: URL) throws -> [ManifestRow] {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return try contents.split(whereSeparator: \.isNewline).dropFirst().map { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count >= 2, !fields[0].isEmpty, !fields[1].isEmpty else {
                throw NSError(domain: "VoiceASREvaluation", code: 1)
            }
            let caseID = fields[0]
            let locale = fields[1]
            let category = fields.count > 2 ? fields[2] : "legacy"
            let expectedEvent = fields.count > 7 ? fields[7] : ""
            let expectedPlayer = fields.count > 8 ? fields[8] : ""
            let expectedRelatedPlayer = fields.count > 11 ? fields[11] : ""
            let wavFile = fields.count > 12 && !fields[12].isEmpty ? fields[12] : "\(caseID).wav"
            return ManifestRow(
                caseID: caseID,
                locale: locale,
                category: category,
                expectedEvent: expectedEvent,
                expectedPlayer: expectedPlayer,
                expectedRelatedPlayer: expectedRelatedPlayer,
                wavFile: wavFile
            )
        }
    }

    private func parsedResult(for row: ManifestRow, in rows: [ManifestRow], engine: VoiceASREngine, transcript: String, alternatives: [String]) async -> ParsedResult {
        let store = AppStore()
        store.voiceLogEnabled = true
        store.voiceLog = []
        let names = orderedNames(for: row, in: rows)
        let ids = names.enumerated().map { index, name in
            (name, UUID(), "\(index + 1)")
        }
        store.players = ids.map { Player(id: $0.1, name: $0.0, number: $0.2) }
        let homeTeamID = UUID()
        let awayTeamID = UUID()
        store.teams = [
            Team(id: homeTeamID, name: "Evaluation Home", playerIDs: ids.map(\.1)),
            Team(id: awayTeamID, name: "Evaluation Away", playerIDs: ids.map(\.1))
        ]

        let idByName = Dictionary(uniqueKeysWithValues: ids.map { ($0.0, $0.1) })
        let expectedID = idByName[row.expectedPlayer]
        let expectedRelatedID = idByName[row.expectedRelatedPlayer]
        let allIDs = ids.map(\.1)
        var snapshot = GameSnapshot()
        snapshot.homeTeamID = homeTeamID
        snapshot.awayTeamID = awayTeamID

        if row.category == "substitution" {
            if let expectedID {
                snapshot.homeOnCourtPlayerIDs = [expectedID]
                snapshot.homeAvailablePlayerIDs = allIDs
            }
        } else if row.expectedEvent == "stat.stealTurnover", let expectedID, let expectedRelatedID {
            snapshot.homeOnCourtPlayerIDs = [expectedID]
            snapshot.awayOnCourtPlayerIDs = [expectedRelatedID]
            snapshot.homeAvailablePlayerIDs = [expectedID]
            snapshot.awayAvailablePlayerIDs = [expectedRelatedID]
        } else {
            snapshot.homeOnCourtPlayerIDs = allIDs
            snapshot.homeAvailablePlayerIDs = allIDs
        }

        let recognizer = VoiceRecognizer()
        recognizer.configureForFileEvaluation(store: store, engine: engine)
        recognizer.currentSnapshot = snapshot
        recognizer.updateRules(for: Locale(identifier: row.locale))
        if row.expectedEvent == "stat.offensiveRebound" || row.expectedEvent == "stat.defensiveRebound" {
            recognizer.setReboundFilterMode(true)
        }

        var code = ""
        var playerMatch = row.expectedPlayer.isEmpty
        var relatedPlayerMatch = row.expectedRelatedPlayer.isEmpty
        recognizer.onAction = { action, playerID, _, _ in
            code = action.eventCode
            playerMatch = expectedID == playerID
        }
        recognizer.onDualAction = { action, playerID, _, relatedAction, relatedPlayerID, _ in
            if action.eventCode == "stat.assist", relatedAction.eventCode == "stat.twoMade" {
                code = "stat.assistTwoMade"
            } else if action.eventCode == "stat.assist", relatedAction.eventCode == "stat.threeMade" {
                code = "stat.assistThreeMade"
            } else if action.eventCode == "stat.steal", relatedAction.eventCode == "stat.turnover" {
                code = "stat.stealTurnover"
            } else {
                code = action.eventCode
            }
            playerMatch = expectedID == playerID
            relatedPlayerMatch = expectedRelatedID == relatedPlayerID
        }
        recognizer.onSubstitution = { _, outgoingID, incomingID in
            code = "event.substitution"
            playerMatch = expectedID == outgoingID
            relatedPlayerMatch = expectedRelatedID == incomingID
        }
        recognizer.onCommand = { command in
            switch command {
            case .startPeriod: code = "event.period"
            case .togglePause: code = "event.pause"
            case .finishGame: code = "event.game_end"
            case .undo: code = "event.undo"
            case .redo: code = "event.redo"
            case .substitution: code = "event.substitution"
            }
        }
        var bestResult = ParsedResult(eventCode: "", playerMatch: row.expectedPlayer.isEmpty, relatedPlayerMatch: row.expectedRelatedPlayer.isEmpty, voiceLogTrace: "")
        var bestScore = -1
        var candidates = [transcript]
        candidates.append(contentsOf: alternatives.filter { !$0.isEmpty && !candidates.contains($0) })
        for candidate in candidates {
            code = ""
            playerMatch = row.expectedPlayer.isEmpty
            relatedPlayerMatch = row.expectedRelatedPlayer.isEmpty
            let logCountBeforeCandidate = store.voiceLog.count
            recognizer.simulateText(candidate)
            for _ in 0..<8 {
                await Task.yield()
            }
            let newLogEntries = Array(store.voiceLog.prefix(max(0, store.voiceLog.count - logCountBeforeCandidate)))
            let candidateResult = ParsedResult(
                eventCode: code,
                playerMatch: playerMatch,
                relatedPlayerMatch: relatedPlayerMatch,
                voiceLogTrace: newLogEntries.reversed().map(voiceLogLine).joined(separator: " || ")
            )
            let score = (candidateResult.eventCode == row.expectedEvent ? 4 : 0)
                + (candidateResult.playerMatch ? 2 : 0)
                + (candidateResult.relatedPlayerMatch ? 2 : 0)
            if score > bestScore {
                bestScore = score
                bestResult = candidateResult
            }
            if score == 8 { break }
        }
        return bestResult
    }

    private func voiceLogLine(_ entry: VoiceLogEntry) -> String {
        var values = [entry.isSuccess ? "success" : "failure", entry.text]
        if let locale = entry.locale { values.append("locale=\(locale)") }
        if let engine = entry.engine { values.append("engine=\(engine)") }
        if let stage = entry.stage { values.append("stage=\(stage)") }
        if let failureReason = entry.failureReason { values.append("reason=\(failureReason)") }
        if let action = entry.action { values.append("action=\(action)") }
        if let playerName = entry.playerName { values.append("player=\(playerName)") }
        if let detail = entry.matchDetail { values.append(detail) }
        return values.joined(separator: " | ")
    }

    private func orderedNames(for row: ManifestRow, in rows: [ManifestRow]) -> [String] {
        var names: [String] = []
        for candidate in rows where candidate.locale == row.locale {
            for name in [candidate.expectedPlayer, candidate.expectedRelatedPlayer] where !name.isEmpty && !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }

    private func csvRow(
        engine: String,
        row: ManifestRow,
        transcript: String,
        firstResultMilliseconds: Int?,
        finalResultMilliseconds: Int?,
        eventCode: String,
        playerMatch: Bool,
        relatedPlayerMatch: Bool,
        error: String = "",
        recognitionStatus: String = "parser_failure",
        candidates: [String] = [],
        voiceLogTrace: String = ""
    ) -> String {
        [
            engine,
            row.caseID,
            transcript,
            firstResultMilliseconds.map(String.init) ?? "",
            finalResultMilliseconds.map(String.init) ?? "",
            eventCode,
            playerMatch ? "true" : "false",
            relatedPlayerMatch ? "true" : "false",
            error,
            recognitionStatus,
            candidates.joined(separator: " || "),
            voiceLogTrace
        ].map(csvField).joined(separator: ",")
    }

    private func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func replayStore(player: String, relatedPlayer: String) -> AppStore {
        let store = AppStore()
        let names = [player, relatedPlayer].filter { !$0.isEmpty }
        let players = names.enumerated().map { index, name in
            Player(name: name, number: String(index + 1))
        }
        store.players = players
        let teamID = UUID()
        store.teams = [Team(id: teamID, name: "Replay", playerIDs: players.map(\.id))]
        return store
    }

    private func replaySnapshot(store: AppStore) -> GameSnapshot {
        var snapshot = GameSnapshot()
        guard let team = store.teams.first else { return snapshot }
        snapshot.homeTeamID = team.id
        snapshot.homeOnCourtPlayerIDs = team.playerIDs
        snapshot.homeAvailablePlayerIDs = team.playerIDs
        return snapshot
    }

    private func replayEventMatches(events: [String], expected: String) -> Bool {
        if events.contains(expected) { return true }
        if expected == "stat.assistTwoMade" {
            return events.contains("stat.assist") && events.contains("stat.twoMade")
        }
        if expected == "stat.assistThreeMade" {
            return events.contains("stat.assist") && events.contains("stat.threeMade")
        }
        if expected == "stat.stealTurnover" {
            return events.contains("stat.steal") && events.contains("stat.turnover")
        }
        return false
    }
}

private struct TranscriptReplayScore: Decodable {
    let rows: [TranscriptReplayRow]
}

private struct TranscriptReplayRow: Decodable {
    let caseID: String
    let locale: String
    let expectedEvent: String
    let expectedPlayer: String
    let expectedRelatedPlayer: String
    let transcript: String

    enum CodingKeys: String, CodingKey {
        case caseID = "case_id"
        case locale
        case expectedEvent = "expected_event"
        case expectedPlayer = "expected_player"
        case expectedRelatedPlayer = "expected_related_player"
        case transcript
    }
}
