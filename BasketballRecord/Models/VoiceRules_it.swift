import Foundation

extension VoiceRules {
    static let italian = VoiceRules(
        locale: Locale(identifier: "it-IT"),
        speechRecognizerLocale: Locale(identifier: "it-IT"),
        shotKeywords: [
            .init(keyword: "due", eventPrefix: "stat.two"),
            .init(keyword: "2", eventPrefix: "stat.two"),
            .init(keyword: "tre", eventPrefix: "stat.three"),
            .init(keyword: "3", eventPrefix: "stat.three"),
            .init(keyword: "layup", eventPrefix: "stat.layup"),
            .init(keyword: "media", eventPrefix: "stat.midRange"),
            .init(keyword: "tiro libero", eventPrefix: "stat.freeThrow"),
            .init(keyword: "bonus", eventPrefix: "stat.bonus"),
        ],
        madeStates: ["segnato", "dentro", "buono"],
        missedStates: ["sbagliato", "fuori", "bloccato"],
        statEvents: [
            ("fallo", "stat.foul"),
            ("rimbalzo", "stat.rebound"),
            ("assist", "stat.assist"),
            ("stoppata", "stat.block"),
            ("palla rubata", "stat.steal"),
            ("perse", "stat.turnover"),
        ],
        substitutionKeywords: ["cambio", "sostituzione"],
        commandEvents: [
            ("inizio", "event.period"),
            ("pausa", "event.pause"),
            ("timeout", "event.pause"),
            ("continuare", "event.pause"),
            ("fine", "event.game_end"),
            ("fine partita", "event.game_end"),
        ],
        fuzzyMap: []
    )
}
