import Foundation

enum CalendarDay {
    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func dayKey(from date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: startOfDay(date, calendar: calendar))
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func isFuture(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> Bool {
        startOfDay(date, calendar: calendar) > startOfDay(now, calendar: calendar)
    }

    static func date(fromDayKey key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
    }

    static func datesBack(_ count: Int, from date: Date, calendar: Calendar = .current) -> [Date] {
        let end = startOfDay(date, calendar: calendar)
        return (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: end)
        }
    }

    static func endOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        let start = startOfDay(date, calendar: calendar)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? start
    }

    static func addingDays(_ value: Int, to date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: value, to: startOfDay(date, calendar: calendar))
            ?? startOfDay(date, calendar: calendar)
    }

    static func atHour(
        _ hour: Int,
        minute: Int = 0,
        on date: Date,
        calendar: Calendar = .current
    ) -> Date {
        calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: startOfDay(date, calendar: calendar)
        ) ?? startOfDay(date, calendar: calendar)
    }
}
