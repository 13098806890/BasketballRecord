import Foundation

extension VoiceRules {
    static let russian = VoiceRules(
        locale: Locale(identifier: "ru-RU"),
        speechRecognizerLocale: Locale(identifier: "ru-RU"),
        shotKeywords: [
            .init(keyword: "два", eventPrefix: "stat.two"),
            .init(keyword: "2", eventPrefix: "stat.two"),
            .init(keyword: "три", eventPrefix: "stat.three"),
            .init(keyword: "3", eventPrefix: "stat.three"),
            .init(keyword: "лей-ап", eventPrefix: "stat.layup"),
            .init(keyword: "средний", eventPrefix: "stat.midRange"),
            .init(keyword: "штрафной", eventPrefix: "stat.freeThrow"),
            .init(keyword: "бонус", eventPrefix: "stat.bonus"),
        ],
        madeStates: ["забил", "попал", "есть"],
        missedStates: ["промах", "мимо", "заблокировали"],
        statEvents: [
            ("фол", "stat.foul"),
            ("подбор", "stat.rebound"),
            ("передача", "stat.assist"),
            ("блок", "stat.block"),
            ("перехват", "stat.steal"),
            ("потеря", "stat.turnover"),
        ],
        substitutionKeywords: ["замена", "меняем"],
        commandEvents: [
            ("начало", "event.period"),
            ("пауза", "event.pause"),
            ("тайм-аут", "event.pause"),
            ("продолжить", "event.pause"),
            ("конец", "event.game_end"),
            ("конец игры", "event.game_end"),
        ],
        fuzzyMap: []
    )
}
