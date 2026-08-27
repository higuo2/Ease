import XCTest
@testable import Ease

@MainActor
final class MealCutoutPreferencesTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private var prefs: MealCutoutPreferences!

    override func setUp() {
        super.setUp()
        suiteName = "EaseCutoutTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        prefs = MealCutoutPreferences(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        prefs = nil
        super.tearDown()
    }

    func test_默认跟随全局开启() {
        XCTAssertTrue(prefs.isAutoCutoutEnabled)
        XCTAssertTrue(prefs.isCutoutActive(for: "a.jpg"))
        XCTAssertFalse(prefs.isCutoutActive(for: nil))
        XCTAssertFalse(prefs.isCutoutActive(for: ""))
    }

    func test_魔棒写入单卡覆盖不影响其它卡() {
        prefs.toggle(fileName: "a.jpg")
        XCTAssertFalse(prefs.isCutoutActive(for: "a.jpg"))
        XCTAssertTrue(prefs.isCutoutActive(for: "b.jpg"))

        prefs.toggle(fileName: "a.jpg")
        XCTAssertTrue(prefs.isCutoutActive(for: "a.jpg"))
    }

    func test_全局关闭后无覆盖的卡片跟随() {
        prefs.isAutoCutoutEnabled = false
        XCTAssertFalse(prefs.isCutoutActive(for: "a.jpg"))
        prefs.toggle(fileName: "a.jpg")
        XCTAssertTrue(prefs.isCutoutActive(for: "a.jpg"))
        XCTAssertFalse(prefs.isCutoutActive(for: "b.jpg"))
    }

    func test_覆盖可落盘再读() {
        prefs.toggle(fileName: "a.jpg")
        let reloaded = MealCutoutPreferences(defaults: defaults)
        XCTAssertFalse(reloaded.isCutoutActive(for: "a.jpg"))
        XCTAssertTrue(reloaded.isCutoutActive(for: "b.jpg"))
    }

    func test_reset_恢复默认并清空覆盖() {
        prefs.isAutoCutoutEnabled = false
        prefs.toggle(fileName: "a.jpg")
        prefs.reset()
        XCTAssertTrue(prefs.isAutoCutoutEnabled)
        XCTAssertTrue(prefs.isCutoutActive(for: "a.jpg"))
        XCTAssertTrue(prefs.overrides.isEmpty)
    }
}
