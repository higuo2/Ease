import SwiftUI
import Charts

struct EnergyDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let history: EnergyHistory
    let focusKcal: Double?
    var isPlaceholder = false

    private var chartDays: [EnergyDay] { history.loggedDays }
    private var latestChartDate: Date { chartDays.last?.date ?? history.endingOn }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        EaseCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("health.energy")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(EasePalette.secondaryText)
                                if let focusKcal {
                                    Text(EaseFormatters.kcal(focusKcal))
                                        .font(EaseFont.number(32))
                                        .monospacedDigit()
                                        .foregroundStyle(EasePalette.primaryText)
                                } else {
                                    Text("module.noData")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(EasePalette.secondaryText)
                                }
                                if let average = history.averageKcal {
                                    Text(String(format: String(localized: "energy.average"), locale: .current, Int(average)))
                                        .font(.system(size: 14, weight: .regular))
                                        .foregroundStyle(EasePalette.secondaryText)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if !chartDays.isEmpty {
                            EaseCard {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text("energy.chart.title")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(EasePalette.primaryText)
                                    Chart {
                                        ForEach(chartDays) { day in
                                            BarMark(
                                                x: .value("chart.axis.date", day.date, unit: .day),
                                                y: .value("chart.axis.energy", day.kcal ?? 0),
                                                width: .ratio(HealthDetailChart.barRatio)
                                            )
                                            .foregroundStyle(EasePalette.morandiEnergy)
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
                                                    Text("\(Int(number.rounded()))")
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

                                    VStack(spacing: 8) {
                                        ForEach(Array(chartDays.suffix(30).reversed())) { day in
                                            HealthHistoryRow(
                                                date: day.date,
                                                value: EaseFormatters.kcal(day.kcal ?? 0)
                                            )
                                        }
                                    }
                                }
                            }
                        } else {
                            EaseCard {
                                Text("energy.empty")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(EasePalette.secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(20)
                }
                .easeHealthPlaceholder(isPlaceholder)
            }
            .navigationTitle("health.energy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EaseCloseToolbarButton(action: { dismiss() })
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }
}
