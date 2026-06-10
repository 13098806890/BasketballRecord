import Foundation

extension VoiceRules {
    static let japanese = VoiceRules(
        locale: Locale(identifier: "ja-JP"),
        speechRecognizerLocale: Locale(identifier: "ja-JP"),
        shotKeywords: [
            .init(keyword: "ツー", eventPrefix: "stat.two"),
            .init(keyword: "2", eventPrefix: "stat.two"),
            .init(keyword: "スリー", eventPrefix: "stat.three"),
            .init(keyword: "3", eventPrefix: "stat.three"),
            .init(keyword: "レイアップ", eventPrefix: "stat.layup"),
            .init(keyword: "ミドル", eventPrefix: "stat.midRange"),
            .init(keyword: "ペイント", eventPrefix: "stat.paint"),
            .init(keyword: "フリースロー", eventPrefix: "stat.freeThrow"),
            .init(keyword: "ボーナス", eventPrefix: "stat.bonus"),
        ],
        madeStates: ["入った", "成功", "決まった"],
        missedStates: ["外した", "不入り", "ミス", "ブロック"],
        statEvents: [
            ("ファウル", "stat.foul"),
            ("リバウンド", "stat.rebound"),
            ("アシスト", "stat.assist"),
            ("ブロック", "stat.block"),
            ("スティール", "stat.steal"),
            ("ターンオーバー", "stat.turnover"),
        ],
        substitutionKeywords: ["交代", "チェンジ", "入れ替え"],
        commandEvents: [
            ("開始", "event.period"),
            ("スタート", "event.period"),
            ("一時停止", "event.pause"),
            ("タイムアウト", "event.pause"),
            ("再開", "event.pause"),
            ("終了", "event.game_end"),
            ("試合終了", "event.game_end"),
        ],
        fuzzyMap: []
    )
}
