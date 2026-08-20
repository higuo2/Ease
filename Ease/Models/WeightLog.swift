import Foundation
import SwiftData

@Model
final class WeightLog {
    /// CloudKit requires defaults so remote records can materialize without `init`.
    var id: UUID = UUID()
    var timestamp: Date = Date.now
    var weight: Double = 0
    var bodyFat: Double?
    var updatedAt: Date = Date.now

    init(timestamp: Date, weight: Double, bodyFat: Double? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.weight = weight
        self.bodyFat = bodyFat
        self.updatedAt = .now
    }
}
