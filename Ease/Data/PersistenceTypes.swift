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
    var weight: FieldUpdate<Double?> = .unchanged
    var bodyFat: FieldUpdate<Double?> = .unchanged
    var dietStatus: FieldUpdate<DietStatus?> = .unchanged
    var tags: FieldUpdate<[VariableTag]> = .unchanged
    var note: FieldUpdate<String?> = .unchanged

    var isEmpty: Bool {
        if case .unchanged = weight,
           case .unchanged = bodyFat,
           case .unchanged = dietStatus,
           case .unchanged = tags,
           case .unchanged = note {
            return true
        }
        return false
    }
}

enum EaseDataError: Error, Equatable {
    case emptyRecord
    case emptyPatch
    case invalidWeight
    case invalidBodyFat
    case futureDate
    case invalidProfile
}
