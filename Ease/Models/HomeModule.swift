import SwiftUI

enum HomeModule: String, CaseIterable, Identifiable, Sendable, Equatable {
    case bmi
    case measurements
    case weight
    case diet
    case sleep
    case period
    case energy

    var id: String { rawValue }

    static let defaults: [HomeModule] = [.bmi, .measurements, .weight]

    /// Modules the user can still turn on. `diet` stays in the enum for stored raw strings.
    static var selectable: [HomeModule] {
        allCases.filter { $0 != .diet }
    }

    var titleKey: String {
        switch self {
        case .bmi: "grid.bmi"
        case .measurements: "dashboard.metrics"
        case .weight: "module.weight"
        case .diet: "module.diet"
        case .sleep: "health.sleep"
        case .period: "health.period"
        case .energy: "health.energy"
        }
    }

    var symbolName: String {
        switch self {
        case .bmi: "heart.text.clipboard"
        case .measurements: "ruler"
        case .weight: "scalemass"
        case .diet: "fork.knife"
        case .sleep: "moon.fill"
        case .period: "drop.fill"
        case .energy: "bolt.fill"
        }
    }

    var settingsIconTint: Color {
        switch self {
        case .sleep: EasePalette.iconSleep
        case .period: EasePalette.iconPeriod
        case .energy: EasePalette.iconEnergy
        default: EasePalette.primaryText
        }
    }

    var fill: Color {
        switch self {
        case .bmi: EasePalette.morandiMist
        case .measurements: EasePalette.morandiBlush
        case .weight: EasePalette.morandiSage
        case .diet: EasePalette.morandiSand
        case .sleep: EasePalette.morandiSleep
        case .period: EasePalette.morandiPeriod
        case .energy: EasePalette.morandiEnergy
        }
    }

    static func decode(_ raw: String) -> [HomeModule] {
        let tokens = raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var seen = Set<HomeModule>()
        let parsed: [HomeModule] = tokens.compactMap { token in
            guard let module = HomeModule(rawValue: token), module != .diet, seen.insert(module).inserted else { return nil }
            return module
        }
        return parsed.isEmpty ? defaults : parsed
    }

    static func encode(_ modules: [HomeModule]) -> String {
        var seen = Set<HomeModule>()
        return modules
            .filter { $0 != .diet && seen.insert($0).inserted }
            .map(\.rawValue)
            .joined(separator: ",")
    }
}
