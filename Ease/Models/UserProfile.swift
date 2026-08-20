import Foundation
import SwiftData

@Model
final class UserProfile {
    var heightCm: Double = 0
    var startWeight: Double = 0
    var targetWeight: Double = 0
    var notificationsEnabled: Bool = false
    var hasCompletedOnboarding: Bool = false
    var hasMigratedWeightLogs: Bool = false
    var sleepTargetHours: Double = 8.0
    /// Device-local wall clock hour. Not a time zone.
    var weightReminderHour: Int = 8
    var weightReminderMinute: Int = 0
    var dietReminderHour: Int = 22
    var dietReminderMinute: Int = 30
    var updatedAt: Date = Date.now

    init() {
        self.heightCm = 0
        self.startWeight = 0
        self.targetWeight = 0
        self.notificationsEnabled = false
        self.hasCompletedOnboarding = false
        self.hasMigratedWeightLogs = false
        self.sleepTargetHours = 8.0
        self.weightReminderHour = 8
        self.weightReminderMinute = 0
        self.dietReminderHour = 22
        self.dietReminderMinute = 30
        self.updatedAt = .now
    }
}
