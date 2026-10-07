import Foundation
import SwiftData

@MainActor
struct WorkoutLogRepository {
    let context: ModelContext
    let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    @discardableResult
    func insert(timestamp: Date, kcal: Double, durationMinutes: Int? = nil) throws -> WorkoutLog {
        guard !CalendarDay.isFuture(timestamp, calendar: calendar) else {
            throw EaseDataError.futureDate
        }
        let log = WorkoutLog(
            timestamp: timestamp,
            kcal: try MeasurementBounds.validatedWorkoutKcal(kcal),
            durationMinutes: try MeasurementBounds.validatedWorkoutDuration(durationMinutes)
        )
        context.insert(log)
        try context.save()
        return log
    }

    func logs(on date: Date) throws -> [WorkoutLog] {
        let start = CalendarDay.startOfDay(date, calendar: calendar)
        let end = CalendarDay.endOfDay(date, calendar: calendar)
        let descriptor = FetchDescriptor<WorkoutLog>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func log(id: UUID) throws -> WorkoutLog? {
        let targetID = id
        let descriptor = FetchDescriptor<WorkoutLog>(
            predicate: #Predicate { $0.id == targetID }
        )
        return try context.fetch(descriptor).first
    }

    func update(_ log: WorkoutLog, kcal: Double, durationMinutes: Int?) throws {
        guard !CalendarDay.isFuture(log.timestamp, calendar: calendar) else {
            throw EaseDataError.futureDate
        }
        log.kcal = try MeasurementBounds.validatedWorkoutKcal(kcal)
        log.durationMinutes = try MeasurementBounds.validatedWorkoutDuration(durationMinutes)
        log.updatedAt = .now
        try context.save()
    }

    func hasLog(on date: Date) throws -> Bool {
        try !logs(on: date).isEmpty
    }

    func delete(_ log: WorkoutLog) throws {
        context.delete(log)
        try context.save()
    }

    func deleteAll() throws {
        for log in try context.fetch(FetchDescriptor<WorkoutLog>()) {
            context.delete(log)
        }
        try context.save()
    }
}
