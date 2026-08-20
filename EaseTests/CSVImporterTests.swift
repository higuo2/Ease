import XCTest
@testable import Ease

@MainActor
final class CSVImporterTests: EaseStoreTestCase {

    func test_导入日记_合并写入体重和饮食() throws {
        let csv = """
        \(CSVImporter.journalHeader)
        2026-08-10,07:05,71.0,18.2,clean,period;travel,hello
        2026-08-10,21:10,70.4,,,
        2026-08-11,,,,cheat,bowel,diet only
        """
        let preview = try CSVImporter.preview(
            from: Data(csv.utf8),
            existingLogs: [],
            existingRecords: [],
            existingMetricLogs: [],
            metricSpecs: [:],
            now: calendar.testDate(2026, 8, 20),
            calendar: calendar
        )
        XCTAssertEqual(preview.kind, .journal)
        XCTAssertEqual(preview.weighInCount, 2)
        XCTAssertEqual(preview.dietDayCount, 2)
        XCTAssertEqual(preview.invalidCount, 0)

        let result = try CSVImporter.apply(preview, context: context, calendar: calendar)
        XCTAssertEqual(result.weighInsWritten, 2)
        XCTAssertEqual(result.dietDaysWritten, 2)
        XCTAssertEqual(try fetchAll(WeightLog.self).count, 2)
        let records = try fetchAll(DailyRecord.self)
        XCTAssertEqual(records.count, 2)
    }

    func test_兼容v1_无time列_时间记为0800() throws {
        let csv = """
        \(CSVImporter.legacyHeader)
        2026-08-12,72.5,19.1,normal,,
        """
        let preview = try CSVImporter.preview(
            from: Data(csv.utf8),
            existingLogs: [],
            existingRecords: [],
            existingMetricLogs: [],
            metricSpecs: [:],
            now: calendar.testDate(2026, 8, 20),
            calendar: calendar
        )
        XCTAssertEqual(preview.weighInCount, 1)
        let stamp = preview.pendingWeighIns[0].timestamp
        XCTAssertEqual(calendar.component(.hour, from: stamp), 8)
        XCTAssertEqual(calendar.component(.minute, from: stamp), 0)
    }

    func test_同日同时刻同体重_视为重复跳过() throws {
        let existing = WeightLog(
            timestamp: calendar.testDate(2026, 8, 10, hour: 7, minute: 5),
            weight: 71.0
        )
        context.insert(existing)
        try context.save()
        let csv = """
        \(CSVImporter.journalHeader)
        2026-08-10,07:05,71.0,,,,
        2026-08-10,07:05,70.4,,,,
        """
        let preview = try CSVImporter.preview(
            from: Data(csv.utf8),
            existingLogs: [existing],
            existingRecords: [],
            existingMetricLogs: [],
            metricSpecs: [:],
            now: calendar.testDate(2026, 8, 20),
            calendar: calendar
        )
        XCTAssertEqual(preview.duplicateCount, 1)
        XCTAssertEqual(preview.weighInCount, 1)
    }

    func test_未来日期和越界体重_计入invalid() throws {
        let csv = """
        \(CSVImporter.journalHeader)
        2026-08-30,08:00,70.0,,,,
        2026-08-10,08:00,200.0,,,,
        not-a-date,08:00,70.0,,,,
        """
        let preview = try CSVImporter.preview(
            from: Data(csv.utf8),
            existingLogs: [],
            existingRecords: [],
            existingMetricLogs: [],
            metricSpecs: [:],
            now: calendar.testDate(2026, 8, 20),
            calendar: calendar
        )
        XCTAssertEqual(preview.invalidCount, 3)
        XCTAssertEqual(preview.weighInCount, 0)
    }

    func test_超过5000行_截断不拒绝() throws {
        var lines = [CSVImporter.journalHeader]
        for day in 0..<5002 {
            lines.append("2026-01-01,08:00,70.0,,,,\(day)")
        }
        let preview = try CSVImporter.preview(
            from: Data(lines.joined(separator: "\n").utf8),
            existingLogs: [],
            existingRecords: [],
            existingMetricLogs: [],
            metricSpecs: [:],
            now: calendar.testDate(2026, 8, 20),
            calendar: calendar
        )
        XCTAssertTrue(preview.isTruncated)
        XCTAssertEqual(preview.weighInCount, 1)
        XCTAssertEqual(preview.pendingJournals.count, 1)
    }

