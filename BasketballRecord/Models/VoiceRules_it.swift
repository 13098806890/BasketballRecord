import Foundation

extension VoiceRules {
    static let italian = VoiceRules(
        locale: Locale(identifier: "it-IT"),
        speechRecognizerLocale: Locale(identifier: "it-IT"),
        shotKeywords: [
            .init(keyword: "due", eventPrefix: "stat.two"),
            .init(keyword: "due punti", eventPrefix: "stat.two"),
            .init(keyword: "2", eventPrefix: "stat.two"),
            .init(keyword: "tre", eventPrefix: "stat.three"),
            .init(keyword: "tre punti", eventPrefix: "stat.three"),
            .init(keyword: "3", eventPrefix: "stat.three"),
            .init(keyword: "layup", eventPrefix: "stat.layup"),
            .init(keyword: "media", eventPrefix: "stat.midRange"),
            .init(keyword: "media distanza", eventPrefix: "stat.midRange"),
            .init(keyword: "dentro", eventPrefix: "stat.paint"),
            .init(keyword: "pitturato", eventPrefix: "stat.paint"),
            .init(keyword: "tiro libero", eventPrefix: "stat.freeThrow"),
            .init(keyword: "libero", eventPrefix: "stat.freeThrow"),
            .init(keyword: "bonus", eventPrefix: "stat.bonus"),
            .init(keyword: "e uno", eventPrefix: "stat.bonus"),
        ],
        madeStates: ["segnato", "dentro", "buono", "fatto"],
        missedStates: ["sbagliato", "fuori", "bloccato", "mancato"],
        statEvents: [
            ("fallo", "stat.foul"),
            ("rimbalzo", "stat.rebound"),
            ("rimbalzo offensivo", "stat.rebound"),
            ("rimbalzo difensivo", "stat.rebound"),
            ("assist", "stat.assist"),
            ("stoppata", "stat.block"),
            ("palla rubata", "stat.steal"),
            ("perse", "stat.turnover"),
            ("passi", "stat.turnover"),
            ("doppio dribbling", "stat.turnover"),
        ],
        substitutionKeywords: ["cambio", "sostituzione", "sostituisci", "entra"],
        commandEvents: [
            ("inizio", "event.period"),
            ("primo quarto", "event.period"),
            ("pausa", "event.pause"),
            ("timeout", "event.pause"),
            ("continuare", "event.pause"),
            ("riprendere", "event.pause"),
            ("fine", "event.game_end"),
            ("fine partita", "event.game_end"),
        ],
        fuzzyMap: []
    )
}
