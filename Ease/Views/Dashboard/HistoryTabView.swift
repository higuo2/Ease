import SwiftUI

struct HistoryTabView: View {
    @Bindable var viewModel: DashboardViewModel
    let records: [DailyRecord]
    let logs: [WeightLog]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var rows: [HistoryDayRow] {
        HistoryDayRow.build(records: records, logs: logs)
    }
    private var isAccessibilityType: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                if rows.isEmpty {
                    EaseEmptyState(
                        symbol: "scalemass",
                        title: "empty.history.title",
                        message: "empty.history.message",
                        action: { viewModel.openWeightEntry(for: .now) }
                    )
                } else {
                    VStack(spacing: 0) {
                        if !isAccessibilityType {
                            header
                        }
                        List {
                            ForEach(rows) { row in
                                Button {
                                    open(row)
                                } label: {
                                    HistoryRowView(row: row, stacked: isAccessibilityType)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(EasePalette.card)
                                .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
                                .easeRecordContextMenu(
                                    onEdit: { open(row) },
                                    onDelete: row.latestLogID == nil ? nil : {
                                        if let id = row.latestLogID {
                                            deleteLog(id: id)
                                        }
                                    }
                                )
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if let logID = row.latestLogID {
                                        Button(role: .destructive) {
                                            deleteLog(id: logID)
                                        } label: {
                                            Label("log.delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("tab.history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
    }

    private var header: some View {
        HStack(spacing: 0) {
            headerCell("history.date", flex: 1.2)
            headerCell("history.morning", flex: 1)
            headerCell("history.evening", flex: 1)
            headerCell("history.daytimeSwing", flex: 1)
            headerCell("history.overnight", flex: 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(EasePalette.recessed)
        .accessibilityHidden(true)
    }

    private func headerCell(_ key: LocalizedStringKey, flex: CGFloat) -> some View {
        Text(key)
            .font(.caption.weight(.semibold))
            .foregroundStyle(EasePalette.secondaryText)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .layoutPriority(flex)
    }

    private func open(_ row: HistoryDayRow) {
        viewModel.selectedDate = row.day
        if let logID = row.latestLogID, let log = logs.first(where: { $0.id == logID }) {
            viewModel.openWeightLog(log)
        } else {
            viewModel.openLog(for: row.day)
        }
    }

    private func deleteLog(id: UUID) {
        guard let log = logs.first(where: { $0.id == id }) else { return }
        try? WeightLogRepository(context: modelContext).delete(log)
    }
}

struct HistoryRowView: View {
    let row: HistoryDayRow
    var stacked: Bool = false

    var body: some View {
        Group {
            if stacked {
                VStack(alignment: .leading, spacing: 8) {
                    Text(row.day, format: .dateTime.month(.wide).day())
                        .font(.headline)
                        .foregroundStyle(EasePalette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    labeled("history.morning", row.morning)
                    labeled("history.evening", row.evening)
                    labeled("history.daytimeSwing", row.daytimeSwing, signed: true)
                    labeled("history.overnight", row.overnight, signed: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: 0) {
                    Text(row.day, format: .dateTime.month(.twoDigits).day(.twoDigits))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(EasePalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity)
                    cell(row.morning)
                    cell(row.evening)
                    cell(row.daytimeSwing, signed: true)
                    cell(row.overnight, signed: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityHint(Text("a11y.record.hint"))
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilitySummary: Text {
        var text = Text(row.day, format: .dateTime.month(.wide).day())
        text = text + Text(verbatim: ", ") + labeledValue("history.morning", row.morning)
        text = text + Text(verbatim: ", ") + labeledValue("history.evening", row.evening)
        return text
    }

    private func labeledValue(_ key: LocalizedStringKey, _ value: Double?) -> Text {
        Text(key) + Text(verbatim: " ") + Text(value.map(EaseFormatters.oneDecimal) ?? "—")
    }

    private func labeled(_ key: LocalizedStringKey, _ value: Double?, signed: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(key)
                .font(.subheadline)
                .foregroundStyle(EasePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let value {
                Text(signed ? signedText(value) : EaseFormatters.oneDecimal(value))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(signed ? EasePalette.deltaColor(value) : EasePalette.primaryText)
            } else {
                Text("—")
                    .font(.body)
                    .foregroundStyle(EasePalette.secondaryText)
            }
        }
    }

    private func cell(_ value: Double?, signed: Bool = false) -> some View {
        Group {
            if let value {
                Text(signed ? signedText(value) : EaseFormatters.oneDecimal(value))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(signed ? EasePalette.deltaColor(value) : EasePalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } else {
                Text("—")
                    .font(.subheadline)
                    .foregroundStyle(EasePalette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func signedText(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(EaseFormatters.oneDecimal(value))"
    }
}

struct HistoryDayRow: Identifiable {
    var id: String { dayKey }
    var dayKey: String
    var day: Date
    var morning: Double?
    var evening: Double?
    var daytimeSwing: Double?
    var overnight: Double?
    var latestLogID: UUID?

    static func build(
        records: [DailyRecord],
        logs: [WeightLog],
        calendar: Calendar = .current
    ) -> [HistoryDayRow] {
        let samples = WeightMetrics.samples(from: records, logs: logs, calendar: calendar)
        let days = Set(samples.map { CalendarDay.dayKey(from: $0.date, calendar: calendar) })
        return days.compactMap { key -> HistoryDayRow? in
            guard let day = CalendarDay.date(fromDayKey: key, calendar: calendar) else { return nil }
            let bounds = WeightMetrics.dayBounds(records: records, logs: logs, on: day, calendar: calendar)
            let latest = logs
                .filter { CalendarDay.dayKey(from: $0.timestamp, calendar: calendar) == key }
                .max(by: { $0.timestamp < $1.timestamp })
            return HistoryDayRow(
                dayKey: key,
                day: day,
                morning: bounds.morning,
                evening: bounds.evening,
                daytimeSwing: WeightMetrics.daytimeSwing(records: records, logs: logs, on: day, calendar: calendar),
                overnight: WeightMetrics.overnightMetabolism(records: records, logs: logs, on: day, calendar: calendar),
                latestLogID: latest?.id
            )
        }
        .sorted { $0.day > $1.day }
    }
}
