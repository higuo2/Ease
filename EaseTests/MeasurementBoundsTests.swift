import XCTest
@testable import Ease

final class MeasurementBoundsTests: XCTestCase {
    func test_roundedToTenth_半数远离零() {
        XCTAssertEqual(MeasurementBounds.roundedToTenth(70.04), 70.0)
        XCTAssertEqual(MeasurementBounds.roundedToTenth(70.05), 70.1)
        XCTAssertEqual(MeasurementBounds.roundedToTenth(70.14), 70.1)
    }

    func test_roundedToHalf_半数远离零() {
        XCTAssertEqual(MeasurementBounds.roundedToHalf(8.24), 8.0)
        XCTAssertEqual(MeasurementBounds.roundedToHalf(8.25), 8.5)
        XCTAssertEqual(MeasurementBounds.roundedToHalf(8.75), 9.0)
    }

    func test_validatedWeight_合法值四舍五入后落入范围() throws {
        XCTAssertEqual(try MeasurementBounds.validatedWeight(70.04), 70.0)
        XCTAssertEqual(try MeasurementBounds.validatedWeight(30), 30.0)
        XCTAssertEqual(try MeasurementBounds.validatedWeight(150), 150.0)
        XCTAssertEqual(try MeasurementBounds.validatedWeight(29.95), 30.0)
    }

    func test_validatedWeight_越界_抛invalidWeight() {
        XCTAssertThrowsError(try MeasurementBounds.validatedWeight(29.94)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidWeight)
        }
        XCTAssertThrowsError(try MeasurementBounds.validatedWeight(150.05)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidWeight)
        }
    }

    func test_validatedBodyFat_合法与越界() throws {
        XCTAssertEqual(try MeasurementBounds.validatedBodyFat(18.24), 18.2)
        XCTAssertEqual(try MeasurementBounds.validatedBodyFat(5), 5.0)
        XCTAssertEqual(try MeasurementBounds.validatedBodyFat(50), 50.0)
        XCTAssertThrowsError(try MeasurementBounds.validatedBodyFat(4.94)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidBodyFat)
        }
        XCTAssertThrowsError(try MeasurementBounds.validatedBodyFat(50.05)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidBodyFat)
        }
    }

    func test_validatedHeight_合法与越界() throws {
        XCTAssertEqual(try MeasurementBounds.validatedHeight(175.04), 175.0)
        XCTAssertEqual(try MeasurementBounds.validatedHeight(100), 100.0)
        XCTAssertEqual(try MeasurementBounds.validatedHeight(250), 250.0)
        XCTAssertThrowsError(try MeasurementBounds.validatedHeight(99.94)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidProfile)
        }
    }

    func test_validatedSleepTarget_半小时步进并限制范围() throws {
        XCTAssertEqual(try MeasurementBounds.validatedSleepTarget(8.24), 8.0)
        XCTAssertEqual(try MeasurementBounds.validatedSleepTarget(8.25), 8.5)
        XCTAssertEqual(try MeasurementBounds.validatedSleepTarget(4), 4.0)
        XCTAssertEqual(try MeasurementBounds.validatedSleepTarget(12), 12.0)
        XCTAssertThrowsError(try MeasurementBounds.validatedSleepTarget(3.7)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidProfile)
        }
        XCTAssertThrowsError(try MeasurementBounds.validatedSleepTarget(12.3)) { error in
            XCTAssertEqual(error as? EaseDataError, .invalidProfile)
        }
    }

    func test_roundedToStep_与时刻钳制() {
        XCTAssertEqual(MeasurementBounds.roundedToStep(1230, step: 50), 1250)
        XCTAssertEqual(MeasurementBounds.roundedToStep(68.04, step: 0.1), 68.0)
        XCTAssertEqual(MeasurementBounds.clampedHour(-1), 0)
        XCTAssertEqual(MeasurementBounds.clampedHour(24), 23)
        XCTAssertEqual(MeasurementBounds.clampedMinute(60), 59)
    }
}
