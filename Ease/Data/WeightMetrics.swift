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
            samples.map { (CalendarDay.dayKey(from: $0.date, calendar: calendar), $0.weight) },
            uniquingKeysWith: { _, latest in latest }
        )
        let values = window.compactMap { day in
            weightsByDay[CalendarDay.dayKey(from: day, calendar: calendar)]
        }
        guard values.count == 7 else { return nil }
        return MeasurementBounds.roundedToTenth(values.reduce(0, +) / 7)
    }

    static func latestWeight(samples: [WeightSample], calendar: Calendar = .current) -> Double? {
        samples
            .sorted { lhs, rhs in
                let left = CalendarDay.startOfDay(lhs.date, calendar: calendar)
                let right = CalendarDay.startOfDay(rhs.date, calendar: calendar)
                if left == right { return false }
                return left < right
            }
            .last?
            .weight
    }

    static func displayWeight(
        samples: [WeightSample],
        on date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        sevenDayMA(samples: samples, endingOn: date, calendar: calendar)
            ?? latestWeight(samples: samples, calendar: calendar)
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

    static func samples(from records: [DailyRecord], calendar: Calendar = .current) -> [WeightSample] {
        records.compactMap { record in
            guard let weight = record.weight else { return nil }
            return WeightSample(date: record.date, weight: weight)
        }
        .sorted {
            CalendarDay.startOfDay($0.date, calendar: calendar) < CalendarDay.startOfDay($1.date, calendar: calendar)
        }
    }

    static func sevenDayMA(
        records: [DailyRecord],
        endingOn date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        sevenDayMA(samples: samples(from: records, calendar: calendar), endingOn: date, calendar: calendar)
    }

    static func displayWeight(
        records: [DailyRecord],
        on date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        displayWeight(samples: samples(from: records, calendar: calendar), on: date, calendar: calendar)
    }
}
