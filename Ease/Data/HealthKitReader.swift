import Foundation
import HealthKit

struct HealthDaySnapshot: Sendable, Equatable {
    var dayKey: String
    var activeEnergyKcal: Double?
    var previousNightSleepHours: Double?
    var isMenstrual: Bool = false

    var hasStripMetrics: Bool {
        activeEnergyKcal != nil || previousNightSleepHours != nil
    }
}

struct HealthKitPayload: Sendable, Equatable {
    var byDay: [String: HealthDaySnapshot]
    var sleep: SleepHistory
    var cycle: CycleHistory

    static let empty = HealthKitPayload(
        byDay: [:],
        sleep: .empty,
        cycle: .empty
    )
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
    static let dashboardSnapshotDays = 90
    static let sleepHistoryNights = 30
    static let cycleHistoryDays = 180

    static func load(days: Int, endingOn date: Date = .now, calendar: Calendar = .current) async -> [String: HealthDaySnapshot] {
        await loadAll(
            snapshotDays: max(days, 1),
            sleepNights: max(days, 1),
            cycleDays: max(days, 1),
            endingOn: date,
            calendar: calendar
        ).byDay
    }

    /// Dashboard snapshots plus the 30-night sleep series and 180-day cycle history.
    /// Sleep / menstrual queries are shared; HealthKit is never written.
    static func loadAll(
        snapshotDays: Int = dashboardSnapshotDays,
        sleepNights: Int = sleepHistoryNights,
        cycleDays: Int = cycleHistoryDays,
        endingOn date: Date = .now,
        calendar: Calendar = .current
    ) async -> HealthKitPayload {
#if DEBUG
        if !HKHealthStore.isHealthDataAvailable() {
            return mockPayload(
                snapshotDays: snapshotDays,
                sleepNights: sleepNights,
                cycleDays: cycleDays,
                endingOn: date,
                calendar: calendar
            )
        }
#endif
        guard HKHealthStore.isHealthDataAvailable() else { return .empty }
        let store = HKHealthStore()
        let snapshotCount = max(snapshotDays, 1)
        let sleepCount = max(sleepNights, snapshotCount)
        let cycleCount = max(cycleDays, snapshotCount)

        let snapshotStarts = CalendarDay.datesBack(snapshotCount, from: date, calendar: calendar)
        let sleepStarts = CalendarDay.datesBack(sleepCount, from: date, calendar: calendar)
        let cycleStarts = CalendarDay.datesBack(cycleCount, from: date, calendar: calendar)
        guard let energyStart = snapshotStarts.first,
              let cycleStart = cycleStarts.first else { return .empty }
        let rangeEnd = CalendarDay.endOfDay(date, calendar: calendar)

        async let energy = loadEnergy(store: store, start: energyStart, end: rangeEnd, calendar: calendar)
        async let sleep = loadSleep(store: store, dayStarts: sleepStarts, calendar: calendar)
        async let period = loadMenstrual(store: store, start: cycleStart, end: rangeEnd, calendar: calendar)

        let energyMap = await energy
        let sleepMap = await sleep
        let periodSet = await period

        var byDay: [String: HealthDaySnapshot] = [:]
        for start in snapshotStarts {
            let key = CalendarDay.dayKey(from: start, calendar: calendar)
            byDay[key] = HealthDaySnapshot(
                dayKey: key,
                activeEnergyKcal: energyMap[key],
                previousNightSleepHours: sleepMap[key],
                isMenstrual: periodSet.contains(key)
            )
        }

        return HealthKitPayload(
            byDay: byDay,
            sleep: SleepHistory.make(
                hoursByDay: sleepMap,
                nights: sleepNights,
                endingOn: date,
                calendar: calendar
            ),
            cycle: CycleMetrics.make(
                periodDayKeys: periodSet,
                endingOn: date,
                calendar: calendar
            )
        )
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
            var cursor = CalendarDay.startOfDay(sample.startDate, calendar: calendar)
            days.insert(CalendarDay.dayKey(from: cursor, calendar: calendar))
            cursor = CalendarDay.addingDays(1, to: cursor, calendar: calendar)
            while cursor < sample.endDate {
                days.insert(CalendarDay.dayKey(from: cursor, calendar: calendar))
                cursor = CalendarDay.addingDays(1, to: cursor, calendar: calendar)
            }
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
    private static func mockPayload(
        snapshotDays: Int,
        sleepNights: Int,
        cycleDays: Int,
        endingOn date: Date,
        calendar: Calendar
    ) -> HealthKitPayload {
        let sleepMap = mockSleepHours(days: max(snapshotDays, sleepNights), endingOn: date, calendar: calendar)
        let periodSet = mockPeriodDays(days: max(snapshotDays, cycleDays), endingOn: date, calendar: calendar)
        let snapshotStarts = CalendarDay.datesBack(max(snapshotDays, 1), from: date, calendar: calendar)
        var byDay: [String: HealthDaySnapshot] = [:]
        for (offset, start) in snapshotStarts.enumerated() {
            let key = CalendarDay.dayKey(from: start, calendar: calendar)
            let dayIndex = snapshotStarts.count - 1 - offset
            byDay[key] = HealthDaySnapshot(
                dayKey: key,
                activeEnergyKcal: Double(320 + (dayIndex * 17) % 280).rounded(),
                previousNightSleepHours: sleepMap[key],
                isMenstrual: periodSet.contains(key)
            )
        }
        return HealthKitPayload(
            byDay: byDay,
            sleep: SleepHistory.make(
                hoursByDay: sleepMap,
                nights: sleepNights,
                endingOn: date,
                calendar: calendar
            ),
            cycle: CycleMetrics.make(
                periodDayKeys: periodSet,
                endingOn: date,
                calendar: calendar
            )
        )
    }

    private static func mockSleepHours(
        days: Int,
        endingOn date: Date,
        calendar: Calendar
    ) -> [String: Double] {
        let dayStarts = CalendarDay.datesBack(max(days, 1), from: date, calendar: calendar)
        var hours: [String: Double] = [:]
        for (offset, start) in dayStarts.enumerated() {
            let dayIndex = dayStarts.count - 1 - offset
            let key = CalendarDay.dayKey(from: start, calendar: calendar)
            hours[key] = MeasurementBounds.roundedToTenth(6.5 + Double(dayIndex % 4) * 0.5)
        }
        return hours
    }

    private static func mockPeriodDays(
        days: Int,
        endingOn date: Date,
        calendar: Calendar
    ) -> Set<String> {
        let dayStarts = CalendarDay.datesBack(max(days, 1), from: date, calendar: calendar)
        var keys: Set<String> = []
        for (offset, start) in dayStarts.enumerated() {
            let dayIndex = dayStarts.count - 1 - offset
            if dayIndex % 28 < 5 {
                keys.insert(CalendarDay.dayKey(from: start, calendar: calendar))
            }
        }
        return keys
    }
#endif
}
