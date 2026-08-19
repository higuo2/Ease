import Foundation

enum CSVExporter {
    static let header = "date,weight,bodyFat,dietStatus,tags,note"

    static func export(_ records: [DailyRecord], calendar: Calendar = .current) -> String {
        let rows = records
            .sorted { $0.date < $1.date }
            .map { row(for: $0, calendar: calendar) }
        return ([header] + rows).joined(separator: "\n")
    }

    private static func row(for record: DailyRecord, calendar: Calendar) -> String {
        let fields = [
            CalendarDay.dayKey(from: record.date, calendar: calendar),
            csv(record.weight),
            csv(record.bodyFat),
            record.dietStatus?.rawValue ?? "",
            record.variableTags.map(\.rawValue).joined(separator: ";"),
            escaped(record.note ?? "")
        ]
        return fields.joined(separator: ",")
    }

    private static func csv(_ value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.1f", value)
    }

    private static func escaped(_ text: String) -> String {
        guard text.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else {
            return text
        }
        return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
