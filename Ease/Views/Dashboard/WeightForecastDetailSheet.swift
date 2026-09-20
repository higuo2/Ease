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
                        heroSection

                        VStack(alignment: .leading, spacing: 12) {
                            Text("trend.forecast.projectionFactors")
                                .font(.headline)
                                .foregroundStyle(EasePalette.primaryText)
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                factorRow(
                                    symbol: "moon.fill",
                                    tint: EasePalette.iconSleep,
                                    title: "trend.advanced.sleep",
                                    value: sleepValue
                                )
                                factorRow(
                                    symbol: "bolt.fill",
                                    tint: EasePalette.iconEnergy,
                                    title: "trend.advanced.energy",
                                    value: energyValue
                                )
                                factorRow(
                                    symbol: "drop.fill",
                                    tint: EasePalette.iconPeriod,
                                    title: "trend.advanced.period",
                                    value: periodValue
                                )
                                factorRow(
                                    symbol: "chart.line.downtrend.xyaxis",
                                    tint: EasePalette.accent,
                                    title: "trend.advanced.slope",
                                    value: EaseFormatters.signedKgPerDay(estimate.adjustedSlopeKg)
                                )
                            }
                            .padding(.vertical, 4)
                            .background(
                                EasePalette.card,
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
                            }
                        }

                        TrendLegalFootnote("trend.forecast.disclaimer")
                            .padding(.top, 8)
                    }
                    .padding(20)
                    .padding(.bottom, 12)
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

    private var heroSection: some View {
        VStack(spacing: 10) {
            Text("trend.forecast.detail.headline")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(EaseFormatters.advancedPaceHorizon(estimate.eta))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(EasePalette.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .background(
            HomeModule.weight.fill,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
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
            TrendTintIconTile(systemName: symbol, tint: tint, soft: true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(EasePalette.primaryText)
                Text(value)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }
}
