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
    /// Legacy in-DB meal blobs (briefly shipped). Kept forever for CloudKit/SwiftData
    /// compatibility — never delete these attributes. Runtime photos use filenames.
    @Attribute(.externalStorage) var breakfastPhotoData: Data?
    @Attribute(.externalStorage) var lunchPhotoData: Data?
    @Attribute(.externalStorage) var dinnerPhotoData: Data?
    /// Sandbox JPEG filename in Documents (not raw image bytes).
    var breakfastPhotoFileName: String?
    var lunchPhotoFileName: String?
    var dinnerPhotoFileName: String?
    /// Extra meal slots (afternoon tea, late night, custom). Breakfast/lunch/dinner
    /// never live here. Decode failure yields an empty array and does not fail the record.
    var extraMealsJSON: String? = nil
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

    var extraMeals: [ExtraMealPhoto] {
        get { ExtraMealPhoto.decode(extraMealsJSON) }
        set { extraMealsJSON = ExtraMealPhoto.encode(newValue) }
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
        self.breakfastPhotoFileName = nil
        self.lunchPhotoFileName = nil
        self.dinnerPhotoFileName = nil
        self.extraMealsJSON = nil
        self.updatedAt = .now
    }

    func mealPhotoFileName(for slot: MealSlot) -> String? {
        switch slot {
        case .breakfast: breakfastPhotoFileName
        case .lunch: lunchPhotoFileName
        case .dinner: dinnerPhotoFileName
        default: extraMeals.first(where: { $0.id == slot.id })?.fileName
        }
    }

    func setMealPhotoFileName(_ fileName: String?, for slot: MealSlot) {
        switch slot {
        case .breakfast:
            breakfastPhotoFileName = fileName
        case .lunch:
            lunchPhotoFileName = fileName
        case .dinner:
            dinnerPhotoFileName = fileName
        default:
            var extras = extraMeals
            extras.upsert(slot: slot, fileName: fileName)
            extraMeals = extras
        }
    }

    var hasMealPhoto: Bool {
        breakfastPhotoFileName != nil
            || lunchPhotoFileName != nil
            || dinnerPhotoFileName != nil
            || extraMeals.contains { $0.fileName != nil }
    }

    var allMealFileNames: [String?] {
        [breakfastPhotoFileName, lunchPhotoFileName, dinnerPhotoFileName]
            + extraMeals.map(\.fileName)
    }

    var visibleMealSlots: [MealSlot] {
        MealSlot.presets + extraMeals.filter(\.isCustom).map(MealSlot.fromExtra)
    }
}
