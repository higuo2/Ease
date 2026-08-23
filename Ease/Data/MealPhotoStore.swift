import Foundation
import UIKit

enum MealPhotoStore {
    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// Writes JPEG into the app Documents sandbox on a background queue.
    /// Returns the filename only (not a full path).
    static func saveJPEG(
        _ image: UIImage,
        compressionQuality: CGFloat = 0.8
    ) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            guard let data = image.jpegData(compressionQuality: compressionQuality) else {
                throw CocoaError(.fileWriteUnknown)
            }
            let fileName = UUID().uuidString + ".jpg"
            let url = documentsDirectory.appendingPathComponent(fileName)
            try data.write(to: url, options: .atomic)
            return fileName
        }.value
    }

    static func loadImage(fileName: String?) async -> UIImage? {
        await Task.detached(priority: .utility) {
            guard let url = fileURL(for: fileName) else { return nil }
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)
        }.value
    }

    /// Fire-and-forget sandbox cleanup — never block the main actor.
    static func deleteAsync(fileName: String?) {
        guard let fileName, !fileName.isEmpty else { return }
        Task.detached(priority: .utility) {
            deleteSync(fileName: fileName)
        }
    }

    static func deleteAsync(fileNames: [String?]) {
        let names = fileNames.compactMap { $0 }.filter { !$0.isEmpty }
        guard !names.isEmpty else { return }
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
