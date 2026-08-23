import SwiftUI
import UIKit

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

struct AdvancedPaceCard: View {
    let profile: UserProfile?
    let records: [DailyRecord]
    let logs: [WeightLog]
    let healthByDay: [String: HealthDaySnapshot]
    let sleepHistory: SleepHistory
    let energyHistory: EnergyHistory
    let cycleHistory: CycleHistory
    let snapshot: DashboardSnapshot

    private var estimate: AdvancedPaceEstimator.Result? {
        var sleepMap: [String: Double] = [:]
        for night in sleepHistory.nights {
            if let hours = night.hours {
                sleepMap[night.dayKey] = hours
            }
        }
        for (key, snap) in healthByDay {
            if let hours = snap.previousNightSleepHours {
                sleepMap[key] = sleepMap[key] ?? hours
            }
        }

        var energyMap: [String: Double] = [:]
        for day in energyHistory.days {
            if let kcal = day.kcal {
                energyMap[day.dayKey] = kcal
            }
        }
        for (key, snap) in healthByDay {
            if let kcal = snap.activeEnergyKcal {
                energyMap[key] = energyMap[key] ?? kcal
            }
        }

        var periodKeys = cycleHistory.periodDayKeys
        for (key, snap) in healthByDay where snap.isMenstrual {
            periodKeys.insert(key)
        }

        return AdvancedPaceEstimator.estimate(
            samples: WeightMetrics.samples(from: records, logs: logs),
            targetWeight: snapshot.targetWeight,
            displayWeight: snapshot.displayWeight,
            progress: snapshot.progress,
            context: .init(
                sleepHoursByDay: sleepMap,
                energyKcalByDay: energyMap,
                periodDayKeys: periodKeys,
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
                    VStack(alignment: .leading, spacing: 6) {
                        Text(EaseFormatters.advancedPaceDate(estimate.eta))
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(EasePalette.primaryText)
                        Text(EaseFormatters.advancedPaceDays(estimate.daysRemaining))
                            .font(.subheadline)
                            .foregroundStyle(EasePalette.secondaryText)
                    }
                    .padding(.top, 12)

                    Divider()
                        .overlay(EasePalette.hairline)
                        .padding(.vertical, 16)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        alignment: .leading,
                        spacing: 16
                    ) {
                        factorItem(
                            symbol: "moon.fill",
                            title: "trend.advanced.sleep",
                            detail: estimate.averageSleepHours.map(EaseFormatters.sleepDuration),
                            factor: estimate.sleepFactor
                        )
                        factorItem(
                            symbol: "bolt.fill",
                            title: "trend.advanced.energy",
                            detail: estimate.averageEnergyKcal.map { EaseFormatters.kcal($0) },
                            factor: estimate.energyFactor
                        )
                        factorItem(
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
                            inactiveWhenNilDetail: true
                        )
                        factorItem(
                            symbol: "chart.line.downtrend.xyaxis",
                            title: "trend.advanced.slope",
                            detail: EaseFormatters.signedKgPerDay(estimate.adjustedSlopeKg),
                            factor: nil,
                            inactiveWhenNilDetail: false
                        )
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
    }

    private func factorItem(
        symbol: String,
        title: LocalizedStringKey,
        detail: String?,
        factor: Double?,
        inactiveWhenNilDetail: Bool = true
    ) -> some View {
        let inactive = inactiveWhenNilDetail && detail == nil
        let detailText: String = {
            if let detail { return detail }
            if let factor, abs(factor - 1) < 0.02 {
                return String(localized: "trend.advanced.factor.neutral")
            }
            return "—"
        }()

        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(inactive ? EasePalette.secondaryText.opacity(0.45) : EasePalette.secondaryText)
                .frame(width: 18, alignment: .center)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(inactive ? EasePalette.secondaryText.opacity(0.55) : EasePalette.primaryText)
                Text(detailText)
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(inactive ? EasePalette.secondaryText.opacity(0.45) : EasePalette.secondaryText)
                if let factor, abs(factor - 1) >= 0.02, !inactive {
                    Text(EaseFormatters.paceFactor(factor))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .opacity(inactive ? 0.7 : 1)
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
            weightStat(
                "trend.stats.high",
                value: stats.high,
                subtitle: stats.highDate.map { $0.formatted(.dateTime.month(.defaultDigits).day()) }
            )
            weightStat(
                "trend.stats.low",
                value: stats.low,
                subtitle: stats.lowDate.map { $0.formatted(.dateTime.month(.defaultDigits).day()) }
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
                valueColor: stats.change.map(EasePalette.deltaColor)
            )
            weightStat(
                "trend.stats.toTarget",
                value: stats.distanceToTarget
            )
            statCell(
                title: "trend.stats.days",
                number: stats.recordedDays.map(String.init),
                unit: stats.recordedDays == nil
                    ? nil
                    : String(localized: "trend.stats.days.unit"),
                subtitle: nil,
                valueColor: nil
            )
        }
    }

    private func weightStat(
        _ title: LocalizedStringKey,
        value: Double?,
        signed: Bool = false,
        subtitle: String? = nil,
        valueColor: Color? = nil
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
            valueColor: valueColor
        )
    }

    private func statCell(
        title: LocalizedStringKey,
        number: String?,
        unit: String?,
        subtitle: String?,
        valueColor: Color?
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(number ?? "—")
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(valueColor ?? EasePalette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
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
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
