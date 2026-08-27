import Foundation
import Observation

/// Display preference for meal-photo cutouts. Not synced — SwiftData/CloudKit stay filename-only.
@MainActor
@Observable
final class MealCutoutPreferences {
    static let shared = MealCutoutPreferences()

    private enum Keys {
        static let auto = "ease.isAutoCutoutEnabled"
        static let overrides = "ease.mealCutoutOverrides"
    }

    private let defaults: UserDefaults

    var isAutoCutoutEnabled: Bool {
        didSet { defaults.set(isAutoCutoutEnabled, forKey: Keys.auto) }
    }

    private(set) var overrides: [String: Bool]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Keys.auto) == nil {
            self.isAutoCutoutEnabled = true
        } else {
            self.isAutoCutoutEnabled = defaults.bool(forKey: Keys.auto)
        }
        self.overrides = Self.loadOverrides(from: defaults)
    }

    func isCutoutActive(for fileName: String?) -> Bool {
        guard let fileName, !fileName.isEmpty else { return false }
        if let override = overrides[fileName] {
            return override
        }
        return isAutoCutoutEnabled
    }

    func toggle(fileName: String) {
        guard !fileName.isEmpty else { return }
        var next = overrides
        next[fileName] = !isCutoutActive(for: fileName)
        overrides = next
        persistOverrides()
    }

    func removeOverride(for fileName: String?) {
        guard let fileName else { return }
        var next = overrides
        guard next.removeValue(forKey: fileName) != nil else { return }
        overrides = next
        persistOverrides()
    }

    func reset() {
        isAutoCutoutEnabled = true
        overrides = [:]
        persistOverrides()
    }

    private func persistOverrides() {
        defaults.set(overrides, forKey: Keys.overrides)
    }

    private static func loadOverrides(from defaults: UserDefaults) -> [String: Bool] {
        let raw = defaults.dictionary(forKey: Keys.overrides) ?? [:]
        return raw.reduce(into: [:]) { result, pair in
            if let value = pair.value as? Bool {
                result[pair.key] = value
            } else if let number = pair.value as? NSNumber {
                result[pair.key] = number.boolValue
            }
        }
    }
}
