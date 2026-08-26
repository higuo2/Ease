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
        XCTAssertTrue(HealthKitCachePolicy.isFresh(fetchedAt: now.addingTimeInterval(-30), now: now))
        XCTAssertTrue(HealthKitCachePolicy.isFresh(fetchedAt: now.addingTimeInterval(-59), now: now))
        XCTAssertFalse(HealthKitCachePolicy.isFresh(fetchedAt: now.addingTimeInterval(-60), now: now))
        XCTAssertFalse(HealthKitCachePolicy.isFresh(fetchedAt: now.addingTimeInterval(-61), now: now))
        XCTAssertEqual(HealthKitCachePolicy.ttl, 60)
    }
}
