import XCTest
@testable import Ease

@MainActor
final class CSVExporterTests: EaseStoreTestCase {

    func test_export_表头固定且空数据只有表头() {
        let csv = CSVExporter.export([], logs: [], calendar: calendar)
        XCTAssertEqual(csv, CSVExporter.header)
        XCTAssertEqual(CSVExporter.header, "date,time,weight,bodyFat,dietStatus,tags,note")
    }

    func test_export_同日多条WeightLog_饮食标签备注只出现在第一行() throws {
        let day = calendar.testDate(2026, 8, 10)
        let record = DailyRecord(date: day, calendar: calendar)
        record.dietStatus = .clean
        record.variableTags = [.period, .travel]
        record.note = "first row only"

        let morning = WeightLog(
            timestamp: calendar.testDate(2026, 8, 10, hour: 7, minute: 5),
            weight: 71.0,
            bodyFat: 18.2
        )
        let evening = WeightLog(
            timestamp: calendar.testDate(2026, 8, 10, hour: 21, minute: 10),
            weight: 70.4
        )
        context.insert(record)
        context.insert(morning)
        context.insert(evening)
        try context.save()

        let csv = CSVExporter.export([record], logs: [evening, morning], calendar: calendar)
        let rows = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(rows[0], CSVExporter.header)
        XCTAssertEqual(rows[1], "2026-08-10,07:05,71.0,18.2,clean,period;travel,first row only")
        XCTAssertEqual(rows[2], "2026-08-10,21:10,70.4,,,,")
        XCTAssertEqual(rows.count, 3)
    }

    func test_export_仅有饮食无体重_仍输出一行且time体重体脂为空() throws {
        let record = DailyRecord(date: calendar.testDate(2026, 8, 11), calendar: calendar)
        record.dietStatus = .cheat
        record.variableTags = [.bowel]
        record.note = "diet only"
        context.insert(record)
        try context.save()

        let csv = CSVExporter.export([record], logs: [], calendar: calendar)
        let rows = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(rows[1], "2026-08-11,,,,cheat,bowel,diet only")
    }

    func test_export_仅有legacy体重无WeightLog_time为0800() throws {
        let record = DailyRecord(date: calendar.testDate(2026, 8, 12), calendar: calendar)
        record.weight = 72.5
        record.bodyFat = 19.1
        record.dietStatus = .normal
        context.insert(record)
        try context.save()

        let csv = CSVExporter.export([record], logs: [], calendar: calendar)
        let rows = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(rows[1], "2026-08-12,08:00,72.5,19.1,normal,,")
    }

    func test_export_note含逗号和引号_正确转义() throws {
        let record = DailyRecord(date: calendar.testDate(2026, 8, 13), calendar: calendar)
        record.dietStatus = .normal
        record.note = #"he said "hi", then left"#
        context.insert(record)
        try context.save()

        let csv = CSVExporter.export([record], logs: [], calendar: calendar)
        let rows = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        XCTAssertEqual(rows[1], #"2026-08-13,,,,normal,,"he said ""hi"", then left""#)
    }

    func test_exportMetrics_按精度输出且不混入体重表() throws {
        let waist = MetricLog(
            timestamp: calendar.testDate(2026, 8, 10, hour: 8),
            metricKey: "waist",
            value: 68.04
        )
        let water = MetricLog(
            timestamp: calendar.testDate(2026, 8, 10, hour: 9),
            metricKey: "water",
            value: 1500
        )
        let csv = CSVExporter.exportMetrics([water, waist], calendar: calendar)
        let rows = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(rows[0], CSVExporter.metricsHeader)
        XCTAssertEqual(rows[1], "2026-08-10,08:00,waist,68.0")
        XCTAssertEqual(rows[2], "2026-08-10,09:00,water,1500")
        XCTAssertFalse(csv.contains("dietStatus"))
    }
}
