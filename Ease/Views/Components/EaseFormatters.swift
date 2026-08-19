import Foundation

enum EaseFormatters {
    static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", locale: .current, value)
    }

    static func kg(_ value: Double) -> String {
        String(format: String(localized: "format.kg"), locale: .current, value)
    }

    static func lostKg(_ value: Double) -> String {
        String(format: String(localized: "format.lostKg"), locale: .current, value)
    }

    static func remainingKg(_ value: Double) -> String {
        String(format: String(localized: "format.remainingKg"), locale: .current, value)
    }

    static func targetKg(_ value: Double) -> String {
        String(format: String(localized: "format.targetKg"), locale: .current, value)
    }

    static func bmi(_ value: Double) -> String {
        String(format: String(localized: "format.bmi"), locale: .current, value)
    }

    static func bodyFat(_ value: Double) -> String {
        String(format: String(localized: "format.bodyFat"), locale: .current, value)
    }

    static func kcal(_ value: Double) -> String {
        String(format: String(localized: "format.kcal"), locale: .current, value)
    }

    static func hours(_ value: Double) -> String {
        String(format: String(localized: "format.hours"), locale: .current, value)
    }

    static func parseDecimal(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var normalized = trimmed
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "．", with: ".")

        let separators = normalized.filter { $0 == "." || $0 == "," }
        if separators.count > 1, let last = normalized.lastIndex(where: { $0 == "." || $0 == "," }) {
            let integerPart = normalized[..<last]
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: ".", with: "")
            let fractionPart = normalized[normalized.index(after: last)...]
            normalized = integerPart + "." + fractionPart
        } else {
            normalized = normalized.replacingOccurrences(of: ",", with: ".")
        }

        guard let value = Double(normalized) else { return nil }
        return MeasurementBounds.roundedToTenth(value)
    }
}
