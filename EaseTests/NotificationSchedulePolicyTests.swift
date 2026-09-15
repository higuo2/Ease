import XCTest
@testable import Ease

@MainActor
final class NotificationSchedulePolicyTests: EaseStoreTestCase {

    func test_体重提醒_当天已有体重_跳过今天08点() throws {
        let now = calendar.testDate(2026, 8, 20, hour: 7, minute: 0)
        let today = calendar.testDate(2026, 8, 20)
        let tomorrow = calendar.testDate(2026, 8, 21)
        let log = WeightLog(timestamp: calendar.testDate(2026, 8, 20, hour: 6, minute: 50), weight: 70)
        context.insert(log)
        try context.save()

        XCTAssertFalse(
            NotificationSchedulePolicy.shouldScheduleWeightReminder(
                on: today,
                now: now,
                logs: [log],
                calendar: calendar
            )
        )
        XCTAssertTrue(
            NotificationSchedulePolicy.shouldScheduleWeightReminder(
                on: tomorrow,
                now: now,
                logs: [log],
                calendar: calendar
            )
        )
    }

    func test_体重提醒_当天无体重且08点未到_今天仍调度() {
        let now = calendar.testDate(2026, 8, 20, hour: 7, minute: 0)
        XCTAssertTrue(
            NotificationSchedulePolicy.shouldScheduleWeightReminder(
                on: calendar.testDate(2026, 8, 20),
                now: now,
                hasWeightToday: false,
                calendar: calendar
            )
        )
    }

    func test_体重提醒_08点已过_推迟到次日() {
        let now = calendar.testDate(2026, 8, 20, hour: 9, minute: 0)
        XCTAssertFalse(
            NotificationSchedulePolicy.shouldScheduleWeightReminder(
                on: calendar.testDate(2026, 8, 20),
                now: now,
                hasWeightToday: false,
                calendar: calendar
            )
        )
        XCTAssertTrue(
            NotificationSchedulePolicy.shouldScheduleWeightReminder(
                on: calendar.testDate(2026, 8, 21),
                now: now,
                hasWeightToday: false,
                calendar: calendar
            )
        )
    }

    func test_饮食提醒已停用_当天无饮食不调度饮食() {
        // Diet reminders are no longer scheduled. Weight reminder is independent.
        let now = calendar.testDate(2026, 8, 20, hour: 10)
        let today = calendar.testDate(2026, 8, 20)
        XCTAssertFalse(
            NotificationSchedulePolicy.shouldScheduleWeightReminder(
                on: today,
                now: now,
                hasWeightToday: true,
                calendar: calendar
            )
        )
    }

    func test_过去的日期永不调度() {
        let now = calendar.testDate(2026, 8, 20, hour: 7)
        XCTAssertFalse(
            NotificationSchedulePolicy.shouldScheduleWeightReminder(
                on: calendar.testDate(2026, 8, 19),
                now: now,
                hasWeightToday: false,
                calendar: calendar
            )
        )
    }

    func test_恰好等于触发时刻_视为已过不调度() {
        let now = CalendarDay.atHour(8, on: calendar.testDate(2026, 8, 20), calendar: calendar)
        XCTAssertFalse(
            NotificationSchedulePolicy.shouldScheduleWeightReminder(
                on: calendar.testDate(2026, 8, 20),
                now: now,
                hasWeightToday: false,
                calendar: calendar
            )
        )
    }

    func test_自定义体重时刻_0930未到则今天仍调度() {
        let now = calendar.testDate(2026, 8, 20, hour: 9, minute: 0)
        XCTAssertTrue(
            NotificationSchedulePolicy.shouldScheduleWeightReminder(
                on: calendar.testDate(2026, 8, 20),
                now: now,
                hasWeightToday: false,
                hour: 9,
                minute: 30,
                calendar: calendar
            )
        )
        XCTAssertFalse(
            NotificationSchedulePolicy.shouldScheduleWeightReminder(
                on: calendar.testDate(2026, 8, 20),
                now: calendar.testDate(2026, 8, 20, hour: 9, minute: 30),
                hasWeightToday: false,
                hour: 9,
                minute: 30,
                calendar: calendar
            )
        )
    }

    func test_自定义时刻仍尊重当天已打卡() {
        let now = calendar.testDate(2026, 8, 20, hour: 7)
        XCTAssertFalse(
            NotificationSchedulePolicy.shouldScheduleWeightReminder(
                on: calendar.testDate(2026, 8, 20),
                now: now,
                hasWeightToday: true,
                hour: 9,
                minute: 30,
                calendar: calendar
            )
        )
    }

    func test_越界hour会钳制后再判断() {
        let now = calendar.testDate(2026, 8, 20, hour: 22, minute: 0)
        XCTAssertTrue(
            NotificationSchedulePolicy.shouldScheduleWeightReminder(
                on: calendar.testDate(2026, 8, 20),
                now: now,
                hasWeightToday: false,
                hour: 99,
                minute: 0,
                calendar: calendar
            )
        )
    }
}
