import Foundation

/// Cheap change fingerprints for `onChange` — avoids string joins on every body pass.
enum DashboardComputeToken {
    static func mixWeightLogTail(_ log: WeightLog?, into hasher: inout Hasher) {
        guard let log else { return }
        hasher.combine(log.id)
        hasher.combine(log.weight)
        hasher.combine(log.timestamp.timeIntervalSinceReferenceDate)
    }

    static func mixDailyRecordChartTail(_ record: DailyRecord?, into hasher: inout Hasher) {
        guard let record else { return }
        hasher.combine(record.dayKey)
        hasher.combine(record.weight ?? -1)
        hasher.combine(record.updatedAt.timeIntervalSinceReferenceDate)
    }

    static func mixDailyRecordCalendarTail(_ record: DailyRecord?, into hasher: inout Hasher) {
        guard let record else { return }
        hasher.combine(record.dayKey)
        hasher.combine(record.weight ?? -1)
        hasher.combine(record.note ?? "")
        for tag in record.variableTags {
            hasher.combine(tag)
        }
    }

    /// Shared revision for weight series derived from `records` + `logs`.
    static func weightSeriesRevision(records: [DailyRecord], logs: [WeightLog]) -> Int {
        var hasher = Hasher()
        hasher.combine(records.count)
        hasher.combine(logs.count)
        mixWeightLogTail(logs.last, into: &hasher)
        mixDailyRecordChartTail(records.last, into: &hasher)
        return hasher.finalize()
    }
}
