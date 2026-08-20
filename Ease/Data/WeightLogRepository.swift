import Foundation
import SwiftData

@MainActor
struct WeightLogRepository {
    let context: ModelContext
    let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    @discardableResult
    func insert(timestamp: Date, weight: Double, bodyFat: Double? = nil) throws -> WeightLog {
        guard !CalendarDay.isFuture(timestamp, calendar: calendar) else {
            throw EaseDataError.futureDate
        }
        let validatedWeight = try MeasurementBounds.validatedWeight(weight)
        let validatedFat = try bodyFat.map(MeasurementBounds.validatedBodyFat)
        let log = WeightLog(timestamp: timestamp, weight: validatedWeight, bodyFat: validatedFat)
        context.insert(log)
        try context.save()
        return log
    }

    func logs(on date: Date) throws -> [WeightLog] {
        let start = CalendarDay.startOfDay(date, calendar: calendar)
        let end = CalendarDay.endOfDay(date, calendar: calendar)
        let descriptor = FetchDescriptor<WeightLog>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func latest(on date: Date) throws -> WeightLog? {
        try logs(on: date).last
    }

    func log(id: UUID) throws -> WeightLog? {
        let targetID = id
        let descriptor = FetchDescriptor<WeightLog>(
            predicate: #Predicate { $0.id == targetID }
        )
        return try context.fetch(descriptor).first
    }

    func update(_ log: WeightLog, weight: Double, bodyFat: Double?) throws {
        guard !CalendarDay.isFuture(log.timestamp, calendar: calendar) else {
            throw EaseDataError.futureDate
        }
        log.weight = try MeasurementBounds.validatedWeight(weight)
        log.bodyFat = try bodyFat.map(MeasurementBounds.validatedBodyFat)
        log.updatedAt = .now
        try context.save()
    }

    func allLogs() throws -> [WeightLog] {
        let descriptor = FetchDescriptor<WeightLog>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func hasLog(on date: Date) throws -> Bool {
        try !logs(on: date).isEmpty
    }

    func delete(_ log: WeightLog) throws {
        context.delete(log)
        try context.save()
    }

    func deleteAll() throws {
        for log in try context.fetch(FetchDescriptor<WeightLog>()) {
            context.delete(log)
        }
        try context.save()
    }
}
