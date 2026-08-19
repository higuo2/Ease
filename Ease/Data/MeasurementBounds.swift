import Foundation

enum MeasurementBounds {
    static let weightKg = 30.0...150.0
    static let bodyFatPercent = 5.0...50.0
    static let heightCm = 100.0...250.0

    static func roundedToTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    static func validatedWeight(_ value: Double) throws -> Double {
        let rounded = roundedToTenth(value)
        guard weightKg.contains(rounded) else { throw EaseDataError.invalidWeight }
        return rounded
    }

    static func validatedBodyFat(_ value: Double) throws -> Double {
        let rounded = roundedToTenth(value)
        guard bodyFatPercent.contains(rounded) else { throw EaseDataError.invalidBodyFat }
        return rounded
    }

    static func validatedHeight(_ value: Double) throws -> Double {
        let rounded = roundedToTenth(value)
        guard heightCm.contains(rounded) else { throw EaseDataError.invalidProfile }
        return rounded
    }
}
