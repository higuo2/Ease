import Foundation
import SwiftData

@MainActor
struct UserProfileRepository {
    let context: ModelContext
    let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    func profile() throws -> UserProfile {
        try deduplicate()
        if let existing = try fetchAll().first {
            return existing
        }
        let created = UserProfile()
        context.insert(created)
        try context.save()
        return created
    }

    func update(
        heightCm: Double? = nil,
        startWeight: Double? = nil,
        targetWeight: Double? = nil,
        notificationsEnabled: Bool? = nil
    ) throws -> UserProfile {
        let profile = try profile()
        let nextHeight = try heightCm.map(MeasurementBounds.validatedHeight) ?? profile.heightCm
        let nextStart = try startWeight.map(MeasurementBounds.validatedWeight) ?? profile.startWeight
        let nextTarget = try targetWeight.map(MeasurementBounds.validatedWeight) ?? profile.targetWeight
        let nextNotifications = notificationsEnabled ?? profile.notificationsEnabled
        let shouldValidate = profile.hasCompletedOnboarding
            || heightCm != nil
            || startWeight != nil
            || targetWeight != nil
        if shouldValidate {
            try validate(heightCm: nextHeight, startWeight: nextStart, targetWeight: nextTarget)
        }

        profile.heightCm = nextHeight
        profile.startWeight = nextStart
        profile.targetWeight = nextTarget
        profile.notificationsEnabled = nextNotifications
        profile.updatedAt = .now
        try context.save()
        return profile
    }

    @discardableResult
    func completeOnboarding(heightCm: Double, currentWeight: Double, targetWeight: Double) throws -> UserProfile {
        let height = try MeasurementBounds.validatedHeight(heightCm)
        let weight = try MeasurementBounds.validatedWeight(currentWeight)
        let target = try MeasurementBounds.validatedWeight(targetWeight)

        let records = DailyRecordRepository(context: context, calendar: calendar)
        try records.upsert(on: .now, patch: DailyRecordPatch(weight: .set(weight)))

        let profile = try profile()
        profile.heightCm = height
        profile.startWeight = weight
        profile.targetWeight = target
        profile.hasCompletedOnboarding = true
        profile.updatedAt = .now
        try context.save()
        return profile
    }

    func resetAll() throws {
        try DailyRecordRepository(context: context, calendar: calendar).deleteAll()
        for profile in try fetchAll() {
            context.delete(profile)
        }
        try context.save()
    }

    private func validate(heightCm: Double, startWeight: Double, targetWeight: Double) throws {
        guard heightCm > 0, startWeight > 0, targetWeight > 0 else {
            throw EaseDataError.invalidProfile
        }
        _ = try MeasurementBounds.validatedHeight(heightCm)
        _ = try MeasurementBounds.validatedWeight(startWeight)
        _ = try MeasurementBounds.validatedWeight(targetWeight)
    }

    private func fetchAll() throws -> [UserProfile] {
        try context.fetch(
            FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)])
        )
    }

    @discardableResult
    private func deduplicate() throws -> UserProfile? {
        let profiles = try fetchAll()
        guard let keeper = profiles.first else { return nil }
        for duplicate in profiles.dropFirst() {
            context.delete(duplicate)
        }
        if profiles.count > 1 {
            try context.save()
        }
        return keeper
    }
}
