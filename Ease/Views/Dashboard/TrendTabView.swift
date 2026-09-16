import SwiftUI
import UIKit

struct TrendTabView: View {
    @Bindable var viewModel: DashboardViewModel
    let profile: UserProfile?
    let records: [DailyRecord]
    let logs: [WeightLog]

    @State private var chartFocusDate: Date?
    @State private var chartFocusNonce = 0

    private var snapshot: DashboardSnapshot {
        DashboardSnapshot.make(
            profile: profile,
            records: records,
            logs: logs,
            now: viewModel.selectedDate
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                if hasWeighIns {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: EaseLayout.sectionSpacing) {
                                TrendChartCard(
                                    records: records,
                                    logs: logs,
                                    range: viewModel.chartRange,
                                    targetWeight: snapshot.targetWeight > 0 ? snapshot.targetWeight : nil,
                                    logSheetPresented: viewModel.isLogPresented,
                                    focusDate: chartFocusDate,
                                    focusNonce: chartFocusNonce,
                                    onSelectRange: { viewModel.chartRange = $0 },
                                    onSelectLog: { viewModel.openWeightLog($0) }
                                )
                                .id("trend.chart")
                                TrendStatsGrid(
                                    records: records,
                                    logs: logs,
                                    range: viewModel.chartRange,
                                    targetWeight: snapshot.targetWeight,
                                    onFocusDay: { date in
                                        if let date {
                                            chartFocusDate = date
                                            chartFocusNonce += 1
                                        }
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            proxy.scrollTo("trend.chart", anchor: .top)
                                        }
                                    }
                                )
                                AdvancedPaceCard(
                                    profile: profile,
                                    records: records,
                                    logs: logs,
                                    healthByDay: viewModel.healthByDay,
                                    sleepHistory: viewModel.sleepHistory,
                                    energyHistory: viewModel.energyHistory,
                                    cycleHistory: viewModel.cycleHistory,
                                    snapshot: snapshot
                                )
                                HealthInsightsCard(insights: insightReport.trend)
                            }
                            .easeTabScrollContent()
                        }
                    }
                } else {
                    EaseEmptyState(
                        symbol: "chart.xyaxis.line",
                        title: "empty.trend.title",
                        message: "empty.trend.message",
                        action: { viewModel.openWeightEntry(for: .now) }
                    )
                    .easeTabScrollContent()
                }
            }
            .navigationTitle("tab.trend")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
    }

    private var hasWeighIns: Bool {
        !WeightMetrics.samples(from: records, logs: logs).isEmpty
    }

    private var insightReport: HealthInsightReport {
        HealthInsightEngine.report(
            records: records,
            logs: logs,
            healthByDay: viewModel.healthByDay,
            sleepHistory: viewModel.sleepHistory,
            energyHistory: viewModel.energyHistory,
            cycleHistory: viewModel.cycleHistory
        )
    }
}

struct AdvancedPaceCard: View {
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
                Text("trend.advanced.title")
                    .font(.headline)
                    .foregroundStyle(EasePalette.primaryText)

                if let estimate {
                    Text(EaseFormatters.advancedPaceHorizon(estimate.eta))
                        .font(.system(.title, design: .rounded, weight: .bold))
                        .foregroundStyle(EasePalette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 12)

                    Divider()
                        .overlay(EasePalette.hairline)
                        .padding(.vertical, 16)

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

                    if let selectedFactor {
                        Text(factorExplanation(selectedFactor, estimate: estimate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 12)
                    }

                    Text("trend.advanced.subtitle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 18)
                } else {
                    Text("trend.advanced.unavailable")
                        .font(.subheadline)
                        .foregroundStyle(EasePalette.secondaryText)
                        .padding(.top, 12)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sensoryFeedback(.selection, trigger: selectedFactor)
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
            selectedFactor = selected ? nil : kind
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(inactive ? iconColor.opacity(0.35) : iconColor)
                    .frame(width: 18, alignment: .center)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(inactive ? EasePalette.secondaryText.opacity(0.55) : EasePalette.primaryText)
                    Text(detailText)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(inactive ? EasePalette.secondaryText.opacity(0.45) : EasePalette.secondaryText)
                        .contentTransition(.numericText())
                    if let factor, abs(factor - 1) >= 0.02, !inactive {
                        Text(EaseFormatters.paceFactor(factor))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .background(
                selected ? EasePalette.recessed : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .opacity(inactive ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("trend.advanced.factor.hint"))
    }
}

struct TrendStatsGrid: View {
    let records: [DailyRecord]
    let logs: [WeightLog]
    let range: ChartRange
    let targetWeight: Double
    var onFocusDay: (Date?) -> Void = { _ in }

    @State private var selectionTick = 0

    private var stats: TrendRangeStats {
        TrendRangeStats.make(records: records, logs: logs, range: range, targetWeight: targetWeight)
    }

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: EaseLayout.gridGap),
                GridItem(.flexible(), spacing: EaseLayout.gridGap),
                GridItem(.flexible(), spacing: EaseLayout.gridGap)
            ],
            spacing: EaseLayout.gridGap
        ) {
            weightStat(
                "trend.stats.high",
                value: stats.high,
                subtitle: stats.highDate.map { $0.formatted(.dateTime.month(.defaultDigits).day()) },
                focusDate: stats.highDate
            )
            weightStat(
                "trend.stats.low",
                value: stats.low,
                subtitle: stats.lowDate.map { $0.formatted(.dateTime.month(.defaultDigits).day()) },
                focusDate: stats.lowDate
            )
            weightStat(
                "trend.stats.avg",
                value: stats.average,
                subtitle: stats.averageCaption
            )
            weightStat(
                "trend.stats.change",
                value: stats.change,
                signed: true,
                valueColor: stats.change.map(EasePalette.semanticDelta),
                focusDate: stats.lastDate
            )
            weightStat(
                "trend.stats.toTarget",
                value: stats.distanceToTarget,
                focusDate: stats.lastDate
            )
            statCell(
                title: "trend.stats.days",
                number: stats.recordedDays.map(String.init),
                unit: stats.recordedDays == nil
                    ? nil
                    : String(localized: "trend.stats.days.unit"),
                subtitle: nil,
                valueColor: nil,
                focusDate: nil
            )
        }
        .sensoryFeedback(.selection, trigger: selectionTick)
    }

