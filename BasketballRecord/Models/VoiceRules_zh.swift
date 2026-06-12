import Foundation

extension VoiceRules {
    static let chinese = VoiceRules(
        locale: Locale(identifier: "zh-CN"),
        speechRecognizerLocale: Locale(identifier: "zh-CN"),
        shotKeywords: [
            .init(keyword: "两分", eventPrefix: "stat.two"),
            .init(keyword: "2分", eventPrefix: "stat.two"),
            .init(keyword: "三分", eventPrefix: "stat.three"),
            .init(keyword: "3分", eventPrefix: "stat.three"),
            .init(keyword: "上篮", eventPrefix: "stat.layup"),
            .init(keyword: "中投", eventPrefix: "stat.midRange"),
            .init(keyword: "中距离", eventPrefix: "stat.midRange"),
            .init(keyword: "篮下", eventPrefix: "stat.paint"),
            .init(keyword: "内线", eventPrefix: "stat.paint"),
            .init(keyword: "罚球", eventPrefix: "stat.freeThrow"),
            .init(keyword: "罚篮", eventPrefix: "stat.freeThrow"),
            .init(keyword: "发球", eventPrefix: "stat.freeThrow"),
            .init(keyword: "加罚", eventPrefix: "stat.bonus"),
            .init(keyword: "山分", eventPrefix: "stat.three"),
            .init(keyword: "散分", eventPrefix: "stat.three"),
            .init(keyword: "三份", eventPrefix: "stat.three"),
            .init(keyword: "法球", eventPrefix: "stat.freeThrow"),
            .init(keyword: "上南", eventPrefix: "stat.layup"),
            .init(keyword: "桑兰", eventPrefix: "stat.layup"),
            .init(keyword: "总投", eventPrefix: "stat.midRange"),
            .init(keyword: "南夏", eventPrefix: "stat.paint"),
            .init(keyword: "加法", eventPrefix: "stat.bonus"),
        ],
        madeStates: ["命中", "进", "得分", "成功"],
        missedStates: ["未中", "没中", "不中", "不进", "没进", "打铁"],
        statEvents: [
            ("犯规", "stat.foul"),
            ("篮板", "stat.rebound"),
            ("板", "stat.rebound"),
            ("nanban", "stat.rebound"),
            ("nan ban", "stat.rebound"),
            ("前场板", "stat.rebound"),
            ("后场板", "stat.rebound"),
            ("抢板", "stat.rebound"),
            ("助攻", "stat.assist"),
            ("盖帽", "stat.block"),
            ("封盖", "stat.block"),
            ("抢断", "stat.steal"),
            ("断球", "stat.steal"),
            ("失误", "stat.turnover"),
            ("方归", "stat.foul"),
            ("lan ban", "stat.rebound"),
            ("兰板", "stat.rebound"),
            ("主攻", "stat.assist"),
            ("概貌", "stat.block"),
            ("强段", "stat.steal"),
            ("失物", "stat.turnover"),
            ("走步", "stat.turnover"),
            ("违例", "stat.turnover"),
        ],
        substitutionKeywords: ["换人", "替换", "换上", "换下", "换"],
        commandEvents: [
            ("开始", "event.period"),
            ("第一节", "event.period"),
            ("第1节", "event.period"),
            ("第二节", "event.period"),
            ("第2节", "event.period"),
            ("第三节", "event.period"),
            ("第3节", "event.period"),
            ("第四节", "event.period"),
            ("第4节", "event.period"),
            ("下一节", "event.period"),
            ("暂停", "event.pause"),
            ("停表", "event.pause"),
            ("继续", "event.pause"),
            ("继续比赛", "event.pause"),
            ("比赛继续", "event.pause"),
        ],
        fuzzyMap: [
            ("zh", "z"), ("ch", "c"), ("sh", "s"),
            ("r", "l"),
            ("eng", "en"), ("ing", "in"), ("ang", "an"),
        ],
        surnamePinyinOverrides: [
            "曾": ["zeng"],        // surname: Zēng, not Céng
            "单": ["shan"],        // surname: Shàn, not Dān
            "朴": ["piao"],        // surname: Piáo (Korean origin), not Pǔ
            "解": ["xie"],         // surname: Xiè, not Jiě
            "区": ["ou"],          // surname: Ōu, not Qū
            "仇": ["qiu"],         // surname: Qiú, not Chóu
            "盖": ["ge"],          // surname: Gě, not Gài
            "查": ["zha"],         // surname: Zhā, not Chá
            "华": ["hua"],         // surname: Huà, not Huá (both common)
            "缪": ["miao"],        // surname: Miào, not Miù
            "覃": ["qin"],         // surname: Qín, not Tán
            "芮": ["rui"],         // surname: Ruì
            "逄": ["pang"],        // surname: Páng
        ]
    )
}
