import SwiftUI
import Charts

struct SleepDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let history: SleepHistory
    let focusHours: Double?
    let targetHours: Double
    var isPlaceholder = false

    private var ringProgress: Double? {
        guard let focusHours, targetHours > 0 else { return nil }
        return min(max(focusHours / targetHours, 0), 1)
    }
    private var chartNights: [SleepNight] { history.nights.filter { $0.hours != nil } }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        EaseCard {
                            HStack(spacing: 20) {
                                if let ringProgress {
                                    EaseArcRing(
                                        progress: ringProgress,
                                        colors: [EasePalette.sleepMint, EasePalette.sleepTeal],
                                        diameter: 108
                                    )
                                }
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("health.sleep")
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(EasePalette.secondaryText)
                                    if let focusHours {
                                        Text(EaseFormatters.sleepDuration(focusHours))
                                            .font(EaseFont.number(28))
                                            .monospacedDigit()
                                            .foregroundStyle(EasePalette.primaryText)
                                    } else {
                                        Text("module.noData")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundStyle(EasePalette.secondaryText)
                                    }
                                    Text(String(format: String(localized: "sleep.targetLine"), locale: .current, EaseFormatters.hours(targetHours)))
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(EasePalette.secondaryText)
                                }
                                Spacer(minLength: 0)
                            }
                        }

                        if !chartNights.isEmpty {
                            EaseCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("sleep.chart.title")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(EasePalette.primaryText)
                                    Chart {
                                        if targetHours > 0 {
                                            RuleMark(y: .value("chart.axis.sleep", targetHours))
                                                .foregroundStyle(EasePalette.secondaryText.opacity(0.45))
                                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                        }
                                        ForEach(chartNights) { night in
                                            BarMark(
                                                x: .value("chart.axis.date", night.morning, unit: .day),
                                                y: .value("chart.axis.sleep", night.hours ?? 0)
                                            )
                                            .foregroundStyle(EasePalette.sleepTeal.opacity(0.7))
                                            .cornerRadius(3)
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .automatic(desiredCount: 6)) { value in
                                            AxisGridLine().foregroundStyle(EasePalette.track)
                                            AxisValueLabel {
                                                if let date = value.as(Date.self) {
                                                    Text(date, format: .dateTime.month(.defaultDigits).day())
                                                        .font(.system(size: 10))
                                                        .foregroundStyle(EasePalette.secondaryText)
                                                }
                                            }
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                                            AxisGridLine().foregroundStyle(EasePalette.track)
                                            AxisValueLabel {
                                                if let number = value.as(Double.self) {
                                                    Text(EaseFormatters.oneDecimal(number))
                                                        .font(.system(size: 10).monospacedDigit())
                                                        .foregroundStyle(EasePalette.secondaryText)
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: 180)

                                    if let average = history.averageHours {
                                        Text(EaseFormatters.sleepAverage(average))
                                            .font(.system(size: 14, weight: .regular))
                                            .monospacedDigit()
                                            .foregroundStyle(EasePalette.secondaryText)
                                    }

                                    ForEach(Array(chartNights.suffix(10).reversed())) { night in
                                        HStack {
                                            Text(night.morning, format: .dateTime.month(.abbreviated).day().weekday(.narrow))
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundStyle(EasePalette.secondaryText)
                                            Spacer()
                                            Text(EaseFormatters.sleepDuration(night.hours ?? 0))
                                                .font(EaseFont.number(15))
                                                .monospacedDigit()
                                                .foregroundStyle(EasePalette.primaryText)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .easeHealthPlaceholder(isPlaceholder)
            }
            .navigationTitle("sleep.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EaseTextButton(title: "common.close", action: { dismiss() })
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
        .preferredColorScheme(.light)
        .tint(EasePalette.sleepTeal)
    }
}
