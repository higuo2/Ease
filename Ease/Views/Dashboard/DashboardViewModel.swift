import Foundation
import Observation
import SwiftData

enum ChartRange: Int, CaseIterable, Identifiable {
    case days7 = 7
    case days30 = 30
    case days90 = 90
    case all = 0

    var id: Int { rawValue }

    var titleKey: String {
        switch self {
        case .days7: "chart.range.7"
        case .days30: "chart.range.30"
        case .days90: "chart.range.90"
        case .all: "chart.range.all"
        }
    }

    /// Inclusive day count for X domain. `nil` means use earliest sample → today.
    var dayCount: Int? {
        switch self {
        case .all: nil
        default: rawValue
        }
    }
}

enum LogSheetMode: Equatable {
    /// Weight + body fat (+ OCR). No diet.
    case weight
    /// Diet + tags + note. No weight.
    case diet
}

/// Home-card gray line. Nil when nothing is enabled.
/// Enabled with no log that day → entry copy. Enabled with logs → readings only.
enum DashboardMetricsLine {
    static func text(
        enabled: [MetricDefinition],
        logs: [MetricLog],
        on date: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard !enabled.isEmpty else { return nil }
        let key = CalendarDay.dayKey(from: date, calendar: calendar)
        var parts: [String] = []
        for definition in enabled {
            let onDay = logs
                .filter { $0.metricKey == definition.key && CalendarDay.dayKey(from: $0.timestamp, calendar: calendar) == key }
                .sorted { $0.timestamp < $1.timestamp }
            guard let latest = onDay.last else { continue }
            parts.append(MetricCatalog.formattedReading(latest.value, spec: MetricCatalog.spec(for: definition)))
        }
        if parts.isEmpty {
            return String(localized: "dashboard.metrics")
        }
        return parts.joined(separator: "  ")
    }

    static func focusKey(
        enabled: [MetricDefinition],
        logs: [MetricLog],
        on date: Date,
        calendar: Calendar = .current
    ) -> String? {
        guard !enabled.isEmpty else { return nil }
        let key = CalendarDay.dayKey(from: date, calendar: calendar)
        for definition in enabled {
            let hasLog = logs.contains {
                $0.metricKey == definition.key
                    && CalendarDay.dayKey(from: $0.timestamp, calendar: calendar) == key
            }
            if hasLog { return definition.key }
        }
        return enabled.first?.key
    }
}

@Observable
@MainActor
final class DashboardViewModel {
    var chartRange: ChartRange = .days7
    var selectedDate = CalendarDay.startOfDay(.now)
    var dayPickerMode: DayPickerMode = .week
    var isSettingsPresented = false
    var isLogPresented = false
    var isSleepPresented = false
    var isCyclePresented = false
    var isEnergyPresented = false
    var isMetricSheetPresented = false
    var metricsDate = Date.now
    var metricFocusKey: String?
    var editingDate = Date.now
    var editingLogID: UUID?
    var logMode: LogSheetMode = .weight
    var healthByDay: [String: HealthDaySnapshot] = [:]
    var sleepHistory = SleepHistory.empty
    var cycleHistory = CycleHistory.empty
    var energyHistory = EnergyHistory.empty

    func openLog(for date: Date, mode: LogSheetMode = .weight) {
        editingDate = CalendarDay.startOfDay(date)
        editingLogID = nil
        logMode = mode
        isLogPresented = true
    }

    func openWeightEntry(for date: Date) {
        openLog(for: date, mode: .weight)
    }

    func openDietEntry(for date: Date) {
        openLog(for: date, mode: .diet)
    }

    func openWeightLog(_ log: WeightLog) {
        editingDate = CalendarDay.startOfDay(log.timestamp)
        editingLogID = log.id
        logMode = .weight
        isLogPresented = true
    }

    func openSelectedLog() {
        openWeightEntry(for: selectedDate)
    }

    func openMetrics(on date: Date, key: String? = nil) {
        metricsDate = CalendarDay.startOfDay(date)
        metricFocusKey = key.flatMap { MetricCatalog.isActiveMetricKey($0) ? $0 : nil }
        isMetricSheetPresented = true
    }

    func reloadHealthAndNotifications(
        enabled: Bool,
        records: [DailyRecord],
        logs: [WeightLog],
        weightHour: Int = NotificationSchedulePolicy.weightHour,
        weightMinute: Int = NotificationSchedulePolicy.weightMinute,
        dietHour: Int = NotificationSchedulePolicy.dietHour,
        dietMinute: Int = NotificationSchedulePolicy.dietMinute
    ) async {
        let payload = await HealthKitReader.loadAll()
        healthByDay = payload.byDay
        sleepHistory = payload.sleep
        cycleHistory = payload.cycle
        energyHistory = payload.energy
        let todayKey = CalendarDay.dayKey(from: .now)
        await NotificationScheduler.refresh(
            enabled: enabled,
            todayRecord: records.first { $0.dayKey == todayKey },
            hasWeightToday: WeightMetrics.hasWeight(records: records, logs: logs, on: .now),
            healthToday: healthByDay[todayKey],
            weightHour: weightHour,
            weightMinute: weightMinute,
            dietHour: dietHour,
            dietMinute: dietMinute
        )
    }
}

struct DashboardSnapshot {
    let displayWeight: Double?
    let bodyFat: Double?
    let bmi: Double?
    let progress: Double
    let lostKg: Double
    let remainingKg: Double
    let targetWeight: Double
    let startWeight: Double
    let today: DailyRecord?

    static func make(
        profile: UserProfile?,
        records: [DailyRecord],
        logs: [WeightLog] = [],
        now: Date = .now
    ) -> DashboardSnapshot {
        let start = profile?.startWeight ?? 0
        let target = profile?.targetWeight ?? 0
        let height = profile?.heightCm ?? 0
        let display = WeightMetrics.displayWeight(records: records, logs: logs, on: now)
        let todayKey = CalendarDay.dayKey(from: now)
        let today = records.first { $0.dayKey == todayKey }
        let progress: Double
        let lost: Double
        let remaining: Double
        if let display, start > 0, target > 0 {
            progress = WeightMetrics.progress(start: start, target: target, display: display)
            lost = WeightMetrics.lostKg(start: start, display: display)
            remaining = WeightMetrics.remainingKg(display: display, target: target)
        } else {
            progress = 0
            lost = 0
            remaining = 0
        }
        let bmi: Double?
        if let display, height > 0 {
            bmi = WeightMetrics.bmi(weightKg: display, heightCm: height)
        } else {
            bmi = nil
        }
        return DashboardSnapshot(
            displayWeight: display,
            bodyFat: WeightMetrics.latestBodyFat(records: records, logs: logs, on: now),
            bmi: bmi,
            progress: progress,
            lostKg: lost,
            remainingKg: remaining,
            targetWeight: target,
            startWeight: start,
            today: today
        )
    }
}
