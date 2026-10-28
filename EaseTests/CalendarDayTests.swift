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

final class MonthWeightStatsTests: XCTestCase {
    private let calendar = EaseTestCalendar.make()

    func test_月内首尾差_涨跌只计相邻两天_同日取最后一次() {
        let records = [
            daily(2026, 8, 3, weight: 10),
            daily(2026, 8, 5, weight: 68.2)
        ]
        let logs = [
            WeightLog(timestamp: calendar.testDate(2026, 8, 1, hour: 8), weight: 70.0),
            WeightLog(timestamp: calendar.testDate(2026, 8, 2, hour: 8), weight: 69.5),
            WeightLog(timestamp: calendar.testDate(2026, 8, 3, hour: 8), weight: 80.0),
            WeightLog(timestamp: calendar.testDate(2026, 8, 3, hour: 20), weight: 69.8),
            WeightLog(timestamp: calendar.testDate(2026, 8, 10, hour: 8), weight: 69.0)
        ]
        let stats = MonthWeightStats.make(
            weightIndex: WeightMetrics.DayIndex.make(records: records, logs: logs, calendar: calendar),
            monthContaining: calendar.testDate(2026, 8, 1),
            calendar: calendar
        )
        XCTAssertEqual(stats.checkinDays, 5)
        XCTAssertEqual(stats.elapsedDays, 31)
        XCTAssertEqual(stats.lossDays, 1)
        XCTAssertEqual(stats.gainDays, 1)
        XCTAssertEqual(stats.averageDelta, -0.1)
        XCTAssertEqual(stats.monthDelta, -1.0)
    }

    func test_未来日不计入打卡和月差() {
        let today = CalendarDay.startOfDay(.now, calendar: calendar)
        let tomorrow = CalendarDay.addingDays(1, to: today, calendar: calendar)
        let logs = [
            WeightLog(timestamp: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today)!, weight: 70),
            WeightLog(timestamp: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: tomorrow)!, weight: 50)
        ]
        let stats = MonthWeightStats.make(
            weightIndex: WeightMetrics.DayIndex.make(records: [], logs: logs, calendar: calendar),
            monthContaining: today,
            calendar: calendar
        )
        XCTAssertEqual(stats.checkinDays, 1)
        XCTAssertEqual(stats.monthDelta, 0)
    }

    private func daily(_ year: Int, _ month: Int, _ day: Int, weight: Double) -> DailyRecord {
        let record = DailyRecord(date: calendar.testDate(year, month, day), calendar: calendar)
        record.weight = weight
        return record
    }
}

final class CalendarMonthSnapshotTests: XCTestCase {
    private let calendar = EaseTestCalendar.make()

    func test_格子标记_健康睡眠优先于睡眠史_空白备注不算记录() {
        let now = calendar.testDate(2026, 8, 20, hour: 12)
        let noted = DailyRecord(date: calendar.testDate(2026, 8, 10), calendar: calendar)
        noted.note = "  hello  "
        noted.variableTags = [.period]
        let logs = [WeightLog(timestamp: calendar.testDate(2026, 8, 10, hour: 8), weight: 69.0)]
        let workouts = [WorkoutLog(timestamp: calendar.testDate(2026, 8, 12, hour: 8), kcal: 200)]
        let snapshot = CalendarMonthSnapshot.make(
            records: [noted],
            logs: logs,
            visibleMonth: calendar.testDate(2026, 8, 15),
            healthByDay: [
                "2026-08-10": HealthDaySnapshot(
                    dayKey: "2026-08-10",
                    activeEnergyKcal: 320,
                    previousNightSleepHours: 6.5
                )
            ],
            sleepHistory: SleepHistory.make(
                hoursByDay: ["2026-08-10": 9.0, "2026-08-11": 8.0],
                nights: 31,
                endingOn: now,
                calendar: calendar
            ),
            cycleHistory: CycleMetrics.make(
                periodDayKeys: ["2026-08-11"],
                endingOn: now,
                calendar: calendar
            ),
            workoutLogs: workouts,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(snapshot.days.count, 31)
        XCTAssertEqual(
            snapshot.leadingEmpty,
            CalendarDay.leadingEmptyDays(inMonthContaining: now, calendar: calendar)
        )

        let tenth = snapshot.day(for: calendar.testDate(2026, 8, 10), calendar: calendar)
        XCTAssertEqual(tenth?.weight, 69)
        XCTAssertEqual(tenth?.sleepHours, 6.5)
        XCTAssertEqual(tenth?.activeEnergyKcal, 320)
        XCTAssertEqual(tenth?.note, "hello")
        XCTAssertNil(tenth?.periodDayNumber)
        XCTAssertEqual(tenth?.marks, [.weight, .period, .sleep])
        XCTAssertEqual(tenth?.hasLogs, true)

        let eleventh = snapshot.day(for: calendar.testDate(2026, 8, 11), calendar: calendar)
        XCTAssertEqual(eleventh?.sleepHours, 8)
        XCTAssertEqual(eleventh?.marks, .sleep.union(.period))
        XCTAssertEqual(eleventh?.periodDayNumber, 1)
        XCTAssertNil(eleventh?.note)

        let twelfth = snapshot.day(for: calendar.testDate(2026, 8, 12), calendar: calendar)
        XCTAssertEqual(twelfth?.marks, .workout)
        XCTAssertTrue(twelfth?.hasLogs == true)

        let empty = snapshot.day(for: calendar.testDate(2026, 8, 4), calendar: calendar)
        XCTAssertEqual(empty?.marks, [])
        XCTAssertEqual(empty?.hasLogs, false)

        let today = snapshot.day(for: now, calendar: calendar)
        XCTAssertTrue(today?.isToday == true)
        XCTAssertFalse(today?.isFuture == true)
        let future = snapshot.day(for: calendar.testDate(2026, 8, 21), calendar: calendar)
        XCTAssertTrue(future?.isFuture == true)
    }
}
