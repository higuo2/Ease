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
    private var loggedNights: [SleepNight] { history.nights.filter { $0.hours != nil } }
    private var chartNights: [SleepNight] { Array(loggedNights.suffix(HealthDetailChart.chartPointLimit)) }
    private var latestChartDate: Date { chartNights.last?.morning ?? history.endingOn }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        EaseCard(combinesChildren: true) {
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
                                                y: .value("chart.axis.sleep", night.hours ?? 0),
                                                width: .ratio(HealthDetailChart.barRatio)
                                            )
                                            .foregroundStyle(EasePalette.sleepTeal.opacity(0.7))
                                            .cornerRadius(HealthDetailChart.barCornerRadius)
                                        }
                                    }
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: .day)) { value in
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
                                    .easeScrollableHealthChart(
                                        latestDate: latestChartDate,
                                        visibleDays: HealthDetailChart.dayBarVisibleDays
                                    )
                                    .frame(height: 180)

                                    if let average = history.averageHours {
                                        Text(EaseFormatters.sleepAverage(average))
                                            .font(.system(size: 14, weight: .regular))
                                            .monospacedDigit()
                                            .foregroundStyle(EasePalette.secondaryText)
                                    }

                                    VStack(spacing: 8) {
                                        ForEach(Array(chartNights.reversed())) { night in
                                            HealthHistoryRow(
                                                date: night.morning,
                                                value: EaseFormatters.sleepDuration(night.hours ?? 0)
                                            )
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
                ToolbarItem(placement: .topBarLeading) {
                    EaseCloseToolbarButton(action: { dismiss() })
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
        .preferredColorScheme(.light)
        .tint(EasePalette.sleepTeal)
    }
}
