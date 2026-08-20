import Foundation
import SwiftData

/// Copies legacy `DailyRecord.weight` into `WeightLog` without nilling the old fields.
@MainActor
enum LegacyWeightMigrator {
    static func run(context: ModelContext, calendar: Calendar = .current) throws {
        let profile = try UserProfileRepository(context: context, calendar: calendar).profile()
        guard !profile.hasMigratedWeightLogs else { return }

        let records = try context.fetch(FetchDescriptor<DailyRecord>())
        let logs = WeightLogRepository(context: context, calendar: calendar)

        for record in records {
            guard let weight = record.weight else { continue }
            if try logs.hasLog(on: record.date) { continue }
            let timestamp = Self.timestamp(for: record, calendar: calendar)
            _ = try logs.insert(timestamp: timestamp, weight: weight, bodyFat: record.bodyFat)
        }

        profile.hasMigratedWeightLogs = true
        profile.updatedAt = .now
        try context.save()
    }

    private static func timestamp(for record: DailyRecord, calendar: Calendar) -> Date {
        let day = CalendarDay.startOfDay(record.date, calendar: calendar)
        if calendar.isDate(record.updatedAt, inSameDayAs: day) {
            return record.updatedAt
        }
        return CalendarDay.atHour(8, on: day, calendar: calendar)
    }
}
