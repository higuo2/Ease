import XCTest
@testable import Ease

final class AdvancedPaceEstimatorTests: XCTestCase {
    private var calendar: Calendar { EaseTestCalendar.make() }

    func test_线性减重_返回未来达标日与默认系数() {
        let samples = consecutive(from: calendar.testDate(2026, 7, 1), count: 40) {
            MeasurementBounds.roundedToTenth(80 - 0.2 * Double($0))
        }
        let now = samples.last!.date
        let result = AdvancedPaceEstimator.estimate(
            samples: samples,
            targetWeight: 70,
            displayWeight: samples.last?.weight,
            progress: WeightMetrics.progress(start: 80, target: 70, display: samples.last!.weight),
            context: emptyContext(),
            now: now,
            calendar: calendar
        )
        XCTAssertNotNil(result)
        XCTAssertGreaterThan(result!.eta, CalendarDay.startOfDay(now, calendar: calendar))
        XCTAssertEqual(result!.sleepFactor, 1, accuracy: 0.001)
        XCTAssertEqual(result!.energyFactor, 1, accuracy: 0.001)
        XCTAssertEqual(result!.periodFactor, 1, accuracy: 0.001)
        XCTAssertEqual(result!.periodDaysInWindow, 0)
        XCTAssertNil(result!.averageSleepHours)
        XCTAssertNil(result!.averageEnergyKcal)
        let horizon = CalendarDay.addingDays(730, to: now, calendar: calendar)
        XCTAssertLessThanOrEqual(result!.eta, horizon)
    }

    func test_均线点不足14_隐藏() {
        let samples = consecutive(from: calendar.testDate(2026, 7, 1), count: 13) { 80 - 0.2 * Double($0) }
        XCTAssertNil(
            AdvancedPaceEstimator.estimate(
                samples: samples,
                targetWeight: 70,
                displayWeight: samples.last?.weight,
                progress: 0.2,
                context: emptyContext(),
                now: samples.last!.date,
                calendar: calendar
            )
        )
    }

    func test_进度已达100_隐藏() {
        let samples = consecutive(from: calendar.testDate(2026, 7, 1), count: 40) { 70 }
        XCTAssertNil(
            AdvancedPaceEstimator.estimate(
                samples: samples,
                targetWeight: 70,
                displayWeight: 70,
                progress: 1,
                context: emptyContext(),
                now: samples.last!.date,
                calendar: calendar
            )
        )
    }

    func test_斜率过小_隐藏() {
        let samples = consecutive(from: calendar.testDate(2026, 7, 1), count: 40) { 80 }
        XCTAssertNil(
            AdvancedPaceEstimator.estimate(
                samples: samples,
                targetWeight: 70,
                displayWeight: 80,
                progress: 0,
                context: emptyContext(),
                now: samples.last!.date,
                calendar: calendar
            )
        )
    }

    func test_睡眠低于目标_放缓系数() {
        let start = calendar.testDate(2026, 7, 1)
        let samples = consecutive(from: start, count: 40) {
            MeasurementBounds.roundedToTenth(80 - 0.2 * Double($0))
        }
        let sleepHours = hoursByDay(from: start, count: 50, value: 6.0)
        let result = AdvancedPaceEstimator.estimate(
            samples: samples,
            targetWeight: 70,
            displayWeight: samples.last?.weight,
            progress: WeightMetrics.progress(start: 80, target: 70, display: samples.last!.weight),
            context: AdvancedPaceEstimator.Context(
                sleepHoursByDay: sleepHours,
                energyKcalByDay: [:],
                periodDayKeys: [],
                sleepTargetHours: 8
            ),
            now: samples.last!.date,
            calendar: calendar
        )
        guard let result else {
            return XCTFail("expected estimate")
        }
        XCTAssertEqual(result.sleepFactor, 0.88, accuracy: 0.001)
        XCTAssertEqual(result.averageSleepHours, 6.0)
        XCTAssertEqual(result.energyFactor, 1, accuracy: 0.001)
        XCTAssertEqual(result.periodFactor, 1, accuracy: 0.001)
    }

    func test_当天经期_周期系数0_9() {
        let start = calendar.testDate(2026, 7, 1)
        let samples = consecutive(from: start, count: 40) {
            MeasurementBounds.roundedToTenth(80 - 0.2 * Double($0))
        }
        let now = samples.last!.date
        let todayKey = CalendarDay.dayKey(from: now, calendar: calendar)
        let result = AdvancedPaceEstimator.estimate(
            samples: samples,
            targetWeight: 70,
            displayWeight: samples.last?.weight,
            progress: WeightMetrics.progress(start: 80, target: 70, display: samples.last!.weight),
            context: AdvancedPaceEstimator.Context(
                sleepHoursByDay: [:],
                energyKcalByDay: [:],
                periodDayKeys: [todayKey],
                sleepTargetHours: 8
            ),
            now: now,
            calendar: calendar
        )
        guard let result else {
            return XCTFail("expected estimate")
        }
        XCTAssertEqual(result.periodFactor, 0.9, accuracy: 0.001)
    }

    func test_窗口内经期满4天且当天无经期_周期系数0_95() {
        let start = calendar.testDate(2026, 7, 1)
        let samples = consecutive(from: start, count: 40) {
            MeasurementBounds.roundedToTenth(80 - 0.2 * Double($0))
        }
        let now = samples.last!.date
        let today = CalendarDay.startOfDay(now, calendar: calendar)
        let todayKey = CalendarDay.dayKey(from: today, calendar: calendar)
        let periodKeys = Set((1...4).compactMap { offset -> String? in
            calendar.date(byAdding: .day, value: -offset, to: today).map {
                CalendarDay.dayKey(from: $0, calendar: calendar)
            }
        })
        XCTAssertFalse(periodKeys.contains(todayKey))
        let result = AdvancedPaceEstimator.estimate(
            samples: samples,
            targetWeight: 70,
            displayWeight: samples.last?.weight,
            progress: WeightMetrics.progress(start: 80, target: 70, display: samples.last!.weight),
            context: AdvancedPaceEstimator.Context(
                sleepHoursByDay: [:],
                energyKcalByDay: [:],
                periodDayKeys: periodKeys,
                sleepTargetHours: 8
            ),
            now: now,
            calendar: calendar
        )
        guard let result else {
            return XCTFail("expected estimate")
        }
        XCTAssertEqual(result.periodFactor, 0.95, accuracy: 0.001)
        XCTAssertEqual(result.periodDaysInWindow, 4)
    }

    private func emptyContext() -> AdvancedPaceEstimator.Context {
        AdvancedPaceEstimator.Context(
            sleepHoursByDay: [:],
            energyKcalByDay: [:],
            periodDayKeys: [],
            sleepTargetHours: 8
        )
    }

    private func hoursByDay(from start: Date, count: Int, value: Double) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: (0..<count).compactMap { offset -> (String, Double)? in
            guard let date = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return (CalendarDay.dayKey(from: date, calendar: calendar), value)
        })
    }

    private func consecutive(
        from start: Date,
        count: Int,
        weight: (Int) -> Double
    ) -> [WeightSample] {
        (0..<count).map { offset in
            WeightSample(
                date: calendar.date(byAdding: .day, value: offset, to: start)!,
                weight: weight(offset)
            )
        }
    }
}
