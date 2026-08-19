import Foundation
import SwiftData

enum EaseModelContainer {
    static func make() -> ModelContainer {
        let schema = Schema([DailyRecord.self, UserProfile.self])
        let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        if let container = try? ModelContainer(schema: schema, configurations: [cloud]) {
            return container
        }
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(schema: schema, configurations: [local])
        } catch {
            fatalError("Failed to create Ease ModelContainer: \(error)")
        }
    }

    static func preview() -> ModelContainer {
        let schema = Schema([DailyRecord.self, UserProfile.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(schema: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }
}
