import Foundation
import SwiftData

@Model
final class DailyRecord {
    /// CloudKit requires non-optional stored properties to have defaults so remote
    /// records can materialize without calling `init(date:)`. Local inserts always
    /// go through `init(date:)`, which overwrites every stored property.
    var dayKey: String = ""
    var date: Date = Date.now
    var weight: Double?
    var bodyFat: Double?
    var dietStatusRaw: String?
    var tags: [String] = []
    var note: String?
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
            tags = VariableTag.sanitized(newValue).map(\.rawValue)
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
        self.updatedAt = .now
    }
}
