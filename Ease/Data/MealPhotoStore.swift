import Foundation
import UIKit

enum MealPhotoStore {
    private static let maxThumbnailPixel: CGFloat = 512
    private static let cutoutSuffix = "-cutout.png"
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

    static func cutoutFileName(for original: String?) -> String? {
        guard let original, isAllowedJPEG(original) else { return nil }
        let stem = (original as NSString).deletingPathExtension
        guard !stem.isEmpty else { return nil }
        return stem + cutoutSuffix
    }

    static func saveCutout(_ image: UIImage, forOriginal original: String) async throws -> String {
        guard let fileName = cutoutFileName(for: original) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try await Task.detached(priority: .userInitiated) {
            guard let data = image.pngData() else {
                throw CocoaError(.fileWriteUnknown)
            }
            guard let url = fileURL(for: fileName) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try data.write(to: url, options: .atomic)
        }.value
        storeCached(thumbnail(image, preservesAlpha: true), fileName: fileName)
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
        let preserveAlpha = isAllowedCutoutPNG(fileName)
        let loaded = await Task.detached(priority: .utility) { () -> UIImage? in
            guard let url = fileURL(for: fileName) else { return nil }
            guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
                return nil
            }
            return thumbnail(image, preservesAlpha: preserveAlpha)
        }.value
        if let loaded {
            storeCached(loaded, fileName: fileName)
        }
        return loaded
    }

    /// Loads a cached cutout PNG, or generates one from the original JPEG thumbnail.
    static func cutoutImage(forOriginal fileName: String?) async -> UIImage? {
        guard let fileName, let cutoutName = cutoutFileName(for: fileName) else { return nil }
        if let hit = peek(cutoutName) { return hit }
        if let disk = await loadImage(fileName: cutoutName) { return disk }
        guard let source = await loadImage(fileName: fileName) else { return nil }
        do {
            let cut = try await ImageCutoutService.shared.cutout(from: source)
            _ = try? await saveCutout(cut, forOriginal: fileName)
            return cut
        } catch {
            return nil
        }
    }

    /// Full-resolution JPEG from Documents. Not stored in the thumbnail cache.
    static func loadOriginal(fileName: String?) async -> UIImage? {
        guard let fileName, !fileName.isEmpty else { return nil }
        return await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let url = fileURL(for: fileName) else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
    }

    /// Fire-and-forget sandbox cleanup — never block the main actor.
    static func deleteAsync(fileName: String?) {
        deleteAsync(fileNames: [fileName])
    }

    static func deleteAsync(fileNames: [String?]) {
        var names: [String] = []
        var originals: [String] = []
        for raw in fileNames.compactMap({ $0 }).filter({ !$0.isEmpty }) {
            names.append(raw)
            originals.append(raw)
            if let cutout = cutoutFileName(for: raw) {
                names.append(cutout)
            }
        }
        let unique = Array(Set(names))
        guard !unique.isEmpty else { return }
        for name in unique { removeCached(name) }
        Task.detached(priority: .utility) {
            for name in unique {
                deleteSync(fileName: name)
            }
        }
        Task { @MainActor in
            for name in originals {
                MealCutoutPreferences.shared.removeOverride(for: name)
            }
        }
    }

    static func deleteAllAsync(in record: DailyRecord) {
        deleteAsync(fileNames: record.allMealFileNames)
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

    private static func thumbnail(_ image: UIImage, preservesAlpha: Bool = false) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let longest = max(pixelWidth, pixelHeight)
        guard longest > maxThumbnailPixel else { return image }
        let ratio = maxThumbnailPixel / longest
        let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = !preservesAlpha
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func deleteSync(fileName: String) {
        guard let url = fileURL(for: fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private static func isAllowedJPEG(_ fileName: String) -> Bool {
        let safe = (fileName as NSString).lastPathComponent
        return safe == fileName && (safe.hasSuffix(".jpg") || safe.hasSuffix(".jpeg"))
    }

    private static func isAllowedCutoutPNG(_ fileName: String) -> Bool {
        let safe = (fileName as NSString).lastPathComponent
        return safe == fileName && safe.hasSuffix(cutoutSuffix) && safe.count > cutoutSuffix.count
    }

    private static func fileURL(for fileName: String?) -> URL? {
        guard let fileName, !fileName.isEmpty else { return nil }
        guard isAllowedJPEG(fileName) || isAllowedCutoutPNG(fileName) else { return nil }
        return documentsDirectory.appendingPathComponent(fileName)
    }
}
