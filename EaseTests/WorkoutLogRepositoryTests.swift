import XCTest
@testable import Ease

@MainActor
final class WorkoutLogRepositoryTests: EaseStoreTestCase {
    func test_insert_同一天多次_全部保留且按timestamp排序() throws {
        let morning = calendar.testDate(2026, 8, 10, hour: 7, minute: 30)
        let evening = calendar.testDate(2026, 8, 10, hour: 21, minute: 10)
        try workouts.insert(timestamp: evening, kcal: 420)
        try workouts.insert(timestamp: morning, kcal: 180, durationMinutes: 25)

        let logs = try workouts.logs(on: calendar.testDate(2026, 8, 10))
        XCTAssertEqual(logs.map(\.kcal), [180, 420])
        XCTAssertEqual(logs.map(\.durationMinutes), [25, nil])
    }

    func test_insert_kcal越界_抛错且不落库() {
        let day = calendar.testDate(2026, 8, 10, hour: 8)
        XCTAssertThrowsError(try workouts.insert(timestamp: day, kcal: 5)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidWorkout)
        }
        XCTAssertThrowsError(try workouts.insert(timestamp: day, kcal: 2001)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidWorkout)
        }
        XCTAssertTrue((try? fetchAll(WorkoutLog.self).isEmpty) ?? false)
    }

    func test_insert_时长越界_抛invalidWorkout() {
        let day = calendar.testDate(2026, 8, 10, hour: 8)
        XCTAssertThrowsError(try workouts.insert(timestamp: day, kcal: 300, durationMinutes: 0)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidWorkout)
        }
        XCTAssertThrowsError(try workouts.insert(timestamp: day, kcal: 300, durationMinutes: 301)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidWorkout)
        }
        XCTAssertTrue((try? fetchAll(WorkoutLog.self).isEmpty) ?? false)
    }

    func test_insert_未来日期_抛futureDate且不落库() {
        let tomorrow = CalendarDay.addingDays(1, to: .now, calendar: calendar)
        XCTAssertThrowsError(try workouts.insert(timestamp: tomorrow, kcal: 300)) { error in
            XCTAssertEqual(error as? EaseDataError, .futureDate)
        }
        XCTAssertTrue((try? fetchAll(WorkoutLog.self).isEmpty) ?? false)
    }

    func test_insert_kcal四舍五入到整数() throws {
        let log = try workouts.insert(
            timestamp: calendar.testDate(2026, 8, 10, hour: 8),
            kcal: 249.6,
            durationMinutes: 40
        )
        XCTAssertEqual(log.kcal, 250)
        XCTAssertEqual(log.durationMinutes, 40)
    }

    func test_update_只改该条_不影响同日其他log() throws {
        let morning = try workouts.insert(
            timestamp: calendar.testDate(2026, 8, 10, hour: 8),
            kcal: 180,
            durationMinutes: 20
        )
        let evening = try workouts.insert(
            timestamp: calendar.testDate(2026, 8, 10, hour: 21),
            kcal: 400
        )

        try workouts.update(morning, kcal: 200, durationMinutes: 30)

        XCTAssertEqual(morning.kcal, 200)
        XCTAssertEqual(morning.durationMinutes, 30)
        XCTAssertEqual(evening.kcal, 400)
        XCTAssertNil(evening.durationMinutes)
    }

    func test_delete_只删该条_不影响同日其他log() throws {
        let day = calendar.testDate(2026, 8, 10)
        let morning = try workouts.insert(
            timestamp: calendar.testDate(2026, 8, 10, hour: 8),
            kcal: 180
        )
        let evening = try workouts.insert(
            timestamp: calendar.testDate(2026, 8, 10, hour: 21),
            kcal: 400
        )

        try workouts.delete(morning)

        XCTAssertEqual(try workouts.logs(on: day).map(\.id), [evening.id])
    }

    func test_hasLog_当天有记录返回true() throws {
        XCTAssertFalse(try workouts.hasLog(on: calendar.testDate(2026, 8, 10)))
        try workouts.insert(timestamp: calendar.testDate(2026, 8, 10, hour: 8), kcal: 200)
        XCTAssertTrue(try workouts.hasLog(on: calendar.testDate(2026, 8, 10)))
        XCTAssertFalse(try workouts.hasLog(on: calendar.testDate(2026, 8, 11)))
    }
}
