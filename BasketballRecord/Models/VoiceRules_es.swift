import Foundation

extension VoiceRules {
    static let spanish = VoiceRules(
        locale: Locale(identifier: "es-ES"),
        speechRecognizerLocale: Locale(identifier: "es-ES"),
        shotKeywords: [
            .init(keyword: "dos", eventPrefix: "stat.two"),
            .init(keyword: "2", eventPrefix: "stat.two"),
            .init(keyword: "tres", eventPrefix: "stat.three"),
            .init(keyword: "3", eventPrefix: "stat.three"),
            .init(keyword: "bandeja", eventPrefix: "stat.layup"),
            .init(keyword: "media", eventPrefix: "stat.midRange"),
            .init(keyword: "tiro libre", eventPrefix: "stat.freeThrow"),
            .init(keyword: "bonus", eventPrefix: "stat.bonus"),
        ],
        madeStates: ["encestado", "dentro", "bueno"],
        missedStates: ["fallado", "fuera", "bloqueado"],
        statEvents: [
            ("falta", "stat.foul"),
            ("rebote", "stat.rebound"),
            ("asistencia", "stat.assist"),
            ("bloqueo", "stat.block"),
            ("robo", "stat.steal"),
            ("perdida", "stat.turnover"),
        ],
        substitutionKeywords: ["cambio", "sustitución", "reemplazo"],
        commandEvents: [
            ("inicio", "event.period"),
            ("pausa", "event.pause"),
            ("tiempo muerto", "event.pause"),
            ("continuar", "event.pause"),
            ("final", "event.game_end"),
            ("fin del partido", "event.game_end"),
        ],
        fuzzyMap: []
    )
}
