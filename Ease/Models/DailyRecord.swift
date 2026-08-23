import Foundation
import SwiftData

@Model
final class DailyRecord {
    /// CloudKit requires non-optional stored properties to have defaults so remote
    /// records can materialize without calling `init(date:)`. Local inserts always
    /// go through `init(date:)`, which overwrites every stored property.
    var dayKey: String = ""
    var date: Date = Date.now
    /// Legacy snapshot from v1.0. Kept on the CloudKit schema as Optional.
    /// v1.1+ never writes this field; `WeightLog` is the source of truth.
    var weight: Double?
    /// Legacy snapshot from v1.0. Kept on the CloudKit schema as Optional.
    /// v1.1+ never writes this field; `WeightLog` is the source of truth.
    var bodyFat: Double?
    var dietStatusRaw: String?
    var tags: [String] = []
    var note: String?
    @Attribute(.externalStorage) var breakfastPhotoData: Data?
    @Attribute(.externalStorage) var lunchPhotoData: Data?
    @Attribute(.externalStorage) var dinnerPhotoData: Data?
    var updatedAt: Date = Date.now

    var dietStatus: DietStatus? {
        get { dietStatusRaw.flatMap(DietStatus.init(rawValue:)) }
        set { dietStatusRaw = newValue?.rawValue }
    }

    var variableTags: [VariableTag] {
        get {
            VariableTag.sanitized(tags.compactMap(VariableTag.init(rawValue:)))
        }
        set {
            tags = Array(VariableTag.sanitized(newValue).map(\.rawValue))
        }
    }

    init(date: Date, calendar: Calendar = .current) {
        let start = CalendarDay.startOfDay(date, calendar: calendar)
        self.dayKey = CalendarDay.dayKey(from: start, calendar: calendar)
        self.date = start
        self.weight = nil
        self.bodyFat = nil
        self.dietStatusRaw = nil
        self.tags = []
        self.note = nil
        self.breakfastPhotoData = nil
        self.lunchPhotoData = nil
        self.dinnerPhotoData = nil
        self.updatedAt = .now
    }

    func mealPhotoData(for slot: MealSlot) -> Data? {
        switch slot {
        case .breakfast: breakfastPhotoData
        case .lunch: lunchPhotoData
        case .dinner: dinnerPhotoData
        }
    }

    func setMealPhotoData(_ data: Data?, for slot: MealSlot) {
        switch slot {
        case .breakfast: breakfastPhotoData = data
        case .lunch: lunchPhotoData = data
        case .dinner: dinnerPhotoData = data
        }
    }

    var hasMealPhoto: Bool {
        breakfastPhotoData != nil || lunchPhotoData != nil || dinnerPhotoData != nil
    }
}
