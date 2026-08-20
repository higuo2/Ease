import XCTest
@testable import Ease

@MainActor
final class WeightLogRepositoryTests: EaseStoreTestCase {
    func test_insert_同一天多次_全部保留且按timestamp排序() throws {
        let morning = calendar.testDate(2026, 8, 10, hour: 7, minute: 30)
        let evening = calendar.testDate(2026, 8, 10, hour: 21, minute: 10)
        try weightLogs.insert(timestamp: evening, weight: 70.4)
        try weightLogs.insert(timestamp: morning, weight: 71.0, bodyFat: 18.2)

        let logs = try weightLogs.logs(on: calendar.testDate(2026, 8, 10))
        XCTAssertEqual(logs.map(\.weight), [71.0, 70.4])
        XCTAssertEqual(logs.map(\.bodyFat), [18.2, nil])
    }

    func test_insert_体重越界_抛错且不落库() {
        let day = calendar.testDate(2026, 8, 10, hour: 8)
        XCTAssertThrowsError(try weightLogs.insert(timestamp: day, weight: 20)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidWeight)
        }
        XCTAssertTrue((try? fetchAll(WeightLog.self).isEmpty) ?? false)
    }

    func test_insert_体脂越界_抛invalidBodyFat() {
        let day = calendar.testDate(2026, 8, 10, hour: 8)
        XCTAssertThrowsError(try weightLogs.insert(timestamp: day, weight: 70, bodyFat: 60)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidBodyFat)
        }
        XCTAssertTrue((try? fetchAll(WeightLog.self).isEmpty) ?? false)
    }

    func test_insert_未来日期_抛futureDate且不落库() {
        let tomorrow = CalendarDay.addingDays(1, to: .now, calendar: calendar)
        XCTAssertThrowsError(try weightLogs.insert(timestamp: tomorrow, weight: 70)) { error in
            XCTAssertEqual(error as? EaseDataError, .futureDate)
        }
        XCTAssertTrue((try? fetchAll(WeightLog.self).isEmpty) ?? false)
    }

    func test_update_只改该条_不影响同日其他log() throws {
        let morning = try weightLogs.insert(
            timestamp: calendar.testDate(2026, 8, 10, hour: 8),
            weight: 71.0,
            bodyFat: 18.0
        )
        let evening = try weightLogs.insert(
            timestamp: calendar.testDate(2026, 8, 10, hour: 21),
            weight: 70.4
        )

        try weightLogs.update(morning, weight: 70.8, bodyFat: 17.6)

        XCTAssertEqual(morning.weight, 70.8)
        XCTAssertEqual(morning.bodyFat, 17.6)
        XCTAssertEqual(evening.weight, 70.4)
        XCTAssertNil(evening.bodyFat)
    }

    func test_delete_只删该条_不影响同日其他log和DailyRecord() throws {
        let day = calendar.testDate(2026, 8, 10)
        var patch = DailyRecordPatch()
        patch.dietStatus = .set(.clean)
        try dailyRecords.upsert(on: day, patch: patch)

        let morning = try weightLogs.insert(timestamp: calendar.testDate(2026, 8, 10, hour: 8), weight: 71.0)
        let evening = try weightLogs.insert(timestamp: calendar.testDate(2026, 8, 10, hour: 21), weight: 70.4)

        try weightLogs.delete(morning)

        XCTAssertEqual(try weightLogs.logs(on: day).map(\.id), [evening.id])
        XCTAssertEqual(try dailyRecords.record(on: day)?.dietStatus, .clean)
    }

    func test_latest_返回当天timestamp最大的一条() throws {
        try weightLogs.insert(timestamp: calendar.testDate(2026, 8, 10, hour: 8), weight: 71.0)
        let evening = try weightLogs.insert(
            timestamp: calendar.testDate(2026, 8, 10, hour: 21),
            weight: 70.4
        )
        try weightLogs.insert(timestamp: calendar.testDate(2026, 8, 11, hour: 8), weight: 70.0)

        let latest = try weightLogs.latest(on: calendar.testDate(2026, 8, 10))
        XCTAssertEqual(latest?.id, evening.id)
        XCTAssertEqual(latest?.weight, 70.4)
    }

    func test_insert_体重四舍五入到0点1() throws {
        let log = try weightLogs.insert(
            timestamp: calendar.testDate(2026, 8, 10, hour: 8),
            weight: 70.24,
            bodyFat: 18.25
        )
        XCTAssertEqual(log.weight, 70.2)
        XCTAssertEqual(log.bodyFat, 18.3)
    }
}
