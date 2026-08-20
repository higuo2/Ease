import Foundation
import SwiftData

@MainActor
struct MetricRepository {
    let context: ModelContext
    let calendar: Calendar

    init(context: ModelContext, calendar: Calendar = .current) {
        self.context = context
        self.calendar = calendar
    }

    @discardableResult
    func seedBuiltinsIfNeeded() throws -> [MetricDefinition] {
        let existing = try allDefinitions()
        let existingKeys = Set(existing.map(\.key))
        var inserted = false
        for spec in MetricCatalog.builtins where !existingKeys.contains(spec.key) {
            context.insert(
                MetricDefinition(
                    key: spec.key,
                    kind: .builtin,
                    unit: spec.unit,
                    symbolName: spec.symbolName,
                    isEnabled: false,
                    sortOrder: spec.sortOrder
                )
            )
            inserted = true
        }
        if inserted {
            try context.save()
        }
        return try allDefinitions()
    }

    func allDefinitions() throws -> [MetricDefinition] {
        let descriptor = FetchDescriptor<MetricDefinition>(
            sortBy: [SortDescriptor(\.sortOrder, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    func enabledDefinitions() throws -> [MetricDefinition] {
        try allDefinitions().filter(\.isEnabled)
    }

    func definition(key: String) throws -> MetricDefinition? {
        let target = key
        let descriptor = FetchDescriptor<MetricDefinition>(
            predicate: #Predicate { $0.key == target }
        )
        return try context.fetch(descriptor).first
    }

    func knownKeys() throws -> Set<String> {
        MetricCatalog.builtinKeys.union(Set(try allDefinitions().map(\.key)))
    }

    func setEnabled(_ definition: MetricDefinition, isEnabled: Bool) throws {
        definition.isEnabled = isEnabled
        definition.updatedAt = .now
        try context.save()
    }

    @discardableResult
    func addCustom(name: String, unit: MetricUnit, symbolName: String) throws -> MetricDefinition {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EaseDataError.invalidMetric }
        guard MetricCatalog.isAllowedSymbol(symbolName) else { throw EaseDataError.invalidMetric }
        let customCount = try allDefinitions().filter { $0.kind == .custom }.count
        guard customCount < MetricCatalog.maxCustom else { throw EaseDataError.tooManyCustomMetrics }

        let nextOrder = (try allDefinitions().map(\.sortOrder).max() ?? 99) + 1
        let definition = MetricDefinition(
            key: "custom.\(UUID().uuidString.lowercased())",
            kind: .custom,
            unit: unit,
            symbolName: symbolName,
            isEnabled: true,
            sortOrder: nextOrder,
            displayName: trimmed
        )
        context.insert(definition)
        try context.save()
        return definition
    }

    @discardableResult
    func insertLog(timestamp: Date, metricKey: String, value: Double) throws -> MetricLog {
        let inserted = try insertLogs([
            MetricLogDraft(timestamp: timestamp, metricKey: metricKey, value: value)
        ])
        guard let log = inserted.first else { throw EaseDataError.invalidMetric }
        return log
    }

    /// Validates every draft first, then writes once. Empty input is a no-op.
    @discardableResult
    func insertLogs(_ drafts: [MetricLogDraft]) throws -> [MetricLog] {
        guard !drafts.isEmpty else { return [] }
        var prepared: [(Date, String, Double)] = []
        for draft in drafts {
            guard !CalendarDay.isFuture(draft.timestamp, calendar: calendar) else {
                throw EaseDataError.futureDate
            }
            let spec = try spec(forKey: draft.metricKey)
            let validated = try MetricCatalog.validated(draft.value, spec: spec)
            prepared.append((draft.timestamp, draft.metricKey, validated))
        }
        var logs: [MetricLog] = []
        for (timestamp, metricKey, value) in prepared {
            let log = MetricLog(timestamp: timestamp, metricKey: metricKey, value: value)
            context.insert(log)
            logs.append(log)
        }
        try context.save()
        return logs
    }

    func logs(on date: Date, metricKey: String? = nil) throws -> [MetricLog] {
        let start = CalendarDay.startOfDay(date, calendar: calendar)
        let end = CalendarDay.endOfDay(date, calendar: calendar)
        let descriptor = FetchDescriptor<MetricLog>(
            predicate: #Predicate { $0.timestamp >= start && $0.timestamp < end },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let fetched = try context.fetch(descriptor)
        guard let metricKey else { return fetched }
        return fetched.filter { $0.metricKey == metricKey }
    }

    func latest(on date: Date, metricKey: String) throws -> MetricLog? {
        try logs(on: date, metricKey: metricKey).last
    }

    func allLogs(metricKey: String? = nil) throws -> [MetricLog] {
        let descriptor = FetchDescriptor<MetricLog>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        let fetched = try context.fetch(descriptor)
        guard let metricKey else { return fetched }
        return fetched.filter { $0.metricKey == metricKey }
    }

    func delete(_ log: MetricLog) throws {
        context.delete(log)
        try context.save()
    }

    func deleteAll() throws {
        for log in try context.fetch(FetchDescriptor<MetricLog>()) {
            context.delete(log)
        }
        for definition in try context.fetch(FetchDescriptor<MetricDefinition>()) {
            context.delete(definition)
        }
        try context.save()
    }

    /// Readings-only. Dashboard gray entry uses `DashboardMetricsLine`, not this.
    func homeLine(on date: Date) throws -> String? {
        let enabled = try enabledDefinitions()
        var parts: [String] = []
        for definition in enabled {
            guard let log = try latest(on: date, metricKey: definition.key) else { continue }
            parts.append(MetricCatalog.formattedReading(log.value, spec: MetricCatalog.spec(for: definition)))
        }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "  ")
    }

    func spec(forKey key: String) throws -> MetricSpec {
        if let definition = try definition(key: key) {
            return MetricCatalog.spec(for: definition)
        }
        if let builtin = MetricCatalog.builtin(for: key) {
            return builtin
        }
        throw EaseDataError.invalidMetric
    }
}
