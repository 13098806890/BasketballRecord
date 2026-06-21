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

    /// Polyphonic surname overrides: character → alternative pinyin readings.
    /// For a character that CFStringTransform converts to the wrong reading for surname use,
    /// list one or more alternative pinyin forms that should also be tried.
    /// Only populated for CJK locales; empty for others.
    let surnamePinyinOverrides: [Character: [String]]

    /// Bidirectional pinyin variant rules for generatePinyinVariants.
    /// Only populated for CJK locales; empty for others.
    let pinyinVariantRules: [(String, String)]

    /// Multi-pronunciation character overrides: character → all valid pinyin readings.
    /// For 多音字 characters like 长(chang/zhang), list all readings.
    /// generatePinyinVariants will produce variants for each alternative reading.
    /// Only populated for CJK locales with multi-pronunciation characters; empty for others.
    let multiPronunciations: [Character: [String]]

    // MARK: - Advanced matching features

    /// Whether to enable Levenshtein distance matching for player/team names.
    /// Provides character-level error tolerance for alphabetic languages.
    let useLevenshteinMatching: Bool

    /// Levenshtein distance thresholds: (shortNameThreshold, longNameThreshold)
    /// shortNameThreshold applies to names with < 4 characters
    /// longNameThreshold applies to names with >= 4 characters
    let levenshteinThreshold: (short: Int, long: Int)

    /// Whether to enable anchor-based matching (e.g., "James got three").
    /// Splits text using state words as anchors: left=player, anchor=state, right=action.
    /// Useful for languages where state words appear in the middle.
    let useAnchorMatching: Bool

    /// Anchor words for anchor-based matching (e.g., ["got", "get", "made", "missed"]).
    /// Only used when useAnchorMatching is true.
    let anchorWords: [String]

    // MARK: - Steal target rule

    /// Rule for extracting the target player in a steal+turnover dual action.
    struct StealTargetRule: Sendable {
        /// Where to extract the second player after the steal keyword is matched.
        enum ExtractFrom: String, Sendable, Codable {
            case rightText = "rightText"
            case leftTextAfterPlayer = "leftTextAfterPlayer"
        }

        var extractFrom: ExtractFrom = .rightText
        var prefixesToStrip: [String] = []
        var suffixesToStrip: [String] = []
        var segmentParticles: [String] = []
    }

    var stealTargetRule: StealTargetRule = StealTargetRule()

    func toPinyin(_ s: String) -> String {
        let mutable = NSMutableString(string: s) as CFMutableString
        CFStringTransform(mutable, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutable, nil, kCFStringTransformStripDiacritics, false)
        return (mutable as String).lowercased().trimmingCharacters(in: .whitespaces)
    }

    func fuzzyPinyin(_ s: String) -> String {
        let syllables = s.split(separator: " ").map { String($0) }
        return syllables.map { syl in
            var r = syl
            for (a, b) in fuzzyMap {
                r = r.replacingOccurrences(of: a, with: b)
            }
            return r
        }.joined(separator: " ")
    }

    func generatePinyinVariants(_ text: String) -> Set<String> {
        let basePinyin = toPinyin(text)
        var variants = Set<String>()
        variants.insert(basePinyin)
        let syllables = basePinyin.split(separator: " ").map(String.init)
        guard !syllables.isEmpty else { return variants }
        for (index, syllable) in syllables.enumerated() {
            for (from, to) in pinyinVariantRules {
                if syllable.contains(from) {
                    var modifiedSyllables = syllables
                    modifiedSyllables[index] = syllable.replacingOccurrences(of: from, with: to)
                    variants.insert(modifiedSyllables.joined(separator: " "))
                }
            }
        }
        if !multiPronunciations.isEmpty {
            let chars = Array(text)
            if chars.count == syllables.count {
                for (i, ch) in chars.enumerated() {
                    guard let alternatives = multiPronunciations[ch] else { continue }
                    for alt in alternatives where alt != syllables[i] {
                        var altSyllables = syllables
                        altSyllables[i] = alt
                        variants.insert(altSyllables.joined(separator: " "))
                        for (from, to) in pinyinVariantRules {
                            if alt.contains(from) {
                                var modified = altSyllables
                                modified[i] = alt.replacingOccurrences(of: from, with: to)
                                variants.insert(modified.joined(separator: " "))
                            }
                        }
                    }
                }
            }
        }
        let noSpace = basePinyin.replacingOccurrences(of: " ", with: "")
        if noSpace != basePinyin { variants.insert(noSpace) }
        return variants
    }

    func letterPinyin(_ ch: Character) -> String {
        switch ch {
        case "a": return "a"; case "b": return "bi"; case "c": return "ci"
        case "d": return "di"; case "e": return "yi"
        case "f": return "efu"; case "g": return "ji"; case "h": return "equ"
        case "i": return "ai"; case "j": return "ji"; case "k": return "ke"
        case "l": return "elou"; case "m": return "emu"; case "n": return "en"
        case "o": return "ou"; case "p": return "pi"; case "q": return "q"
        case "r": return "aer"; case "s": return "esi"; case "t": return "ti"
        case "u": return "you"; case "v": return "wei"; case "w": return "dabuliu"
        case "x": return "eks"; case "y": return "wai"; case "z": return "zei"
        default: return String(ch)
        }
    }

    func namePinyinVariants(_ name: String) -> [String] {
        let clean = toPinyin(name)
        var variants = [clean]
        let letters = name.lowercased().filter { $0.isLetter && $0.isASCII }
        if letters.count >= 1 && letters.count <= 4 {
            let letterPinyins = letters.map { letterPinyin($0) }
            variants.append(letterPinyins.joined(separator: " "))
            variants.append(String(letters))
            variants.append(letters.map { String($0) }.joined(separator: " "))
        }
        if !surnamePinyinOverrides.isEmpty {
            let chars = Array(name)
            let syllables = clean.split(separator: " ").map(String.init)
            guard syllables.count == chars.count else { return variants }
            for (i, ch) in chars.enumerated() {
                guard let alternatives = surnamePinyinOverrides[ch] else { continue }
                for alt in alternatives {
                    var altSyllables = syllables
                    altSyllables[i] = alt
                    variants.append(altSyllables.joined(separator: " "))
                }
            }
        }
        return variants
    }

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
