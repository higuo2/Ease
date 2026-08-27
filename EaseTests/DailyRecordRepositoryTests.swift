import XCTest
@testable import Ease

@MainActor
final class DailyRecordRepositoryTests: EaseStoreTestCase {
    func test_upsert_仅餐食照片文件名_创建DailyRecord() throws {
        let day = calendar.testDate(2026, 8, 10)
        var patch = DailyRecordPatch()
        patch.breakfastPhoto = .set("abc-123.jpg")

        let record = try dailyRecords.upsert(on: day, patch: patch)

        XCTAssertNotNil(record)
        XCTAssertEqual(record?.breakfastPhotoFileName, "abc-123.jpg")
        XCTAssertNil(record?.dietStatus)
        XCTAssertTrue(try fetchAll(WeightLog.self).isEmpty)
    }

    func test_upsert_字段级合并_改饮食保留餐食文件名() throws {
        let day = calendar.testDate(2026, 8, 10)
        var initial = DailyRecordPatch()
        initial.lunchPhoto = .set("lunch.jpg")
        try dailyRecords.upsert(on: day, patch: initial)

        var dietOnly = DailyRecordPatch()
        dietOnly.dietStatus = .set(.clean)
        let updated = try dailyRecords.upsert(on: day, patch: dietOnly)

        XCTAssertEqual(updated?.dietStatus, .clean)
        XCTAssertEqual(updated?.lunchPhotoFileName, "lunch.jpg")
    }


