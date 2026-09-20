import Foundation

struct MetricSpec: Sendable, Equatable {
    var key: String
    var kind: MetricKind
    var unit: MetricUnit
    var step: Double
    var range: ClosedRange<Double>
    var symbolName: String
    var titleKey: String?
    var displayName: String
    var sortOrder: Int

    var resolvedTitle: String {
        if kind == .custom {
            return displayName
        }
        if let titleKey {
            return String(localized: String.LocalizationValue(titleKey))
        }
        return key
    }
}

enum MetricInputCategory: String, CaseIterable, Identifiable, Sendable {
    case core
    case limbs
    case other

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .core: "metric.category.core"
        case .limbs: "metric.category.limbs"
        case .other: "metric.category.other"
        }
    }

    private static let coreKeys: Set<String> = [
        "waist", "highWaist", "navel", "hip", "chest", "underbust"
    ]
    private static let limbKeys: Set<String> = [
        "thigh", "leftArm", "rightArm", "leftThigh", "rightThigh", "leftCalf", "rightCalf"
    ]

    static func category(for key: String, kind: MetricKind) -> MetricInputCategory {
        if kind == .custom { return .other }
        if coreKeys.contains(key) { return .core }
        if limbKeys.contains(key) { return .limbs }
        return .other
    }

    func matches(key: String, kind: MetricKind) -> Bool {
        Self.category(for: key, kind: kind) == self
    }

    /// Top-to-bottom anatomical order within each sheet category.
    var anatomicalSortKeys: [String] {
        switch self {
        case .core:
            return ["chest", "underbust", "highWaist", "navel", "waist", "hip"]
        case .limbs:
            return ["leftArm", "rightArm", "leftThigh", "thigh", "leftCalf", "rightCalf"]
        case .other:
            return ["head", "shoulderWidth", "shoulder", "wrist"]
        }
    }

    private static let globalAnatomicalOrder: [String] = MetricInputCategory.allCases.flatMap(\.anatomicalSortKeys)

    func sort(_ definitions: [MetricDefinition]) -> [MetricDefinition] {
        let order = anatomicalSortKeys
        return definitions.sorted { lhs, rhs in
            Self.compare(lhs, rhs, order: order)
        }
    }

    static func anatomicalSort(_ definitions: [MetricDefinition]) -> [MetricDefinition] {
        definitions.sorted { lhs, rhs in
            compare(lhs, rhs, order: globalAnatomicalOrder)
        }
    }

    private static func compare(
        _ lhs: MetricDefinition,
        _ rhs: MetricDefinition,
        order: [String]
    ) -> Bool {
        let leftIndex = order.firstIndex(of: lhs.key)
        let rightIndex = order.firstIndex(of: rhs.key)
        switch (leftIndex, rightIndex) {
        case let (left?, right?):
            if left != right { return left < right }
        case (nil, nil):
            break
        case (nil, _?):
            return false
        case (_?, nil):
            return true
        }
        if lhs.kind == .custom && rhs.kind == .custom {
            return lhs.displayName.localizedCompare(rhs.displayName) == .orderedAscending
        }
        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.key < rhs.key
    }
}

enum MetricCatalog {
    static let maxCustom = 8

    static let allowedSymbols = [
        "ruler",
        "drop",
        "figure.stand",
        "figure.cooldown",
        "figure.arms.open",
        "figure.walk",
        "hand.raised.fill",
        "cup.and.saucer",
        "dumbbell",
        "heart",
        "waveform.path.ecg",
        "circle",
        "arrow.left.and.right",
        "tshirt",
        "person.crop.circle"
    ]

    static let builtins: [MetricSpec] = [
        cm("waist", title: "metric.waist", symbol: "ruler", range: 40...200, order: 0),
        cm("hip", title: "metric.hip", symbol: "figure.stand", range: 40...200, order: 1),
        cm("chest", title: "metric.chest", symbol: "figure.cooldown", range: 40...200, order: 2),
        cm("thigh", title: "metric.thigh", symbol: "figure.walk", range: 20...120, order: 3),
        cm("underbust", title: "metric.underbust", symbol: "figure.cooldown", range: 40...200, order: 4),
        cm("highWaist", title: "metric.highWaist", symbol: "ruler", range: 40...200, order: 5),
        cm("navel", title: "metric.navel", symbol: "ruler", range: 40...200, order: 6),
        cm("leftArm", title: "metric.leftArm", symbol: "figure.arms.open", range: 15...60, order: 7),
        cm("rightArm", title: "metric.rightArm", symbol: "figure.arms.open", range: 15...60, order: 8),
        cm("leftThigh", title: "metric.leftThigh", symbol: "figure.walk", range: 20...120, order: 9),
        cm("leftCalf", title: "metric.leftCalf", symbol: "figure.walk", range: 20...60, order: 10),
        cm("rightCalf", title: "metric.rightCalf", symbol: "figure.walk", range: 20...60, order: 11),
        cm("shoulderWidth", title: "metric.shoulderWidth", symbol: "arrow.left.and.right", range: 20...80, order: 12),
        cm("shoulder", title: "metric.shoulder", symbol: "tshirt", range: 50...160, order: 13),
        cm("wrist", title: "metric.wrist", symbol: "hand.raised.fill", range: 10...30, order: 14),
        cm("head", title: "metric.head", symbol: "person.crop.circle", range: 40...70, order: 15)
    ]

