import Foundation

struct SleepNight: Sendable, Equatable, Identifiable {
    var id: String { dayKey }
    var dayKey: String
    /// Calendar morning this night belongs to (“that day's previous night”).
    var morning: Date
    var hours: Double?
}

struct SleepHistory: Sendable, Equatable {
    var nights: [SleepNight]
    var endingOn: Date

    static let empty = SleepHistory(nights: [], endingOn: .distantPast)

    var lastNightHours: Double? {
        hours(on: endingOn)
    }

    var loggedNights: [SleepNight] {
        nights.filter { $0.hours != nil }
    }

    var hasData: Bool {
        !loggedNights.isEmpty
    }

    /// Mean of nights that have asleep data. Nil when none.
    var averageHours: Double? {
        let values = loggedNights.compactMap(\.hours)
        guard !values.isEmpty else { return nil }
        return MeasurementBounds.roundedToTenth(values.reduce(0, +) / Double(values.count))
    }

    func hours(on date: Date, calendar: Calendar = .current) -> Double? {
        let key = CalendarDay.dayKey(from: date, calendar: calendar)
        return nights.first { $0.dayKey == key }?.hours
    }

    /// Sleep-target ring fill. Nil when that night has no data — do not draw 0%.
    func ringProgress(on date: Date, targetHours: Double, calendar: Calendar = .current) -> Double? {
        guard let hours = hours(on: date, calendar: calendar), targetHours > 0 else { return nil }
        return min(max(hours / targetHours, 0), 1)
    }

    func ringProgress(targetHours: Double) -> Double? {
        ringProgress(on: endingOn, targetHours: targetHours)
    }

    static func make(
        hoursByDay: [String: Double],
        nights: Int,
        endingOn date: Date = .now,
        calendar: Calendar = .current
    ) -> SleepHistory {
        let count = max(nights, 1)
        let mornings = CalendarDay.datesBack(count, from: date, calendar: calendar)
        let rows = mornings.map { morning in
            let key = CalendarDay.dayKey(from: morning, calendar: calendar)
            return SleepNight(dayKey: key, morning: morning, hours: hoursByDay[key])
        }
        return SleepHistory(nights: rows, endingOn: CalendarDay.startOfDay(date, calendar: calendar))
    }
}
