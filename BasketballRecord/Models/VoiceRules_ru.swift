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
            .init(keyword: "краска", eventPrefix: "stat.paint"),
            .init(keyword: "изнутри", eventPrefix: "stat.paint"),
            .init(keyword: "штрафной", eventPrefix: "stat.freeThrow"),
            .init(keyword: "штрафной бросок", eventPrefix: "stat.freeThrow"),
            .init(keyword: "бонус", eventPrefix: "stat.bonus"),
        ],
        madeStates: ["забил", "попал", "есть", "очко"],
        missedStates: ["промах", "мимо", "заблокировали", "не попал"],
        statEvents: [
            ("фол", "stat.foul"),
            ("подбор", "stat.rebound"),
            ("подбор в нападении", "stat.rebound"),
            ("подбор в защите", "stat.rebound"),
            ("передача", "stat.assist"),
            ("ассист", "stat.assist"),
            ("блок", "stat.block"),
            ("блок-шот", "stat.block"),
            ("перехват", "stat.steal"),
            ("потеря", "stat.turnover"),
            ("пробежка", "stat.turnover"),
            ("нарушение", "stat.turnover"),
        ],
        substitutionKeywords: ["замена", "меняем", "заменить"],
        commandEvents: [
            ("начало", "event.period"),
            ("старт", "event.period"),
            ("первая четверть", "event.period"),
            ("пауза", "event.pause"),
            ("тайм-аут", "event.pause"),
            ("продолжить", "event.pause"),
            ("конец", "event.game_end"),
            ("конец игры", "event.game_end"),
        ],
        fuzzyMap: []
    )
}
