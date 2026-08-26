import Foundation

enum BMIBand: String, CaseIterable, Hashable, Sendable {
    case underweight
    case normal
    case overweight
    case obese

    var titleKey: String {
        switch self {
        case .underweight: "bmi.band.underweight"
        case .normal: "bmi.band.normal"
        case .overweight: "bmi.band.overweight"
        case .obese: "bmi.band.obese"
        }
    }

    var chinaRangeKey: String {
        switch self {
        case .underweight: "bmi.range.china.underweight"
        case .normal: "bmi.range.china.normal"
        case .overweight: "bmi.range.china.overweight"
        case .obese: "bmi.range.china.obese"
        }
    }

    var whoRangeKey: String {
        switch self {
        case .underweight: "bmi.range.who.underweight"
        case .normal: "bmi.range.who.normal"
        case .overweight: "bmi.range.who.overweight"
        case .obese: "bmi.range.who.obese"
        }
    }
}

enum BMIClassifier {
    static let adultAgeYears = 18

    /// Chinese adult (WGOC) cutoffs used for the home tile and primary band.
    static func chinaBand(bmi: Double) -> BMIBand {
        if bmi < 18.5 { return .underweight }
        if bmi < 24.0 { return .normal }
        if bmi < 28.0 { return .overweight }
        return .obese
    }

    /// WHO adult cutoffs, shown only as a reference table.
    static func whoBand(bmi: Double) -> BMIBand {
        if bmi < 18.5 { return .underweight }
        if bmi < 25.0 { return .normal }
        if bmi < 30.0 { return .overweight }
        return .obese
    }

    enum Verdict: Equatable, Sendable {
        case none
        case notApplicable
        case band(BMIBand, assumedAdult: Bool)

        var titleKey: String? {
            switch self {
            case .none: nil
            case .notApplicable: "bmi.category.notApplicable"
            case .band(let band, _): band.titleKey
            }
        }

        var assumedAdult: Bool {
            if case .band(_, let assumed) = self { return assumed }
            return false
        }
    }

    static func ageYears(
        birthDate: Date,
        on now: Date,
        calendar: Calendar = .current
    ) -> Int? {
        let birth = calendar.startOfDay(for: birthDate)
        let day = calendar.startOfDay(for: now)
        guard birth <= day else { return nil }
        return calendar.dateComponents([.year], from: birth, to: day).year
    }

    static func classify(
        bmi: Double?,
        birthDate: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Verdict {
        guard let bmi else { return .none }
        if let birthDate {
            guard let age = ageYears(birthDate: birthDate, on: now, calendar: calendar) else {
                return .none
            }
            if age < adultAgeYears { return .notApplicable }
            return .band(chinaBand(bmi: bmi), assumedAdult: false)
        }
        return .band(chinaBand(bmi: bmi), assumedAdult: true)
    }

    /// Weight range whose BMI sits in the Chinese adult “normal” band (18.5...23.9).
    static func chinaHealthyWeightKg(heightCm: Double) -> (low: Double, high: Double)? {
        guard heightCm > 0 else { return nil }
        let meters = heightCm / 100
        let squared = meters * meters
        let low = MeasurementBounds.roundedToTenth(18.5 * squared)
        let high = MeasurementBounds.roundedToTenth(23.9 * squared)
        guard high >= low else { return nil }
        return (low, high)
    }
}
