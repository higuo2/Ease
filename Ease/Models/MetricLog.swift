import Foundation
import SwiftData

@Model
final class MetricLog {
    var id: UUID = UUID()
    var timestamp: Date = Date.now
    var metricKey: String = ""
    var value: Double = 0
    var updatedAt: Date = Date.now

    init(timestamp: Date, metricKey: String, value: Double) {
        self.id = UUID()
        self.timestamp = timestamp
        self.metricKey = metricKey
        self.value = value
        self.updatedAt = .now
    }
}
