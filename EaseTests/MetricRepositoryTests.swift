import XCTest
@testable import Ease

@MainActor
final class MetricRepositoryTests: EaseStoreTestCase {

    func test_seedBuiltins_默认关闭且可幂等() throws {
        let first = try metrics.seedBuiltinsIfNeeded()
        XCTAssertEqual(first.count, MetricCatalog.builtins.count)
        XCTAssertTrue(first.allSatisfy { $0.isEnabled == false })
        XCTAssertEqual(first.map(\.key), MetricCatalog.builtins.map(\.key))

        _ = try metrics.seedBuiltinsIfNeeded()
        XCTAssertEqual(try fetchAll(MetricDefinition.self).count, MetricCatalog.builtins.count)
    }

    func test_禁用后历史保留且首页行不展示() throws {
        // homeLine is readings-only: disabled or no log that day → nil.
        // The dashboard entry copy is covered by DashboardMetricsLine tests.
        try metrics.seedBuiltinsIfNeeded()
        let waist = try metrics.definition(key: "waist")!
        try metrics.setEnabled(waist, isEnabled: true)
        _ = try metrics.insertLog(
            timestamp: calendar.testDate(2026, 8, 10, hour: 8),
            metricKey: "waist",
            value: 68.0
        )
        XCTAssertEqual(
            try metrics.homeLine(on: calendar.testDate(2026, 8, 10)),
            MetricCatalog.formattedReading(68.0, spec: MetricCatalog.builtin(for: "waist")!)
        )

        try metrics.setEnabled(waist, isEnabled: false)
        XCTAssertNil(try metrics.homeLine(on: calendar.testDate(2026, 8, 10)))
        XCTAssertEqual(try metrics.allLogs(metricKey: "waist").count, 1)
    }

    func test_自定义最多8条() throws {
        for index in 0..<MetricCatalog.maxCustom {
            _ = try metrics.addCustom(name: "Custom \(index)", unit: .cm, symbolName: "ruler")
        }
        XCTAssertThrowsError(
            try metrics.addCustom(name: "Ninth", unit: .cm, symbolName: "ruler")
        ) { error in
            XCTAssertEqual(error as? EaseDataError, .tooManyCustomMetrics)
        }
    }