    func test_无法识别表头_整文件拒绝() {
        XCTAssertThrowsError(
            try CSVImporter.preview(
                from: Data("foo,bar\n1,2".utf8),
                existingLogs: [],
                existingRecords: [],
                existingMetricLogs: [],
                metricSpecs: [:],
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? CSVImporter.Failure, .unrecognizedHeader)
        }
    }

    func test_非UTF8_整文件拒绝() {
        XCTAssertThrowsError(
            try CSVImporter.preview(
                from: Data([0xFF, 0xFE, 0x00]),
                existingLogs: [],
                existingRecords: [],
                existingMetricLogs: [],
                metricSpecs: [:],
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? CSVImporter.Failure, .notUTF8)
        }
    }

    func test_导入指标_未知key无效_已知key写入() throws {
        try metrics.seedBuiltinsIfNeeded()
        let csv = """
        \(CSVImporter.metricsHeader)
        2026-08-10,08:00,waist,68.0
        2026-08-10,08:00,unknown_metric,12
        2026-08-10,09:00,water,1500
        """
        let specs = Dictionary(
            uniqueKeysWithValues: MetricCatalog.builtins.map { ($0.key, $0) }
        )
        let preview = try CSVImporter.preview(
            from: Data(csv.utf8),
            existingLogs: [],
            existingRecords: [],
            existingMetricLogs: [],
            metricSpecs: specs,
            now: calendar.testDate(2026, 8, 20),
            calendar: calendar
        )
        XCTAssertEqual(preview.kind, .metrics)
        XCTAssertEqual(preview.metricLogCount, 2)
        XCTAssertEqual(preview.invalidCount, 1)
        let result = try CSVImporter.apply(preview, context: context, calendar: calendar)
        XCTAssertEqual(result.metricLogsWritten, 2)
    }

    func test_指标去重_同日同时刻同key同值跳过() throws {
        try metrics.seedBuiltinsIfNeeded()
        _ = try metrics.insertLog(
            timestamp: calendar.testDate(2026, 8, 10, hour: 8),
            metricKey: "waist",
            value: 68.0
        )
        let csv = """
        \(CSVImporter.metricsHeader)
        2026-08-10,08:00,waist,68.0
        """
        let preview = try CSVImporter.preview(
            from: Data(csv.utf8),
            existingLogs: [],
            existingRecords: [],
            existingMetricLogs: try fetchAll(MetricLog.self),
            metricSpecs: Dictionary(uniqueKeysWithValues: MetricCatalog.builtins.map { ($0.key, $0) }),
            now: calendar.testDate(2026, 8, 20),
            calendar: calendar
        )
        XCTAssertEqual(preview.duplicateCount, 1)
        XCTAssertEqual(preview.metricLogCount, 0)
    }

