import XCTest
import UIKit
@testable import Ease

final class ScaleOCRTests: XCTestCase {
    func test_parse_kg与百分号分行_分别识别体重和体脂() {
        let result = ScaleOCR.parse(lines: [
            ScaleOCR.Line(text: "72.4 kg", area: 1.0),
            ScaleOCR.Line(text: "18.6%", area: 0.6)
        ])
        XCTAssertEqual(result.weightKg, 72.4)
        XCTAssertEqual(result.bodyFatPercent, 18.6)
    }

    func test_parse_中文体重体脂标签_分别识别() {
        let result = ScaleOCR.parse(lines: [
            ScaleOCR.Line(text: "体重 70.2 kg", area: 1.0),
            ScaleOCR.Line(text: "体脂 19.5%", area: 0.8)
        ])
        XCTAssertEqual(result.weightKg, 70.2)
        XCTAssertEqual(result.bodyFatPercent, 19.5)
    }

    func test_parse_BMI水分肌肉不误当体重() {
        let result = ScaleOCR.parse(lines: [
            ScaleOCR.Line(text: "BMI 22.4", area: 1.2),
            ScaleOCR.Line(text: "水分 52.3%", area: 1.0),
            ScaleOCR.Line(text: "肌肉 45.0 kg", area: 1.0),
            ScaleOCR.Line(text: "72.4 kg", area: 0.9)
        ])
        XCTAssertEqual(result.weightKg, 72.4)
        XCTAssertNil(result.bodyFatPercent)
    }

    func test_parse_无法唯一确定体重_返回nil() {
        let result = ScaleOCR.parse(lines: [
            ScaleOCR.Line(text: "70.2", area: 1.0),
            ScaleOCR.Line(text: "65.0", area: 0.95)
        ])
        XCTAssertNil(result.weightKg)
        XCTAssertNil(result.bodyFatPercent)
    }

    func test_parse_面积明显更大的未标注数字_取最大者() {
        let result = ScaleOCR.parse(lines: [
            ScaleOCR.Line(text: "72.0", area: 1.4),
            ScaleOCR.Line(text: "60.0", area: 1.0)
        ])
        XCTAssertEqual(result.weightKg, 72.0)
    }

    func test_parse_同一行同时有kg和百分号_只取体重不取体脂() {
        let result = ScaleOCR.parse(lines: [
            ScaleOCR.Line(text: "72.4 kg 18.6%", area: 1.0)
        ])
        XCTAssertEqual(result.weightKg, 72.4)
        XCTAssertNil(result.bodyFatPercent)
    }

    func test_parse_空行_全部为nil() {
        let result = ScaleOCR.parse(lines: [])
        XCTAssertEqual(result, ScaleOCR.Result())
    }
}