    func test_围度越界_抛invalidMetric() throws {
        try metrics.seedBuiltinsIfNeeded()
        XCTAssertThrowsError(
            try metrics.insertLog(
                timestamp: calendar.testDate(2026, 8, 10),
                metricKey: "waist",
                value: 20
            )
        ) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidMetric)
        }
    }

    func test_围度按0_1步进() throws {
        try metrics.seedBuiltinsIfNeeded()
        let log = try metrics.insertLog(
            timestamp: calendar.testDate(2026, 8, 10, hour: 9),
            metricKey: "waist",
            value: 68.04
        )
        XCTAssertEqual(log.value, 68.0)
    }

    func test_不允许的符号_拒绝自定义() {
        XCTAssertThrowsError(
            try metrics.addCustom(name: "X", unit: .count, symbolName: "flame.fill")
        ) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidMetric)
        }
    }

    func test_首页行_只含已启用且所选日有log的最新值() throws {
        try metrics.seedBuiltinsIfNeeded()
        let waist = try metrics.definition(key: "waist")!
        let hip = try metrics.definition(key: "hip")!
        try metrics.setEnabled(waist, isEnabled: true)
        try metrics.setEnabled(hip, isEnabled: true)

        _ = try metrics.insertLog(
            timestamp: calendar.testDate(2026, 8, 10, hour: 8),
            metricKey: "waist",
            value: 70.0
        )
        _ = try metrics.insertLog(
            timestamp: calendar.testDate(2026, 8, 10, hour: 21),
            metricKey: "waist",
            value: 68.0
        )
        _ = try metrics.insertLog(
            timestamp: calendar.testDate(2026, 8, 11, hour: 8),
            metricKey: "hip",
            value: 90.0
        )

        let line = try metrics.homeLine(on: calendar.testDate(2026, 8, 10))
        XCTAssertEqual(
            line,
            MetricCatalog.formattedReading(68.0, spec: MetricCatalog.builtin(for: "waist")!)
        )
        XCTAssertFalse(line?.contains("90") == true)
        XCTAssertNil(try metrics.homeLine(on: calendar.testDate(2026, 8, 12)))
    }

    func test_homeLine_已启用但当日无记录_返回nil_不含入口文案() throws {
        try metrics.seedBuiltinsIfNeeded()
        let waist = try metrics.definition(key: "waist")!
        try metrics.setEnabled(waist, isEnabled: true)
        XCTAssertNil(try metrics.homeLine(on: calendar.testDate(2026, 8, 10)))
    }

    func test_空名称拒绝自定义_合法自定义key带custom前缀() throws {
        XCTAssertThrowsError(try metrics.addCustom(name: "   ", unit: .cm, symbolName: "ruler")) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidMetric)
        }
        let created = try metrics.addCustom(name: "Neck", unit: .cm, symbolName: "ruler")
        XCTAssertTrue(created.key.hasPrefix("custom."))
        XCTAssertTrue(created.isEnabled)
        XCTAssertEqual(created.kind, .custom)
        XCTAssertEqual(created.displayName, "Neck")
    }

    func test_未来日期插入指标_抛futureDate() throws {
        try metrics.seedBuiltinsIfNeeded()
        XCTAssertThrowsError(
            try metrics.insertLog(
                timestamp: calendar.testDate(2099, 1, 1),
                metricKey: "waist",
                value: 68
            )
        ) { error in
            XCTAssertEqual(error as? EaseDataError, .futureDate)
        }
    }

    func test_大腿与手腕边界() throws {
        try metrics.seedBuiltinsIfNeeded()
        XCTAssertEqual(
            try metrics.insertLog(
                timestamp: calendar.testDate(2026, 8, 10, hour: 8),
                metricKey: "thigh",
                value: 20
            ).value,
            20
        )
        XCTAssertEqual(
            try metrics.insertLog(
                timestamp: calendar.testDate(2026, 8, 10, hour: 9),
                metricKey: "wrist",
                value: 15.4
            ).value,
            15.4
        )
        XCTAssertThrowsError(
            try metrics.insertLog(
                timestamp: calendar.testDate(2026, 8, 10, hour: 10),
                metricKey: "thigh",
                value: 121
            )
        )
        XCTAssertThrowsError(
            try metrics.insertLog(
                timestamp: calendar.testDate(2026, 8, 10, hour: 11),
                metricKey: "wrist",
                value: 40
            )
        )
    }

    func test_内置符号与单位() {
        XCTAssertNil(MetricCatalog.builtin(for: "water"))
        XCTAssertEqual(MetricCatalog.builtin(for: "waist")?.symbolName, "ruler")
        XCTAssertEqual(MetricCatalog.builtin(for: "waist")?.unit, .cm)
        XCTAssertEqual(MetricCatalog.builtin(for: "thigh")?.range, 20...120)
    }

    func test_内置目录含围度细分且手腕范围覆盖15() {
        XCTAssertNotNil(MetricCatalog.builtin(for: "underbust"))
        XCTAssertNotNil(MetricCatalog.builtin(for: "leftArm"))
        XCTAssertTrue(MetricCatalog.builtin(for: "wrist")!.range.contains(15.4))
        XCTAssertTrue(MetricCatalog.builtin(for: "head")!.range.contains(52.5))
        XCTAssertEqual(try MetricCatalog.validated(15.4, spec: MetricCatalog.builtin(for: "wrist")!), 15.4)
        XCTAssertEqual(try MetricCatalog.validated(31.5, spec: MetricCatalog.builtin(for: "leftArm")!), 31.5)
    }

    func test_删一条MetricLog_不影响定义() throws {
        try metrics.seedBuiltinsIfNeeded()
        let log = try metrics.insertLog(
            timestamp: calendar.testDate(2026, 8, 10, hour: 8),
            metricKey: "hip",
            value: 90
        )
        try metrics.delete(log)
        XCTAssertTrue(try metrics.allLogs(metricKey: "hip").isEmpty)
        XCTAssertNotNil(try metrics.definition(key: "hip"))
    }

    func test_批量写入_先校验后一次保存_失败则零写入() throws {
        try metrics.seedBuiltinsIfNeeded()
        let day = calendar.testDate(2026, 8, 10, hour: 8)
        XCTAssertTrue(try metrics.insertLogs([]).isEmpty)

        XCTAssertThrowsError(
            try metrics.insertLogs([
                MetricLogDraft(timestamp: day, metricKey: "waist", value: 81),
                MetricLogDraft(timestamp: day, metricKey: "leftArm", value: 31.5),
                MetricLogDraft(timestamp: day, metricKey: "underbust", value: 76),
                MetricLogDraft(timestamp: day, metricKey: "wrist", value: 9)
            ])
        ) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidMetric)
        }
        XCTAssertTrue(try fetchAll(MetricLog.self).isEmpty)

        XCTAssertThrowsError(
            try metrics.insertLogs([
                MetricLogDraft(timestamp: day, metricKey: "waist", value: 81),
                MetricLogDraft(timestamp: day, metricKey: "not_a_metric", value: 40)
            ])
        ) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidMetric)
        }
        XCTAssertTrue(try fetchAll(MetricLog.self).isEmpty)
        XCTAssertEqual(try fetchAll(MetricDefinition.self).count, MetricCatalog.builtins.count)

        let written = try metrics.insertLogs([
            MetricLogDraft(timestamp: day, metricKey: "leftArm", value: 31.5),
            MetricLogDraft(timestamp: day, metricKey: "wrist", value: 15.4)
        ])
        XCTAssertEqual(written.count, 2)
        XCTAssertEqual(try fetchAll(MetricLog.self).count, 2)
    }
}
