import HealthKit
import UserNotifications

enum PermissionsService {
    static func requestHealthKitRead() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let store = HKHealthStore()
        var read: Set<HKObjectType> = []
        if let energy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            read.insert(energy)
        }
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            read.insert(sleep)
        }
        if let flow = HKCategoryType.categoryType(forIdentifier: .menstrualFlow) {
            read.insert(flow)
        }
        guard !read.isEmpty else { return }
        _ = try? await store.requestAuthorization(toShare: Set<HKSampleType>(), read: read)
    }

    static func requestNotifications() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }
}
