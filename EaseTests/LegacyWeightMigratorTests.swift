import XCTest
@testable import Ease

@MainActor
final class LegacyWeightMigratorTests: EaseStoreTestCase {
    private func insertUnmigratedProfile() throws -> UserProfile {
        let profile = UserProfile()
        profile.hasMigratedWeightLogs = false
        context.insert(profile)
        try context.save()
        return profile
    }

    func test_迁移_有legacy体重且该日无WeightLog_插入一条且不把legacy置nil() throws {
        let profile = try insertUnmigratedProfile()
        let day = calendar.testDate(2026, 8, 10)
        let record = DailyRecord(date: day, calendar: calendar)
        record.weight = 71.2
        record.bodyFat = 18.4
        record.updatedAt = calendar.testDate(2026, 8, 10, hour: 7, minute: 15)
        context.insert(record)
        try context.save()

        try LegacyWeightMigrator.run(context: context, calendar: calendar)

        let logs = try weightLogs.logs(on: day)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].weight, 71.2)
        XCTAssertEqual(logs[0].bodyFat, 18.4)
        XCTAssertEqual(logs[0].timestamp, record.updatedAt)
        XCTAssertEqual(record.weight, 71.2)
        XCTAssertEqual(record.bodyFat, 18.4)
        XCTAssertTrue(profile.hasMigratedWeightLogs)
    }

    func test_迁移_该日已有WeightLog_跳过不重复插入() throws {
        try insertUnmigratedProfile()
        let day = calendar.testDate(2026, 8, 10)
        let record = DailyRecord(date: day, calendar: calendar)
        record.weight = 99.9
        context.insert(record)
        try weightLogs.insert(timestamp: calendar.testDate(2026, 8, 10, hour: 8), weight: 70.1)

        try LegacyWeightMigrator.run(context: context, calendar: calendar)

        let logs = try weightLogs.logs(on: day)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].weight, 70.1)
        XCTAssertEqual(record.weight, 99.9)
    }

    func test_迁移_updatedAt不在该日_timestamp用当天08点() throws {
        try insertUnmigratedProfile()
        let day = calendar.testDate(2026, 8, 10)
        let record = DailyRecord(date: day, calendar: calendar)
        record.weight = 70.0
        record.updatedAt = calendar.testDate(2026, 8, 12, hour: 9)
        context.insert(record)
        try context.save()

        try LegacyWeightMigrator.run(context: context, calendar: calendar)

        let logs = try weightLogs.logs(on: day)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(
            logs[0].timestamp,
            CalendarDay.atHour(8, on: day, calendar: calendar)
        )
    }

    func test_迁移_hasMigratedWeightLogs已为true_整表跳过() throws {
        let profile = UserProfile()
        profile.hasMigratedWeightLogs = true
        context.insert(profile)
        let day = calendar.testDate(2026, 8, 10)
        let record = DailyRecord(date: day, calendar: calendar)
        record.weight = 70.0
        context.insert(record)
        try context.save()

        try LegacyWeightMigrator.run(context: context, calendar: calendar)

        XCTAssertTrue(try fetchAll(WeightLog.self).isEmpty)
        XCTAssertTrue(profile.hasMigratedWeightLogs)
    }

    func test_迁移_成功后标记true_再跑幂等() throws {
        try insertUnmigratedProfile()
        let day = calendar.testDate(2026, 8, 10)
        let record = DailyRecord(date: day, calendar: calendar)
        record.weight = 70.0
        context.insert(record)
        try context.save()

        try LegacyWeightMigrator.run(context: context, calendar: calendar)
        try LegacyWeightMigrator.run(context: context, calendar: calendar)

        XCTAssertEqual(try fetchAll(WeightLog.self).count, 1)
        XCTAssertTrue(try profiles.profile().hasMigratedWeightLogs)
    }

    func test_迁移_无UserProfile_直接返回() throws {
        let day = calendar.testDate(2026, 8, 10)
        let record = DailyRecord(date: day, calendar: calendar)
        record.weight = 70.0
        context.insert(record)
        try context.save()

        try LegacyWeightMigrator.run(context: context, calendar: calendar)

        XCTAssertTrue(try fetchAll(WeightLog.self).isEmpty)
    }
}
