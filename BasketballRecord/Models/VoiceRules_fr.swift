import Foundation

extension VoiceRules {
    static let french = VoiceRules(
        locale: Locale(identifier: "fr-FR"),
        speechRecognizerLocale: Locale(identifier: "fr-FR"),
        shotKeywords: [
            .init(keyword: "deux", eventPrefix: "stat.two"),
            .init(keyword: "2", eventPrefix: "stat.two"),
            .init(keyword: "trois", eventPrefix: "stat.three"),
            .init(keyword: "3", eventPrefix: "stat.three"),
            .init(keyword: "lay-up", eventPrefix: "stat.layup"),
            .init(keyword: "mi-distance", eventPrefix: "stat.midRange"),
            .init(keyword: "lancer franc", eventPrefix: "stat.freeThrow"),
            .init(keyword: "bonus", eventPrefix: "stat.bonus"),
        ],
        madeStates: ["marqué", "dedans", "bon"],
        missedStates: ["raté", "dehors", "contré"],
        statEvents: [
            ("faute", "stat.foul"),
            ("rebond", "stat.rebound"),
            ("passe", "stat.assist"),
            ("contre", "stat.block"),
            ("interception", "stat.steal"),
            ("perte de balle", "stat.turnover"),
        ],
        substitutionKeywords: ["remplacement", "changement", "substitution"],
        commandEvents: [
            ("début", "event.period"),
            ("pause", "event.pause"),
            ("temps mort", "event.pause"),
            ("continuer", "event.pause"),
            ("fin", "event.game_end"),
            ("fin du match", "event.game_end"),
        ],
        fuzzyMap: []
    )
}
