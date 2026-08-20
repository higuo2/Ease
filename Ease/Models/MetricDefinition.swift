import Foundation
import SwiftData

enum MetricKind: String, Codable, Sendable {
    case builtin
    case custom
}

enum MetricUnit: String, Codable, CaseIterable, Sendable {
    case cm
    case ml
    case count

    var titleKey: String {
        "unit.\(rawValue)"
    }
}

@Model
final class MetricDefinition {
    var key: String = ""
    var kindRaw: String = MetricKind.builtin.rawValue
    var unitRaw: String = MetricUnit.cm.rawValue
    var symbolName: String = "ruler"
    var isEnabled: Bool = false
    var sortOrder: Int = 0
    /// User-entered name for custom metrics. Unused for builtins.
    var displayName: String = ""
    var updatedAt: Date = Date.now

    var kind: MetricKind {
        get { MetricKind(rawValue: kindRaw) ?? .builtin }
        set { kindRaw = newValue.rawValue }
    }

    var unit: MetricUnit {
        get { MetricUnit(rawValue: unitRaw) ?? .cm }
        set { unitRaw = newValue.rawValue }
    }

    init(
        key: String,
        kind: MetricKind,
        unit: MetricUnit,
        symbolName: String,
        isEnabled: Bool = false,
        sortOrder: Int,
        displayName: String = ""
    ) {
        self.key = key
        self.kindRaw = kind.rawValue
        self.unitRaw = unit.rawValue
        self.symbolName = symbolName
        self.isEnabled = isEnabled
        self.sortOrder = sortOrder
        self.displayName = displayName
        self.updatedAt = .now
    }
}
