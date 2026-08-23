import Foundation

/// Soft health-aware pace estimate for Trend. Does not replace `PaceEstimator` on the stage card.
enum AdvancedPaceEstimator {
    static let lookbackDays = 28
    static let minWeightPoints = 14
    static let minAbsSlope = 0.01
    static let maxHorizonDays = 730

    struct Context: Equatable {
        var sleepHoursByDay: [String: Double]
        var energyKcalByDay: [String: Double]
        var periodDayKeys: Set<String>
        var sleepTargetHours: Double
    }

    struct Result: Equatable {
        var eta: Date
        var daysRemaining: Int
        var dailySlopeKg: Double
        var adjustedSlopeKg: Double
        var sleepFactor: Double
        var energyFactor: Double
        var periodFactor: Double
        var averageSleepHours: Double?
        var averageEnergyKcal: Double?
        var periodDaysInWindow: Int
    }

    static func estimate(
        samples: [WeightSample],
        targetWeight: Double,
        displayWeight: Double?,
        progress: Double,
        context: Context,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Result? {
        guard let displayWeight, displayWeight > 0, targetWeight > 0 else { return nil }
        guard progress < 1 else { return nil }

        let movingAverages = PaceEstimator.movingAveragePoints(samples: samples, calendar: calendar)
        let window = Array(movingAverages.suffix(lookbackDays))
        let filtered = PaceEstimator.filterMAD(window)
        guard filtered.count >= minWeightPoints else { return nil }

        let origin = CalendarDay.startOfDay(filtered[0].date, calendar: calendar)
        let xs = filtered.map { daysBetween(origin, $0.date, calendar: calendar) }
        let ys = filtered.map(\.weight)
        guard let fit = PaceEstimator.ordinaryLeastSquares(xs: xs, ys: ys) else { return nil }
        guard abs(fit.slope) >= minAbsSlope else { return nil }

        let lastY = ys.last ?? displayWeight
        let towardTarget = (targetWeight - lastY) * fit.slope
        guard towardTarget > 0 else { return nil }

        let today = CalendarDay.startOfDay(now, calendar: calendar)
        let factors = softFactors(
            windowDays: filtered.map(\.date),
            context: context,
            now: today,
            calendar: calendar
        )
        let adjustedSlope = fit.slope * factors.combined
        guard abs(adjustedSlope) >= minAbsSlope else { return nil }
        guard (targetWeight - lastY) * adjustedSlope > 0 else { return nil }

        let remaining = targetWeight - displayWeight
        let days = remaining / adjustedSlope
        guard days.isFinite, days > 0 else { return nil }
        let dayOffset = Int(days.rounded(.up))
        guard dayOffset > 0 else { return nil }
        guard let eta = calendar.date(byAdding: .day, value: dayOffset, to: today) else { return nil }
        let etaDay = CalendarDay.startOfDay(eta, calendar: calendar)
        guard etaDay > today else { return nil }
        let horizon = CalendarDay.addingDays(maxHorizonDays, to: today, calendar: calendar)
        guard etaDay <= horizon else { return nil }

        return Result(
            eta: etaDay,
            daysRemaining: dayOffset,
            dailySlopeKg: round2(fit.slope),
            adjustedSlopeKg: round2(adjustedSlope),
            sleepFactor: round2(factors.sleep),
            energyFactor: round2(factors.energy),
            periodFactor: round2(factors.period),
            averageSleepHours: factors.averageSleep,
            averageEnergyKcal: factors.averageEnergy,
            periodDaysInWindow: factors.periodDays
        )
    }

    private static func round2(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private struct SoftFactors {
        var sleep: Double
        var energy: Double
        var period: Double
        var averageSleep: Double?
        var averageEnergy: Double?
        var periodDays: Int
        var combined: Double { sleep * energy * period }
    }

    /// Mild multipliers only — not calorie accounting.
    /// Sleep below target slows expected pace; higher energy vs median speeds it; period days dampen slightly.
    private static func softFactors(
        windowDays: [Date],
        context: Context,
        now: Date,
        calendar: Calendar
    ) -> SoftFactors {
        let keys = windowDays.map { CalendarDay.dayKey(from: $0, calendar: calendar) }
        let sleepValues = keys.compactMap { context.sleepHoursByDay[$0] }
        let energyValues = keys.compactMap { context.energyKcalByDay[$0] }
        let periodDays = keys.filter { context.periodDayKeys.contains($0) }.count

        let averageSleep: Double? = sleepValues.isEmpty
            ? nil
            : MeasurementBounds.roundedToTenth(sleepValues.reduce(0, +) / Double(sleepValues.count))
        let averageEnergy: Double? = energyValues.isEmpty
            ? nil
            : (energyValues.reduce(0, +) / Double(energyValues.count)).rounded()

        var sleepFactor = 1.0
        if let averageSleep, context.sleepTargetHours > 0 {
            let ratio = averageSleep / context.sleepTargetHours
            if ratio < 0.85 {
                sleepFactor = 0.88
            } else if ratio < 0.95 {
                sleepFactor = 0.94
            } else if ratio > 1.05 {
                sleepFactor = 1.04
            }
        }

        var energyFactor = 1.0
        if let medianEnergy = PaceEstimator.median(energyValues), medianEnergy > 0, let averageEnergy {
            let ratio = averageEnergy / medianEnergy
            if ratio >= 1.15 {
                energyFactor = 1.08
            } else if ratio <= 0.85 {
                energyFactor = 0.94
            }
        }

        var periodFactor = 1.0
        let todayKey = CalendarDay.dayKey(from: now, calendar: calendar)
        if context.periodDayKeys.contains(todayKey) {
            periodFactor = 0.9
        } else if periodDays >= 4 {
            periodFactor = 0.95
        }

        return SoftFactors(
            sleep: sleepFactor,
            energy: energyFactor,
            period: periodFactor,
            averageSleep: averageSleep,
            averageEnergy: averageEnergy,
            periodDays: periodDays
        )
    }

    private static func daysBetween(_ start: Date, _ end: Date, calendar: Calendar) -> Double {
        let from = CalendarDay.startOfDay(start, calendar: calendar)
        let to = CalendarDay.startOfDay(end, calendar: calendar)
        return Double(calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }
}
