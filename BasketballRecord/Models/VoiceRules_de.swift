import Foundation

extension VoiceRules {
    static let german = VoiceRules(
        locale: Locale(identifier: "de-DE"),
        speechRecognizerLocale: Locale(identifier: "de-DE"),
        shotKeywords: [
            .init(keyword: "zwei", eventPrefix: "stat.two"),
            .init(keyword: "2", eventPrefix: "stat.two"),
            .init(keyword: "drei", eventPrefix: "stat.three"),
            .init(keyword: "3", eventPrefix: "stat.three"),
            .init(keyword: "layup", eventPrefix: "stat.layup"),
            .init(keyword: "mitteldistanz", eventPrefix: "stat.midRange"),
            .init(keyword: "freiwurf", eventPrefix: "stat.freeThrow"),
            .init(keyword: "bonus", eventPrefix: "stat.bonus"),
        ],
        madeStates: ["getroffen", "drin", "gut"],
        missedStates: ["verfehlt", "daneben", "blockiert"],
        statEvents: [
            ("foul", "stat.foul"),
            ("rebound", "stat.rebound"),
            ("assist", "stat.assist"),
            ("block", "stat.block"),
            ("steal", "stat.steal"),
            ("turnover", "stat.turnover"),
        ],
        substitutionKeywords: ["wechsel", "auswechslung", "ersetzen"],
        commandEvents: [
            ("start", "event.period"),
            ("pause", "event.pause"),
            ("auszeit", "event.pause"),
            ("weiter", "event.pause"),
            ("ende", "event.game_end"),
            ("spielende", "event.game_end"),
        ],
        fuzzyMap: []
    )
}
