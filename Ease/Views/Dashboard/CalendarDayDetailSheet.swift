import SwiftUI
import SwiftData

struct CalendarDayDetailSheet: View {
    @Query(sort: \DailyRecord.date, order: .forward) private var allRecords: [DailyRecord]

    let date: Date
    let logs: [WeightLog]
    let onLogWeight: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        weightCard
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                        .font(.headline)
                        .foregroundStyle(EasePalette.primaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onLogWeight()
                    } label: {
                        Text("calendar.log")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(EasePalette.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .preferredColorScheme(.light)
    }

    private var weightCard: some View {
        let bounds = WeightMetrics.dayBounds(records: allRecords, logs: logs, on: date)
        let swing = WeightMetrics.daytimeSwing(records: allRecords, logs: logs, on: date)

        return EaseCard(radius: 16, padding: 18) {
            HStack(alignment: .top, spacing: 0) {
                detailMetric("calendar.detail.am", bounds.morning.map(EaseFormatters.oneDecimal))
                detailMetric("calendar.detail.pm", bounds.evening.map(EaseFormatters.oneDecimal))
                detailMetric(
                    "calendar.detail.day",
                    swing.map(signedOne),
                    showUnit: false,
                    valueColor: swing.map(EasePalette.semanticDelta)
                )
            }
        }
    }

    private func detailMetric(
        _ title: LocalizedStringKey,
        _ value: String?,
        showUnit: Bool = true,
        valueColor: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value ?? "—")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(valueColor ?? EasePalette.primaryText)
                if showUnit, value != nil {
                    Text("unit.kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func signedOne(_ value: Double) -> String {
        if value > 0 { return "+\(EaseFormatters.oneDecimal(value))" }
        if value < 0 { return EaseFormatters.oneDecimal(value) }
        return EaseFormatters.oneDecimal(value)
    }
}
