import XCTest
@testable import Ease

final class InsightEngineTests: XCTestCase {
    private var calendar: Calendar { EaseTestCalendar.make() }

    func test_连续体重不足_无体重类洞察() {
        let start = calendar.testDate(2026, 7, 1)
        let samples = consecutiveWeights(from: start, count: 8) { 80 - 0.1 * Double($0) }
        let report = HealthInsightEngine.evaluate(
            samples: samples,
            series: .init(sleepHoursByDay: [:], energyKcalByDay: [:], periodDayKeys: []),
            now: samples.last!.date,
            calendar: calendar
        )
        XCTAssertTrue(report.insights.filter { $0.kind != .weekdaySleep }.isEmpty)
    }

    func test_短睡眠次日体重变化更大() {
        let start = calendar.testDate(2026, 7, 1)
        let built = shortSleepWeights(from: start, days: 30)
        let report = HealthInsightEngine.evaluate(
            samples: built.samples,
            series: .init(
                sleepHoursByDay: built.sleep,
                energyKcalByDay: [:],
                periodDayKeys: []
            ),
            now: built.samples.last!.date,
            calendar: calendar
        )
        let insight = report.first(of: .shortSleepWeight)
        guard let insight else {
            return XCTFail("expected shortSleepWeight")
        }
        XCTAssertEqual(insight.inMean, 0.4, accuracy: 0.001)
        XCTAssertEqual(insight.outMean, -0.2, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(insight.inCount, HealthInsightEngine.minGroupCount)
        XCTAssertGreaterThanOrEqual(insight.outCount, HealthInsightEngine.minGroupCount)
    }

    func test_体重差低于0_1kg_隐藏() {
        let start = calendar.testDate(2026, 7, 1)
        var samples: [WeightSample] = []
        var sleep: [String: Double] = [:]
        var weight = 80.0
        for offset in 0..<30 {
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            if offset > 0 {
                weight += offset.isMultiple(of: 2) ? 0.04 : 0.0
            }
            samples.append(WeightSample(date: date, weight: MeasurementBounds.roundedToTenth(weight)))
            sleep[CalendarDay.dayKey(from: date, calendar: calendar)] = offset.isMultiple(of: 2) ? 5.0 : 7.5
        }
        let report = HealthInsightEngine.evaluate(
            samples: samples,
            series: .init(sleepHoursByDay: sleep, energyKcalByDay: [:], periodDayKeys: []),
            now: samples.last!.date,
            calendar: calendar
        )
        XCTAssertNil(report.first(of: .shortSleepWeight))
    }

    func test_周三夜睡眠更短_按夜归属星期() {
        let start = calendar.testDate(2026, 7, 1)
        XCTAssertEqual(calendar.component(.weekday, from: start), 4)
        var sleep: [String: Double] = [:]
        let days = 56
        for offset in 0..<days {
            let morning = calendar.date(byAdding: .day, value: offset, to: start)!
            let night = CalendarDay.addingDays(-1, to: morning, calendar: calendar)
            let weekday = calendar.component(.weekday, from: night)
            let key = CalendarDay.dayKey(from: morning, calendar: calendar)
            sleep[key] = weekday == 4 ? 5.0 : 7.5
        }
        let now = calendar.date(byAdding: .day, value: days - 1, to: start)!
        let report = HealthInsightEngine.evaluate(
            samples: [],
            series: .init(sleepHoursByDay: sleep, energyKcalByDay: [:], periodDayKeys: []),
            now: now,
            calendar: calendar
        )
        let insight = report.first(of: .weekdaySleep)
        guard let insight else {
            return XCTFail("expected weekdaySleep")
        }
        XCTAssertEqual(insight.weekday, 4)
        XCTAssertEqual(insight.inMean, 5.0, accuracy: 0.001)
        XCTAssertEqual(insight.outMean, 7.5, accuracy: 0.001)
        let english = Locale(identifier: "en")
        let headline = insight.localizedHeadline(locale: english, calendar: calendar)
        XCTAssertTrue(headline.hasPrefix("Shorter sleep on "))
        XCTAssertTrue(headline.hasSuffix("s"))
        XCTAssertFalse(headline.lowercased().contains("vs"))
        XCTAssertEqual(insight.deltaText(), EaseFormatters.signedSleepDelta(-2.5))
        let samples = insight.sampleSizeText(locale: english)
        XCTAssertTrue(samples.hasPrefix("Based on "))
        XCTAssertTrue(samples.contains("logged nights"))
        XCTAssertFalse(samples.contains("n="))
        XCTAssertFalse(samples.lowercased().contains("vs"))
    }

    func test_经期日体重变化更大() {
        let start = calendar.testDate(2026, 7, 1)
        var samples: [WeightSample] = []
        var period: Set<String> = []
        var weight = 80.0
        for offset in 0..<30 {
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            let key = CalendarDay.dayKey(from: date, calendar: calendar)
            if offset > 0 {
                let isPeriod = offset % 5 < 2
                if isPeriod { period.insert(key) }
                weight += isPeriod ? 0.3 : -0.2
            }
            samples.append(WeightSample(date: date, weight: MeasurementBounds.roundedToTenth(weight)))
        }
        let report = HealthInsightEngine.evaluate(
            samples: samples,
            series: .init(sleepHoursByDay: [:], energyKcalByDay: [:], periodDayKeys: period),
            now: samples.last!.date,
            calendar: calendar
        )
        let insight = report.first(of: .periodWeight)
        XCTAssertNotNil(insight)
        XCTAssertGreaterThan(insight!.inMean, insight!.outMean)
        XCTAssertGreaterThanOrEqual(abs(insight!.inMean - insight!.outMean), HealthInsightEngine.minWeightDeltaKg)
    }

    func test_前一日低消耗_对照次日体重变化() {
        let start = calendar.testDate(2026, 7, 1)
        var samples: [WeightSample] = []
        var energy: [String: Double] = [:]
        var weight = 80.0
        for offset in 0..<31 {
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            let key = CalendarDay.dayKey(from: date, calendar: calendar)
            energy[key] = offset.isMultiple(of: 2) ? 200 : 500
            if offset > 0 {
                let previous = calendar.date(byAdding: .day, value: offset - 1, to: start)!
                let previousKey = CalendarDay.dayKey(from: previous, calendar: calendar)
                weight += (energy[previousKey] ?? 500) < 350 ? 0.3 : -0.2
            }
            samples.append(WeightSample(date: date, weight: MeasurementBounds.roundedToTenth(weight)))
        }
        let report = HealthInsightEngine.evaluate(
            samples: samples,
            series: .init(sleepHoursByDay: [:], energyKcalByDay: energy, periodDayKeys: []),
            now: samples.last!.date,
            calendar: calendar
        )
        let insight = report.first(of: .lowEnergyWeight)
        guard let insight else {
            return XCTFail("expected lowEnergyWeight")
        }
        XCTAssertEqual(insight.inMean, 0.3, accuracy: 0.001)
        XCTAssertEqual(insight.outMean, -0.2, accuracy: 0.001)
    }

    func test_趋势最多三条_按效果量排序() {
        let start = calendar.testDate(2026, 7, 1)
        let short = shortSleepWeights(from: start, days: 56)
        var energy: [String: Double] = [:]
        var period: Set<String> = []
        var sleep = short.sleep
        for offset in 0..<56 {
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            let key = CalendarDay.dayKey(from: date, calendar: calendar)
            let night = CalendarDay.addingDays(-1, to: date, calendar: calendar)
            if calendar.component(.weekday, from: night) == 4 {
                sleep[key] = 4.5
            }
            energy[key] = offset.isMultiple(of: 2) ? 180 : 520
            if offset % 6 < 2 { period.insert(key) }
        }
        let report = HealthInsightEngine.evaluate(
            samples: short.samples,
            series: .init(sleepHoursByDay: sleep, energyKcalByDay: energy, periodDayKeys: period),
            now: short.samples.last!.date,
            calendar: calendar
        )
        XCTAssertLessThanOrEqual(report.trend.count, HealthInsightEngine.maxTrendInsights)
        if report.insights.count >= 2 {
            XCTAssertGreaterThanOrEqual(report.insights[0].score, report.insights[1].score)
        }
    }

    func test_非连续称重不进入日变化() {
        let samples = [
            WeightSample(date: calendar.testDate(2026, 7, 1), weight: 80),
            WeightSample(date: calendar.testDate(2026, 7, 3), weight: 81),
            WeightSample(date: calendar.testDate(2026, 7, 5), weight: 82)
        ]
        var sleep: [String: Double] = [:]
        for sample in samples {
            sleep[CalendarDay.dayKey(from: sample.date, calendar: calendar)] = 5.0
        }
        let report = HealthInsightEngine.evaluate(
            samples: samples,
            series: .init(sleepHoursByDay: sleep, energyKcalByDay: [:], periodDayKeys: []),
            now: samples.last!.date,
            calendar: calendar
        )
        XCTAssertNil(report.first(of: .shortSleepWeight))
    }

    func test_series合并_healthByDay补足历史缺口() {
        let day = calendar.testDate(2026, 8, 10)
        let key = CalendarDay.dayKey(from: day, calendar: calendar)
        let series = HealthInsightEngine.series(
            healthByDay: [
                key: HealthDaySnapshot(
                    dayKey: key,
                    activeEnergyKcal: 400,
                    previousNightSleepHours: 7.2,
                    isMenstrual: true
                )
            ],
            sleepHistory: .empty,
            energyHistory: .empty,
            cycleHistory: .empty
        )
        XCTAssertEqual(series.sleepHoursByDay[key], 7.2)
        XCTAssertEqual(series.energyKcalByDay[key], 400)
        XCTAssertTrue(series.periodDayKeys.contains(key))
    }

    func test_展示字段_短睡眠含样本数与标题键() {
        let start = calendar.testDate(2026, 7, 1)
        let built = shortSleepWeights(from: start, days: 30)
        let report = HealthInsightEngine.evaluate(
            samples: built.samples,
            series: .init(
                sleepHoursByDay: built.sleep,
                energyKcalByDay: [:],
                periodDayKeys: []
            ),
            now: built.samples.last!.date,
            calendar: calendar
        )
        let insight = report.first(of: .shortSleepWeight)
        guard let insight else {
            return XCTFail("expected shortSleepWeight")
        }
        XCTAssertEqual(insight.titleKey, "trend.insights.shortSleepWeight.title.up")
        XCTAssertTrue(insight.comparesWeight)
        XCTAssertEqual(insight.delta, 0.6, accuracy: 0.001)
        let english = Locale(identifier: "en")
        let samples = insight.sampleSizeText(locale: english)
        XCTAssertEqual(samples, "Based on \(insight.sampleCount) logged days")
        XCTAssertFalse(samples.lowercased().contains("vs"))
        XCTAssertFalse(samples.contains("n="))
        let headline = insight.localizedHeadline(locale: english, calendar: calendar)
        XCTAssertEqual(headline, "Weight up after short nights")
        XCTAssertFalse(headline.lowercased().contains("vs"))
        XCTAssertTrue(insight.accessibilitySummary(locale: english, calendar: calendar).contains("\(insight.sampleCount)"))
        XCTAssertFalse(insight.outGroupLabel(locale: english).lowercased().contains("vs"))
    }

    private func consecutiveWeights(
        from start: Date,
        count: Int,
        weight: (Int) -> Double
    ) -> [WeightSample] {
        (0..<count).map { offset in
            WeightSample(
                date: calendar.date(byAdding: .day, value: offset, to: start)!,
                weight: MeasurementBounds.roundedToTenth(weight(offset))
            )
        }
    }

    private func shortSleepWeights(from start: Date, days: Int) -> (samples: [WeightSample], sleep: [String: Double]) {
        var samples: [WeightSample] = []
        var sleep: [String: Double] = [:]
        var weight = 80.0
        for offset in 0..<days {
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            let key = CalendarDay.dayKey(from: date, calendar: calendar)
            let short = offset.isMultiple(of: 2)
            sleep[key] = short ? 5.0 : 7.5
            if offset > 0 {
                weight += short ? 0.4 : -0.2
            }
            samples.append(WeightSample(date: date, weight: MeasurementBounds.roundedToTenth(weight)))
        }
        return (samples, sleep)
    }
}
