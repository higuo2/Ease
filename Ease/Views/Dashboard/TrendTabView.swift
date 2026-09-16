import SwiftUI
import UIKit

struct TrendTabView: View {
    @Bindable var viewModel: DashboardViewModel
    let profile: UserProfile?
    let records: [DailyRecord]
    let logs: [WeightLog]

    @State private var chartFocusDate: Date?
    @State private var chartFocusNonce = 0
    @State private var chartModel: TrendChartModel?
    @State private var rangeStats: TrendRangeStats?
    @State private var snapshot: DashboardSnapshot?
    @State private var estimate: AdvancedPaceEstimator.Result?
    @State private var insights: [HealthInsight] = []

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                if hasWeighIns {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: EaseLayout.sectionSpacing) {
                                if let chartModel {
                                    TrendChartCard(
                                        model: chartModel,
                                        targetWeight: snapshot.flatMap { $0.targetWeight > 0 ? $0.targetWeight : nil },
                                        logSheetPresented: viewModel.isLogPresented,
                                        focusDate: chartFocusDate,
                                        focusNonce: chartFocusNonce,
                                        onSelectRange: { viewModel.chartRange = $0 },
                                        onSelectLog: { id, timestamp in
                                            viewModel.openWeightLog(id: id, timestamp: timestamp)
                                        }
                                    )
                                    .id("trend.chart")
                                }
                                if let rangeStats {
                                    TrendStatsGrid(
                                        stats: rangeStats,
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
                                }
                                AdvancedEstimateCard(
                                    snapshot: snapshot,
                                    estimate: estimate
                                )
                                HealthInsightsCard(insights: insights)
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
            .onChange(of: chartComputeID, initial: true) { _, _ in
                refreshChart()
            }
            .onChange(of: analysisComputeID, initial: true) { _, _ in
                refreshAnalysis()
            }
        }
    }

    private var hasWeighIns: Bool {
        !logs.isEmpty || records.contains { $0.weight != nil }
    }

    /// Chart series + range stats. Omits health insights and selected-day snapshot.
    private var chartComputeID: String {
        let logStamp = logs.last.map {
            "\($0.id.uuidString)-\($0.weight)-\($0.timestamp.timeIntervalSinceReferenceDate)"
        } ?? "0"
        let recordStamp = records.last.map {
            "\($0.dayKey)-\($0.weight ?? -1)-\($0.updatedAt.timeIntervalSinceReferenceDate)"
        } ?? "0"
        return "\(records.count)|\(logs.count)|\(viewModel.chartRange.rawValue)|\(profile?.targetWeight ?? 0)|\(logStamp)|\(recordStamp)"
    }

    /// Insights / advanced estimate. Omits chart range so chips don't rebuild analysis.
    private var analysisComputeID: String {
        let logStamp = logs.last.map { "\($0.id.uuidString)-\($0.weight)" } ?? "0"
        return [
            "\(records.count)",
            "\(logs.count)",
            "\(viewModel.healthByDay.count)",
            "\(viewModel.sleepHistory.nights.count)",
            "\(viewModel.energyHistory.days.count)",
            "\(viewModel.cycleHistory.periodDayKeys.count)",
            "\(profile?.sleepTargetHours ?? 8)",
            "\(profile?.targetWeight ?? 0)",
            "\(profile?.startWeight ?? 0)",
            CalendarDay.dayKey(from: viewModel.selectedDate),
            logStamp
        ].joined(separator: "|")
    }

    private func refreshChart() {
        let model = TrendChartModel.make(
            records: records,
            logs: logs,
            range: viewModel.chartRange,
            targetWeight: profile?.targetWeight
        )
        chartModel = model
        rangeStats = TrendRangeStats.make(
            daily: model.daily,
            range: model.range,
            targetWeight: profile?.targetWeight ?? 0
        )
    }

    private func refreshAnalysis() {
        let nextSnapshot = DashboardSnapshot.make(
            profile: profile,
            records: records,
            logs: logs,
            now: viewModel.selectedDate
        )
        snapshot = nextSnapshot
        let samples = WeightMetrics.samples(from: records, logs: logs)
        let series = HealthInsightEngine.series(
            healthByDay: viewModel.healthByDay,
            sleepHistory: viewModel.sleepHistory,
            energyHistory: viewModel.energyHistory,
            cycleHistory: viewModel.cycleHistory
        )
        insights = HealthInsightEngine.evaluate(
            samples: samples,
            series: series
        ).trend
        estimate = AdvancedPaceEstimator.estimate(
            samples: samples,
            targetWeight: nextSnapshot.targetWeight,
            displayWeight: nextSnapshot.displayWeight,
            progress: nextSnapshot.progress,
            context: .init(
                sleepHoursByDay: series.sleepHoursByDay,
                energyKcalByDay: series.energyKcalByDay,
                periodDayKeys: series.periodDayKeys,
                sleepTargetHours: profile?.sleepTargetHours ?? 8.0
            )
        )
    }
}

struct TrendStatsGrid: View, Equatable {
    let stats: TrendRangeStats
    var onFocusDay: (Date?) -> Void = { _ in }

    @State private var selectionTick = 0

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.stats == rhs.stats
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
                subtitle: stats.highDate.map { $0.formatted(EaseDateFormat.monthDayNumeric) },
                focusDate: stats.highDate
            )
            weightStat(
                "trend.stats.low",
                value: stats.low,
                subtitle: stats.lowDate.map { $0.formatted(EaseDateFormat.monthDayNumeric) },
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

struct TrendRangeStats: Equatable, Sendable {
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
        daily: [TrendChartPoint],
        range: ChartRange,
        targetWeight: Double
    ) -> TrendRangeStats {
        let highSample = daily.max(by: { $0.weight < $1.weight })
        let lowSample = daily.min(by: { $0.weight < $1.weight })
        let weights = daily.map(\.weight)
        let average = weights.isEmpty
            ? nil
            : MeasurementBounds.roundedToTenth(weights.reduce(0, +) / Double(weights.count))
        let change: Double?
        if let first = daily.first?.weight, let last = daily.last?.weight {
            change = MeasurementBounds.roundedToTenth(last - first)
        } else {
            change = nil
        }
        let distance: Double?
        if let last = daily.last?.weight, targetWeight > 0 {
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
            lastDate: daily.last?.date
        )
    }
}
