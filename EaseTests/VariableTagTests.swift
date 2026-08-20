import XCTest
@testable import Ease

@MainActor
final class VariableTagTests: EaseStoreTestCase {
    func test_sanitized_未知顺序被规范为period_travel_bowel() {
        XCTAssertEqual(
            VariableTag.sanitized([.bowel, .period, .travel, .period]),
            [.period, .travel, .bowel]
        )
        XCTAssertEqual(VariableTag.sanitized([]), [])
        XCTAssertEqual(VariableTag.sanitized([.travel]), [.travel])
    }

    func test_DailyRecord_variableTags_丢弃未知字符串() throws {
        let record = DailyRecord(date: calendar.testDate(2026, 8, 20), calendar: calendar)
        record.tags = ["period", "custom", "travel", "nope"]
        context.insert(record)
        try context.save()
        XCTAssertEqual(record.variableTags, [.period, .travel])
    }

    func test_HealthDisplay_tags_HK经期与手动period去重只保留一个() throws {
        let record = DailyRecord(date: calendar.testDate(2026, 8, 20), calendar: calendar)
        record.variableTags = [.period, .travel]
        context.insert(record)
        try context.save()

        XCTAssertEqual(
            HealthDisplay.tags(record: record, isMenstrual: true),
            [.period, .travel]
        )
        XCTAssertEqual(
            HealthDisplay.tags(record: record, isMenstrual: false),
            [.period, .travel]
        )
    }

    func test_HealthDisplay_tags_无记录但HK显示经期_只出现period() {
        XCTAssertEqual(HealthDisplay.tags(record: nil, isMenstrual: true), [.period])
        XCTAssertEqual(HealthDisplay.tags(record: nil, isMenstrual: false), [])
    }

    func test_HealthDisplay_tags_仅差旅加HK经期_合并为period和travel() throws {
        let record = DailyRecord(date: calendar.testDate(2026, 8, 20), calendar: calendar)
        record.variableTags = [.travel]
        context.insert(record)
        try context.save()
        XCTAssertEqual(
            HealthDisplay.tags(record: record, isMenstrual: true),
            [.period, .travel]
        )
    }
}
