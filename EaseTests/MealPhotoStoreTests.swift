import UIKit
import XCTest
@testable import Ease

final class MealPhotoStoreTests: XCTestCase {
    override func tearDown() {
        MealPhotoStore.removeAllCached()
        super.tearDown()
    }

    func test_peek_未知文件_返回nil() {
        MealPhotoStore.removeAllCached()
        XCTAssertNil(MealPhotoStore.peek("missing.jpg"))
        XCTAssertNil(MealPhotoStore.peek(nil))
        XCTAssertNil(MealPhotoStore.peek(""))
    }

    func test_saveJPEG_写入缓存_删除时驱逐() async throws {
        MealPhotoStore.removeAllCached()
        let fileName = try await MealPhotoStore.saveJPEG(sampleImage())
        XCTAssertNotNil(MealPhotoStore.peek(fileName))

        MealPhotoStore.deleteAsync(fileName: fileName)
        XCTAssertNil(MealPhotoStore.peek(fileName))
    }

    func test_loadImage_缓存未命中时读盘再写入() async throws {
        MealPhotoStore.removeAllCached()
        let fileName = try await MealPhotoStore.saveJPEG(sampleImage())
        MealPhotoStore.removeAllCached()
        XCTAssertNil(MealPhotoStore.peek(fileName))

        let loaded = await MealPhotoStore.loadImage(fileName: fileName)
        XCTAssertNotNil(loaded)
        XCTAssertNotNil(MealPhotoStore.peek(fileName))

        MealPhotoStore.deleteAsync(fileName: fileName)
    }

    func test_loadOriginal_不写入缩略图缓存() async throws {
        MealPhotoStore.removeAllCached()
        let fileName = try await MealPhotoStore.saveJPEG(sampleImage())
        MealPhotoStore.removeAllCached()
        XCTAssertNotNil(await MealPhotoStore.loadOriginal(fileName: fileName))
        XCTAssertNil(MealPhotoStore.peek(fileName))
        MealPhotoStore.deleteAsync(fileName: fileName)
    }

    func test_loadOriginal_缺失或不安全文件名_返回nil() async {
        MealPhotoStore.removeAllCached()
        XCTAssertNil(await MealPhotoStore.loadOriginal(fileName: nil))
        XCTAssertNil(await MealPhotoStore.loadOriginal(fileName: ""))
        XCTAssertNil(await MealPhotoStore.loadOriginal(fileName: "missing.jpg"))
        XCTAssertNil(await MealPhotoStore.loadOriginal(fileName: "../escape.jpg"))
        XCTAssertNil(await MealPhotoStore.loadOriginal(fileName: "photo.png"))
        XCTAssertNil(await MealPhotoStore.loadImage(fileName: "../escape.jpg"))
        XCTAssertNil(await MealPhotoStore.loadImage(fileName: "missing.jpg"))
    }

    func test_removeAllCached_驱逐已保存缩略图() async throws {
        MealPhotoStore.removeAllCached()
        let fileName = try await MealPhotoStore.saveJPEG(sampleImage())
        XCTAssertNotNil(MealPhotoStore.peek(fileName))
        MealPhotoStore.removeAllCached()
        XCTAssertNil(MealPhotoStore.peek(fileName))
        MealPhotoStore.deleteAsync(fileName: fileName)
    }

    func test_cutoutFileName_只从安全jpg派生() {
        XCTAssertEqual(MealPhotoStore.cutoutFileName(for: "abc-123.jpg"), "abc-123-cutout.png")
        XCTAssertEqual(MealPhotoStore.cutoutFileName(for: "abc.jpeg"), "abc-cutout.png")
        XCTAssertNil(MealPhotoStore.cutoutFileName(for: "../escape.jpg"))
        XCTAssertNil(MealPhotoStore.cutoutFileName(for: "photo.png"))
        XCTAssertNil(MealPhotoStore.cutoutFileName(for: nil))
        XCTAssertNil(MealPhotoStore.cutoutFileName(for: ""))
    }

    func test_saveCutout_删原图时驱逐配对png() async throws {
        MealPhotoStore.removeAllCached()
        let original = try await MealPhotoStore.saveJPEG(sampleImage())
        let cutoutName = try await MealPhotoStore.saveCutout(sampleImage(), forOriginal: original)
        XCTAssertEqual(cutoutName, MealPhotoStore.cutoutFileName(for: original))
        XCTAssertNotNil(MealPhotoStore.peek(cutoutName))

        MealPhotoStore.removeAllCached()
        XCTAssertNotNil(await MealPhotoStore.loadImage(fileName: cutoutName))

        MealPhotoStore.deleteAsync(fileName: original)
        XCTAssertNil(MealPhotoStore.peek(original))
        XCTAssertNil(MealPhotoStore.peek(cutoutName))
    }

    func test_loadImage_拒绝任意png和路径穿越cutout() async {
        MealPhotoStore.removeAllCached()
        XCTAssertNil(await MealPhotoStore.loadImage(fileName: "photo.png"))
        XCTAssertNil(await MealPhotoStore.loadImage(fileName: "../escape-cutout.png"))
        XCTAssertNil(await MealPhotoStore.loadOriginal(fileName: "photo.png"))
    }

    private func sampleImage(size: CGSize = CGSize(width: 8, height: 8)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
