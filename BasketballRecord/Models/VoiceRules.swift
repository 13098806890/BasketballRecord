import Foundation

/// Language-specific voice matching rules.
/// Each language provides its own implementation defining:
/// - Shot keywords and their event prefixes
/// - State words (made/missed)
/// - Non-shot action keywords
/// - Substitution keywords
/// - Command keywords
struct VoiceRules: Sendable {
    let locale: Locale
    let speechRecognizerLocale: Locale

    struct ShotDef: Sendable {
        let keyword: String          // e.g. "三分", "three"
        let eventPrefix: String      // e.g. "stat.three"
    }

    let shotKeywords: [ShotDef]
    let madeStates: [String]
    let missedStates: [String]

    /// Non-shot stat events: (keyword, eventCode)
    let statEvents: [(keyword: String, eventCode: String)]

    /// Keywords that trigger substitution
    let substitutionKeywords: [String]

    /// Command events: (keyword, eventCode)
    let commandEvents: [(keyword: String, eventCode: String)]

    /// Additional pinyin/fuzzy normalization per language (empty for non-CJK)
    let fuzzyMap: [(String, String)]

    /// Detect the best rule set for the current app language.
    static func forCurrentAppLanguage() -> VoiceRules {
        let preferredLang = Bundle.main.preferredLocalizations.first ?? "zh-Hans"
        switch preferredLang {
        case "en": return .english
        case "ja": return .japanese
        case "ko": return .korean
        case "de": return .german
        case "es": return .spanish
        case "fr": return .french
        case "it": return .italian
        case "ru": return .russian
        case "zh-Hant-TW", "zh-Hant-HK": return .traditionalChinese
        case "zh-Hans", "zh": fallthrough
        default: return .chinese
        }
    }

    /// All supported rule sets for testing.
    static var allSupported: [VoiceRules] {
        [.chinese, .traditionalChinese, .english, .japanese, .korean, .german, .spanish, .french, .italian, .russian]
    }
}
