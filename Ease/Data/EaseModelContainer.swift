import Foundation
import SwiftData

enum EaseModelContainer {
    static let models: [any PersistentModel.Type] = [
        DailyRecord.self,
        UserProfile.self,
        WeightLog.self,
        MetricDefinition.self,
        MetricLog.self
    ]

    static func make() -> ModelContainer {
        let schema = Schema(models)
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
        let schema = Schema(models)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }
}
