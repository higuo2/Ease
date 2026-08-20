import Foundation

struct CycleSpan: Sendable, Equatable, Identifiable {
    var id: String { CalendarDay.dayKey(from: start) }
    /// First calendar day of a consecutive menstrual run.
    var start: Date
    /// Last calendar day of the run (inclusive).
    var end: Date

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = CalendarDay.startOfDay(date, calendar: calendar)
        return day >= CalendarDay.startOfDay(start, calendar: calendar)
            && day <= CalendarDay.startOfDay(end, calendar: calendar)
    }
}

struct CycleHistory: Sendable, Equatable {
    var periodDayKeys: Set<String>
    var spans: [CycleSpan]
    var starts: [Date]
    /// Median of adjacent-start gaps in 15...45 days. Nil when prediction is not possible.
    var cycleLengthDays: Double?
    var predictedNextStart: Date?
    /// Elapsed days since last start / cycle length, clamped 0...1.
    var progress: Double?
    var endingOn: Date

    static let empty = CycleHistory(
        periodDayKeys: [],
        spans: [],
        starts: [],
        cycleLengthDays: nil,
        predictedNextStart: nil,
        progress: nil,
        endingOn: .distantPast
    )

    var hasData: Bool { !periodDayKeys.isEmpty }
    var lastStart: Date? { starts.last }

    func isMenstrual(_ date: Date, calendar: Calendar = .current) -> Bool {
        periodDayKeys.contains(CalendarDay.dayKey(from: date, calendar: calendar))
    }
}

enum CycleMetrics {
    static let validGapDays = 15.0...45.0

    static func make(
        periodDayKeys: Set<String>,
        endingOn date: Date = .now,
        calendar: Calendar = .current
    ) -> CycleHistory {
        let days = periodDayKeys.compactMap { CalendarDay.date(fromDayKey: $0, calendar: calendar) }
            .map { CalendarDay.startOfDay($0, calendar: calendar) }
            .sorted()
        let spans = spans(from: days, calendar: calendar)
        let starts = spans.map(\.start)
        let length = cycleLengthDays(starts: starts, calendar: calendar)
        let lastStart = starts.last
        let predicted: Date?
        if let lastStart, let length {
            predicted = calendar.date(
                byAdding: .day,
                value: Int(length.rounded()),
                to: lastStart
            )
        } else {
            predicted = nil
        }
        let progress: Double?
        if let lastStart, let length, length > 0 {
            let elapsed = calendar.dateComponents(
                [.day],
                from: CalendarDay.startOfDay(lastStart, calendar: calendar),
                to: CalendarDay.startOfDay(date, calendar: calendar)
            ).day ?? 0
            progress = min(max(Double(elapsed) / length, 0), 1)
        } else {
            progress = nil
        }
        return CycleHistory(
            periodDayKeys: periodDayKeys,
            spans: spans,
            starts: starts,
            cycleLengthDays: length,
            predictedNextStart: predicted,
            progress: progress,
            endingOn: CalendarDay.startOfDay(date, calendar: calendar)
        )
    }

    static func spans(from sortedDays: [Date], calendar: Calendar) -> [CycleSpan] {
        var result: [CycleSpan] = []
        var runStart: Date?
        var runEnd: Date?
        for day in sortedDays {
            if let end = runEnd,
               calendar.isDate(day, inSameDayAs: CalendarDay.addingDays(1, to: end, calendar: calendar)) {
                runEnd = day
            } else {
                if let start = runStart, let end = runEnd {
                    result.append(CycleSpan(start: start, end: end))
                }
                runStart = day
                runEnd = day
            }
        }
        if let start = runStart, let end = runEnd {
            result.append(CycleSpan(start: start, end: end))
        }
        return result
    }

    /// Consecutive menstrual days share one cycle start (the first day of the run).
    /// Length is the median of adjacent-start gaps after dropping gaps outside 15...45 days.
    /// Needs at least two starts and one valid gap; otherwise no prediction.
    static func cycleLengthDays(starts: [Date], calendar: Calendar) -> Double? {
        guard starts.count >= 2 else { return nil }
        var gaps: [Double] = []
        for index in 1..<starts.count {
            let days = calendar.dateComponents(
                [.day],
                from: starts[index - 1],
                to: starts[index]
            ).day ?? 0
            let value = Double(days)
            if validGapDays.contains(value) {
                gaps.append(value)
            }
        }
        return median(gaps)
    }

    static func median(_ values: [Double]) -> Double? {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return nil }
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }
}
