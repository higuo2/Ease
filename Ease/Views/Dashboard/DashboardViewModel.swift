import Foundation
import Observation
import SwiftData

enum ChartRange: Int, CaseIterable, Identifiable {
    case days7 = 7
    case days30 = 30
    case days90 = 90

    var id: Int { rawValue }

    var titleKey: String {
        switch self {
        case .days7: "chart.range.7"
        case .days30: "chart.range.30"
        case .days90: "chart.range.90"
        }
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
    var editingDate = Date.now
    var editingLogID: UUID?
    var healthByDay: [String: HealthDaySnapshot] = [:]
    var sleepHistory = SleepHistory.empty
    var cycleHistory = CycleHistory.empty

    func openLog(for date: Date) {
        editingDate = CalendarDay.startOfDay(date)
        editingLogID = nil
        isLogPresented = true
    }

    func openWeightLog(_ log: WeightLog) {
        editingDate = CalendarDay.startOfDay(log.timestamp)
        editingLogID = log.id
        isLogPresented = true
    }

    func openSelectedLog() {
        openLog(for: selectedDate)
    }

    func reloadHealthAndNotifications(enabled: Bool, records: [DailyRecord], logs: [WeightLog]) async {
        let payload = await HealthKitReader.loadAll()
        healthByDay = payload.byDay
        sleepHistory = payload.sleep
        cycleHistory = payload.cycle
        let todayKey = CalendarDay.dayKey(from: .now)
        await NotificationScheduler.refresh(
            enabled: enabled,
            todayRecord: records.first { $0.dayKey == todayKey },
            hasWeightToday: WeightMetrics.hasWeight(records: records, logs: logs, on: .now),
            healthToday: healthByDay[todayKey]
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
