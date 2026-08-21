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
                    VStack(spacing: 20) {
                        TrendChartCard(
                            records: records,
                            logs: logs,
                            healthByDay: viewModel.healthByDay,
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
            .navigationBarTitleDisplayMode(.inline)
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
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statCell("trend.stats.high", stats.high.map(EaseFormatters.kg))
            statCell("trend.stats.low", stats.low.map(EaseFormatters.kg))
            statCell("trend.stats.avg", stats.average.map(EaseFormatters.kg))
            statCell("trend.stats.change", stats.change.map(Self.signedKg))
            statCell("trend.stats.toTarget", stats.distanceToTarget.map(EaseFormatters.kg))
            statCell("trend.stats.days", stats.recordedDays.map { "\($0)" })
        }
    }

    private func statCell(_ title: LocalizedStringKey, _ value: String?) -> some View {
        EaseRecessedCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
                Text(value ?? "—")
                    .font(EaseFont.number(22))
                    .monospacedDigit()
                    .foregroundStyle(EasePalette.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private static func signedKg(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(EaseFormatters.kg(value))"
    }
}

struct TrendRangeStats {
    var high: Double?
    var low: Double?
    var average: Double?
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
        let weights = lastPerDay.map(\.weight)
        let high = weights.max()
        let low = weights.min()
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
        return TrendRangeStats(
            high: high.map(MeasurementBounds.roundedToTenth),
            low: low.map(MeasurementBounds.roundedToTenth),
            average: average,
            change: change,
            distanceToTarget: distance,
            recordedDays: weights.isEmpty ? nil : weights.count
        )
    }
}
