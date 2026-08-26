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
        XCTAssertEqual(profile.weightReminderHour, 8)
        XCTAssertEqual(profile.weightReminderMinute, 0)
        XCTAssertEqual(profile.dietReminderHour, 22)
        XCTAssertEqual(profile.dietReminderMinute, 30)

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
        try metrics.seedBuiltinsIfNeeded()
        let waist = try metrics.definition(key: "waist")!
        try metrics.setEnabled(waist, isEnabled: true)
        _ = try metrics.insertLog(
            timestamp: calendar.testDate(2026, 8, 10, hour: 8),
            metricKey: "waist",
            value: 68
        )

        try profiles.resetAll()

        XCTAssertTrue(try fetchAll(WeightLog.self).isEmpty)
        XCTAssertTrue(try fetchAll(DailyRecord.self).isEmpty)
        XCTAssertTrue(try fetchAll(UserProfile.self).isEmpty)
        XCTAssertTrue(try fetchAll(MetricDefinition.self).isEmpty)
        XCTAssertTrue(try fetchAll(MetricLog.self).isEmpty)

        let restored = try profiles.profile()
        XCTAssertFalse(restored.hasCompletedOnboarding)
        XCTAssertFalse(restored.hasMigratedWeightLogs)
        XCTAssertEqual(restored.startWeight, 0)
    }

    func test_update_提醒时刻写入并钳制() throws {
        _ = try profiles.completeOnboarding(heightCm: 170, currentWeight: 72, targetWeight: 62)
        let updated = try profiles.update(
            weightReminderHour: 9,
            weightReminderMinute: 30,
            dietReminderHour: 21,
            dietReminderMinute: 0
        )
        XCTAssertEqual(updated.weightReminderHour, 9)
        XCTAssertEqual(updated.weightReminderMinute, 30)
        XCTAssertEqual(updated.dietReminderHour, 21)
        XCTAssertEqual(updated.dietReminderMinute, 0)

        let clamped = try profiles.update(weightReminderHour: 25, weightReminderMinute: 99)
        XCTAssertEqual(clamped.weightReminderHour, 23)
        XCTAssertEqual(clamped.weightReminderMinute, 59)
    }

    func test_deduplicate_提醒时刻随整份较新profile走() throws {
        let older = UserProfile()
        older.weightReminderHour = 8
        older.weightReminderMinute = 0
        older.dietReminderHour = 22
        older.dietReminderMinute = 30
        older.updatedAt = calendar.testDate(2026, 8, 1, hour: 8)
        context.insert(older)

        let newer = UserProfile()
        newer.weightReminderHour = 9
        newer.weightReminderMinute = 15
        newer.dietReminderHour = 21
        newer.dietReminderMinute = 0
        newer.updatedAt = calendar.testDate(2026, 8, 10, hour: 8)
        context.insert(newer)
        try context.save()

        let kept = try profiles.profile()
        XCTAssertEqual(kept.weightReminderHour, 9)
        XCTAssertEqual(kept.weightReminderMinute, 15)
        XCTAssertEqual(kept.dietReminderHour, 21)
        XCTAssertEqual(kept.dietReminderMinute, 0)
        XCTAssertEqual(try fetchAll(UserProfile.self).count, 1)
    }

    func test_homeModules_空字符串回退默认且去重() {
        XCTAssertEqual(HomeModule.decode(""), HomeModule.defaults)
        XCTAssertEqual(
            HomeModule.decode("bmi,weight,bmi,sleep"),
            [.bmi, .weight, .sleep]
        )
        XCTAssertEqual(HomeModule.encode([.sleep, .sleep, .diet]), "sleep,diet")
    }

    func test_update_生日与性别可写入也可清空() throws {
        _ = try profiles.completeOnboarding(heightCm: 170, currentWeight: 72, targetWeight: 62)
        let birth = calendar.startOfDay(for: calendar.testDate(1998, 3, 12))
        let updated = try profiles.update(
            birthDate: .set(birth),
            sex: .female
        )
        XCTAssertEqual(updated.birthDate, birth)
        XCTAssertEqual(updated.sex, .female)

        let cleared = try profiles.update(birthDate: .set(nil), sex: .unspecified)
        XCTAssertNil(cleared.birthDate)
        XCTAssertEqual(cleared.sex, .unspecified)
    }

    func test_update_未来生日_抛invalidProfile() throws {
        _ = try profiles.completeOnboarding(heightCm: 170, currentWeight: 72, targetWeight: 62)
        XCTAssertThrowsError(
            try profiles.update(birthDate: .set(calendar.testDate(2099, 1, 1)))
        ) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidProfile)
        }
        XCTAssertNil(try profiles.profile().birthDate)
    }
}
