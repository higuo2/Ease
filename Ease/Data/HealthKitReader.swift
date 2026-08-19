import Foundation
import HealthKit
import SwiftData

struct HealthDaySnapshot: Sendable, Equatable {
    var dayKey: String
    var activeEnergyKcal: Double?
    var previousNightSleepHours: Double?
    var isMenstrual: Bool = false

    var hasStripMetrics: Bool {
        activeEnergyKcal != nil || previousNightSleepHours != nil
    }
}

enum HealthDisplay {
    static func tags(record: DailyRecord?, isMenstrual: Bool) -> [VariableTag] {
        var tags = record?.variableTags ?? []
        if isMenstrual {
            tags.append(.period)
        }
        return VariableTag.sanitized(tags)
    }
}

enum HealthKitReader {
    static func load(days: Int, endingOn date: Date = .now, calendar: Calendar = .current) async -> [String: HealthDaySnapshot] {
#if DEBUG
        if !HKHealthStore.isHealthDataAvailable() {
            return mockSnapshots(days: days, endingOn: date, calendar: calendar)
        }
#endif
        guard HKHealthStore.isHealthDataAvailable() else { return [:] }
        let store = HKHealthStore()
        let days = max(days, 1)
        let dayStarts = CalendarDay.datesBack(days, from: date, calendar: calendar)
        guard let rangeStart = dayStarts.first else { return [:] }
        let rangeEnd = CalendarDay.endOfDay(date, calendar: calendar)

        var snapshots: [String: HealthDaySnapshot] = [:]
        for start in dayStarts {
            let key = CalendarDay.dayKey(from: start, calendar: calendar)
            snapshots[key] = HealthDaySnapshot(dayKey: key)
        }

        async let energy = loadEnergy(store: store, start: rangeStart, end: rangeEnd, calendar: calendar)
        async let sleep = loadSleep(store: store, dayStarts: dayStarts, calendar: calendar)
        async let period = loadMenstrual(store: store, start: rangeStart, end: rangeEnd, calendar: calendar)

        let energyMap = await energy
        let sleepMap = await sleep
        let periodSet = await period

        for key in snapshots.keys {
            snapshots[key]?.activeEnergyKcal = energyMap[key]
            snapshots[key]?.previousNightSleepHours = sleepMap[key]
            snapshots[key]?.isMenstrual = periodSet.contains(key)
        }
        return snapshots
    }

    private static func loadEnergy(
        store: HKHealthStore,
        start: Date,
        end: Date,
        calendar: Calendar
    ) async -> [String: Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return [:] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKStatisticsCollectionQueryDescriptor(
            predicate: .quantitySample(type: type, predicate: predicate),
            options: .cumulativeSum,
            anchorDate: start,
            intervalComponents: DateComponents(day: 1)
        )
        guard let collection = try? await descriptor.result(for: store) else { return [:] }
        var result: [String: Double] = [:]
        collection.enumerateStatistics(from: start, to: end) { stats, _ in
            guard let kcal = stats.sumQuantity()?.doubleValue(for: .kilocalorie()), kcal > 0 else { return }
            let key = CalendarDay.dayKey(from: stats.startDate, calendar: calendar)
            result[key] = kcal.rounded()
        }
        return result
    }

