import Foundation
import SwiftData

@MainActor
struct DailyRecordRepository {
    let context: ModelContext
    let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    func record(on date: Date) throws -> DailyRecord? {
        try deduplicate(dayKey: CalendarDay.dayKey(from: date, calendar: calendar))
    }

    func allRecords() throws -> [DailyRecord] {
        try deduplicateAll()
        let descriptor = FetchDescriptor<DailyRecord>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    /// Journal fields (`dietStatus` / `tags` / `note` / meal photos) upsert into `DailyRecord`.
    /// `patch.weight` / `patch.bodyFat` insert a `WeightLog` and never write the legacy fields.
    @discardableResult
    func upsert(on date: Date, patch: DailyRecordPatch) throws -> DailyRecord? {
        guard !CalendarDay.isFuture(date, calendar: calendar) else {
            throw EaseDataError.futureDate
        }
        guard !patch.isEmpty else { throw EaseDataError.emptyPatch }

        let insertedLog = try insertWeightIfNeeded(on: date, patch: patch)
        let next = try journalState(on: date, patch: patch)
        let existing = try record(on: date)
        let hasJournal = next.hasContent
        if !insertedLog && !hasJournal && existing == nil {
            throw EaseDataError.emptyRecord
        }
        if existing == nil && !hasJournal {
            return nil
        }

        let record = existing ?? DailyRecord(date: date, calendar: calendar)
        record.dietStatus = next.diet
        record.variableTags = next.tags
        record.note = next.note
        record.breakfastPhotoData = next.breakfastPhoto
        record.lunchPhotoData = next.lunchPhoto
        record.dinnerPhotoData = next.dinnerPhoto
        record.updatedAt = .now
        if existing == nil {
            context.insert(record)
        }
        try context.save()
        return record
    }

    func delete(on date: Date) throws {
        if let record = try record(on: date) {
            context.delete(record)
            try context.save()
        }
    }

    func deleteAll() throws {
        for record in try context.fetch(FetchDescriptor<DailyRecord>()) {
            context.delete(record)
        }
        try context.save()
    }

    private func insertWeightIfNeeded(on date: Date, patch: DailyRecordPatch) throws -> Bool {
        let weight: Double?
        switch patch.weight {
        case .unchanged:
            return false
        case .set(let value):
            weight = try value.map(MeasurementBounds.validatedWeight)
        }
        guard let weight else { return false }

        let bodyFat: Double?
        switch patch.bodyFat {
        case .unchanged:
            bodyFat = nil
        case .set(let value):
            bodyFat = try value.map(MeasurementBounds.validatedBodyFat)
        }

        let timestamp: Date
        if calendar.isDate(date, inSameDayAs: .now) {
            timestamp = .now
        } else {
            timestamp = CalendarDay.atHour(8, on: date, calendar: calendar)
        }
        try WeightLogRepository(context: context, calendar: calendar)
            .insert(timestamp: timestamp, weight: weight, bodyFat: bodyFat)
        return true
    }

    private struct JournalState {
        var diet: DietStatus?
        var tags: [VariableTag]
        var note: String?
        var breakfastPhoto: Data?
        var lunchPhoto: Data?
        var dinnerPhoto: Data?

        var hasContent: Bool {
            diet != nil
                || !tags.isEmpty
                || note != nil
                || breakfastPhoto != nil
                || lunchPhoto != nil
                || dinnerPhoto != nil
        }
    }

    private func journalState(on date: Date, patch: DailyRecordPatch) throws -> JournalState {
        let existing = try record(on: date)
        var diet = existing?.dietStatus
        var tags = existing?.variableTags ?? []
        var note = existing?.note
        var breakfastPhoto = existing?.breakfastPhotoData
        var lunchPhoto = existing?.lunchPhotoData
        var dinnerPhoto = existing?.dinnerPhotoData

        switch patch.dietStatus {
        case .unchanged:
            break
        case .set(let value):
            diet = value
        }
        switch patch.tags {
        case .unchanged:
            break
        case .set(let value):
            tags = VariableTag.sanitized(value)
        }
        switch patch.note {
        case .unchanged:
            break
        case .set(let value):
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            note = (trimmed?.isEmpty == false) ? trimmed : nil
        }
        switch patch.breakfastPhoto {
        case .unchanged:
            break
        case .set(let value):
            breakfastPhoto = value
        }
        switch patch.lunchPhoto {
        case .unchanged:
            break
        case .set(let value):
            lunchPhoto = value
        }
        switch patch.dinnerPhoto {
        case .unchanged:
            break
        case .set(let value):
            dinnerPhoto = value
        }

        let journalTouched: Bool = {
            if case .unchanged = patch.dietStatus,
               case .unchanged = patch.tags,
               case .unchanged = patch.note,
               case .unchanged = patch.breakfastPhoto,
               case .unchanged = patch.lunchPhoto,
               case .unchanged = patch.dinnerPhoto {
                return false
            }
            return true
        }()

        if !journalTouched && existing == nil {
            return JournalState(
                diet: nil,
                tags: [],
                note: nil,
                breakfastPhoto: nil,
                lunchPhoto: nil,
                dinnerPhoto: nil
            )
        }
        return JournalState(
            diet: diet,
            tags: tags,
            note: note,
            breakfastPhoto: breakfastPhoto,
            lunchPhoto: lunchPhoto,
            dinnerPhoto: dinnerPhoto
        )
    }

    @discardableResult
    private func deduplicate(dayKey: String) throws -> DailyRecord? {
        let descriptor = FetchDescriptor<DailyRecord>(
            predicate: #Predicate { $0.dayKey == dayKey },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        let matches = try context.fetch(descriptor)
        guard let keeper = matches.first else { return nil }
        for duplicate in matches.dropFirst() {
            context.delete(duplicate)
        }
        if matches.count > 1 {
            try context.save()
        }
        return keeper
    }

    private func deduplicateAll() throws {
        let records = try context.fetch(FetchDescriptor<DailyRecord>())
        let grouped = Dictionary(grouping: records, by: \.dayKey)
        var removed = false
        for group in grouped.values {
            let sorted = group.sorted { $0.updatedAt > $1.updatedAt }
            for duplicate in sorted.dropFirst() {
                context.delete(duplicate)
                removed = true
            }
        }
        if removed {
            try context.save()
        }
    }
}
