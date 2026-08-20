import XCTest
@testable import Ease

final class EaseFormattersTests: XCTestCase {
    func test_parseDecimal_逗号小数_返回一位小数() {
        XCTAssertEqual(EaseFormatters.parseDecimal("72,4"), 72.4)
    }

    func test_parseDecimal_点号小数_返回一位小数() {
        XCTAssertEqual(EaseFormatters.parseDecimal("72.4"), 72.4)
    }

    func test_parseDecimal_空串或空白_返回nil() {
        XCTAssertNil(EaseFormatters.parseDecimal(""))
        XCTAssertNil(EaseFormatters.parseDecimal("   "))
        XCTAssertNil(EaseFormatters.parseDecimal("\n"))
    }

    func test_parseDecimal_千分位与小数同时出现_取最后一个分隔符为小数点() {
        XCTAssertEqual(EaseFormatters.parseDecimal("1,234.5"), 1234.5)
        XCTAssertEqual(EaseFormatters.parseDecimal("1.234,5"), 1234.5)
    }

    func test_parseDecimal_中文逗号与全角点() {
        XCTAssertEqual(EaseFormatters.parseDecimal("72，4"), 72.4)
        XCTAssertEqual(EaseFormatters.parseDecimal("72．4"), 72.4)
    }

    func test_parseDecimal_非法文本_返回nil() {
        XCTAssertNil(EaseFormatters.parseDecimal("abc"))
    }
}
