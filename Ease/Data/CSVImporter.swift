import Foundation
import SwiftData

enum CSVImporter {
    static let maxDataRows = 5000
    static let maxBytes = 2 * 1024 * 1024
    static let journalHeader = "date,time,weight,bodyFat,dietStatus,tags,note"
    static let legacyHeader = "date,weight,bodyFat,dietStatus,tags,note"
    static let metricsHeader = "date,time,metricKey,value"

    enum Failure: Error, Equatable {
        case unreadable
        case notUTF8
        case unrecognizedHeader
    }

    enum Kind: Equatable {
        case journal
        case metrics
    }

    struct PendingWeighIn: Equatable {
        var timestamp: Date
        var weight: Double
        var bodyFat: Double?
    }

    struct PendingJournal: Equatable {
        var day: Date
        var dietStatus: DietStatus?
        var tags: [VariableTag]?
        var note: String?
    }

    struct PendingMetric: Equatable {
        var timestamp: Date
        var metricKey: String
        var value: Double
    }

    struct Preview: Equatable {
        var kind: Kind
        var weighInCount: Int = 0
        var dietDayCount: Int = 0
        var metricLogCount: Int = 0
        var duplicateCount: Int = 0
        var invalidCount: Int = 0
        var isTruncated: Bool = false
        var pendingWeighIns: [PendingWeighIn] = []
        var pendingJournals: [PendingJournal] = []
        var pendingMetrics: [PendingMetric] = []
    }

    struct ApplyResult: Equatable {
        var weighInsWritten: Int = 0
        var dietDaysWritten: Int = 0
        var metricLogsWritten: Int = 0
    }

    static func preview(
        from data: Data,
        existingLogs: [WeightLog],
        existingRecords: [DailyRecord],
        existingMetricLogs: [MetricLog],
        metricSpecs: [String: MetricSpec],
        now: Date = .now,
        calendar: Calendar = .current
    ) throws -> Preview {
        let (text, truncatedBySize) = try decodeStreamingText(data)
        let rawLines = splitLines(text)
        guard let headerLine = rawLines.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw Failure.unrecognizedHeader
        }
        let header = headerLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let kind: Kind
        let isLegacy: Bool
        switch header {
        case journalHeader:
            kind = .journal
            isLegacy = false
        case legacyHeader:
            kind = .journal
            isLegacy = true
        case metricsHeader:
            kind = .metrics
            isLegacy = false
        default:
            throw Failure.unrecognizedHeader
        }

        let headerIndex = rawLines.firstIndex(of: headerLine) ?? 0
        let dataLines = Array(rawLines[(headerIndex + 1)...]).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let truncatedByRows = dataLines.count > maxDataRows
        let limited = Array(dataLines.prefix(maxDataRows))

