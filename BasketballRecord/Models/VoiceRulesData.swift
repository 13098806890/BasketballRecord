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

    static func load(language: String) -> VoiceRulesData? {
        switch language {
        case "zh-Hans", "zh": return .chineseSimplified
        case "zh-Hant-TW", "zh-Hant-HK": return .traditionalChinese
        case "en": return .english
        case "ja": return .japanese
        case "ko": return .korean
        case "de": return .german
        case "es": return .spanish
        case "fr": return .french
        case "it": return .italian
        case "ru": return .russian
        default: return nil
        }
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
            surnamePinyinOverrides: data.surnamePinyinOverrides?.reduce(into: [:]) { result, pair in
                if let key = pair.key.first { result[key] = pair.value }
            } ?? [:],
            pinyinVariantRules: data.pinyinVariantRules?.compactMap { pair in
                guard pair.count == 2 else { return nil }
                return (pair[0], pair[1])
            } ?? [],
            multiPronunciations: data.multiPronunciations?.reduce(into: [:]) { result, pair in
                if let key = pair.key.first { result[key] = pair.value }
            } ?? [:],
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
