import XCTest
@testable import Ease

final class SleepHistoryTests: XCTestCase {
    private let calendar = EaseTestCalendar.make()

    func test_averageHours_只平均有数据的夜() {
        let ending = calendar.testDate(2026, 8, 20)
        let history = SleepHistory.make(
            hoursByDay: [
                "2026-08-18": 7.0,
                "2026-08-20": 8.0
            ],
            nights: 7,
            endingOn: ending,
            calendar: calendar
        )
        XCTAssertEqual(history.nights.count, 7)
        XCTAssertEqual(history.loggedNights.count, 2)
        XCTAssertEqual(history.averageHours, 7.5)
        XCTAssertTrue(history.hasData)
    }

    func test_ringProgress_无数据返回nil而不是0() {
        let ending = calendar.testDate(2026, 8, 20)
        let history = SleepHistory.make(
            hoursByDay: ["2026-08-19": 7.5],
            nights: 3,
            endingOn: ending,
            calendar: calendar
        )
        XCTAssertNil(history.ringProgress(targetHours: 8))
        XCTAssertNil(history.lastNightHours)
        XCTAssertEqual(history.hours(on: calendar.testDate(2026, 8, 19), calendar: calendar), 7.5)
    }

    func test_ringProgress_超过目标clamp到1() {
        let ending = calendar.testDate(2026, 8, 20)
        let history = SleepHistory.make(
            hoursByDay: ["2026-08-20": 10.0],
            nights: 1,
            endingOn: ending,
            calendar: calendar
        )
        XCTAssertEqual(history.ringProgress(targetHours: 8), 1)
        XCTAssertEqual(history.ringProgress(on: ending, targetHours: 8, calendar: calendar), 1)
        XCTAssertEqual(history.ringProgress(targetHours: 10), 1)
        XCTAssertEqual(history.ringProgress(targetHours: 20), 0.5)
    }

    func test_ringProgress_目标为0返回nil() {
        let history = SleepHistory.make(
            hoursByDay: ["2026-08-20": 8.0],
            nights: 1,
            endingOn: calendar.testDate(2026, 8, 20),
            calendar: calendar
        )
        XCTAssertNil(history.ringProgress(targetHours: 0))
    }

    func test_make_生成连续N夜_缺数据夜hours为nil() {
        let ending = calendar.testDate(2026, 8, 20, hour: 21)
        let history = SleepHistory.make(
            hoursByDay: ["2026-08-20": 7.2],
            nights: 5,
            endingOn: ending,
            calendar: calendar
        )
        XCTAssertEqual(
            history.nights.map(\.dayKey),
            ["2026-08-16", "2026-08-17", "2026-08-18", "2026-08-19", "2026-08-20"]
        )
        XCTAssertEqual(history.nights.filter { $0.hours == nil }.count, 4)
        XCTAssertEqual(history.nights.last?.hours, 7.2)
        XCTAssertEqual(
            CalendarDay.dayKey(from: history.endingOn, calendar: calendar),
            "2026-08-20"
        )
    }

    func test_empty_无数据平均为nil() {
        XCTAssertNil(SleepHistory.empty.averageHours)
        XCTAssertFalse(SleepHistory.empty.hasData)
        XCTAssertNil(SleepHistory.empty.ringProgress(targetHours: 8))
    }
}
