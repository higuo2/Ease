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

enum BMIStandard: String, CaseIterable, Identifiable, Sendable {
    case china
    case who

    var id: String { rawValue }

    var pickerKey: String {
        switch self {
        case .china: "bmi.standard.china.short"
        case .who: "bmi.standard.who.short"
        }
    }

    /// Exclusive upper bounds for underweight / normal / overweight. Obese is open-ended.
    var exclusiveUppers: (underweight: Double, normal: Double, overweight: Double) {
        switch self {
        case .china: (18.5, 24.0, 28.0)
        case .who: (18.5, 25.0, 30.0)
        }
    }

    var normalInclusiveUpper: Double {
        switch self {
        case .china: 23.9
        case .who: 24.9
        }
    }
}

enum BMIClassifier {
    static let adultAgeYears = 18
    static let barMinBMI = 15.0
    static let barMaxBMI = 40.0

    /// Chinese adult (WGOC) cutoffs used for the home tile and the default sheet standard.
    static func chinaBand(bmi: Double) -> BMIBand {
        if bmi < 18.5 { return .underweight }
        if bmi < 24.0 { return .normal }
        if bmi < 28.0 { return .overweight }
        return .obese
    }

    /// WHO adult cutoffs, used only when the BMI sheet picker is on WHO.
    static func whoBand(bmi: Double) -> BMIBand {
        if bmi < 18.5 { return .underweight }
        if bmi < 25.0 { return .normal }
        if bmi < 30.0 { return .overweight }
        return .obese
    }

    static func band(bmi: Double, standard: BMIStandard) -> BMIBand {
        switch standard {
        case .china: chinaBand(bmi)
        case .who: whoBand(bmi)
        }
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

        var showsNeedle: Bool {
            if case .band = self { return true }
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
        calendar: Calendar = .current,
        standard: BMIStandard = .china
    ) -> Verdict {
        guard let bmi else { return .none }
        if let birthDate {
            guard let age = ageYears(birthDate: birthDate, on: now, calendar: calendar) else {
                return .none
            }
            if age < adultAgeYears { return .notApplicable }
            return .band(band(bmi: bmi, standard: standard), assumedAdult: false)
        }
        return .band(band(bmi: bmi, standard: standard), assumedAdult: true)
    }

    static func chinaHealthyWeightKg(heightCm: Double) -> (low: Double, high: Double)? {
        healthyWeightKg(heightCm: heightCm, standard: .china)
    }

    static func healthyWeightKg(
        heightCm: Double,
        standard: BMIStandard
    ) -> (low: Double, high: Double)? {
        guard heightCm > 0 else { return nil }
        let meters = heightCm / 100
        let squared = meters * meters
        let low = MeasurementBounds.roundedToTenth(18.5 * squared)
        let high = MeasurementBounds.roundedToTenth(standard.normalInclusiveUpper * squared)
        guard high >= low else { return nil }
        return (low, high)
    }

    /// Needle position on the sheet bar, clamped to `barMinBMI...barMaxBMI`.
    static func barFraction(bmi: Double) -> Double {
        let span = barMaxBMI - barMinBMI
        guard span > 0 else { return 0 }
        return min(max((bmi - barMinBMI) / span, 0), 1)
    }

    static func bandFractions(standard: BMIStandard) -> [BMIBand: Double] {
        let cuts = standard.exclusiveUppers
        let edges = [barMinBMI, cuts.underweight, cuts.normal, cuts.overweight, barMaxBMI]
        let span = barMaxBMI - barMinBMI
        var result: [BMIBand: Double] = [:]
        for (index, band) in BMIBand.allCases.enumerated() {
            result[band] = (edges[index + 1] - edges[index]) / span
        }
        return result
    }
}
