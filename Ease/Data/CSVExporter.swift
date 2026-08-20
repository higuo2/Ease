import Foundation

enum CSVExporter {
    static let header = "date,time,weight,bodyFat,dietStatus,tags,note"

    static func export(
        _ records: [DailyRecord],
        logs: [WeightLog] = [],
        calendar: Calendar = .current
    ) -> String {
        let recordsByDay = Dictionary(
            records.map { (CalendarDay.dayKey(from: $0.date, calendar: calendar), $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        let logsByDay = Dictionary(grouping: logs) {
            CalendarDay.dayKey(from: $0.timestamp, calendar: calendar)
        }

        let dayKeys = Set(recordsByDay.keys).union(logsByDay.keys)
        let sortedDays = dayKeys.sorted()
        var rows: [String] = []
        for key in sortedDays {
            let dayLogs = (logsByDay[key] ?? []).sorted { $0.timestamp < $1.timestamp }
            let record = recordsByDay[key]
            if dayLogs.isEmpty {
                let day = CalendarDay.date(fromDayKey: key, calendar: calendar)
                let legacyWeight = day.flatMap {
                    WeightMetrics.weightOnDay(
                        records: record.map { [$0] } ?? [],
                        logs: [],
                        on: $0,
                        calendar: calendar
                    )
                }
                rows.append(row(
                    date: key,
                    time: legacyWeight == nil ? "" : "08:00",
                    weight: legacyWeight,
                    bodyFat: legacyWeight == nil ? nil : record?.bodyFat,
                    record: record,
                    includeJournal: true
                ))
                continue
            }
            for (index, log) in dayLogs.enumerated() {
                rows.append(row(
                    date: key,
                    time: timeString(log.timestamp, calendar: calendar),
                    weight: log.weight,
                    bodyFat: log.bodyFat,
                    record: record,
                    includeJournal: index == 0
                ))
            }
        }
        return ([header] + rows).joined(separator: "\n")
    }

    private static func row(
        date: String,
        time: String,
        weight: Double?,
        bodyFat: Double?,
        record: DailyRecord?,
        includeJournal: Bool
    ) -> String {
        let fields = [
            date,
            time,
            csv(weight),
            csv(bodyFat),
            includeJournal ? (record?.dietStatus?.rawValue ?? "") : "",
            includeJournal ? escaped(record?.variableTags.map(\.rawValue).joined(separator: ";") ?? "") : "",
            includeJournal ? escaped(record?.note ?? "") : ""
        ]
        return fields.joined(separator: ",")
    }

    private static func timeString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    private static func csv(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.1f", value)
    }

    private static func escaped(_ text: String) -> String {
        guard text.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else {
            return text
        }
        return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
