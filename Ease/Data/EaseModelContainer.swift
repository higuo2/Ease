import Foundation
import SwiftData

enum EaseModelContainer {
    static func make() -> ModelContainer {
        let schema = Schema([DailyRecord.self, UserProfile.self, WeightLog.self])
        let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
        if let container = try? ModelContainer(for: schema, configurations: [cloud]) {
            return container
        }
        
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [local])
        } catch {
            fatalError("Failed to create Ease ModelContainer: \(error)")
        }
    }
    
    static func preview() -> ModelContainer {
        let schema = Schema([DailyRecord.self, UserProfile.self, WeightLog.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }
}