    func test_note含逗号_解析后写入() throws {
        let csv = """
        \(CSVImporter.journalHeader)
        2026-08-13,,,,normal,,"he said ""hi"", then left"
        """
        let preview = try CSVImporter.preview(
            from: Data(csv.utf8),
            existingLogs: [],
            existingRecords: [],
            existingMetricLogs: [],
            metricSpecs: [:],
            now: calendar.testDate(2026, 8, 20),
            calendar: calendar
        )
        XCTAssertEqual(preview.pendingJournals.first?.note, #"he said "hi", then left"#)
    }

    func test_预览不调用apply_零写入() throws {
        let csv = """
        \(CSVImporter.journalHeader)
        2026-08-10,08:00,70.0,,clean,,
        """
        _ = try previewJournal(csv)
        XCTAssertTrue(try fetchAll(WeightLog.self).isEmpty)
        XCTAssertTrue(try fetchAll(DailyRecord.self).isEmpty)
    }

    func test_空单元格不覆盖已有饮食() throws {
        var patch = DailyRecordPatch()
        patch.dietStatus = .set(.clean)
        patch.note = .set("keep me")
        try dailyRecords.upsert(on: calendar.testDate(2026, 8, 10), patch: patch)

        let csv = """
        \(CSVImporter.journalHeader)
        2026-08-10,,,,,,imported note
        """
        let preview = try previewJournal(csv)
        _ = try CSVImporter.apply(preview, context: context, calendar: calendar)

        let record = try dailyRecords.record(on: calendar.testDate(2026, 8, 10))
        XCTAssertEqual(record?.dietStatus, .clean)
        XCTAssertEqual(record?.note, "imported note")
    }

    func test_tags只保留period_travel_bowel() throws {
        let csv = """
        \(CSVImporter.journalHeader)
        2026-08-10,,,,normal,foo;travel;kcal;bowel,
        """
        let preview = try previewJournal(csv)
        XCTAssertEqual(preview.pendingJournals.first?.tags, [.travel, .bowel])
        _ = try CSVImporter.apply(preview, context: context, calendar: calendar)
        let record = try dailyRecords.record(on: calendar.testDate(2026, 8, 10))
        XCTAssertEqual(record?.variableTags, [.travel, .bowel])
    }

    func test_仅饮食无体重_不插入WeightLog() throws {
        let csv = """
        \(CSVImporter.journalHeader)
        2026-08-11,,,,cheat,,
        """
        let preview = try previewJournal(csv)
        XCTAssertEqual(preview.weighInCount, 0)
        XCTAssertEqual(preview.dietDayCount, 1)
        _ = try CSVImporter.apply(preview, context: context, calendar: calendar)
        XCTAssertTrue(try fetchAll(WeightLog.self).isEmpty)
        XCTAssertEqual(try fetchAll(DailyRecord.self).first?.dietStatus, .cheat)
    }

    func test_体脂越界或非法饮食_整行invalid() throws {
        let csv = """
        \(CSVImporter.journalHeader)
        2026-08-10,08:00,70.0,80.0,,,
        2026-08-10,09:00,70.0,,junk,,
        """
        let preview = try previewJournal(csv)
        XCTAssertEqual(preview.invalidCount, 2)
        XCTAssertEqual(preview.weighInCount, 0)
    }

    func test_超过2MB_截断并保留已解析行() throws {
        var csv = CSVImporter.journalHeader + "\n2026-08-10,08:00,70.0,,,,ok\n"
        csv += String(repeating: "x", count: CSVImporter.maxBytes)
        let preview = try CSVImporter.preview(
            from: Data(csv.utf8),
            existingLogs: [],
            existingRecords: [],
            existingMetricLogs: [],
            metricSpecs: [:],
            now: calendar.testDate(2026, 8, 20),
            calendar: calendar
        )
        XCTAssertTrue(preview.isTruncated)
        XCTAssertEqual(preview.weighInCount, 1)
    }

    func test_空文件_拒绝整文件() {
        XCTAssertThrowsError(
            try CSVImporter.preview(
                from: Data(),
                existingLogs: [],
                existingRecords: [],
                existingMetricLogs: [],
                metricSpecs: [:],
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? CSVImporter.Failure, .unreadable)
        }
    }

    func test_内置指标未seed也可导入_围度越界invalid() throws {
        let csv = """
        \(CSVImporter.metricsHeader)
        2026-08-10,08:00,waist,68.0
        2026-08-10,09:00,waist,12.0
        """
        let preview = try CSVImporter.preview(
            from: Data(csv.utf8),
            existingLogs: [],
            existingRecords: [],
            existingMetricLogs: [],
            metricSpecs: [:],
            now: calendar.testDate(2026, 8, 20),
            calendar: calendar
        )
        XCTAssertEqual(preview.metricLogCount, 1)
        XCTAssertEqual(preview.invalidCount, 1)
    }

    func test_自定义已定义key可导入_未定义key无效() throws {
        let custom = try metrics.addCustom(name: "Neck", unit: .cm, symbolName: "ruler")
        let csv = """
        \(CSVImporter.metricsHeader)
        2026-08-10,08:00,\(custom.key),38.0
        2026-08-10,09:00,custom.missing,38.0
        """
        let specs = [custom.key: MetricCatalog.spec(for: custom)]
        let preview = try CSVImporter.preview(
            from: Data(csv.utf8),
            existingLogs: [],
            existingRecords: [],
            existingMetricLogs: [],
            metricSpecs: specs,
            now: calendar.testDate(2026, 8, 20),
            calendar: calendar
        )
        XCTAssertEqual(preview.metricLogCount, 1)
        XCTAssertEqual(preview.invalidCount, 1)
    }

    private func previewJournal(_ csv: String) throws -> CSVImporter.Preview {
        try CSVImporter.preview(
            from: Data(csv.utf8),
            existingLogs: (try? fetchAll(WeightLog.self)) ?? [],
            existingRecords: (try? fetchAll(DailyRecord.self)) ?? [],
            existingMetricLogs: [],
            metricSpecs: [:],
            now: calendar.testDate(2026, 8, 20),
            calendar: calendar
        )
    }
}
