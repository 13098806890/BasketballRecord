import Foundation

struct VoiceRulesData: Decodable {
    let locale: String
    let speechRecognizerLocale: String
    let shotKeywords: [ShotKeywordData]
    let madeStates: [String]
    let missedStates: [String]
    let statEvents: [[String]]
    let substitutionKeywords: [String]
    let commandEvents: [[String]]
    let fuzzyMap: [[String]]?
    let surnamePinyinOverrides: [String: [String]]?
    let pinyinVariantRules: [[String]]?
    let multiPronunciations: [String: [String]]?
    let useLevenshteinMatching: Bool
    let levenshteinThresholdShort: Int
    let levenshteinThresholdLong: Int
    let useAnchorMatching: Bool
    let anchorWords: [String]
    let stealTargetRule: StealTargetRuleData?

    struct ShotKeywordData: Decodable {
        let keyword: String
        let eventPrefix: String
    }

    struct StealTargetRuleData: Decodable {
        var extractFrom: String?
        var prefixesToStrip: [String]?
        var suffixesToStrip: [String]?
        var segmentParticles: [String]?
    }

    private static let embeddedJSON: [String: String] = [
        "en": Self.loadEmbedded("voice_rules_en"),
        "zh": Self.loadEmbedded("voice_rules_zh"),
        "zh_Hant": Self.loadEmbedded("voice_rules_zh_Hant"),
        "ja": Self.loadEmbedded("voice_rules_ja"),
        "ko": Self.loadEmbedded("voice_rules_ko"),
        "de": Self.loadEmbedded("voice_rules_de"),
        "es": Self.loadEmbedded("voice_rules_es"),
        "fr": Self.loadEmbedded("voice_rules_fr"),
        "it": Self.loadEmbedded("voice_rules_it"),
        "ru": Self.loadEmbedded("voice_rules_ru"),
    ]

    private static func loadEmbedded(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let string = String(data: data, encoding: .utf8)
        else { return "" }
        return string
    }

    static func load(language: String) -> VoiceRulesData? {
        let key: String
        switch language {
        case "en": key = "en"
        case "zh-Hans", "zh": key = "zh"
        case "zh-Hant-TW", "zh-Hant-HK": key = "zh_Hant"
        case "ja": key = "ja"
        case "ko": key = "ko"
        case "de": key = "de"
        case "es": key = "es"
        case "fr": key = "fr"
        case "it": key = "it"
        case "ru": key = "ru"
        default: return nil
        }
        guard let jsonString = embeddedJSON[key], !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(VoiceRulesData.self, from: data)
        else { return nil }
        return decoded
    }
}

extension VoiceRules {
    init(data: VoiceRulesData) {
        self.init(
            locale: Locale(identifier: data.locale),
            speechRecognizerLocale: Locale(identifier: data.speechRecognizerLocale),
            shotKeywords: data.shotKeywords.map { ShotDef(keyword: $0.keyword, eventPrefix: $0.eventPrefix) },
            madeStates: data.madeStates,
            missedStates: data.missedStates,
            statEvents: data.statEvents.compactMap { pair in
                guard pair.count == 2 else { return nil }
                return (pair[0], pair[1])
            },
            substitutionKeywords: data.substitutionKeywords,
            commandEvents: data.commandEvents.compactMap { pair in
                guard pair.count == 2 else { return nil }
                return (pair[0], pair[1])
            },
            fuzzyMap: data.fuzzyMap?.compactMap { pair in
                guard pair.count == 2 else { return nil }
                return (pair[0], pair[1])
            } ?? [],
            surnamePinyinOverrides: data.surnamePinyinOverrides?.mapValues { $0 } ?? [:],
            pinyinVariantRules: data.pinyinVariantRules?.compactMap { pair in
                guard pair.count == 2 else { return nil }
                return (pair[0], pair[1])
            } ?? [],
            multiPronunciations: data.multiPronunciations?.mapValues { $0 } ?? [:],
            useLevenshteinMatching: data.useLevenshteinMatching,
            levenshteinThreshold: (data.levenshteinThresholdShort, data.levenshteinThresholdLong),
            useAnchorMatching: data.useAnchorMatching,
            anchorWords: data.anchorWords,
            stealTargetRule: .init(
                extractFrom: data.stealTargetRule.flatMap { StealTargetRule.ExtractFrom(rawValue: $0.extractFrom ?? "rightText") } ?? .rightText,
                prefixesToStrip: data.stealTargetRule?.prefixesToStrip ?? [],
                suffixesToStrip: data.stealTargetRule?.suffixesToStrip ?? [],
                segmentParticles: data.stealTargetRule?.segmentParticles ?? []
            )
        )
    }
}
