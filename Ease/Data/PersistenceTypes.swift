import Foundation

enum FieldUpdate<Value: Sendable>: Sendable {
    case unchanged
    case set(Value)

    func apply(to current: inout Value) {
        if case .set(let value) = self {
            current = value
        }
    }
}

struct DailyRecordPatch: Sendable {
    /// Routed to a new `WeightLog`. Never written onto `DailyRecord` after v1.1.
    var weight: FieldUpdate<Double?> = .unchanged
    /// Stored on the inserted `WeightLog` when `weight` is set.
    var bodyFat: FieldUpdate<Double?> = .unchanged
    var dietStatus: FieldUpdate<DietStatus?> = .unchanged
    var tags: FieldUpdate<[VariableTag]> = .unchanged
    var note: FieldUpdate<String?> = .unchanged
    /// Documents-directory JPEG filename only.
    var breakfastPhoto: FieldUpdate<String?> = .unchanged
    var lunchPhoto: FieldUpdate<String?> = .unchanged
    var dinnerPhoto: FieldUpdate<String?> = .unchanged

    var isEmpty: Bool {
        if case .unchanged = weight,
           case .unchanged = bodyFat,
           case .unchanged = dietStatus,
           case .unchanged = tags,
           case .unchanged = note,
           case .unchanged = breakfastPhoto,
           case .unchanged = lunchPhoto,
           case .unchanged = dinnerPhoto {
            return true
        }
        return false
    }

    mutating func setMealPhotoFileName(_ fileName: String?, for slot: MealSlot) {
        switch slot {
        case .breakfast: breakfastPhoto = .set(fileName)
        case .lunch: lunchPhoto = .set(fileName)
        case .dinner: dinnerPhoto = .set(fileName)
        }
    }
}

enum EaseDataError: Error, Equatable {
    case emptyRecord
    case emptyPatch
    case invalidWeight
    case invalidBodyFat
    case futureDate
    case invalidProfile
    case invalidMetric
    case tooManyCustomMetrics
}

struct MetricLogDraft: Sendable, Equatable {
    var timestamp: Date
    var metricKey: String
    var value: Double
}
