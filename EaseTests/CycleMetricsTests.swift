import XCTest
@testable import Ease

final class CycleMetricsTests: XCTestCase {
    private let calendar = EaseTestCalendar.make()

    func test_spans_连续经期日合成一个span_start为第一天() {
        let days = [
            calendar.testDate(2026, 3, 1),
            calendar.testDate(2026, 3, 2),
            calendar.testDate(2026, 3, 3),
            calendar.testDate(2026, 3, 20)
        ]
        let spans = CycleMetrics.spans(from: days, calendar: calendar)
        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(CalendarDay.dayKey(from: spans[0].start, calendar: calendar), "2026-03-01")
        XCTAssertEqual(CalendarDay.dayKey(from: spans[0].end, calendar: calendar), "2026-03-03")
        XCTAssertEqual(CalendarDay.dayKey(from: spans[1].start, calendar: calendar), "2026-03-20")
        XCTAssertTrue(spans[0].contains(calendar.testDate(2026, 3, 2), calendar: calendar))
        XCTAssertFalse(spans[0].contains(calendar.testDate(2026, 3, 4), calendar: calendar))
    }

    func test_make_少于两次start_不预测() {
        let history = CycleMetrics.make(
            periodDayKeys: ["2026-03-01", "2026-03-02", "2026-03-03"],
            endingOn: calendar.testDate(2026, 3, 10),
            calendar: calendar
        )
        XCTAssertEqual(history.starts.count, 1)
        XCTAssertNil(history.cycleLengthDays)
        XCTAssertNil(history.predictedNextStart)
        XCTAssertNil(history.progress)
        XCTAssertTrue(history.hasData)
    }

    func test_make_间隔14天和46天被丢弃后再取中位数() {
        let history = CycleMetrics.make(
            periodDayKeys: [
                "2026-01-01",
                "2026-01-15",
                "2026-03-02",
                "2026-03-30"
            ],
            endingOn: calendar.testDate(2026, 3, 30),
            calendar: calendar
        )
        XCTAssertEqual(history.starts.count, 4)
        XCTAssertEqual(history.cycleLengthDays, 28)
        XCTAssertEqual(
            CalendarDay.dayKey(from: history.predictedNextStart!, calendar: calendar),
            "2026-04-27"
        )
    }

    func test_median_偶数个gap取平均() {
        XCTAssertEqual(CycleMetrics.median([28, 30]), 29)
        XCTAssertEqual(CycleMetrics.median([28, 30, 32]), 30)
        XCTAssertNil(CycleMetrics.median([]))
    }

    func test_make_偶数个有效间隔_周期长度为平均中位数() {
        let history = CycleMetrics.make(
            periodDayKeys: ["2026-01-01", "2026-01-29", "2026-02-28"],
            endingOn: calendar.testDate(2026, 2, 28),
            calendar: calendar
        )
        XCTAssertEqual(history.cycleLengthDays, 29)
        XCTAssertEqual(
            CalendarDay.dayKey(from: history.predictedNextStart!, calendar: calendar),
            "2026-03-29"
        )
    }

    func test_progress_clamp到0和1() {
        let keys: Set<String> = ["2025-12-04", "2026-01-01"]
        let start = CycleMetrics.make(
            periodDayKeys: keys,
            endingOn: calendar.testDate(2026, 1, 1),
            calendar: calendar
        )
        XCTAssertEqual(start.progress, 0)

        let mid = CycleMetrics.make(
            periodDayKeys: keys,
            endingOn: calendar.testDate(2026, 1, 15),
            calendar: calendar
        )
        XCTAssertEqual(mid.progress, 0.5)

        let over = CycleMetrics.make(
            periodDayKeys: keys,
            endingOn: calendar.testDate(2026, 2, 15),
            calendar: calendar
        )
        XCTAssertEqual(over.progress, 1)
    }

    func test_make_不相邻的经期日是两次start() {
        let history = CycleMetrics.make(
            periodDayKeys: ["2026-03-01", "2026-03-03"],
            endingOn: calendar.testDate(2026, 3, 10),
            calendar: calendar
        )
        XCTAssertEqual(history.spans.count, 2)
        XCTAssertNil(history.cycleLengthDays)
    }
}
