import Foundation

extension VoiceRules {
    static let english = VoiceRules(
        locale: Locale(identifier: "en-US"),
        speechRecognizerLocale: Locale(identifier: "en-US"),
        shotKeywords: [
            .init(keyword: "two", eventPrefix: "stat.two"),
            .init(keyword: "2", eventPrefix: "stat.two"),
            .init(keyword: "three", eventPrefix: "stat.three"),
            .init(keyword: "3", eventPrefix: "stat.three"),
            .init(keyword: "layup", eventPrefix: "stat.layup"),
            .init(keyword: "mid", eventPrefix: "stat.midRange"),
            .init(keyword: "paint", eventPrefix: "stat.paint"),
            .init(keyword: "free throw", eventPrefix: "stat.freeThrow"),
            .init(keyword: "foul shot", eventPrefix: "stat.freeThrow"),
            .init(keyword: "bonus", eventPrefix: "stat.bonus"),
        ],
        madeStates: ["made", "in", "good", "score"],
        missedStates: ["missed", "no", "miss", "blocked", "out", "airball"],
        statEvents: [
            ("foul", "stat.foul"),
            ("rebound", "stat.rebound"),
            ("board", "stat.rebound"),
            ("assist", "stat.assist"),
            ("block", "stat.block"),
            ("steal", "stat.steal"),
            ("turnover", "stat.turnover"),
            ("travel", "stat.turnover"),
            ("violation", "stat.turnover"),
        ],
        substitutionKeywords: ["sub", "substitution", "replace", "swap", "change"],
        commandEvents: [
            ("start", "event.period"),
            ("begin", "event.period"),
            ("tip off", "event.period"),
            ("pause", "event.pause"),
            ("timeout", "event.pause"),
            ("resume", "event.pause"),
            ("continue", "event.pause"),
            ("end", "event.game_end"),
            ("finish", "event.game_end"),
            ("game over", "event.game_end"),
        ],
        fuzzyMap: []  // English doesn't need pinyin normalization
    )
}
