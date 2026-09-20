import SwiftUI

struct WeightLogEntry: Identifiable, Equatable, Sendable {
    var id: String
    var timestamp: Date
    var weight: Double
    var delta: Double?
    var logID: UUID?
    var isMorning: Bool

    static func build(
        records: [DailyRecord],
        logs: [WeightLog],
        calendar: Calendar = .current
    ) -> [WeightLogEntry] {
        let daysWithLogs = Set(logs.map { CalendarDay.dayKey(from: $0.timestamp, calendar: calendar) })
        var samples: [(id: String, timestamp: Date, weight: Double, logID: UUID?)] = logs.map {
            ($0.id.uuidString, $0.timestamp, $0.weight, $0.id)
        }
        for record in records {
            guard let weight = record.weight, !daysWithLogs.contains(record.dayKey) else { continue }
            samples.append(("legacy-\(record.dayKey)", record.date, weight, nil))
        }
        samples.sort { $0.timestamp < $1.timestamp }

        var previous: Double?
        var entries: [WeightLogEntry] = []
        entries.reserveCapacity(samples.count)
        for sample in samples {
            let delta: Double?
            if let previous {
                delta = MeasurementBounds.roundedToTenth(sample.weight - previous)
            } else {
                delta = nil
            }
            previous = sample.weight
            entries.append(
                WeightLogEntry(
                    id: sample.id,
                    timestamp: sample.timestamp,
                    weight: sample.weight,
                    delta: delta,
                    logID: sample.logID,
                    isMorning: calendar.component(.hour, from: sample.timestamp) < 12
                )
            )
        }
        return entries.reversed()
    }
}

struct WeightLogListView: View {
    let entries: [WeightLogEntry]
    var recentDays: Int = 30
    let onSelect: (WeightLogEntry) -> Void
    var onDelete: ((WeightLogEntry) -> Void)? = nil
    let onShowAll: () -> Void

    private var visibleEntries: [WeightLogEntry] {
        let cutoff = CalendarDay.addingDays(-(recentDays - 1), to: CalendarDay.startOfDay(.now))
        return entries.filter { $0.timestamp >= cutoff }
    }

    private var showsSeeAll: Bool {
        !entries.isEmpty
    }

    var body: some View {
        Section {
            if visibleEntries.isEmpty {
                Text("weight.list.empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
                    .listRowBackground(EasePalette.card)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(visibleEntries) { entry in
                    WeightLogRowButton(
                        entry: entry,
                        onSelect: { onSelect(entry) },
                        onDelete: (onDelete == nil || entry.logID == nil) ? nil : { onDelete?(entry) }
                    )
                }
            }
        } header: {
            WeightLogSectionHeader(showsSeeAll: showsSeeAll, onShowAll: onShowAll)
        }
        .textCase(nil)
    }
}

struct WeightLogRows: View {
    let entries: [WeightLogEntry]
    let onSelect: (WeightLogEntry) -> Void
    var onDelete: ((WeightLogEntry) -> Void)? = nil

    var body: some View {
        ForEach(entries) { entry in
            WeightLogRowButton(
                entry: entry,
                onSelect: { onSelect(entry) },
                onDelete: (onDelete == nil || entry.logID == nil) ? nil : { onDelete?(entry) }
            )
        }
    }
}

private struct WeightLogSectionHeader: View {
    let showsSeeAll: Bool
    let onShowAll: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("weight.list.title")
                .font(.headline)
                .foregroundStyle(EasePalette.primaryText)
                .textCase(nil)
            Spacer(minLength: 8)
            if showsSeeAll {
                Button(action: onShowAll) {
                    Text("weight.list.all")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(EasePalette.primaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(EasePalette.recessed, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("weight.list.all"))
            }
        }
        .textCase(nil)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }
}

private struct WeightLogRowButton: View {
    let entry: WeightLogEntry
    let onSelect: () -> Void
    var onDelete: (() -> Void)? = nil
    @State private var selectionTick = 0

    var body: some View {
        Button {
            selectionTick += 1
            onSelect()
        } label: {
            WeightLogRowView(entry: entry)
        }
        .buttonStyle(.plain)
        .listRowBackground(EasePalette.card)
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 12))
        .sensoryFeedback(.selection, trigger: selectionTick)
        .easeRecordContextMenu(
            onEdit: onSelect,
            onDelete: onDelete
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if onDelete != nil {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel(Text("log.delete"))
            }
        }
    }
}

struct WeightLogRowView: View, Equatable {
    let entry: WeightLogEntry
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.entry == rhs.entry
    }

    private var isAccessibilityType: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        Group {
            if isAccessibilityType {
                VStack(alignment: .leading, spacing: 10) {
                    leadingColumn
                    trailingColumn
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    leadingColumn
                    Spacer(minLength: 8)
                    trailingColumn
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(Text("a11y.record.hint"))
        .accessibilityAddTraits(.isButton)
    }

    private var leadingColumn: some View {
        HStack(alignment: .center, spacing: 12) {
            daypartTile
            VStack(alignment: .leading, spacing: 2) {
                Text(dateLabel)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(EasePalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(entry.timestamp, format: EaseDateFormat.hourMinute)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
        }
    }

    private var trailingColumn: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(EaseFormatters.kg(entry.weight))
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(EasePalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .easeNumericText(entry.weight)
            if let delta = entry.delta, delta != 0 {
                deltaBadge(delta)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }

    private var daypartTile: some View {
        Image(systemName: entry.isMorning ? "sun.max.fill" : "moon.fill")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(entry.isMorning ? Self.morningTint : Self.eveningTint)
            .frame(width: 28, height: 28)
            .background(
                EasePalette.recessed,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .accessibilityHidden(true)
    }

    private func deltaBadge(_ delta: Double) -> some View {
        let color = EasePalette.semanticDelta(delta)
        return Text(EaseFormatters.signedKg(delta))
            .font(.caption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
            .accessibilityLabel(Text(EaseFormatters.signedKg(delta)))
    }

    private var dateLabel: String {
        if Calendar.current.isDateInToday(entry.timestamp) {
            return String(localized: "weight.list.today")
        }
        return entry.timestamp.formatted(EaseDateFormat.monthDay)
    }

    private var accessibilitySummary: Text {
        var text = Text(dateLabel)
            + Text(verbatim: ", ")
            + Text(entry.timestamp, format: EaseDateFormat.hourMinute)
            + Text(verbatim: ", ")
            + Text(entry.isMorning ? "history.morning" : "history.evening")
            + Text(verbatim: " ")
            + Text(EaseFormatters.kg(entry.weight))
        if let delta = entry.delta, delta != 0 {
            text = text + Text(verbatim: ", ") + Text(EaseFormatters.signedKg(delta))
        }
        return text
    }

    private static let morningTint = EasePalette.morandiEnergyDeep
    private static let eveningTint = EasePalette.morandiMistDeep
}
