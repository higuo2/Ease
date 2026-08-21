import SwiftUI
import Charts

struct EnergyDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let history: EnergyHistory
    let focusKcal: Double?

    private var chartDays: [EnergyDay] { history.loggedDays }

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
                                                y: .value("chart.axis.energy", day.kcal ?? 0)
                                            )
                                            .foregroundStyle(EasePalette.morandiEnergy)
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
                                                    Text("\(Int(number.rounded()))")
                                                        .font(.system(size: 10).monospacedDigit())
                                                        .foregroundStyle(EasePalette.secondaryText)
                                                }
                                            }
                                        }
                                    }
                                    .frame(height: 180)

                                    ForEach(Array(chartDays.suffix(14).reversed())) { day in
                                        HStack {
                                            Text(day.date, format: .dateTime.month(.abbreviated).day().weekday(.narrow))
                                                .font(.system(size: 13, weight: .regular))
                                                .foregroundStyle(EasePalette.secondaryText)
                                            Spacer()
                                            Text(EaseFormatters.kcal(day.kcal ?? 0))
                                                .font(EaseFont.number(15))
                                                .monospacedDigit()
                                                .foregroundStyle(EasePalette.primaryText)
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
            }
            .navigationTitle("health.energy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EaseTextButton(title: "common.close", action: { dismiss() })
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }
}
