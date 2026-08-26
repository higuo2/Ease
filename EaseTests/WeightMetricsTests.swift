import XCTest
@testable import Ease

@MainActor
final class WeightMetricsTests: EaseStoreTestCase {

    func test_bmi_身高体重有效_返回一位小数() {
        let bmi = WeightMetrics.bmi(weightKg: 70, heightCm: 175)
        XCTAssertEqual(bmi, 22.9)
    }

    func test_bmi_身高或体重为0_返回nil() {
        XCTAssertNil(WeightMetrics.bmi(weightKg: 70, heightCm: 0))
        XCTAssertNil(WeightMetrics.bmi(weightKg: 0, heightCm: 175))
        XCTAssertNil(WeightMetrics.bmi(weightKg: -1, heightCm: 175))
    }

    func test_progress_减重中途_按公式clamp到0和1() {
        XCTAssertEqual(WeightMetrics.progress(start: 80, target: 70, display: 75), 0.5)
        XCTAssertEqual(WeightMetrics.progress(start: 80, target: 70, display: 80), 0)
        XCTAssertEqual(WeightMetrics.progress(start: 80, target: 70, display: 70), 1)
        XCTAssertEqual(WeightMetrics.progress(start: 80, target: 70, display: 65), 1)
        XCTAssertEqual(WeightMetrics.progress(start: 80, target: 70, display: 85), 0)
    }

    func test_progress_起止体重相同_按是否已达标返回0或1() {
        XCTAssertEqual(WeightMetrics.progress(start: 70, target: 70, display: 70), 1)
        XCTAssertEqual(WeightMetrics.progress(start: 70, target: 70, display: 69), 1)
        XCTAssertEqual(WeightMetrics.progress(start: 70, target: 70, display: 71), 0)
    }

    func test_lostKg_remainingKg_不超过0() {
        XCTAssertEqual(WeightMetrics.lostKg(start: 80, display: 75), 5.0)
        XCTAssertEqual(WeightMetrics.lostKg(start: 80, display: 85), 0)
        XCTAssertEqual(WeightMetrics.remainingKg(display: 75, target: 70), 5.0)
        XCTAssertEqual(WeightMetrics.remainingKg(display: 65, target: 70), 0)
    }

    func test_weightOnDay_同一天多条_取timestamp最大() {
        let day = calendar.testDate(2026, 8, 10)
        let samples = [
            WeightSample(date: calendar.testDate(2026, 8, 10, hour: 7), weight: 71.2),
            WeightSample(date: calendar.testDate(2026, 8, 10, hour: 21, minute: 30), weight: 70.4),
            WeightSample(date: calendar.testDate(2026, 8, 10, hour: 12), weight: 70.8)
        ]
        XCTAssertEqual(WeightMetrics.weightOnDay(samples: samples, date: day, calendar: calendar), 70.4)
    }

    func test_displayWeight_所选日无记录_回退全局最新() {
        let samples = [
            WeightSample(date: calendar.testDate(2026, 8, 8, hour: 8), weight: 72.0),
            WeightSample(date: calendar.testDate(2026, 8, 12, hour: 8), weight: 70.1)
        ]
        let selected = calendar.testDate(2026, 8, 10)
        XCTAssertEqual(
            WeightMetrics.displayWeight(samples: samples, on: selected, calendar: calendar),
            70.1
        )
    }

    func test_displayWeight_所选日有记录_不用全局最新() {
        let samples = [
            WeightSample(date: calendar.testDate(2026, 8, 10, hour: 8), weight: 71.5),
            WeightSample(date: calendar.testDate(2026, 8, 12, hour: 8), weight: 70.1)
        ]
        XCTAssertEqual(
            WeightMetrics.displayWeight(samples: samples, on: calendar.testDate(2026, 8, 10), calendar: calendar),
            71.5
        )
    }

