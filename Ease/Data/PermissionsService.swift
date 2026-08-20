import HealthKit
import Photos
import UserNotifications

enum PermissionsService {
    static func requestHealthKitRead() async {
        guard let store = HealthKitStore.shared else { return }
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

    static func requestPhotoLibrary() async {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .notDetermined else { return }
        _ = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }
}
