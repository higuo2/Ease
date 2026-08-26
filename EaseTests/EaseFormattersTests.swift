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
            PaceHorizon.make(eta: calendar.testDate(2026, 8, 26), now: now, calendar: calendar),
            .thisWeek
        )
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

    func test_paceHorizon_旬边界_10早_11中_20中_21晚() {
        let calendar = EaseTestCalendar.make()
        let now = calendar.testDate(2026, 8, 26)
        XCTAssertEqual(
            PaceHorizon.make(eta: calendar.testDate(2026, 9, 10), now: now, calendar: calendar),
            .monthPart(year: 2026, month: 9, part: .early)
        )
        XCTAssertEqual(
            PaceHorizon.make(eta: calendar.testDate(2026, 9, 11), now: now, calendar: calendar),
            .monthPart(year: 2026, month: 9, part: .mid)
        )
        XCTAssertEqual(
            PaceHorizon.make(eta: calendar.testDate(2026, 10, 20), now: now, calendar: calendar),
            .monthPart(year: 2026, month: 10, part: .mid)
        )
        XCTAssertEqual(
            PaceHorizon.make(eta: calendar.testDate(2026, 10, 21), now: now, calendar: calendar),
            .monthPart(year: 2026, month: 10, part: .late)
        )
        XCTAssertEqual(
            PaceHorizon.make(eta: calendar.testDate(2027, 2, 5), now: now, calendar: calendar),
            .monthPart(year: 2027, month: 2, part: .early)
        )
    }

    func test_paceETA_本周走thisWeek文案_旬区间不含倒计时天数() {
        let calendar = EaseTestCalendar.make()
        let now = calendar.testDate(2026, 8, 26)
        XCTAssertEqual(
            EaseFormatters.paceETA(calendar.testDate(2026, 9, 2), now: now, calendar: calendar),
            String(localized: "format.paceETA.thisWeek")
        )
        XCTAssertEqual(
            EaseFormatters.advancedPaceHorizon(calendar.testDate(2026, 9, 2), now: now, calendar: calendar),
            String(localized: "format.advancedPace.thisWeek")
        )

        let monthCopy = EaseFormatters.paceETA(
            calendar.testDate(2026, 10, 15),
            now: now,
            calendar: calendar
        )
        XCTAssertNotEqual(monthCopy, String(localized: "format.paceETA.thisWeek"))
        XCTAssertFalse(monthCopy.contains("15"))

        var monthStart = DateComponents()
        monthStart.year = 2026
        monthStart.month = 10
        monthStart.day = 1
        let monthName = (calendar.date(from: monthStart) ?? now)
            .formatted(Date.FormatStyle().month(.wide))
        XCTAssertEqual(
            EaseFormatters.advancedPaceHorizon(
                calendar.testDate(2026, 10, 15),
                now: now,
                calendar: calendar
            ),
            String(
                format: String(localized: "format.advancedPaceHorizon"),
                locale: .current,
                String(format: String(localized: "format.paceMonth.mid"), locale: .current, monthName)
            )
        )
    }
}
