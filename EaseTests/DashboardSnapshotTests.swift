import XCTest
@testable import Ease

@MainActor
final class DashboardSnapshotTests: EaseStoreTestCase {
    /// `DashboardSnapshot.make` currently calls `Calendar.current` internally.
    /// Dates here are built with that same calendar so day keys stay aligned.
    private var hostCalendar: Calendar { .current }

    func test_make_所选日最新体重驱动环和BMI_不用7日均线() throws {
        let profile = try insertProfile(heightCm: 170, start: 80, target: 70)
        let selected = hostCalendar.testDate(2026, 8, 20, hour: 21)
        var logs: [WeightLog] = (0..<7).map { offset in
            WeightLog(
                timestamp: hostCalendar.testDate(2026, 8, 14 + offset, hour: 8),
                weight: 78
            )
        }
        let evening = WeightLog(timestamp: selected, weight: 74.0, bodyFat: 18.2)
        logs.append(evening)
        try insertLogs(logs)

        let snapshot = DashboardSnapshot.make(
            profile: profile,
            records: [],
            logs: logs,
            now: selected
        )

        XCTAssertEqual(snapshot.displayWeight, 74.0)
        XCTAssertEqual(snapshot.bodyFat, 18.2)
        XCTAssertEqual(snapshot.progress, 0.6)
        XCTAssertEqual(snapshot.lostKg, 6.0)
        XCTAssertEqual(snapshot.remainingKg, 4.0)
        XCTAssertEqual(snapshot.bmi, WeightMetrics.bmi(weightKg: 74.0, heightCm: 170))
        XCTAssertNotEqual(snapshot.displayWeight, 78)
    }

    func test_make_所选日无记录_回退全局最新且不算均线() throws {
        let profile = try insertProfile(heightCm: 170, start: 80, target: 70)
        let older = WeightLog(
            timestamp: hostCalendar.testDate(2026, 8, 10, hour: 8),
            weight: 76.0
        )
        try insertLogs([older])

        let snapshot = DashboardSnapshot.make(
            profile: profile,
            records: [],
            logs: [older],
            now: hostCalendar.testDate(2026, 8, 20, hour: 12)
        )
        XCTAssertEqual(snapshot.displayWeight, 76.0)
        XCTAssertEqual(snapshot.progress, 0.4)
    }

    func test_make_无displayWeight或profile未就绪_进度为0且bmi为nil() throws {
        let empty = DashboardSnapshot.make(profile: nil, records: [], logs: [], now: hostCalendar.testDate(2026, 8, 20))
        XCTAssertNil(empty.displayWeight)
        XCTAssertEqual(empty.progress, 0)
        XCTAssertEqual(empty.lostKg, 0)
        XCTAssertEqual(empty.remainingKg, 0)
        XCTAssertNil(empty.bmi)

        let unfinished = UserProfile()
        context.insert(unfinished)
        try context.save()
        let log = WeightLog(timestamp: hostCalendar.testDate(2026, 8, 20, hour: 8), weight: 72)
        try insertLogs([log])
        let snapshot = DashboardSnapshot.make(
            profile: unfinished,
            records: [],
            logs: [log],
            now: hostCalendar.testDate(2026, 8, 20, hour: 8)
        )
        XCTAssertEqual(snapshot.displayWeight, 72)
        XCTAssertEqual(snapshot.progress, 0)
        XCTAssertNil(snapshot.bmi)
    }

    func test_make_today取所选日DailyRecord() throws {
        let day = hostCalendar.testDate(2026, 8, 20, hour: 12)
        let record = DailyRecord(date: day, calendar: hostCalendar)
        record.dietStatus = .clean
        context.insert(record)
        try context.save()

        let snapshot = DashboardSnapshot.make(
            profile: nil,
            records: [record],
            logs: [],
            now: day
        )
        XCTAssertEqual(snapshot.today?.dietStatus, .clean)
    }

    func test_首页灰字_未启用则隐藏_已启用无当日记录则入口() throws {
        try metrics.seedBuiltinsIfNeeded()
        let waist = try metrics.definition(key: "waist")!
        let day = calendar.testDate(2026, 8, 10, hour: 8)
        XCTAssertNil(
            DashboardMetricsLine.text(enabled: [], logs: [], on: day, calendar: calendar)
        )

        try metrics.setEnabled(waist, isEnabled: true)
        XCTAssertEqual(
            DashboardMetricsLine.text(enabled: [waist], logs: [], on: day, calendar: calendar),
            String(localized: "dashboard.metrics")
        )
        XCTAssertEqual(
            DashboardMetricsLine.focusKey(enabled: [waist], logs: [], on: day, calendar: calendar),
            "waist"
        )
    }

    func test_首页灰字_已启用且当日有记录_显示读数() throws {
        try metrics.seedBuiltinsIfNeeded()
        let waist = try metrics.definition(key: "waist")!
        try metrics.setEnabled(waist, isEnabled: true)
        let day = calendar.testDate(2026, 8, 10, hour: 8)
        let log = try metrics.insertLog(timestamp: day, metricKey: "waist", value: 68)
        XCTAssertEqual(
            DashboardMetricsLine.text(enabled: [waist], logs: [log], on: day, calendar: calendar),
            MetricCatalog.formattedReading(68, spec: MetricCatalog.builtin(for: "waist")!)
        )
        XCTAssertEqual(
            DashboardMetricsLine.focusKey(enabled: [waist], logs: [log], on: day, calendar: calendar),
            "waist"
        )
    }

    private func insertProfile(heightCm: Double, start: Double, target: Double) throws -> UserProfile {
        let profile = UserProfile()
        profile.heightCm = heightCm
        profile.startWeight = start
        profile.targetWeight = target
        context.insert(profile)
        try context.save()
        return profile
    }

    private func insertLogs(_ logs: [WeightLog]) throws {
        for log in logs {
            context.insert(log)
        }
        try context.save()
    }
}
