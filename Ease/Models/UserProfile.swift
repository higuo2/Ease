import Foundation
import SwiftData

@Model
final class UserProfile {
    var heightCm: Double = 0
    var startWeight: Double = 0
    var targetWeight: Double = 0
    var notificationsEnabled: Bool = false
    var hasCompletedOnboarding: Bool = false
    var updatedAt: Date = Date.now

    init() {
        self.updatedAt = .now
    }
}
