import SwiftUI

struct AdvancedEstimateCard: View {
    let profile: UserProfile?
    let records: [DailyRecord]
    let logs: [WeightLog]
    let healthByDay: [String: HealthDaySnapshot]
    let sleepHistory: SleepHistory
    let energyHistory: EnergyHistory
    let cycleHistory: CycleHistory
    let snapshot: DashboardSnapshot
    @State private var selectedFactor: FactorKind?

    private enum FactorKind: Hashable {
        case sleep, energy, period, slope
    }

    private var estimate: AdvancedPaceEstimator.Result? {
        let series = HealthInsightEngine.series(
            healthByDay: healthByDay,
            sleepHistory: sleepHistory,
            energyHistory: energyHistory,
            cycleHistory: cycleHistory
        )
        return AdvancedPaceEstimator.estimate(
            samples: WeightMetrics.samples(from: records, logs: logs),
            targetWeight: snapshot.targetWeight,
            displayWeight: snapshot.displayWeight,
            progress: snapshot.progress,
            context: .init(
                sleepHoursByDay: series.sleepHoursByDay,
                energyKcalByDay: series.energyKcalByDay,
                periodDayKeys: series.periodDayKeys,
                sleepTargetHours: profile?.sleepTargetHours ?? 8.0
            )
        )
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
        HStack(alignment: .center, spacing: 12) {
            TrendTintIconTile(systemName: "calendar", tint: EasePalette.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("trend.advanced.horizon")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(EasePalette.primaryText)
                Text(EaseFormatters.advancedPaceHorizon(estimate.eta))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(EasePalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
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
            HStack(alignment: .center, spacing: 10) {
                TrendTintIconTile(systemName: symbol, tint: iconColor)
                    .opacity(inactive ? 0.55 : 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(inactive ? EasePalette.secondaryText : EasePalette.primaryText)
                    Text(detailText)
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(inactive ? EasePalette.secondaryText : EasePalette.primaryText)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(
                selected ? EasePalette.recessed : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("trend.advanced.factor.hint"))
        .disabled(inactive)
    }
}
