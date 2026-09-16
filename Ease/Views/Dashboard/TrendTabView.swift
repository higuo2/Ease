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
                                AdvancedEstimateCard(
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