    /// Retired builtins stay out of home / settings / seed (legacy rows may remain in store).
    static let retiredBuiltinKeys: Set<String> = ["water"]

    static func isActiveMetricKey(_ key: String) -> Bool {
        !retiredBuiltinKeys.contains(key)
    }

    private static func cm(
        _ key: String,
        title: String,
        symbol: String = "ruler",
        range: ClosedRange<Double>,
        order: Int
    ) -> MetricSpec {
        MetricSpec(
            key: key,
            kind: .builtin,
            unit: .cm,
            step: 0.1,
            range: range,
            symbolName: allowedSymbols.contains(symbol) ? symbol : "ruler",
            titleKey: title,
            displayName: "",
            sortOrder: order
        )
    }

    static var builtinKeys: Set<String> {
        Set(builtins.map(\.key))
    }

    static func builtin(for key: String) -> MetricSpec? {
        builtins.first { $0.key == key }
    }

    static func spec(for definition: MetricDefinition) -> MetricSpec {
        if let builtin = builtin(for: definition.key), definition.kind == .builtin {
            return builtin
        }
        return MetricSpec(
            key: definition.key,
            kind: definition.kind,
            unit: definition.unit,
            step: step(for: definition.unit),
            range: range(for: definition.unit),
            symbolName: allowedSymbols.contains(definition.symbolName) ? definition.symbolName : "circle",
            titleKey: nil,
            displayName: definition.displayName,
            sortOrder: definition.sortOrder
        )
    }

    static func specs(for definitions: [MetricDefinition]) -> [String: MetricSpec] {
        Dictionary(
            definitions.map { ($0.key, spec(for: $0)) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    static func step(for unit: MetricUnit) -> Double {
        switch unit {
        case .cm: 0.1
        case .ml: 50
        case .count: 1
        }
    }

    static func range(for unit: MetricUnit) -> ClosedRange<Double> {
        switch unit {
        case .cm: 0...300
        case .ml: 0...6000
        case .count: 0...10_000
        }
    }

    static func rounded(_ value: Double, spec: MetricSpec) -> Double {
        MeasurementBounds.roundedToStep(value, step: spec.step)
    }

    static func validated(_ value: Double, spec: MetricSpec) throws -> Double {
        let rounded = rounded(value, spec: spec)
        guard spec.range.contains(rounded) else { throw EaseDataError.invalidMetric }
        return rounded
    }

    static func formattedValue(_ value: Double, spec: MetricSpec) -> String {
        let rounded = rounded(value, spec: spec)
        if spec.step >= 1 {
            return String(format: "%.0f", locale: .current, rounded)
        }
        return String(format: "%.1f", locale: .current, rounded)
    }

    static func formattedReading(_ value: Double, spec: MetricSpec) -> String {
        let number = formattedValue(value, spec: spec)
        let unit = String(localized: String.LocalizationValue(spec.unit.titleKey))
        return "\(spec.resolvedTitle) \(number) \(unit)"
    }

    /// Signed delta with unit, e.g. `-2.0 cm` / `+1.5 cm`.
    static func formattedDelta(_ value: Double, spec: MetricSpec) -> String {
        let sign = value > 0 ? "+" : ""
        let number = "\(sign)\(formattedValue(value, spec: spec))"
        let unit = String(localized: String.LocalizationValue(spec.unit.titleKey))
        return "\(number) \(unit)"
    }

    static func csvValue(_ value: Double, spec: MetricSpec) -> String {
        let rounded = rounded(value, spec: spec)
        if spec.step >= 1 {
            return String(format: "%.0f", locale: Locale(identifier: "en_US_POSIX"), rounded)
        }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), rounded)
    }

    static func isAllowedSymbol(_ name: String) -> Bool {
        allowedSymbols.contains(name)
    }
}
