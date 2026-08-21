import SwiftUI

struct HistoryTabView: View {
    @Bindable var viewModel: DashboardViewModel
    let records: [DailyRecord]
    let logs: [WeightLog]

    private var rows: [HistoryDayRow] {
        HistoryDayRow.build(records: records, logs: logs)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    header
                    if rows.isEmpty {
                        Text("history.empty")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(EasePalette.secondaryText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(rows) { row in
                                Button {
                                    viewModel.selectedDate = row.day
                                    if let logID = row.latestLogID {
                                        if let log = logs.first(where: { $0.id == logID }) {
                                            viewModel.openWeightLog(log)
                                        } else {
                                            viewModel.openLog(for: row.day)
                                        }
                                    } else {
                                        viewModel.openLog(for: row.day)
                                    }
                                } label: {
                                    HistoryRowView(row: row)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(EasePalette.card)
                                .listRowInsets(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
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
    }

    private func headerCell(_ key: LocalizedStringKey, flex: CGFloat) -> some View {
        Text(key)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(EasePalette.secondaryText)
            .frame(maxWidth: .infinity)
            .layoutPriority(flex)
    }

    @Environment(\.modelContext) private var modelContext

    private func deleteLog(id: UUID) {
        guard let log = logs.first(where: { $0.id == id }) else { return }
        try? WeightLogRepository(context: modelContext).delete(log)
    }
}

struct HistoryRowView: View {
    let row: HistoryDayRow

    var body: some View {
        HStack(spacing: 0) {
            Text(row.day, format: .dateTime.month(.twoDigits).day(.twoDigits))
                .font(.system(size: 13, weight: .regular).monospacedDigit())
                .foregroundStyle(EasePalette.primaryText)
                .frame(maxWidth: .infinity)
            cell(row.morning)
            cell(row.evening)
            cell(row.daytimeSwing, signed: true)
            cell(row.overnight, signed: true)
        }
    }

    private func cell(_ value: Double?, signed: Bool = false) -> some View {
        Group {
            if let value {
                Text(signed ? signedText(value) : EaseFormatters.oneDecimal(value))
                    .font(.system(size: 13, weight: .regular).monospacedDigit())
                    .foregroundStyle(signed ? EasePalette.deltaColor(value) : EasePalette.primaryText)
            } else {
                Text("—")
                    .font(.system(size: 13, weight: .regular))
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
