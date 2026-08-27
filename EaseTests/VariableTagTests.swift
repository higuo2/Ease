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
        XCTAssertEqual(
            VariableTag.sanitized([
                VariableTag(rawValue: "custom.tea")!,
                .swollen,
                .bowel,
                .period
            ]),
            [.period, .bowel, .swollen, VariableTag(rawValue: "custom.tea")!]
        )
    }

    func test_init_只接受白名单或custom点前缀() {
        XCTAssertNil(VariableTag(rawValue: "custom"))
        XCTAssertNil(VariableTag(rawValue: "kcal"))
        XCTAssertNil(VariableTag(rawValue: "custom./path"))
        XCTAssertEqual(VariableTag(rawValue: "custom.tea")?.rawValue, "custom.tea")
        XCTAssertEqual(VariableTag.custom(from: "tea")?.rawValue, "custom.tea")
        XCTAssertNil(VariableTag.custom(from: "  "))
    }

    func test_DailyRecord_variableTags_丢弃未知字符串() throws {
        let record = DailyRecord(date: calendar.testDate(2026, 8, 20), calendar: calendar)
        record.tags = ["period", "custom", "travel", "nope", "custom.tea", "kcal"]
        context.insert(record)
        try context.save()
        XCTAssertEqual(
            record.variableTags,
            [.period, .travel, VariableTag(rawValue: "custom.tea")!]
        )
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
