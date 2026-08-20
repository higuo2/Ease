import XCTest
@testable import Ease

final class PaceEstimatorTests: XCTestCase {
    private var calendar: Calendar { EaseTestCalendar.make() }

    func test_线性减重_返回未来达标日() {
        let start = calendar.testDate(2026, 7, 1, hour: 8)
        let samples = (0..<40).map { offset in
            WeightSample(
                date: calendar.date(byAdding: .day, value: offset, to: start)!,
                weight: MeasurementBounds.roundedToTenth(80 - 0.2 * Double(offset))
            )
        }
        let now = samples.last!.date
        let eta = PaceEstimator.estimate(
            samples: samples,
            targetWeight: 70,
            displayWeight: samples.last?.weight,
            progress: WeightMetrics.progress(start: 80, target: 70, display: samples.last!.weight),
            now: now,
            calendar: calendar
        )
        XCTAssertNotNil(eta)
        XCTAssertGreaterThan(eta!, CalendarDay.startOfDay(now, calendar: calendar))
        let horizon = CalendarDay.addingDays(730, to: now, calendar: calendar)
        XCTAssertLessThanOrEqual(eta!, horizon)
    }

    func test_均线点不足14_隐藏() {
        let start = calendar.testDate(2026, 7, 1, hour: 8)
        let samples = (0..<13).map { offset in
            WeightSample(
                date: calendar.date(byAdding: .day, value: offset, to: start)!,
                weight: 80 - 0.2 * Double(offset)
            )
        }
        XCTAssertNil(
            PaceEstimator.estimate(
                samples: samples,
                targetWeight: 70,
                displayWeight: samples.last?.weight,
                progress: 0.2,
                now: samples.last!.date,
                calendar: calendar
            )
        )
    }

    func test_进度已达100_隐藏() {
        let samples = consecutive(from: calendar.testDate(2026, 7, 1), count: 40) { 70 }
        XCTAssertNil(
            PaceEstimator.estimate(
                samples: samples,
                targetWeight: 70,
                displayWeight: 70,
                progress: 1,
                now: samples.last!.date,
                calendar: calendar
            )
        )
    }

    func test_无displayWeight_隐藏() {
        let samples = consecutive(from: calendar.testDate(2026, 7, 1), count: 40) { 80 - 0.2 * Double($0) }
        XCTAssertNil(
            PaceEstimator.estimate(
                samples: samples,
                targetWeight: 70,
                displayWeight: nil,
                progress: 0.3,
                now: samples.last!.date,
                calendar: calendar
            )
        )
    }

    func test_斜率过小_隐藏() {
        let samples = consecutive(from: calendar.testDate(2026, 7, 1), count: 40) { 80 }
        XCTAssertNil(
            PaceEstimator.estimate(
                samples: samples,
                targetWeight: 70,
                displayWeight: 80,
                progress: 0,
                now: samples.last!.date,
                calendar: calendar
            )
        )
    }

    func test_斜率远离目标_隐藏() {
        let samples = consecutive(from: calendar.testDate(2026, 7, 1), count: 40) { 70 + 0.2 * Double($0) }
        XCTAssertNil(
            PaceEstimator.estimate(
                samples: samples,
                targetWeight: 70,
                displayWeight: samples.last?.weight,
                progress: 0,
                now: samples.last!.date,
                calendar: calendar
            )
        )
    }

    func test_外推超过730天_隐藏() {
        let samples = consecutive(from: calendar.testDate(2026, 7, 1), count: 40) { 80 - 0.01 * Double($0) }
        XCTAssertNil(
            PaceEstimator.estimate(
                samples: samples,
                targetWeight: 70,
                displayWeight: samples.last?.weight,
                progress: WeightMetrics.progress(start: 80, target: 70, display: samples.last!.weight),
                now: samples.last!.date,
                calendar: calendar
            )
        )
    }

    func test_MAD过滤掉离群点_不删原始序列() {
        var values = (0..<28).map { 70.0 + Double($0) * 0.1 }
        values[20] = 100
        let points = values.enumerated().map { index, weight in
            WeightSample(date: calendar.testDate(2026, 7, 1 + index), weight: weight)
        }
        let filtered = PaceEstimator.filterMAD(points)
        XCTAssertEqual(filtered.count, 27)
        XCTAssertFalse(filtered.contains { $0.weight == 100 })
        XCTAssertEqual(points.count, 28)
    }

    func test_MAD为0_不过滤() {
        let points = (0..<20).map { WeightSample(date: calendar.testDate(2026, 7, 1 + $0), weight: 70) }
        XCTAssertEqual(PaceEstimator.filterMAD(points).count, 20)
    }

    func test_OLS_已知斜率() {
        let xs = (0..<10).map(Double.init)
        let ys = xs.map { 80 - 0.2 * $0 }
        let fit = PaceEstimator.ordinaryLeastSquares(xs: xs, ys: ys)
        XCTAssertNotNil(fit)
        XCTAssertEqual(fit!.slope, -0.2, accuracy: 0.0001)
        XCTAssertEqual(fit!.intercept, 80, accuracy: 0.0001)
    }

    func test_同日多次称重_回归只用当日最后一次() {
        let start = calendar.testDate(2026, 7, 1, hour: 8)
        var samples: [WeightSample] = []
        for offset in 0..<40 {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            samples.append(WeightSample(date: day, weight: 90))
            samples.append(
                WeightSample(
                    date: calendar.date(byAdding: .hour, value: 12, to: day)!,
                    weight: MeasurementBounds.roundedToTenth(80 - 0.2 * Double(offset))
                )
            )
        }
        let now = samples.last!.date
        let eta = PaceEstimator.estimate(
            samples: samples,
            targetWeight: 70,
            displayWeight: samples.last?.weight,
            progress: WeightMetrics.progress(start: 80, target: 70, display: samples.last!.weight),
            now: now,
            calendar: calendar
        )
        XCTAssertNotNil(eta)
    }

    func test_外推落在过去_隐藏() {
        let samples = consecutive(from: calendar.testDate(2026, 7, 1), count: 40) { 80 - 0.2 * Double($0) }
        XCTAssertNil(
            PaceEstimator.estimate(
                samples: samples,
                targetWeight: 70,
                displayWeight: samples.last?.weight,
                progress: 0.8,
                now: calendar.testDate(2028, 1, 1),
                calendar: calendar
            )
        )
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
