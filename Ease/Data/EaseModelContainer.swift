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

        // Prefer CloudKit; fall back to local if the cloud config cannot open.
        if let container = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)]
        ) {
            return container
        }

        let localConfig = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        if let container = try? ModelContainer(for: schema, configurations: [localConfig]) {
            return container
        }

        // Schema / store mismatch (e.g. removed attributes) can fail lightweight
        // migration and crash at launch via fatalError. Recover by wiping the local
        // store once, then recreating — CloudKit may re-sync afterward.
        NSLog("Ease: ModelContainer open failed; attempting local store reset")
        resetLocalStoreFiles(for: localConfig)
        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            let message = "Failed to create Ease ModelContainer after reset: \(error)"
            NSLog("%@", message)
            fatalError(message)
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

    private static func resetLocalStoreFiles(for configuration: ModelConfiguration) {
        let urls = [
            configuration.url,
            configuration.url.deletingPathExtension().appendingPathExtension("store"),
            configuration.url.appendingPathExtension("shm"),
            configuration.url.appendingPathExtension("wal"),
            configuration.url.deletingLastPathComponent()
                .appendingPathComponent(configuration.url.deletingPathExtension().lastPathComponent + ".store-shm"),
            configuration.url.deletingLastPathComponent()
                .appendingPathComponent(configuration.url.deletingPathExtension().lastPathComponent + ".store-wal")
        ]
        let unique = Array(Set(urls))
        for url in unique {
            try? FileManager.default.removeItem(at: url)
        }
        // Also clear default Application Support SwiftData folder entries if present.
        if let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let candidates = (try? FileManager.default.contentsOfDirectory(
                at: support,
                includingPropertiesForKeys: nil
            )) ?? []
            for url in candidates where url.pathExtension == "store"
                || url.lastPathComponent.contains("default.store")
                || url.pathExtension == "sqlite" {
                try? FileManager.default.removeItem(at: url)
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
            }
        }
    }
}
