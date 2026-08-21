import Foundation

enum PaceEstimator {
    static let windowDays = 28
    static let minPoints = 14
    static let madMultiplier = 3.0
    static let minAbsSlope = 0.01
    static let maxHorizonDays = 730

    /// Last-per-day samples → 7-day MA → last 28 MA days → MAD filter → OLS toward target.
    static func estimate(
        samples: [WeightSample],
        targetWeight: Double,
        displayWeight: Double?,
        progress: Double,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date? {
        guard let displayWeight, displayWeight > 0, targetWeight > 0 else { return nil }
        guard progress < 1 else { return nil }

        let movingAverages = movingAveragePoints(samples: samples, calendar: calendar)
        let window = Array(movingAverages.suffix(windowDays))
        let filtered = filterMAD(window)
        guard filtered.count >= minPoints else { return nil }

        let origin = CalendarDay.startOfDay(filtered[0].date, calendar: calendar)
        let xs = filtered.map { daysBetween(origin, $0.date, calendar: calendar) }
        let ys = filtered.map(\.weight)
        guard let fit = ordinaryLeastSquares(xs: xs, ys: ys) else { return nil }
        guard abs(fit.slope) >= minAbsSlope else { return nil }

        let lastY = ys.last ?? displayWeight
        let towardTarget = (targetWeight - lastY) * fit.slope
        guard towardTarget > 0 else { return nil }

        let xETA = (targetWeight - fit.intercept) / fit.slope
        guard xETA.isFinite else { return nil }
        let dayOffset = Int(xETA.rounded())
        guard let eta = calendar.date(byAdding: .day, value: dayOffset, to: origin) else { return nil }
        let etaDay = CalendarDay.startOfDay(eta, calendar: calendar)
        let today = CalendarDay.startOfDay(now, calendar: calendar)
        guard etaDay > today else { return nil }
        let horizon = CalendarDay.addingDays(maxHorizonDays, to: today, calendar: calendar)
        guard etaDay <= horizon else { return nil }
        return etaDay
    }

    static func movingAveragePoints(
        samples: [WeightSample],
        calendar: Calendar
    ) -> [WeightSample] {
        let lastPerDay = WeightMetrics.lastPerDay(samples: samples, calendar: calendar)
        guard let first = lastPerDay.first, let last = lastPerDay.last else { return [] }
        var day = CalendarDay.startOfDay(first.date, calendar: calendar)
        let end = CalendarDay.startOfDay(last.date, calendar: calendar)
        var points: [WeightSample] = []
        while day <= end {
            if let ma = WeightMetrics.sevenDayMA(samples: lastPerDay, endingOn: day, calendar: calendar) {
                points.append(WeightSample(date: day, weight: ma))
            }
            day = CalendarDay.addingDays(1, to: day, calendar: calendar)
        }
        return points
    }

    /// Drops `|y − median| > 3 × MAD` unless MAD is 0.
    static func filterMAD(_ points: [WeightSample]) -> [WeightSample] {
        let values = points.map(\.weight)
        guard let medianValue = median(values) else { return points }
        let deviations = values.map { abs($0 - medianValue) }
        guard let mad = median(deviations), mad > 0 else { return points }
        let limit = madMultiplier * mad
        return points.filter { abs($0.weight - medianValue) <= limit }
    }

    static func ordinaryLeastSquares(
        xs: [Double],
        ys: [Double]
    ) -> (slope: Double, intercept: Double)? {
        guard xs.count == ys.count, xs.count >= 2 else { return nil }
        let n = Double(xs.count)
        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).reduce(0) { $0 + $1.0 * $1.1 }
        let sumXX = xs.reduce(0) { $0 + $1 * $1 }
        let denominator = n * sumXX - sumX * sumX
        guard denominator != 0 else { return nil }
        let slope = (n * sumXY - sumX * sumY) / denominator
        let intercept = (sumY - slope * sumX) / n
        guard slope.isFinite, intercept.isFinite else { return nil }
        return (slope, intercept)
    }

    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    private static func daysBetween(_ start: Date, _ end: Date, calendar: Calendar) -> Double {
        let from = CalendarDay.startOfDay(start, calendar: calendar)
        let to = CalendarDay.startOfDay(end, calendar: calendar)
        return Double(calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }
}
