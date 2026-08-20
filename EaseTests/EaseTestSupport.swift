import Foundation
import SwiftData
import XCTest
@testable import Ease

/// Gregorian calendar pinned to Hong Kong (UTC+8) so day-boundary tests do not follow the host TZ.
enum EaseTestCalendar {
    static let timeZoneIdentifier = "Asia/Hong_Kong"

    static func make() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        calendar.locale = Locale(identifier: "en_HK")
        return calendar
    }
}

enum EaseInMemoryStore {
    static func makeContainer() throws -> ModelContainer {
        let schema = Schema(EaseModelContainer.models)
        let configuration = ModelConfiguration(
            "EaseTests-\(UUID().uuidString)",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

extension Calendar {
    func testDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 12,
        minute: Int = 0,
        second: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        guard let date = date(from: components) else {
            preconditionFailure("Invalid test date \(year)-\(month)-\(day) \(hour):\(minute):\(second)")
        }
        return date
    }
}

/// In-memory SwiftData fixture. Each test gets an isolated store that never touches disk.
@MainActor
class EaseStoreTestCase: XCTestCase {
    nonisolated override class var defaultTestSuite: XCTestSuite {
        if self == EaseStoreTestCase.self {
            return XCTestSuite(name: NSStringFromClass(self))
        }
        return super.defaultTestSuite
    }

    private(set) var container: ModelContainer!
    private(set) var context: ModelContext!
    let calendar = EaseTestCalendar.make()

    override func setUp() async throws {
        try await super.setUp()
        container = try EaseInMemoryStore.makeContainer()
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    override func tearDown() async throws {
        context = nil
        container = nil
        try await super.tearDown()
    }

    var dailyRecords: DailyRecordRepository {
        DailyRecordRepository(context: context, calendar: calendar)
    }

    var weightLogs: WeightLogRepository {
        WeightLogRepository(context: context, calendar: calendar)
    }

    var profiles: UserProfileRepository {
        UserProfileRepository(context: context, calendar: calendar)
    }

    var metrics: MetricRepository {
        MetricRepository(context: context, calendar: calendar)
    }

    func fetchAll<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        try context.fetch(FetchDescriptor<T>())
    }
}
