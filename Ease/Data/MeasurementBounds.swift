import Foundation

enum MeasurementBounds {
    static let weightKg = 30.0...150.0
    static let bodyFatPercent = 5.0...50.0
    static let heightCm = 100.0...250.0
    static let sleepTargetHours = 4.0...12.0

    static func roundedToTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    static func roundedToHalf(_ value: Double) -> Double {
        (value * 2).rounded() / 2
    }

    static func roundedToStep(_ value: Double, step: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    static func clampedHour(_ value: Int) -> Int {
        min(max(value, 0), 23)
    }

    static func clampedMinute(_ value: Int) -> Int {
        min(max(value, 0), 59)
    }

    static func validatedSleepTarget(_ value: Double) throws -> Double {
        let rounded = roundedToHalf(value)
        guard sleepTargetHours.contains(rounded) else { throw EaseDataError.invalidProfile }
        return rounded
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
