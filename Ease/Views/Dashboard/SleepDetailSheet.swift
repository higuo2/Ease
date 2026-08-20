import SwiftUI
import Charts

struct SleepDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let history: SleepHistory
    let focusHours: Double?
    let targetHours: Double

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
                                    ZStack {
                                        EaseArcRing(
                                            progress: ringProgress,
                                            colors: [EasePalette.sleepMint, EasePalette.sleepTeal],
                                            diameter: 120
                                        )
                                    }
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
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                        }

                        if !chartNights.isEmpty {
                            EaseCard {
                                VStack(alignment: .leading, spacing: 12) {
                    Chart {
                        ForEach(chartNights) { night in
                            BarMark(
                                x: .value("chart.axis.date", night.morning, unit: .day),
                                y: .value("chart.axis.sleep", night.hours ?? 0)
                            )
                            .foregroundStyle(EasePalette.sleepTeal.opacity(0.55))
                            .cornerRadius(3)
                        }
                    }
                                    .chartXAxis(.hidden)
                                    .chartYAxis(.hidden)
                                    .frame(height: 140)

                                    if let average = history.averageHours {
                                        Text(EaseFormatters.sleepAverage(average))
                                            .font(.system(size: 14, weight: .regular))
                                            .monospacedDigit()
                                            .foregroundStyle(EasePalette.secondaryText)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
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