    func test_sevenDayMA_窗口内满7个有体重日_返回均值() {
        let ending = calendar.testDate(2026, 8, 20)
        let samples = (0..<7).map { offset in
            WeightSample(
                date: calendar.testDate(2026, 8, 14 + offset, hour: 8),
                weight: 70.0 + Double(offset)
            )
        }
        let expected = MeasurementBounds.roundedToTenth((70.0 + 71 + 72 + 73 + 74 + 75 + 76) / 7)
        XCTAssertEqual(
            WeightMetrics.sevenDayMA(samples: samples, endingOn: ending, calendar: calendar),
            expected
        )
    }

    func test_sevenDayMA_不足7个有体重日_返回nil() {
        let ending = calendar.testDate(2026, 8, 20)
        let samples = (0..<6).map { offset in
            WeightSample(
                date: calendar.testDate(2026, 8, 15 + offset, hour: 8),
                weight: 70
            )
        }
        XCTAssertNil(WeightMetrics.sevenDayMA(samples: samples, endingOn: ending, calendar: calendar))
    }

    func test_sevenDayMA_一天多次称重_当天只取最后一次进入窗口() {
        let ending = calendar.testDate(2026, 8, 20)
        var samples = (0..<7).map { offset in
            WeightSample(
                date: calendar.testDate(2026, 8, 14 + offset, hour: 8),
                weight: 70
            )
        }
        samples.append(WeightSample(date: calendar.testDate(2026, 8, 20, hour: 21), weight: 77))
        XCTAssertEqual(
            WeightMetrics.sevenDayMA(samples: samples, endingOn: ending, calendar: calendar),
            71.0
        )
    }

    func test_samples_该日已有WeightLog_忽略legacy_DailyRecord_weight() throws {
        let day = calendar.testDate(2026, 8, 10)
        let record = DailyRecord(date: day, calendar: calendar)
        record.weight = 99.9
        let log = WeightLog(timestamp: calendar.testDate(2026, 8, 10, hour: 8), weight: 70.2)
        context.insert(record)
        context.insert(log)
        try context.save()

        let samples = WeightMetrics.samples(from: [record], logs: [log], calendar: calendar)
        XCTAssertEqual(samples, [WeightSample(date: log.timestamp, weight: 70.2)])
    }

    func test_samples_该日无WeightLog_使用legacy快照() throws {
        let day = calendar.testDate(2026, 8, 10)
        let record = DailyRecord(date: day, calendar: calendar)
        record.weight = 71.3
        context.insert(record)
        try context.save()

        let samples = WeightMetrics.samples(from: [record], logs: [], calendar: calendar)
        XCTAssertEqual(samples.count, 1)
        XCTAssertEqual(samples[0].weight, 71.3)
        XCTAssertEqual(
            CalendarDay.dayKey(from: samples[0].date, calendar: calendar),
            "2026-08-10"
        )
    }

    func test_latestBodyFat_所选日有体脂log_不用legacy() throws {
        let day = calendar.testDate(2026, 8, 10)
        let record = DailyRecord(date: day, calendar: calendar)
        record.bodyFat = 30.0
        let morning = WeightLog(
            timestamp: calendar.testDate(2026, 8, 10, hour: 8),
            weight: 70,
            bodyFat: 18.2
        )
        let evening = WeightLog(
            timestamp: calendar.testDate(2026, 8, 10, hour: 21),
            weight: 70.4,
            bodyFat: 18.8
        )
        context.insert(record)
        context.insert(morning)
        context.insert(evening)
        try context.save()

        XCTAssertEqual(
            WeightMetrics.latestBodyFat(records: [record], logs: [morning, evening], on: day, calendar: calendar),
            18.8
        )
    }

    func test_latestBodyFat_所选日log无体脂_回退legacy() throws {
        let day = calendar.testDate(2026, 8, 10)
        let record = DailyRecord(date: day, calendar: calendar)
        record.bodyFat = 19.4
        let log = WeightLog(timestamp: calendar.testDate(2026, 8, 10, hour: 8), weight: 70, bodyFat: nil)
        context.insert(record)
        context.insert(log)
        try context.save()

        XCTAssertEqual(
            WeightMetrics.latestBodyFat(records: [record], logs: [log], on: day, calendar: calendar),
            19.4
        )
    }

