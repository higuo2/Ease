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

    @discardableResult
    func upsert(on date: Date, patch: DailyRecordPatch) throws -> DailyRecord {
        guard !CalendarDay.isFuture(date, calendar: calendar) else {
            throw EaseDataError.futureDate
        }
        guard !patch.isEmpty else { throw EaseDataError.emptyPatch }

        let existing = try record(on: date)
        let record = existing ?? DailyRecord(date: date, calendar: calendar)
        let snapshot = RecordSnapshot(record)
        do {
            try apply(patch, to: record)
            guard record.weight != nil || record.dietStatus != nil else {
                throw EaseDataError.emptyRecord
            }
        } catch {
            snapshot.restore(to: record)
            throw error
        }

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

    private func apply(_ patch: DailyRecordPatch, to record: DailyRecord) throws {
        var weight = record.weight
        switch patch.weight {
        case .unchanged:
            break
        case .set(let value):
            weight = try value.map(MeasurementBounds.validatedWeight)
        }
        record.weight = weight

        var bodyFat = record.bodyFat
        switch patch.bodyFat {
        case .unchanged:
            break
        case .set(let value):
            bodyFat = try value.map(MeasurementBounds.validatedBodyFat)
        }
        record.bodyFat = bodyFat

        var diet = record.dietStatus
        patch.dietStatus.apply(to: &diet)
        record.dietStatus = diet

        var tags = record.variableTags
        patch.tags.apply(to: &tags)
        record.variableTags = VariableTag.sanitized(tags)

        var note = record.note
        switch patch.note {
        case .unchanged:
            break
        case .set(let value):
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            note = (trimmed?.isEmpty == false) ? trimmed : nil
        }
        record.note = note
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

private struct RecordSnapshot {
    var weight: Double?
    var bodyFat: Double?
    var dietStatusRaw: String?
    var tags: [String]
    var note: String?

    init(_ record: DailyRecord) {
        weight = record.weight
        bodyFat = record.bodyFat
        dietStatusRaw = record.dietStatusRaw
        tags = record.tags
        note = record.note
    }

    func restore(to record: DailyRecord) {
        record.weight = weight
        record.bodyFat = bodyFat
        record.dietStatusRaw = dietStatusRaw
        record.tags = tags
        record.note = note
    }
}
