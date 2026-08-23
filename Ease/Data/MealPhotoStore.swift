import Foundation
import UIKit

enum MealPhotoStore {
    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    /// Writes JPEG into the app Documents sandbox. Returns the filename only (not a full path).
    static func saveJPEG(_ image: UIImage, compressionQuality: CGFloat = 0.8) throws -> String {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw CocoaError(.fileWriteUnknown)
        }
        let fileName = UUID().uuidString + ".jpg"
        let url = documentsDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return fileName
    }

    static func loadImage(fileName: String?) -> UIImage? {
        guard let url = fileURL(for: fileName) else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func delete(fileName: String?) {
        guard let url = fileURL(for: fileName) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func deleteAll(in record: DailyRecord) {
        delete(fileName: record.breakfastPhotoFileName)
        delete(fileName: record.lunchPhotoFileName)
        delete(fileName: record.dinnerPhotoFileName)
    }

    private static func fileURL(for fileName: String?) -> URL? {
        guard let fileName, !fileName.isEmpty else { return nil }
        let safe = (fileName as NSString).lastPathComponent
        guard safe == fileName, safe.hasSuffix(".jpg") || safe.hasSuffix(".jpeg") else { return nil }
        return documentsDirectory.appendingPathComponent(safe)
    }
}