    func test_hasWeight_仅legacy或仅log都算有体重() throws {
        let day = calendar.testDate(2026, 8, 10)
        let record = DailyRecord(date: day, calendar: calendar)
        record.weight = 70
        context.insert(record)
        try context.save()
        XCTAssertTrue(WeightMetrics.hasWeight(records: [record], logs: [], on: day, calendar: calendar))

        let log = WeightLog(timestamp: calendar.testDate(2026, 8, 10, hour: 8), weight: 70)
        context.insert(log)
        try context.save()
        XCTAssertTrue(WeightMetrics.hasWeight(records: [], logs: [log], on: day, calendar: calendar))
        XCTAssertFalse(
            WeightMetrics.hasWeight(
                records: [],
                logs: [log],
                on: calendar.testDate(2026, 8, 11),
                calendar: calendar
            )
        )
    }

    func test_lastPerDay_同一天多条_只留timestamp最大() {
        let samples = [
            WeightSample(date: calendar.testDate(2026, 8, 10, hour: 7), weight: 71.2),
            WeightSample(date: calendar.testDate(2026, 8, 10, hour: 21), weight: 70.4),
            WeightSample(date: calendar.testDate(2026, 8, 11, hour: 8), weight: 70.1)
        ]
        let last = WeightMetrics.lastPerDay(samples: samples, calendar: calendar)
        XCTAssertEqual(last.count, 2)
        XCTAssertEqual(last[0].weight, 70.4)
        XCTAssertEqual(last[1].weight, 70.1)
    }

    func test_bmiClassifier_中国成人切点含边界() {
        XCTAssertEqual(BMIClassifier.chinaBand(bmi: 18.4), .underweight)
        XCTAssertEqual(BMIClassifier.chinaBand(bmi: 18.5), .normal)
        XCTAssertEqual(BMIClassifier.chinaBand(bmi: 23.9), .normal)
        XCTAssertEqual(BMIClassifier.chinaBand(bmi: 24.0), .overweight)
        XCTAssertEqual(BMIClassifier.chinaBand(bmi: 27.9), .overweight)
        XCTAssertEqual(BMIClassifier.chinaBand(bmi: 28.0), .obese)
    }

    func test_bmiClassifier_WHO对照切点() {
        XCTAssertEqual(BMIClassifier.whoBand(bmi: 18.4), .underweight)
        XCTAssertEqual(BMIClassifier.whoBand(bmi: 24.0), .normal)
        XCTAssertEqual(BMIClassifier.whoBand(bmi: 24.9), .normal)
        XCTAssertEqual(BMIClassifier.whoBand(bmi: 25.0), .overweight)
        XCTAssertEqual(BMIClassifier.whoBand(bmi: 29.9), .overweight)
        XCTAssertEqual(BMIClassifier.whoBand(bmi: 30.0), .obese)
    }

    func test_bmiClassifier_未满18不评价_满18按成人() {
        let now = calendar.testDate(2026, 8, 26)
        let seventeen = calendar.testDate(2008, 8, 27)
        let eighteen = calendar.testDate(2008, 8, 26)
        XCTAssertEqual(
            BMIClassifier.classify(bmi: 22.0, birthDate: seventeen, now: now, calendar: calendar),
            .notApplicable
        )
        XCTAssertEqual(
            BMIClassifier.classify(bmi: 22.0, birthDate: eighteen, now: now, calendar: calendar),
            .band(.normal, assumedAdult: false)
        )
    }

    func test_bmiClassifier_无生日按成人并标记assumedAdult() {
        XCTAssertEqual(
            BMIClassifier.classify(bmi: 25.6, birthDate: nil, now: calendar.testDate(2026, 8, 26), calendar: calendar),
            .band(.overweight, assumedAdult: true)
        )
        XCTAssertEqual(
            BMIClassifier.classify(bmi: nil, birthDate: nil, calendar: calendar),
            .none
        )
    }

    func test_bmiClassifier_中国正常体重区间() {
        let range = BMIClassifier.chinaHealthyWeightKg(heightCm: 170)
        XCTAssertEqual(range?.low, 53.5)
        XCTAssertEqual(range?.high, 69.1)
        XCTAssertNil(BMIClassifier.chinaHealthyWeightKg(heightCm: 0))
    }
}
