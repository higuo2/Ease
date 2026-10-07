import XCTest
@testable import Ease

final class CalendarDayTests: XCTestCase {
    private let calendar = EaseTestCalendar.make()

    func test_dayKey_忽略时分秒_格式为年月日() {
        let morning = calendar.testDate(2026, 8, 20, hour: 0, minute: 15)
        let night = calendar.testDate(2026, 8, 20, hour: 23, minute: 59)
        XCTAssertEqual(CalendarDay.dayKey(from: morning, calendar: calendar), "2026-08-20")
        XCTAssertEqual(CalendarDay.dayKey(from: night, calendar: calendar), "2026-08-20")
    }

    func test_isFuture_只比较日历日不比较时钟() {
        let now = calendar.testDate(2026, 8, 20, hour: 10)
        let lateToday = calendar.testDate(2026, 8, 20, hour: 23)
        let tomorrow = calendar.testDate(2026, 8, 21, hour: 0)
        let yesterday = calendar.testDate(2026, 8, 19, hour: 23)
        XCTAssertFalse(CalendarDay.isFuture(lateToday, now: now, calendar: calendar))
        XCTAssertTrue(CalendarDay.isFuture(tomorrow, now: now, calendar: calendar))
        XCTAssertFalse(CalendarDay.isFuture(yesterday, now: now, calendar: calendar))
    }

    func test_date_fromDayKey_合法与非法() {
        let parsed = CalendarDay.date(fromDayKey: "2026-08-20", calendar: calendar)
        XCTAssertEqual(CalendarDay.dayKey(from: parsed!, calendar: calendar), "2026-08-20")
        XCTAssertEqual(parsed, CalendarDay.startOfDay(calendar.testDate(2026, 8, 20), calendar: calendar))
        XCTAssertNil(CalendarDay.date(fromDayKey: "2026/08/20", calendar: calendar))
        XCTAssertNil(CalendarDay.date(fromDayKey: "not-a-date", calendar: calendar))
    }

    func test_datesBack_7天含结束日且升序() {
        let end = calendar.testDate(2026, 8, 20, hour: 21)
        let days = CalendarDay.datesBack(7, from: end, calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.map { CalendarDay.dayKey(from: $0, calendar: calendar) }, [
            "2026-08-14",
            "2026-08-15",
            "2026-08-16",
            "2026-08-17",
            "2026-08-18",
            "2026-08-19",
            "2026-08-20"
        ])
    }

    func test_atHour_落在该日本地时刻() {
        let day = calendar.testDate(2026, 8, 20, hour: 21, minute: 45)
        let eight = CalendarDay.atHour(8, on: day, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: eight), 8)
        XCTAssertEqual(calendar.component(.minute, from: eight), 0)
        XCTAssertEqual(CalendarDay.dayKey(from: eight, calendar: calendar), "2026-08-20")
    }

    func test_dayKey_香港时区午夜与UTC不是同一天() {
        let utc = TimeZone(identifier: "UTC")!
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = utc
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 20
        components.hour = 0
        components.minute = 30
        let utcHalfPastMidnight = utcCalendar.date(from: components)!
        XCTAssertEqual(CalendarDay.dayKey(from: utcHalfPastMidnight, calendar: calendar), "2026-08-20")
        XCTAssertEqual(CalendarDay.dayKey(from: utcHalfPastMidnight, calendar: utcCalendar), "2026-08-20")

        components.hour = 16
        let utcAfternoon = utcCalendar.date(from: components)!
        XCTAssertEqual(CalendarDay.dayKey(from: utcAfternoon, calendar: utcCalendar), "2026-08-20")
        XCTAssertEqual(CalendarDay.dayKey(from: utcAfternoon, calendar: calendar), "2026-08-21")
    }
}

final class MonthWorkoutStatsTests: XCTestCase {
    private let calendar = EaseTestCalendar.make()

    func test_按月汇总天数时长与消耗_同日多次只计一天() {
        let month = calendar.testDate(2026, 8, 1)
        let logs = [
            WorkoutLog(timestamp: calendar.testDate(2026, 8, 10, hour: 8), kcal: 200, durationMinutes: 20),
            WorkoutLog(timestamp: calendar.testDate(2026, 8, 10, hour: 19), kcal: 300, durationMinutes: 40),
            WorkoutLog(timestamp: calendar.testDate(2026, 8, 12, hour: 8), kcal: 180),
            WorkoutLog(timestamp: calendar.testDate(2026, 9, 1, hour: 8), kcal: 400, durationMinutes: 50)
        ]
        let stats = MonthWorkoutStats.make(
            logs: logs,
            monthContaining: month,
            calendar: calendar,
            now: calendar.testDate(2026, 8, 20)
        )
        XCTAssertEqual(stats.days, 2)
        XCTAssertEqual(stats.sessions, 3)
        XCTAssertEqual(stats.totalKcal, 680)
        XCTAssertEqual(stats.totalMinutes, 60)
        XCTAssertEqual(stats.daysWithDuration, 1)
        XCTAssertEqual(stats.averageKcal, 340)
        XCTAssertEqual(stats.averageMinutes, 60)
    }

    func test_无训练记录_返回empty() {
        let stats = MonthWorkoutStats.make(
            logs: [],
            monthContaining: calendar.testDate(2026, 8, 1),
            calendar: calendar,
            now: calendar.testDate(2026, 8, 20)
        )
        XCTAssertEqual(stats, .empty)
    }
}
