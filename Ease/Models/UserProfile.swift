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
        self.heightCm = 0
        self.startWeight = 0
        self.targetWeight = 0
        self.notificationsEnabled = false
        self.hasCompletedOnboarding = false
        self.updatedAt = .now
    }
}
