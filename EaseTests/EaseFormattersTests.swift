import XCTest
@testable import Ease

final class EaseFormattersTests: XCTestCase {
    func test_parseDecimal_逗号小数_返回一位小数() {
        XCTAssertEqual(EaseFormatters.parseDecimal("72,4"), 72.4)
    }

    func test_parseDecimal_点号小数_返回一位小数() {
        XCTAssertEqual(EaseFormatters.parseDecimal("72.4"), 72.4)
    }

    func test_parseDecimal_空串或空白_返回nil() {
        XCTAssertNil(EaseFormatters.parseDecimal(""))
        XCTAssertNil(EaseFormatters.parseDecimal("   "))
        XCTAssertNil(EaseFormatters.parseDecimal("\n"))
    }

    func test_parseDecimal_千分位与小数同时出现_取最后一个分隔符为小数点() {
        XCTAssertEqual(EaseFormatters.parseDecimal("1,234.5"), 1234.5)
        XCTAssertEqual(EaseFormatters.parseDecimal("1.234,5"), 1234.5)
    }

    func test_parseDecimal_中文逗号与全角点() {
        XCTAssertEqual(EaseFormatters.parseDecimal("72，4"), 72.4)
        XCTAssertEqual(EaseFormatters.parseDecimal("72．4"), 72.4)
    }

    func test_parseDecimal_非法文本_返回nil() {
        XCTAssertNil(EaseFormatters.parseDecimal("abc"))
    }

    func test_paceHorizon_7天内是本周_第8天按旬() {
        let calendar = EaseTestCalendar.make()
        let now = calendar.testDate(2026, 8, 26)
        XCTAssertEqual(
            PaceHorizon.make(eta: calendar.testDate(2026, 9, 2), now: now, calendar: calendar),
            .thisWeek
        )
        XCTAssertEqual(
            PaceHorizon.make(eta: calendar.testDate(2026, 9, 3), now: now, calendar: calendar),
            .monthPart(year: 2026, month: 9, part: .early)
        )
        XCTAssertEqual(
            PaceHorizon.make(eta: calendar.testDate(2026, 10, 15), now: now, calendar: calendar),
            .monthPart(year: 2026, month: 10, part: .mid)
        )
        XCTAssertEqual(
            PaceHorizon.make(eta: calendar.testDate(2026, 10, 25), now: now, calendar: calendar),
            .monthPart(year: 2026, month: 10, part: .late)
        )
    }
}
