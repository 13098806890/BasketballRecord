import Foundation

enum HeightUnit: String, CaseIterable, Codable {
    case cm
    case ftIn = "ft_in"

    var displayName: String {
        switch self {
        case .cm: return "cm"
        case .ftIn: return "ft/in"
        }
    }
}

enum WeightUnit: String, CaseIterable, Codable {
    case kg
    case lbs

    var displayName: String {
        switch self {
        case .kg: return "kg"
        case .lbs: return "lbs"
        }
    }
}

enum UnitSettings {
    static let heightUnitKey = "height_unit"
    static let weightUnitKey = "weight_unit"

    static var defaultHeightUnit: HeightUnit {
        let isImperial = Locale.current.measurementSystem == .us || Locale.current.measurementSystem == .uk
        return isImperial ? .ftIn : .cm
    }

    static var defaultWeightUnit: WeightUnit {
        let isImperial = Locale.current.measurementSystem == .us || Locale.current.measurementSystem == .uk
        return isImperial ? .lbs : .kg
    }

    static func heightUnit() -> HeightUnit {
        let raw = UserDefaults.standard.string(forKey: heightUnitKey) ?? ""
        return HeightUnit(rawValue: raw) ?? defaultHeightUnit
    }

    static func weightUnit() -> WeightUnit {
        let raw = UserDefaults.standard.string(forKey: weightUnitKey) ?? ""
        return WeightUnit(rawValue: raw) ?? defaultWeightUnit
    }

    static func displayHeight(_ cmString: String, unit: HeightUnit) -> String {
        guard !cmString.isEmpty, let cm = Double(cmString), cm > 0 else { return cmString }
        switch unit {
        case .cm:
            return "\(Int(round(cm))) cm"
        case .ftIn:
            let totalInches = cm / 2.54
            let feet = Int(totalInches / 12)
            let roundedInches = Int(round(totalInches.truncatingRemainder(dividingBy: 12)))
            let inches = roundedInches == 12 ? 0 : roundedInches
            let adjustedFeet = feet + (roundedInches == 12 ? 1 : 0)
            return "\(adjustedFeet)'\(inches)\""
        }
    }

    static func displayWeight(_ kgString: String, unit: WeightUnit) -> String {
        guard !kgString.isEmpty, let kg = Double(kgString), kg > 0 else { return kgString }
        switch unit {
        case .kg:
            if kg == round(kg) {
                return "\(Int(kg)) kg"
            } else {
                return String(format: "%.1f kg", kg)
            }
        case .lbs:
            let lbs = kg * 2.20462
            return "\(Int(round(lbs))) lbs"
        }
    }

    static func displayHeight(_ cmString: String) -> String {
        displayHeight(cmString, unit: heightUnit())
    }

    static func displayWeight(_ kgString: String) -> String {
        displayWeight(kgString, unit: weightUnit())
    }

    static func editorHeightValue(_ cmString: String, unit: HeightUnit) -> String {
        guard let cm = Double(cmString), cm > 0 else { return cmString }
        switch unit {
        case .cm:
            return canonicalNumber(cm)
        case .ftIn:
            return displayHeight(cmString, unit: .ftIn)
        }
    }

    static func editorWeightValue(_ kgString: String, unit: WeightUnit) -> String {
        guard let kg = Double(kgString), kg > 0 else { return kgString }
        switch unit {
        case .kg:
            return canonicalNumber(kg)
        case .lbs:
            return "\(Int(round(kg * 2.20462)))"
        }
    }

    static func canonicalHeight(_ input: String, unit: HeightUnit) -> String {
        guard let cm = heightInCentimeters(input, unit: unit), cm > 0 else { return input }
        return canonicalNumber(cm)
    }

    static func canonicalWeight(_ input: String, unit: WeightUnit) -> String {
        guard let value = numericValue(input), value > 0 else { return input }
        let kg = unit == .kg ? value : value / 2.20462
        return canonicalNumber(kg)
    }

    private static func heightInCentimeters(_ input: String, unit: HeightUnit) -> Double? {
        switch unit {
        case .cm:
            return numericValue(input)
        case .ftIn:
            let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
            if let apostropheIndex = trimmed.firstIndex(of: "'") {
                let feetText = String(trimmed[..<apostropheIndex])
                let remainder = trimmed[trimmed.index(after: apostropheIndex)...]
                    .replacingOccurrences(of: "\"", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard let feet = numericValue(feetText), let inches = numericValue(remainder) else { return nil }
                return (feet * 12 + inches) * 2.54
            }
            return numericValue(trimmed).map { $0 * 2.54 }
        }
    }

    private static func numericValue(_ input: String) -> Double? {
        let normalized = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private static func canonicalNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return "\(Int(value))"
        }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    static func editorHeightUnitLabel() -> String {
        heightUnit().displayName
    }

    static func editorWeightUnitLabel() -> String {
        weightUnit().displayName
    }
}