    func test_upsert_仅称重_insert一条WeightLog_不创建DailyRecord() throws {
        let day = calendar.testDate(2026, 8, 10)
        var patch = DailyRecordPatch()
        patch.weight = .set(70.2)
        patch.bodyFat = .set(18.4)

        let record = try dailyRecords.upsert(on: day, patch: patch)

        XCTAssertNil(record)
        XCTAssertTrue(try fetchAll(DailyRecord.self).isEmpty)
        let logs = try weightLogs.logs(on: day)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].weight, 70.2)
        XCTAssertEqual(logs[0].bodyFat, 18.4)
        XCTAssertEqual(calendar.component(.hour, from: logs[0].timestamp), 8)
    }

    func test_upsert_称重加饮食_DailyRecord的legacy_weight保持nil() throws {
        let day = calendar.testDate(2026, 8, 10)
        var patch = DailyRecordPatch()
        patch.weight = .set(70.2)
        patch.dietStatus = .set(.normal)

        let record = try dailyRecords.upsert(on: day, patch: patch)

        XCTAssertNotNil(record)
        XCTAssertNil(record?.weight)
        XCTAssertNil(record?.bodyFat)
        XCTAssertEqual(record?.dietStatus, .normal)
        XCTAssertEqual(try weightLogs.logs(on: day).count, 1)
    }

    func test_upsert_同一天第二次称重_两条WeightLog都保留() throws {
        let day = calendar.testDate(2026, 8, 10)
        var first = DailyRecordPatch()
        first.weight = .set(71.0)
        var second = DailyRecordPatch()
        second.weight = .set(70.4)

        try dailyRecords.upsert(on: day, patch: first)
        try dailyRecords.upsert(on: day, patch: second)

        XCTAssertEqual(Set(try weightLogs.logs(on: day).map(\.weight)), [71.0, 70.4])
    }

    func test_upsert_字段级合并_未改的tags和note保持原值() throws {
        let day = calendar.testDate(2026, 8, 10)
        var initial = DailyRecordPatch()
        initial.dietStatus = .set(.clean)
        initial.tags = .set([.period, .travel])
        initial.note = .set("keep me")
        try dailyRecords.upsert(on: day, patch: initial)

        var dietOnly = DailyRecordPatch()
        dietOnly.dietStatus = .set(.cheat)
        let updated = try dailyRecords.upsert(on: day, patch: dietOnly)

        XCTAssertEqual(updated?.dietStatus, .cheat)
        XCTAssertEqual(updated?.variableTags, [.period, .travel])
        XCTAssertEqual(updated?.note, "keep me")
    }

    func test_upsert_空note视为清除备注() throws {
        let day = calendar.testDate(2026, 8, 10)
        var initial = DailyRecordPatch()
        initial.dietStatus = .set(.normal)
        initial.note = .set("hello")
        try dailyRecords.upsert(on: day, patch: initial)

        var clearNote = DailyRecordPatch()
        clearNote.note = .set("   ")
        let updated = try dailyRecords.upsert(on: day, patch: clearNote)

        XCTAssertNil(updated?.note)
        XCTAssertEqual(updated?.dietStatus, .normal)
    }

    func test_upsert_未来日期_抛futureDate() {
        let tomorrow = CalendarDay.addingDays(1, to: .now, calendar: calendar)
        var patch = DailyRecordPatch()
        patch.dietStatus = .set(.clean)
        XCTAssertThrowsError(try dailyRecords.upsert(on: tomorrow, patch: patch)) { error in
            XCTAssertEqual(error as? EaseDataError, .futureDate)
        }
        XCTAssertTrue((try? fetchAll(DailyRecord.self).isEmpty) ?? false)
    }

    func test_upsert_空patch_抛emptyPatch() {
        let day = calendar.testDate(2026, 8, 10)
        XCTAssertThrowsError(try dailyRecords.upsert(on: day, patch: DailyRecordPatch())) { error in
            XCTAssertEqual(error as? EaseDataError, .emptyPatch)
        }
    }

    func test_upsert_只有体脂没有体重和日记_抛emptyRecord() {
        let day = calendar.testDate(2026, 8, 10)
        var patch = DailyRecordPatch()
        patch.bodyFat = .set(18.0)
        XCTAssertThrowsError(try dailyRecords.upsert(on: day, patch: patch)) { error in
            XCTAssertEqual(error as? EaseDataError, .emptyRecord)
        }
        XCTAssertTrue((try? fetchAll(WeightLog.self).isEmpty) ?? false)
        XCTAssertTrue((try? fetchAll(DailyRecord.self).isEmpty) ?? false)
    }

    func test_deduplicate_同一dayKey两条_保留updatedAt较新者() throws {
        let day = calendar.testDate(2026, 8, 10)
        let older = DailyRecord(date: day, calendar: calendar)
        older.note = "old"
        older.updatedAt = calendar.testDate(2026, 8, 10, hour: 8)
        context.insert(older)

        let newer = DailyRecord(date: day, calendar: calendar)
        newer.note = "new"
        newer.updatedAt = calendar.testDate(2026, 8, 10, hour: 21)
        context.insert(newer)
        try context.save()

        let kept = try dailyRecords.record(on: day)
        XCTAssertEqual(kept?.note, "new")
        XCTAssertEqual(try dailyRecords.allRecords().count, 1)
    }

    func test_delete_只删DailyRecord_当天WeightLog仍在() throws {
        let day = calendar.testDate(2026, 8, 10)
        var patch = DailyRecordPatch()
        patch.weight = .set(70.0)
        patch.dietStatus = .set(.clean)
        try dailyRecords.upsert(on: day, patch: patch)

        try dailyRecords.delete(on: day)

        XCTAssertNil(try dailyRecords.record(on: day))
        XCTAssertEqual(try weightLogs.logs(on: day).count, 1)
    }

    func test_upsert_extraMealsJSON_不含三餐字段() throws {
        let day = calendar.testDate(2026, 8, 10)
        var patch = DailyRecordPatch()
        patch.extraMeals = .set([
            ExtraMealPhoto(id: "afternoonTea", title: nil, fileName: "tea.jpg"),
            ExtraMealPhoto(id: "breakfast", title: nil, fileName: "skip.jpg")
        ])
        let record = try dailyRecords.upsert(on: day, patch: patch)

        XCTAssertEqual(record?.extraMeals.map(\.id), ["afternoonTea"])
        XCTAssertEqual(record?.extraMeals.first?.fileName, "tea.jpg")
        XCTAssertNil(record?.breakfastPhotoFileName)
        XCTAssertTrue(record?.hasMealPhoto == true)
    }

    func test_extraMealsJSON_非法字符串解码为空且不崩() throws {
        let day = calendar.testDate(2026, 8, 10)
        let record = DailyRecord(date: day, calendar: calendar)
        record.extraMealsJSON = "{not-json"
        context.insert(record)
        try context.save()
        XCTAssertEqual(record.extraMeals, [])
        XCTAssertFalse(record.hasMealPhoto)
    }
}
