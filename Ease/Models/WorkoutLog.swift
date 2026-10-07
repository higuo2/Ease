import Foundation
import SwiftData

@Model
final class WorkoutLog {
    /// CloudKit requires defaults so remote records can materialize without `init`.
    var id: UUID = UUID()
    var timestamp: Date = Date.now
    var kcal: Double = 0
    var durationMinutes: Int?
    var updatedAt: Date = Date.now

    init(timestamp: Date, kcal: Double, durationMinutes: Int? = nil) {
        self.id = UUID()
        self.timestamp = timestamp
        self.kcal = kcal
        self.durationMinutes = durationMinutes
        self.updatedAt = .now
    }
}
