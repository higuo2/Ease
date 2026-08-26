import Foundation
import UIKit

enum MealPhotoStore {
    private static let maxThumbnailPixel: CGFloat = 512
    private static let lock = NSLock()
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 30
        cache.totalCostLimit = 30 * 512 * 512 * 4
        return cache
    }()

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// Writes JPEG into the app Documents sandbox on a background queue.
    /// Returns the filename only (not a full path).
    static func saveJPEG(
        _ image: UIImage,
        compressionQuality: CGFloat = 0.8
    ) async throws -> String {
        let fileName = try await Task.detached(priority: .userInitiated) {
            guard let data = image.jpegData(compressionQuality: compressionQuality) else {
                throw CocoaError(.fileWriteUnknown)
            }
            let fileName = UUID().uuidString + ".jpg"
            let url = documentsDirectory.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            return fileName
        }.value
        storeCached(thumbnail(image), fileName: fileName)
        return fileName
    }

    static func peek(_ fileName: String?) -> UIImage? {
        guard let fileName, !fileName.isEmpty else { return nil }
        lock.lock()
        defer { lock.unlock() }
        return cache.object(forKey: fileName as NSString)
    }

    static func loadImage(fileName: String?) async -> UIImage? {
        guard let fileName, !fileName.isEmpty else { return nil }
        if let hit = peek(fileName) { return hit }
        let loaded = await Task.detached(priority: .utility) { () -> UIImage? in
            guard let url = fileURL(for: fileName) else { return nil }
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
                return nil
            }
            return thumbnail(image)
        }.value
        if let loaded {
            storeCached(loaded, fileName: fileName)
        }
        return loaded
    }

    /// Fire-and-forget sandbox cleanup — never block the main actor.
    static func deleteAsync(fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        removeCached(fileName)
        Task.detached(priority: .utility) {
            deleteSync(fileName: fileName)
        }
    }

    static func deleteAsync(fileNames: [String?]) {
        let names = fileNames.compactMap { $0 }.filter { !$0.isEmpty }
        guard !names.isEmpty else { return }
        for name in names { removeCached(name) }
        Task.detached(priority: .utility) {
            for name in names {
                deleteSync(fileName: name)
            }
        }
    }

    static func deleteAllAsync(in record: DailyRecord) {
        deleteAsync(fileNames: [
            record.breakfastPhotoFileName,
            record.lunchPhotoFileName,
            record.dinnerPhotoFileName
        ])
    }

    static func removeAllCached() {
        lock.lock()
        cache.removeAllObjects()
        lock.unlock()
    }

    private static func storeCached(_ image: UIImage, fileName: String) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        lock.lock()
        cache.setObject(image, forKey: fileName as NSString, cost: max(cost, 1))
        lock.unlock()
    }

    private static func removeCached(_ fileName: String) {
        lock.lock()
        cache.removeObject(forKey: fileName as NSString)
        lock.unlock()
    }

    private static func thumbnail(_ image: UIImage) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > maxThumbnailPixel else { return image }
        let ratio = maxThumbnailPixel / longest
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func deleteSync(fileName: String) {
        guard let url = fileURL(for: fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func fileURL(for fileName: String?) -> URL? {
        guard let fileName, !fileName.isEmpty else { return nil }
        let safe = (fileName as NSString).lastPathComponent
        guard safe == fileName, safe.hasSuffix(".jpg") || safe.hasSuffix(".jpeg") else { return nil }
        return documentsDirectory.appendingPathComponent(safe)
    }
}