    private static func loadSleep(
        store: HKHealthStore,
        dayStarts: [Date],
        calendar: Calendar
    ) async -> [String: Double] {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis),
              let firstDay = dayStarts.first,
              let lastDay = dayStarts.last else { return [:] }
        let windowStart = calendar.date(byAdding: .hour, value: -12, to: firstDay) ?? firstDay
        let windowEnd = calendar.date(byAdding: .hour, value: 12, to: lastDay) ?? lastDay
        let predicate = HKQuery.predicateForSamples(withStart: windowStart, end: windowEnd)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: [SortDescriptor(\HKCategorySample.startDate, order: .forward)]
        )
        guard let samples = try? await descriptor.result(for: store) else { return [:] }

        var totals: [String: TimeInterval] = [:]
        for day in dayStarts {
            let nightStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: CalendarDay.addingDays(-1, to: day, calendar: calendar)) ?? day
            let nightEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
            let duration = asleepDuration(samples: samples, nightStart: nightStart, nightEnd: nightEnd)
            if duration > 0 {
                totals[CalendarDay.dayKey(from: day, calendar: calendar)] = duration
            }
        }
        return totals.mapValues { MeasurementBounds.roundedToTenth($0 / 3600) }
    }

    private static func asleepDuration(
        samples: [HKCategorySample],
        nightStart: Date,
        nightEnd: Date
    ) -> TimeInterval {
        var staged: [(start: Date, end: Date)] = []
        var fallback: [(start: Date, end: Date)] = []
        for sample in samples {
            guard let kind = HKCategoryValueSleepAnalysis(rawValue: sample.value), isAsleep(sample.value) else {
                continue
            }
            let start = max(sample.startDate, nightStart)
            let end = min(sample.endDate, nightEnd)
            guard end > start else { continue }
            switch kind {
            case .asleepCore, .asleepDeep, .asleepREM:
                staged.append((start, end))
            default:
                fallback.append((start, end))
            }
        }
        return mergedDuration(staged.isEmpty ? fallback : staged)
    }

    private static func mergedDuration(_ intervals: [(start: Date, end: Date)]) -> TimeInterval {
        let sorted = intervals.sorted { $0.start < $1.start }
        guard var current = sorted.first else { return 0 }
        var total: TimeInterval = 0
        for next in sorted.dropFirst() {
            if next.start <= current.end {
                current.end = max(current.end, next.end)
            } else {
                total += current.end.timeIntervalSince(current.start)
                current = next
            }
        }
        total += current.end.timeIntervalSince(current.start)
        return total
    }

    private static func loadMenstrual(
        store: HKHealthStore,
        start: Date,
        end: Date,
        calendar: Calendar
    ) async -> Set<String> {
        guard let type = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let descriptor = HKSampleQueryDescriptor(
            predicates: [.categorySample(type: type, predicate: predicate)],
            sortDescriptors: []
        )
        guard let samples = try? await descriptor.result(for: store) else { return [] }
        var days: Set<String> = []
        for sample in samples {
            guard isMenstrualFlow(sample.value) else { continue }
            days.insert(CalendarDay.dayKey(from: sample.startDate, calendar: calendar))
        }
        return days
    }

    private static func isAsleep(_ value: Int) -> Bool {
        switch HKCategoryValueSleepAnalysis(rawValue: value) {
        case .asleep, .asleepUnspecified, .asleepCore, .asleepDeep, .asleepREM:
            return true
        default:
            return false
        }
    }

    private static func isMenstrualFlow(_ value: Int) -> Bool {
        switch HKCategoryValueMenstrualFlow(rawValue: value) {
        case .unspecified, .light, .medium, .heavy:
            return true
        default:
            return false
        }
    }

#if DEBUG
    private static func mockSnapshots(days: Int, endingOn date: Date, calendar: Calendar) -> [String: HealthDaySnapshot] {
        let count = max(days, 1)
        let dayStarts = CalendarDay.datesBack(count, from: date, calendar: calendar)
        let todayKey = CalendarDay.dayKey(from: date, calendar: calendar)
        var snapshots: [String: HealthDaySnapshot] = [:]
        for (offset, start) in dayStarts.enumerated() {
            let key = CalendarDay.dayKey(from: start, calendar: calendar)
            let dayIndex = dayStarts.count - 1 - offset
            snapshots[key] = HealthDaySnapshot(
                dayKey: key,
                activeEnergyKcal: Double(320 + (dayIndex * 17) % 280).rounded(),
                previousNightSleepHours: MeasurementBounds.roundedToTenth(6.5 + Double(dayIndex % 4) * 0.5),
                isMenstrual: key == todayKey || dayIndex % 28 < 5
            )
        }
        return snapshots
    }
#endif
}
