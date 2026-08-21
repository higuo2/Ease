import SwiftUI

struct TrendTabView: View {
    @Bindable var viewModel: DashboardViewModel
    let profile: UserProfile?
    let records: [DailyRecord]
    let logs: [WeightLog]

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
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        TrendChartCard(
                            records: records,
                            logs: logs,
                            range: viewModel.chartRange,
                            targetWeight: snapshot.targetWeight > 0 ? snapshot.targetWeight : nil,
                            onSelectRange: { viewModel.chartRange = $0 },
                            onSelectLog: { viewModel.openWeightLog($0) }
                        )
                        TrendStatsGrid(
                            records: records,
                            logs: logs,
                            range: viewModel.chartRange,
                            targetWeight: snapshot.targetWeight
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("tab.trend")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
    }
}

struct TrendStatsGrid: View {
    let records: [DailyRecord]
    let logs: [WeightLog]
    let range: ChartRange
    let targetWeight: Double

    private var stats: TrendRangeStats {
        TrendRangeStats.make(records: records, logs: logs, range: range, targetWeight: targetWeight)
    }

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            statCell(
                "trend.stats.high",
                stats.high.map(EaseFormatters.oneDecimal),
                subtitle: stats.highDate.map { $0.formatted(.dateTime.month(.defaultDigits).day()) }
            )
            statCell(
                "trend.stats.low",
                stats.low.map(EaseFormatters.oneDecimal),
                subtitle: stats.lowDate.map { $0.formatted(.dateTime.month(.defaultDigits).day()) }
            )
            statCell(
                "trend.stats.avg",
                stats.average.map(EaseFormatters.oneDecimal),
                subtitle: stats.averageCaption
            )
            statCell(
                "trend.stats.change",
                stats.change.map(Self.signedKg),
                valueColor: stats.change.map(EasePalette.deltaColor)
            )
            statCell(
                "trend.stats.toTarget",
                stats.distanceToTarget.map(EaseFormatters.kg)
            )
            statCell(
                "trend.stats.days",
                stats.recordedDays.map { String(format: String(localized: "trend.stats.days.value"), locale: .current, $0) }
            )
        }
    }

    private func statCell(
        _ title: LocalizedStringKey,
        _ value: String?,
        subtitle: String? = nil,
        valueColor: Color? = nil
    ) -> some View {
        EaseRecessedCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
                Text(value ?? "—")
                    .font(EaseFont.number(20))
                    .monospacedDigit()
                    .foregroundStyle(valueColor ?? EasePalette.primaryText)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        }
    }

    private static func signedKg(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(EaseFormatters.kg(value))"
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
            recordedDays: weights.isEmpty ? nil : weights.count
        )
    }
}
