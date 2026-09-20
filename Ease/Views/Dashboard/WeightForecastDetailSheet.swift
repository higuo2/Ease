import SwiftUI

struct WeightForecastDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let estimate: AdvancedPaceEstimator.Result

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: EaseLayout.sectionSpacing) {
                        EaseCard(padding: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("trend.forecast.detail.headline")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text(EaseFormatters.advancedPaceHorizon(estimate.eta))
                                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                    .foregroundStyle(EasePalette.primaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        EaseCard(padding: 0) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text("trend.forecast.projectionFactors")
                                    .font(.headline)
                                    .foregroundStyle(EasePalette.primaryText)
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)
                                    .padding(.bottom, 12)

                                factorRow(
                                    symbol: "moon.fill",
                                    tint: EasePalette.iconSleep,
                                    title: "trend.advanced.sleep",
                                    value: sleepValue
                                )
                                factorDivider
                                factorRow(
                                    symbol: "bolt.fill",
                                    tint: EasePalette.iconEnergy,
                                    title: "trend.advanced.energy",
                                    value: energyValue
                                )
                                factorDivider
                                factorRow(
                                    symbol: "drop.fill",
                                    tint: EasePalette.iconPeriod,
                                    title: "trend.advanced.period",
                                    value: periodValue
                                )
                                factorDivider
                                factorRow(
                                    symbol: "chart.line.downtrend.xyaxis",
                                    tint: EasePalette.accent,
                                    title: "trend.advanced.slope",
                                    value: EaseFormatters.signedKgPerDay(estimate.adjustedSlopeKg)
                                )
                            }
                            .padding(.bottom, 8)
                        }

                        Text("trend.forecast.disclaimer")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 4)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("trend.forecast.detail.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EaseCloseToolbarButton(action: { dismiss() })
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
        .preferredColorScheme(.light)
        .easeSheetPresentation()
    }

    private var factorDivider: some View {
        Divider()
            .overlay(EasePalette.hairline)
            .padding(.leading, 56)
    }

    private var sleepValue: String {
        factorDetail(
            measurement: estimate.averageSleepHours.map(EaseFormatters.sleepDuration),
            factor: estimate.sleepFactor
        )
    }

    private var energyValue: String {
        factorDetail(
            measurement: estimate.averageEnergyKcal.map { EaseFormatters.kcal($0) },
            factor: estimate.energyFactor
        )
    }

    private var periodValue: String {
        if estimate.periodDaysInWindow > 0 {
            return String(
                format: String(localized: "trend.advanced.periodDays"),
                locale: .current,
                estimate.periodDaysInWindow
            )
        }
        return factorLabel(for: estimate.periodFactor)
    }

    private func factorDetail(measurement: String?, factor: Double) -> String {
        if let measurement {
            return "\(factorLabel(for: factor)) · \(measurement)"
        }
        return factorLabel(for: factor)
    }

    private func factorLabel(for factor: Double) -> String {
        if abs(factor - 1) < 0.02 {
            return String(localized: "trend.advanced.factor.neutral")
        }
        if factor < 1 {
            return String(localized: "trend.forecast.factor.belowBaseline")
        }
        return String(localized: "trend.forecast.factor.aboveBaseline")
    }

    private func factorRow(
        symbol: String,
        tint: Color,
        title: LocalizedStringKey,
        value: String
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            TrendTintIconTile(systemName: symbol, tint: tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(EasePalette.primaryText)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}
