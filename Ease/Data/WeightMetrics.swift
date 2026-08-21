import Foundation

struct WeightSample: Sendable, Equatable {
    var date: Date
    var weight: Double
}

enum WeightMetrics {
    static func bmi(weightKg: Double, heightCm: Double) -> Double? {
        guard heightCm > 0, weightKg > 0 else { return nil }
        let meters = heightCm / 100
        let value = weightKg / (meters * meters)
        return MeasurementBounds.roundedToTenth(value)
    }

    static func sevenDayMA(
        samples: [WeightSample],
        endingOn date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        let window = CalendarDay.datesBack(7, from: date, calendar: calendar)
        let weightsByDay = Dictionary(
            samples
                .sorted { $0.date < $1.date }
                .map { (CalendarDay.dayKey(from: $0.date, calendar: calendar), $0.weight) },
            uniquingKeysWith: { _, latest in latest }
        )
        let values = window.compactMap { day in
            weightsByDay[CalendarDay.dayKey(from: day, calendar: calendar)]
        }
        guard values.count == 7 else { return nil }
        return MeasurementBounds.roundedToTenth(values.reduce(0, +) / 7)
    }

    /// Last weigh-in per local calendar day, sorted by day.
    static func lastPerDay(samples: [WeightSample], calendar: Calendar = .current) -> [WeightSample] {
        Dictionary(
            samples
                .sorted { $0.date < $1.date }
                .map { (CalendarDay.dayKey(from: $0.date, calendar: calendar), $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        .values
        .sorted { $0.date < $1.date }
    }

    static func latestWeight(samples: [WeightSample], calendar: Calendar = .current) -> Double? {
        samples.max { $0.date < $1.date }?.weight
    }

    static func displayWeight(
        samples: [WeightSample],
        on date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        weightOnDay(samples: samples, date: date, calendar: calendar)
            ?? latestWeight(samples: samples, calendar: calendar)
    }

    /// Weight logged on that calendar day only. No global fallback.
    static func weightOnDay(
        samples: [WeightSample],
        date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        let key = CalendarDay.dayKey(from: date, calendar: calendar)
        return samples
            .filter { CalendarDay.dayKey(from: $0.date, calendar: calendar) == key }
            .max { $0.date < $1.date }?
            .weight
    }

    static func hasWeight(
        records: [DailyRecord],
        logs: [WeightLog] = [],
        on date: Date,
        calendar: Calendar = .current
    ) -> Bool {
        weightOnDay(
            samples: samples(from: records, logs: logs, calendar: calendar),
            date: date,
            calendar: calendar
        ) != nil
    }

    static func progress(start: Double, target: Double, display: Double) -> Double {
        let span = start - target
        guard span != 0 else { return display <= target ? 1 : 0 }
        let raw = (start - display) / span
        return min(max(raw, 0), 1)
    }

    static func lostKg(start: Double, display: Double) -> Double {
        MeasurementBounds.roundedToTenth(max(0, start - display))
    }

    static func remainingKg(display: Double, target: Double) -> Double {
        MeasurementBounds.roundedToTenth(max(0, display - target))
    }

    static func samples(
        from records: [DailyRecord],
        logs: [WeightLog] = [],
        calendar: Calendar = .current
    ) -> [WeightSample] {
        let fromLogs = logs.map { WeightSample(date: $0.timestamp, weight: $0.weight) }
        let daysWithLogs = Set(logs.map { CalendarDay.dayKey(from: $0.timestamp, calendar: calendar) })
        let fromLegacy = records.compactMap { record -> WeightSample? in
            guard let weight = record.weight else { return nil }
            guard !daysWithLogs.contains(record.dayKey) else { return nil }
            return WeightSample(date: record.date, weight: weight)
        }
        return (fromLogs + fromLegacy).sorted { $0.date < $1.date }
    }

    static func sevenDayMA(
        records: [DailyRecord],
        logs: [WeightLog] = [],
        endingOn date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        sevenDayMA(samples: samples(from: records, logs: logs, calendar: calendar), endingOn: date, calendar: calendar)
    }

    static func displayWeight(
        records: [DailyRecord],
        logs: [WeightLog] = [],
        on date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        displayWeight(samples: samples(from: records, logs: logs, calendar: calendar), on: date, calendar: calendar)
    }

    static func weightOnDay(
        records: [DailyRecord],
        logs: [WeightLog] = [],
        on date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        weightOnDay(
            samples: samples(from: records, logs: logs, calendar: calendar),
            date: date,
            calendar: calendar
        )
    }

    static func latestBodyFat(
        records: [DailyRecord],
        logs: [WeightLog] = [],
        on date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        let key = CalendarDay.dayKey(from: date, calendar: calendar)
        let onDay = logs
            .filter { CalendarDay.dayKey(from: $0.timestamp, calendar: calendar) == key }
            .sorted { $0.timestamp < $1.timestamp }
        if let fat = onDay.last(where: { $0.bodyFat != nil })?.bodyFat {
            return fat
        }
        return records.first { $0.dayKey == key }?.bodyFat
    }

    /// Earliest / latest weigh-in on a calendar day (for 早 / 晚).
    static func dayBounds(
        records: [DailyRecord],
        logs: [WeightLog] = [],
        on date: Date,
        calendar: Calendar = .current
    ) -> (morning: Double?, evening: Double?) {
        let key = CalendarDay.dayKey(from: date, calendar: calendar)
        let onDay = logs
            .filter { CalendarDay.dayKey(from: $0.timestamp, calendar: calendar) == key }
            .sorted { $0.timestamp < $1.timestamp }
        if let first = onDay.first, let last = onDay.last {
            return (first.weight, last.weight)
        }
        if let legacy = records.first(where: { $0.dayKey == key })?.weight {
            return (legacy, legacy)
        }
        return (nil, nil)
    }

    /// 日间波动 = 同日晚 − 早. Requires ≥2 weigh-ins that day.
    static func daytimeSwing(
        records: [DailyRecord],
        logs: [WeightLog] = [],
        on date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        let key = CalendarDay.dayKey(from: date, calendar: calendar)
        let count = logs.filter { CalendarDay.dayKey(from: $0.timestamp, calendar: calendar) == key }.count
        guard count >= 2 else { return nil }
        let bounds = dayBounds(records: records, logs: logs, on: date, calendar: calendar)
        guard let morning = bounds.morning, let evening = bounds.evening else { return nil }
        return MeasurementBounds.roundedToTenth(evening - morning)
    }

    /// 夜间代谢 = 前一日晚 − 本日早.
    static func overnightMetabolism(
        records: [DailyRecord],
        logs: [WeightLog] = [],
        on date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        let previous = CalendarDay.addingDays(-1, to: date, calendar: calendar)
        let prevEvening = dayBounds(records: records, logs: logs, on: previous, calendar: calendar).evening
        let morning = dayBounds(records: records, logs: logs, on: date, calendar: calendar).morning
        guard let prevEvening, let morning else { return nil }
        return MeasurementBounds.roundedToTenth(prevEvening - morning)
    }

    /// Last-per-day weight N calendar days before `on` (that day only).
    static func weightDaysAgo(
        records: [DailyRecord],
        logs: [WeightLog] = [],
        on date: Date,
        daysAgo: Int,
        calendar: Calendar = .current
    ) -> Double? {
        let past = CalendarDay.addingDays(-daysAgo, to: date, calendar: calendar)
        return weightOnDay(records: records, logs: logs, on: past, calendar: calendar)
    }

    static func weekDelta(
        records: [DailyRecord],
        logs: [WeightLog] = [],
        on date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        guard let current = weightOnDay(records: records, logs: logs, on: date, calendar: calendar)
            ?? displayWeight(records: records, logs: logs, on: date, calendar: calendar)
        else { return nil }
        guard let past = weightDaysAgo(records: records, logs: logs, on: date, daysAgo: 7, calendar: calendar)
        else { return nil }
        return MeasurementBounds.roundedToTenth(current - past)
    }
}
