import Foundation

extension VoiceRules {
    static let korean = VoiceRules(
        locale: Locale(identifier: "ko-KR"),
        speechRecognizerLocale: Locale(identifier: "ko-KR"),
        shotKeywords: [
            .init(keyword: "투", eventPrefix: "stat.two"),
            .init(keyword: "2", eventPrefix: "stat.two"),
            .init(keyword: "쓰리", eventPrefix: "stat.three"),
            .init(keyword: "3", eventPrefix: "stat.three"),
            .init(keyword: "레이업", eventPrefix: "stat.layup"),
            .init(keyword: "미드", eventPrefix: "stat.midRange"),
            .init(keyword: "페인트", eventPrefix: "stat.paint"),
            .init(keyword: "자유투", eventPrefix: "stat.freeThrow"),
            .init(keyword: "프리스로우", eventPrefix: "stat.freeThrow"),
            .init(keyword: "보너스", eventPrefix: "stat.bonus"),
        ],
        madeStates: ["성공", "들어감"],
        missedStates: ["실패", "빗나감", "블록"],
        statEvents: [
            ("파울", "stat.foul"),
            ("리바운드", "stat.rebound"),
            ("어시스트", "stat.assist"),
            ("블록", "stat.block"),
            ("스틸", "stat.steal"),
            ("턴오버", "stat.turnover"),
        ],
        substitutionKeywords: ["교체", "체인지"],
        commandEvents: [
            ("시작", "event.period"),
            ("일시정지", "event.pause"),
            ("타임아웃", "event.pause"),
            ("재개", "event.pause"),
            ("종료", "event.game_end"),
            ("경기종료", "event.game_end"),
        ],
        fuzzyMap: []
    )
}