        var preview = Preview(kind: kind, isTruncated: truncatedBySize || truncatedByRows)
        switch kind {
        case .journal:
            parseJournal(
                lines: limited,
                isLegacy: isLegacy,
                existingLogs: existingLogs,
                existingRecords: existingRecords,
                now: now,
                calendar: calendar,
                into: &preview
            )
        case .metrics:
            parseMetrics(
                lines: limited,
                existingMetricLogs: existingMetricLogs,
                metricSpecs: metricSpecs,
                now: now,
                calendar: calendar,
                into: &preview
            )
        }
        return preview
    }

    @MainActor
    static func apply(
        _ preview: Preview,
        context: ModelContext,
        calendar: Calendar = .current
    ) throws -> ApplyResult {
        switch preview.kind {
        case .journal:
            return try applyJournal(preview, context: context, calendar: calendar)
        case .metrics:
            return try applyMetrics(preview, context: context, calendar: calendar)
        }
    }

    // MARK: - Decode

    static func decodeStreamingText(_ data: Data) throws -> (String, Bool) {
        guard !data.isEmpty else { throw Failure.unreadable }
        let truncated = data.count > maxBytes
        let slice = truncated ? data.prefix(maxBytes) : data
        guard let text = utf8String(from: Data(slice)) else {
            throw Failure.notUTF8
        }
        return (text, truncated)
    }

    static func utf8String(from data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        var end = data.count
        while end > 0 {
            end -= 1
            if let text = String(data: data.prefix(end), encoding: .utf8) {
                return text
            }
        }
        return nil
    }

    static func splitLines(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    static func parseFields(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            if inQuotes {
                if character == "\"" {
                    let next = line.index(after: index)
                    if next < line.endIndex, line[next] == "\"" {
                        current.append("\"")
                        index = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    current.append(character)
                }
            } else if character == "\"" {
                inQuotes = true
            } else if character == "," {
                fields.append(current)
                current = ""
            } else {
                current.append(character)
            }
            index = line.index(after: index)
        }
        fields.append(current)
        return fields
    }

    // MARK: - Journal

    private static func parseJournal(
        lines: [String],
        isLegacy: Bool,
        existingLogs: [WeightLog],
        existingRecords: [DailyRecord],
        now: Date,
        calendar: Calendar,
        into preview: inout Preview
    ) {
        var seenWeighIns = weighInKeys(existingLogs, calendar: calendar)
        var journalsByDay: [String: PendingJournal] = [:]

        for line in lines {
            let fields = parseFields(line)
            let expected = isLegacy ? 6 : 7
            guard fields.count >= expected else {
                preview.invalidCount += 1
                continue
            }
            let dateText = fields[0].trimmingCharacters(in: .whitespaces)
            guard let day = CalendarDay.date(fromDayKey: dateText, calendar: calendar) else {
                preview.invalidCount += 1
                continue
            }
            if CalendarDay.isFuture(day, now: now, calendar: calendar) {
                preview.invalidCount += 1
                continue
            }

            let timeText: String
            let weightText: String
            let fatText: String
            let dietText: String
            let tagsText: String
            let noteText: String
            if isLegacy {
                timeText = "08:00"
                weightText = fields[1]
                fatText = fields[2]
                dietText = fields[3]
                tagsText = fields[4]
                noteText = fields[5]
            } else {
                timeText = fields[1].trimmingCharacters(in: .whitespaces)
                weightText = fields[2]
                fatText = fields[3]
                dietText = fields[4]
                tagsText = fields[5]
                noteText = fields[6]
            }

            let hasWeightCell = !weightText.trimmingCharacters(in: .whitespaces).isEmpty
            let hasFatCell = !fatText.trimmingCharacters(in: .whitespaces).isEmpty
            let hasDietCell = !dietText.trimmingCharacters(in: .whitespaces).isEmpty
            let hasTagsCell = !tagsText.trimmingCharacters(in: .whitespaces).isEmpty
            let hasNoteCell = !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            if !hasWeightCell && !hasFatCell && !hasDietCell && !hasTagsCell && !hasNoteCell {
                preview.invalidCount += 1
                continue
            }

            var pendingWeight: PendingWeighIn?
            if hasWeightCell {
                guard let rawWeight = EaseFormatters.parseUnrounded(weightText),
                      let weight = try? MeasurementBounds.validatedWeight(rawWeight) else {
                    preview.invalidCount += 1
                    continue
                }
                var bodyFat: Double?
                if hasFatCell {
                    guard let rawFat = EaseFormatters.parseUnrounded(fatText),
                          let fat = try? MeasurementBounds.validatedBodyFat(rawFat) else {
                        preview.invalidCount += 1
                        continue
                    }
                    bodyFat = fat
                }
                let timestamp: Date
                if isLegacy || timeText.isEmpty {
                    timestamp = CalendarDay.atHour(8, on: day, calendar: calendar)
                } else {
                    guard let parsed = parseHourMinute(timeText),
                          let stamp = optionalTimestamp(day: day, hour: parsed.hour, minute: parsed.minute, calendar: calendar)
                    else {
                        preview.invalidCount += 1
                        continue
                    }
                    timestamp = stamp
                }
                pendingWeight = PendingWeighIn(timestamp: timestamp, weight: weight, bodyFat: bodyFat)
            } else if hasFatCell {
                preview.invalidCount += 1
                continue
            }

            var diet: DietStatus?
            if hasDietCell {
                guard let parsed = DietStatus(rawValue: dietText.trimmingCharacters(in: .whitespaces)) else {
                    preview.invalidCount += 1
                    continue
                }
                diet = parsed
            }

            var tags: [VariableTag]?
            if hasTagsCell {
                let tokens = tagsText
                    .split { $0 == ";" || $0 == "|" }
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                let parsed = VariableTag.sanitized(tokens.compactMap(VariableTag.init(rawValue:)))
                if parsed.isEmpty {
                    tags = nil
                } else {
                    tags = parsed
                }
            }

            var note: String?
            if hasNoteCell {
                let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                note = trimmed.isEmpty ? nil : trimmed
            }

            if let pendingWeight {
                let key = weighInKey(pendingWeight.timestamp, weight: pendingWeight.weight, calendar: calendar)
                if seenWeighIns.contains(key) {
                    preview.duplicateCount += 1
                } else {
                    seenWeighIns.insert(key)
                    preview.pendingWeighIns.append(pendingWeight)
                }
            }

            if diet != nil || tags != nil || note != nil {
                let dayKey = CalendarDay.dayKey(from: day, calendar: calendar)
                var journal = journalsByDay[dayKey] ?? PendingJournal(day: day, dietStatus: nil, tags: nil, note: nil)
                if let diet { journal.dietStatus = diet }
                if let tags { journal.tags = tags }
                if let note { journal.note = note }
                journalsByDay[dayKey] = journal
            }
        }

        preview.pendingJournals = journalsByDay.values.sorted { $0.day < $1.day }
        preview.weighInCount = preview.pendingWeighIns.count
        preview.dietDayCount = preview.pendingJournals.filter { $0.dietStatus != nil }.count
        _ = existingRecords
    }

    @MainActor
    private static func applyJournal(
        _ preview: Preview,
        context: ModelContext,
        calendar: Calendar
    ) throws -> ApplyResult {
        let logs = WeightLogRepository(context: context, calendar: calendar)
        let records = DailyRecordRepository(context: context, calendar: calendar)
        let existing = (try? logs.allLogs()) ?? []
        var seen = weighInKeys(existing, calendar: calendar)
        var result = ApplyResult()

        for weighIn in preview.pendingWeighIns {
            let key = weighInKey(weighIn.timestamp, weight: weighIn.weight, calendar: calendar)
            if seen.contains(key) { continue }
            seen.insert(key)
            _ = try logs.insert(timestamp: weighIn.timestamp, weight: weighIn.weight, bodyFat: weighIn.bodyFat)
            result.weighInsWritten += 1
        }

        for journal in preview.pendingJournals {
            var patch = DailyRecordPatch()
            if let diet = journal.dietStatus {
                patch.dietStatus = .set(diet)
            }
            if let tags = journal.tags {
                patch.tags = .set(tags)
            }
            if let note = journal.note {
                patch.note = .set(note)
            }
            guard !patch.isEmpty else { continue }
            _ = try records.upsert(on: journal.day, patch: patch)
            if journal.dietStatus != nil {
                result.dietDaysWritten += 1
            }
        }
        return result
    }

    // MARK: - Metrics

    private static func parseMetrics(
        lines: [String],
        existingMetricLogs: [MetricLog],
        metricSpecs: [String: MetricSpec],
        now: Date,
        calendar: Calendar,
        into preview: inout Preview
    ) {
        var seen = metricKeys(existingMetricLogs, specs: metricSpecs, calendar: calendar)
        for line in lines {
            let fields = parseFields(line)
            guard fields.count >= 4 else {
                preview.invalidCount += 1
                continue
            }
            let dateText = fields[0].trimmingCharacters(in: .whitespaces)
            let timeText = fields[1].trimmingCharacters(in: .whitespaces)
            let key = fields[2].trimmingCharacters(in: .whitespaces)
            let valueText = fields[3].trimmingCharacters(in: .whitespaces)

            guard let day = CalendarDay.date(fromDayKey: dateText, calendar: calendar) else {
                preview.invalidCount += 1
                continue
            }
            if CalendarDay.isFuture(day, now: now, calendar: calendar) {
                preview.invalidCount += 1
                continue
            }
            guard let spec = metricSpecs[key] ?? MetricCatalog.builtin(for: key) else {
                preview.invalidCount += 1
                continue
            }
            guard let parsedTime = parseHourMinute(timeText.isEmpty ? "08:00" : timeText),
                  let timestamp = optionalTimestamp(day: day, hour: parsedTime.hour, minute: parsedTime.minute, calendar: calendar),
                  let raw = EaseFormatters.parseUnrounded(valueText),
                  let value = try? MetricCatalog.validated(raw, spec: spec)
            else {
                preview.invalidCount += 1
                continue
            }

            let dedupe = metricKey(timestamp, metricKey: key, value: value, spec: spec, calendar: calendar)
            if seen.contains(dedupe) {
                preview.duplicateCount += 1
                continue
            }
            seen.insert(dedupe)
            preview.pendingMetrics.append(PendingMetric(timestamp: timestamp, metricKey: key, value: value))
        }
        preview.metricLogCount = preview.pendingMetrics.count
    }

    @MainActor
    private static func applyMetrics(
        _ preview: Preview,
        context: ModelContext,
        calendar: Calendar
    ) throws -> ApplyResult {
        let metrics = MetricRepository(context: context, calendar: calendar)
        try metrics.seedBuiltinsIfNeeded()
        let definitions = (try? metrics.allDefinitions()) ?? []
        let specs = Dictionary(uniqueKeysWithValues: definitions.map { ($0.key, MetricCatalog.spec(for: $0)) })
        let existing = (try? metrics.allLogs()) ?? []
        var seen = metricKeys(existing, specs: specs, calendar: calendar)
        var result = ApplyResult()
        for pending in preview.pendingMetrics {
            let spec = try metrics.spec(forKey: pending.metricKey)
            let key = metricKey(pending.timestamp, metricKey: pending.metricKey, value: pending.value, spec: spec, calendar: calendar)
            if seen.contains(key) { continue }
            seen.insert(key)
            _ = try metrics.insertLog(timestamp: pending.timestamp, metricKey: pending.metricKey, value: pending.value)
            result.metricLogsWritten += 1
        }
        return result
    }

    // MARK: - Keys

    static func weighInKey(_ timestamp: Date, weight: Double, calendar: Calendar) -> String {
        let day = CalendarDay.dayKey(from: timestamp, calendar: calendar)
        let parts = calendar.dateComponents([.hour, .minute], from: timestamp)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let rounded = MeasurementBounds.roundedToTenth(weight)
        return String(format: "%@-%02d:%02d-%.1f", day, hour, minute, rounded)
    }

    static func weighInKeys(_ logs: [WeightLog], calendar: Calendar) -> Set<String> {
        Set(logs.map { weighInKey($0.timestamp, weight: $0.weight, calendar: calendar) })
    }

    static func metricKey(
        _ timestamp: Date,
        metricKey: String,
        value: Double,
        spec: MetricSpec,
        calendar: Calendar
    ) -> String {
        let day = CalendarDay.dayKey(from: timestamp, calendar: calendar)
        let parts = calendar.dateComponents([.hour, .minute], from: timestamp)
        let hour = parts.hour ?? 0
        let minute = parts.minute ?? 0
        let rounded = MetricCatalog.rounded(value, spec: spec)
        return "\(day)-\(String(format: "%02d:%02d", hour, minute))-\(metricKey)-\(MetricCatalog.csvValue(rounded, spec: spec))"
    }

    static func metricKeys(
        _ logs: [MetricLog],
        specs: [String: MetricSpec] = [:],
        calendar: Calendar
    ) -> Set<String> {
        Set(logs.map { log in
            let spec = specs[log.metricKey]
                ?? MetricCatalog.builtin(for: log.metricKey)
                ?? MetricSpec(
                    key: log.metricKey,
                    kind: .custom,
                    unit: .count,
                    step: 1,
                    range: 0...10_000,
                    symbolName: "circle",
                    titleKey: nil,
                    displayName: log.metricKey,
                    sortOrder: 0
                )
            return metricKey(log.timestamp, metricKey: log.metricKey, value: log.value, spec: spec, calendar: calendar)
        })
    }

    static func parseHourMinute(_ text: String) -> (hour: Int, minute: Int)? {
        let parts = text.split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0...23).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }
        return (hour, minute)
    }

    private static func optionalTimestamp(day: Date, hour: Int, minute: Int, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: CalendarDay.startOfDay(day, calendar: calendar))
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }
}
