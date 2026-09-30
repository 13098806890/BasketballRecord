import AVFoundation
import Foundation
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
        var resultRows: [String] = []

        engineLoop: for engineName in engineNames {
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
                        let context = rules.contextualStrings(playerNames: orderedNames(for: row, in: allRows))
                        result = try await VoiceASRFileTranscriber.transcribeSpeechTranscriber(url: audioURL, locale: Locale(identifier: row.locale), contextualStrings: context)
                    }
                } catch let error as VoiceASRFileTranscriberError {
                    switch error {
                    case .speechAuthorizationDenied, .recognizerUnavailable, .localeUnsupported, .modelUnavailable:
                        print("VOICE_ASR_UNAVAILABLE,\(engine.rawValue),\(error.localizedDescription)")
                        continue engineLoop
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
                            error: error.localizedDescription
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
                        error: error.localizedDescription
                    ))
                    continue
                }

                let parsed = await parsedResult(for: row, in: rows, transcript: result.transcript)
                resultRows.append(csvRow(
                    engine: engine.rawValue,
                    row: row,
                    transcript: result.transcript,
                    firstResultMilliseconds: result.firstResultMilliseconds,
                    finalResultMilliseconds: result.finalResultMilliseconds,
                    eventCode: parsed.eventCode,
                    playerMatch: parsed.playerMatch,
                    relatedPlayerMatch: parsed.relatedPlayerMatch
                ))
            }
        }

        guard !resultRows.isEmpty else {
            throw XCTSkip("No ASR evaluation rows were produced")
        }

        print("VOICE_ASR_HEADER,engine,case_id,transcript,first_result_ms,final_result_ms,event_code,player_match,related_player_match,error")
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

    private func parsedResult(for row: ManifestRow, in rows: [ManifestRow], transcript: String) async -> ParsedResult {
        let store = AppStore()
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
        recognizer.configureForFileEvaluation(store: store)
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
        recognizer.simulateText(transcript)
        for _ in 0..<8 {
            await Task.yield()
        }
        return ParsedResult(eventCode: code, playerMatch: playerMatch, relatedPlayerMatch: relatedPlayerMatch)
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
        error: String = ""
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
            error
        ].map(csvField).joined(separator: ",")
    }

    private func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