    private func weightStat(
        _ title: LocalizedStringKey,
        value: Double?,
        signed: Bool = false,
        subtitle: String? = nil,
        valueColor: Color? = nil,
        focusDate: Date? = nil
    ) -> some View {
        let number: String? = {
            guard let value else { return nil }
            let core = EaseFormatters.oneDecimal(abs(value))
            if signed {
                if value > 0 { return "+\(core)" }
                if value < 0 { return "-\(core)" }
            }
            return core
        }()
        return statCell(
            title: title,
            number: number,
            unit: number == nil ? nil : String(localized: "unit.kg"),
            subtitle: subtitle,
            valueColor: valueColor,
            focusDate: focusDate
        )
    }

    private func statCell(
        title: LocalizedStringKey,
        number: String?,
        unit: String?,
        subtitle: String?,
        valueColor: Color?,
        focusDate: Date?
    ) -> some View {
        Button {
            selectionTick += 1
            onFocusDay(focusDate)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(number ?? "—")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(valueColor ?? EasePalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.numericText())
                    if let unit, number != nil {
                        Text(unit)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint(focusDate == nil ? Text("trend.stats.chart.hint") : Text("trend.stats.focus.hint"))
    }
}

struct TrendRangeStats {
    var high: Double?
    var highDate: Date?
    var low: Double?
    var lowDate: Date?
    var average: Double?
    var averageCaption: String?
    var change: Double?
    var distanceToTarget: Double?
    var recordedDays: Int?
    var lastDate: Date?

    static func make(
        records: [DailyRecord],
        logs: [WeightLog],
        range: ChartRange,
        targetWeight: Double,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TrendRangeStats {
        let end = CalendarDay.startOfDay(now, calendar: calendar)
        let start: Date
        if let count = range.dayCount {
            start = CalendarDay.addingDays(-(count - 1), to: end, calendar: calendar)
        } else {
            let samples = WeightMetrics.samples(from: records, logs: logs, calendar: calendar)
            start = samples.map(\.date).min().map { CalendarDay.startOfDay($0, calendar: calendar) } ?? end
        }
        let lastPerDay = WeightMetrics.lastPerDay(
            samples: WeightMetrics.samples(from: records, logs: logs, calendar: calendar),
            calendar: calendar
        )
        .filter {
            let day = CalendarDay.startOfDay($0.date, calendar: calendar)
            return day >= start && day <= end
        }
        let highSample = lastPerDay.max(by: { $0.weight < $1.weight })
        let lowSample = lastPerDay.min(by: { $0.weight < $1.weight })
        let weights = lastPerDay.map(\.weight)
        let average = weights.isEmpty
            ? nil
            : MeasurementBounds.roundedToTenth(weights.reduce(0, +) / Double(weights.count))
        let change: Double?
        if let first = lastPerDay.first?.weight, let last = lastPerDay.last?.weight {
            change = MeasurementBounds.roundedToTenth(last - first)
        } else {
            change = nil
        }
        let distance: Double?
        if let last = lastPerDay.last?.weight, targetWeight > 0 {
            distance = MeasurementBounds.roundedToTenth(abs(last - targetWeight))
        } else {
            distance = nil
        }
        let caption: String?
        if let count = range.dayCount {
            caption = String(format: String(localized: "trend.stats.avg.range"), locale: .current, count)
        } else {
            caption = String(localized: "trend.stats.avg.all")
        }
        return TrendRangeStats(
            high: highSample.map { MeasurementBounds.roundedToTenth($0.weight) },
            highDate: highSample?.date,
            low: lowSample.map { MeasurementBounds.roundedToTenth($0.weight) },
            lowDate: lowSample?.date,
            average: average,
            averageCaption: weights.isEmpty ? nil : caption,
            change: change,
            distanceToTarget: distance,
            recordedDays: weights.isEmpty ? nil : weights.count,
            lastDate: lastPerDay.last?.date
        )
    }
}
