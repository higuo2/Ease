import XCTest
@testable import Ease

final class HealthKitCacheTests: XCTestCase {
    func test_isFresh_无时间戳或强制刷新_都不是新鲜缓存() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertFalse(HealthKitCachePolicy.isFresh(fetchedAt: nil, now: now))
        XCTAssertFalse(HealthKitCachePolicy.isFresh(fetchedAt: now, now: now, force: true))
    }

    func test_isFresh_TTL内可复用_过期后不可复用() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertTrue(HealthKitCachePolicy.isFresh(fetchedAt: now.addingTimeInterval(-120), now: now))
        XCTAssertTrue(HealthKitCachePolicy.isFresh(fetchedAt: now.addingTimeInterval(-299), now: now))
        XCTAssertFalse(HealthKitCachePolicy.isFresh(fetchedAt: now.addingTimeInterval(-300), now: now))
        XCTAssertFalse(HealthKitCachePolicy.isFresh(fetchedAt: now.addingTimeInterval(-301), now: now))
        XCTAssertEqual(HealthKitCachePolicy.ttl, 300)
    }
}

final class EnergyHistoryTests: XCTestCase {
    private let calendar = EaseTestCalendar.make()

    func test_make_连续N天_窗口外忽略_平均只算有消耗的天() {
        let ending = calendar.testDate(2026, 8, 20, hour: 15)
        let history = EnergyHistory.make(
            kcalByDay: [
                "2026-08-01": 999,
                "2026-08-18": 400,
                "2026-08-20": 500.4
            ],
            days: 7,
            endingOn: ending,
            calendar: calendar
        )
        XCTAssertEqual(history.days.count, 7)
        XCTAssertEqual(history.days.first?.dayKey, "2026-08-14")
        XCTAssertEqual(history.days.last?.dayKey, "2026-08-20")
        XCTAssertNil(history.days.first?.kcal)
        XCTAssertEqual(history.loggedDays.map(\.kcal), [400, 500.4])
        XCTAssertEqual(history.averageKcal, 450)
        XCTAssertEqual(history.endingOn, calendar.testDate(2026, 8, 20, hour: 0))
    }

    func test_make_天数为0时仍生成结束日_无数据平均为nil() {
        let ending = calendar.testDate(2026, 8, 20)
        let history = EnergyHistory.make(
            kcalByDay: [:],
            days: 0,
            endingOn: ending,
            calendar: calendar
        )
        XCTAssertEqual(history.days.count, 1)
        XCTAssertNil(history.averageKcal)
    }
}
