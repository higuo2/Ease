import SwiftUI

struct AdvancedEstimateCard: View, Equatable {
    let snapshot: DashboardSnapshot?
    let estimate: AdvancedPaceEstimator.Result?
    @State private var selectedFactor: FactorKind?

    private enum FactorKind: Hashable {
        case sleep, energy, period, slope
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.estimate == rhs.estimate
            && lhs.snapshot?.targetWeight == rhs.snapshot?.targetWeight
            && lhs.snapshot?.displayWeight == rhs.snapshot?.displayWeight
            && lhs.snapshot?.progress == rhs.snapshot?.progress
    }

    var body: some View {
        EaseCard(padding: 20) {
            VStack(alignment: .leading, spacing: 0) {
                TrendAnalysisHeader(
                    title: "trend.advanced.title",
                    windowDays: AdvancedPaceEstimator.lookbackDays
                )

                if let estimate {
                    horizonRow(estimate)
                        .padding(.top, 14)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: EaseLayout.gridGap),
                            GridItem(.flexible(), spacing: EaseLayout.gridGap)
                        ],
                        alignment: .leading,
                        spacing: EaseLayout.gridGap
                    ) {
                        factorItem(
                            kind: .sleep,
                            symbol: "moon.fill",
                            title: "trend.advanced.sleep",
                            detail: estimate.averageSleepHours.map(EaseFormatters.sleepDuration),
                            factor: estimate.sleepFactor,
                            iconColor: EasePalette.iconSleep
                        )
                        factorItem(
                            kind: .energy,
                            symbol: "bolt.fill",
                            title: "trend.advanced.energy",
                            detail: estimate.averageEnergyKcal.map { EaseFormatters.kcal($0) },
                            factor: estimate.energyFactor,
                            iconColor: EasePalette.iconEnergy
                        )
                        factorItem(
                            kind: .period,
                            symbol: "drop.fill",
                            title: "trend.advanced.period",
                            detail: estimate.periodDaysInWindow > 0
                                ? String(
                                    format: String(localized: "trend.advanced.periodDays"),
                                    locale: .current,
                                    estimate.periodDaysInWindow
                                )
                                : nil,
                            factor: estimate.periodFactor,
                            inactiveWhenNilDetail: true,
                            iconColor: EasePalette.iconPeriod
                        )
                        factorItem(
                            kind: .slope,
                            symbol: "chart.line.downtrend.xyaxis",
                            title: "trend.advanced.slope",
                            detail: EaseFormatters.signedKgPerDay(estimate.adjustedSlopeKg),
                            factor: nil,
                            inactiveWhenNilDetail: false,
                            iconColor: EasePalette.accent
                        )
                    }
                    .padding(.top, 16)

                    if let selectedFactor {
                        Text(factorExplanation(selectedFactor, estimate: estimate))
                            .font(.caption)
                            .foregroundStyle(EasePalette.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12)
                    }

                    TrendAnalysisFootnote()
                        .padding(.top, 16)
                } else {
                    Text("trend.advanced.unavailable")
                        .font(.subheadline)
                        .foregroundStyle(EasePalette.secondaryText)
                        .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(TrendAnalysisMotion.accordion, value: selectedFactor)
        }
        .sensoryFeedback(.selection, trigger: selectedFactor)
    }

    private func horizonRow(_ estimate: AdvancedPaceEstimator.Result) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("trend.advanced.horizon")
                .font(.subheadline)
                .foregroundStyle(EasePalette.secondaryText)
            Spacer(minLength: 8)
            Text(EaseFormatters.advancedPaceHorizon(estimate.eta))
                .font(.headline.bold())
                .foregroundStyle(EasePalette.primaryText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .accessibilityElement(children: .combine)
    }

    private func factorExplanation(
        _ kind: FactorKind,
        estimate: AdvancedPaceEstimator.Result
    ) -> String {
        switch kind {
        case .sleep:
            if estimate.sleepFactor < 0.99 {
                return String(localized: "trend.advanced.explain.sleep.slow")
            }
            if estimate.sleepFactor > 1.01 {
                return String(localized: "trend.advanced.explain.sleep.fast")
            }
            return String(localized: "trend.advanced.explain.sleep.neutral")
        case .energy:
            if estimate.energyFactor < 0.99 {
                return String(localized: "trend.advanced.explain.energy.slow")
            }
            if estimate.energyFactor > 1.01 {
                return String(localized: "trend.advanced.explain.energy.fast")
            }
            return String(localized: "trend.advanced.explain.energy.neutral")
        case .period:
            if estimate.periodFactor < 0.99 {
                return String(localized: "trend.advanced.explain.period.active")
            }
            return String(localized: "trend.advanced.explain.period.neutral")
        case .slope:
            return String(localized: "trend.advanced.explain.slope")
        }
    }

    private func factorItem(
        kind: FactorKind,
        symbol: String,
        title: LocalizedStringKey,
        detail: String?,
        factor: Double?,
        inactiveWhenNilDetail: Bool = true,
        iconColor: Color
    ) -> some View {
        let inactive = inactiveWhenNilDetail && detail == nil
        let detailText: String = {
            if let detail { return detail }
            if let factor, abs(factor - 1) < 0.02 {
                return String(localized: "trend.advanced.factor.neutral")
            }
            return "—"
        }()
        let selected = selectedFactor == kind

        return Button {
            withAnimation(TrendAnalysisMotion.accordion) {
                selectedFactor = selected ? nil : kind
            }
        } label: {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 20, height: 20)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(EasePalette.secondaryText)
                        .lineLimit(1)
                    Text(detailText)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(inactive ? EasePalette.secondaryText : EasePalette.primaryText)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .background(
                EasePalette.recessed,
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? EasePalette.primaryText.opacity(0.14) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("trend.advanced.factor.hint"))
        .disabled(inactive)
    }
}
