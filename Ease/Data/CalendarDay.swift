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

    static func startOfWeek(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: startOfDay(date, calendar: calendar))?.start
            ?? startOfDay(date, calendar: calendar)
    }

    static func weekDates(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let start = startOfWeek(date, calendar: calendar)
        return (0..<7).map { addingDays($0, to: start, calendar: calendar) }
    }

    static func startOfMonth(_ date: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: startOfDay(date, calendar: calendar))
        return calendar.date(from: parts).map { calendar.startOfDay(for: $0) }
            ?? startOfDay(date, calendar: calendar)
    }

    static func daysInMonth(containing date: Date, calendar: Calendar = .current) -> [Date] {
        let start = startOfMonth(date, calendar: calendar)
        let count = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
        return (0..<count).map { addingDays($0, to: start, calendar: calendar) }
    }

    static func weekdayHeaderSymbols(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        guard first > 0, first < symbols.count else { return symbols }
        return Array(symbols[first...]) + Array(symbols[..<first])
    }

    static func leadingEmptyDays(inMonthContaining date: Date, calendar: Calendar = .current) -> Int {
        let start = startOfMonth(date, calendar: calendar)
        let weekday = calendar.component(.weekday, from: start)
        return (weekday - calendar.firstWeekday + 7) % 7
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
