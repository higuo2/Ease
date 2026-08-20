import XCTest
@testable import Ease

@MainActor
final class UserProfileRepositoryTests: EaseStoreTestCase {
    func test_completeOnboarding_插入当天WeightLog并把该体重存为startWeight() throws {
        let profile = try profiles.completeOnboarding(
            heightCm: 170,
            currentWeight: 72.4,
            targetWeight: 62.0
        )

        XCTAssertEqual(profile.heightCm, 170)
        XCTAssertEqual(profile.startWeight, 72.4)
        XCTAssertEqual(profile.targetWeight, 62.0)
        XCTAssertTrue(profile.hasCompletedOnboarding)
        XCTAssertTrue(profile.hasMigratedWeightLogs)
        XCTAssertEqual(profile.sleepTargetHours, 8.0)

        let todayLogs = try weightLogs.logs(on: .now)
        XCTAssertEqual(todayLogs.count, 1)
        XCTAssertEqual(todayLogs[0].weight, 72.4)
        XCTAssertNil(todayLogs[0].bodyFat)
        XCTAssertTrue(try fetchAll(DailyRecord.self).isEmpty)
    }

    func test_completeOnboarding_非法身高_不落库() {
        XCTAssertThrowsError(
            try profiles.completeOnboarding(heightCm: 90, currentWeight: 70, targetWeight: 60)
        ) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidProfile)
        }
        XCTAssertTrue((try? fetchAll(WeightLog.self).isEmpty) ?? false)
        XCTAssertTrue((try? fetchAll(UserProfile.self).isEmpty) ?? false)
    }

    func test_deduplicate_多份profile_保留updatedAt较新者() throws {
        let older = UserProfile()
        older.heightCm = 160
        older.updatedAt = calendar.testDate(2026, 8, 1, hour: 8)
        context.insert(older)

        let newer = UserProfile()
        newer.heightCm = 172
        newer.updatedAt = calendar.testDate(2026, 8, 10, hour: 8)
        context.insert(newer)
        try context.save()

        let kept = try profiles.profile()
        XCTAssertEqual(kept.heightCm, 172)
        XCTAssertEqual(try fetchAll(UserProfile.self).count, 1)
    }

    func test_update_非法身高或体重_抛invalidProfile() throws {
        _ = try profiles.completeOnboarding(heightCm: 170, currentWeight: 72, targetWeight: 62)
        XCTAssertThrowsError(try profiles.update(heightCm: 80)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidProfile)
        }
        XCTAssertEqual(try profiles.profile().heightCm, 170)
    }

    func test_update_睡眠目标越界_抛invalidProfile() throws {
        _ = try profiles.completeOnboarding(heightCm: 170, currentWeight: 72, targetWeight: 62)
        XCTAssertThrowsError(try profiles.update(sleepTargetHours: 3)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidProfile)
        }
    }

    func test_resetAll_清空记录体重和profile() throws {
        _ = try profiles.completeOnboarding(heightCm: 170, currentWeight: 72, targetWeight: 62)
        var patch = DailyRecordPatch()
        patch.dietStatus = .set(.clean)
        try dailyRecords.upsert(on: calendar.testDate(2026, 8, 10), patch: patch)

        try profiles.resetAll()

        XCTAssertTrue(try fetchAll(WeightLog.self).isEmpty)
        XCTAssertTrue(try fetchAll(DailyRecord.self).isEmpty)
        XCTAssertTrue(try fetchAll(UserProfile.self).isEmpty)

        let restored = try profiles.profile()
        XCTAssertFalse(restored.hasCompletedOnboarding)
        XCTAssertFalse(restored.hasMigratedWeightLogs)
        XCTAssertEqual(restored.startWeight, 0)
    }
}
