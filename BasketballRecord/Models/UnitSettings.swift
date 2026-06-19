import Foundation

enum HeightUnit: String, CaseIterable {
    case cm
    case ftIn = "ft_in"

    var displayName: String {
        switch self {
        case .cm: return "cm"
        case .ftIn: return "ft/in"
        }
    }
}

enum WeightUnit: String, CaseIterable {
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

    static func displayHeight(_ cmString: String) -> String {
        guard !cmString.isEmpty, let cm = Double(cmString), cm > 0 else { return cmString }
        switch heightUnit() {
        case .cm:
            return "\(Int(round(cm))) cm"
        case .ftIn:
            let totalInches = cm / 2.54
            let feet = Int(totalInches / 12)
            let inches = Int(round(totalInches.truncatingRemainder(dividingBy: 12)))
            return "\(feet)'\(inches)\""
        }
    }

    static func displayWeight(_ kgString: String) -> String {
        guard !kgString.isEmpty, let kg = Double(kgString), kg > 0 else { return kgString }
        switch weightUnit() {
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

    static func editorHeightUnitLabel() -> String {
        heightUnit().displayName
    }

    static func editorWeightUnitLabel() -> String {
        weightUnit().displayName
    }
}
