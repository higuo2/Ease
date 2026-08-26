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

    private func sampleImage(size: CGSize = CGSize(width: 8, height: 8)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
