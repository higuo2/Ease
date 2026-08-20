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

enum MetricCatalog {
    static let maxCustom = 8

    static let allowedSymbols = [
        "ruler",
        "drop",
        "figure.stand",
        "cup.and.saucer",
        "dumbbell",
        "heart",
        "waveform.path.ecg",
        "circle"
    ]

    static let builtins: [MetricSpec] = [
        cm("waist", title: "metric.waist", range: 40...200, order: 0),
        cm("hip", title: "metric.hip", range: 40...200, order: 1),
        cm("chest", title: "metric.chest", range: 40...200, order: 2),
        cm("thigh", title: "metric.thigh", range: 20...120, order: 3),
        MetricSpec(
            key: "water",
            kind: .builtin,
            unit: .ml,
            step: 50,
            range: 0...6000,
            symbolName: "drop",
            titleKey: "metric.water",
            displayName: "",
            sortOrder: 4
        ),
        cm("underbust", title: "metric.underbust", range: 40...200, order: 5),
        cm("highWaist", title: "metric.highWaist", range: 40...200, order: 6),
        cm("navel", title: "metric.navel", range: 40...200, order: 7),
        cm("leftArm", title: "metric.leftArm", range: 15...60, order: 8),
        cm("rightArm", title: "metric.rightArm", range: 15...60, order: 9),
        cm("leftThigh", title: "metric.leftThigh", range: 20...120, order: 10),
        cm("leftCalf", title: "metric.leftCalf", range: 20...60, order: 11),
        cm("rightCalf", title: "metric.rightCalf", range: 20...60, order: 12),
        cm("shoulderWidth", title: "metric.shoulderWidth", range: 20...80, order: 13),
        cm("shoulder", title: "metric.shoulder", range: 50...160, order: 14),
        cm("wrist", title: "metric.wrist", range: 10...30, order: 15),
        cm("head", title: "metric.head", range: 40...70, order: 16)
    ]

    private static func cm(
        _ key: String,
        title: String,
        range: ClosedRange<Double>,
        order: Int
    ) -> MetricSpec {
        MetricSpec(
            key: key,
            kind: .builtin,
            unit: .cm,
            step: 0.1,
            range: range,
            symbolName: "ruler",
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
