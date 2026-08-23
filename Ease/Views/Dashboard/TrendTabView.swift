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

    private var stats: TrendRangeStats {
        TrendRangeStats.make(
            records: records,
            logs: logs,
            range: viewModel.chartRange,
            targetWeight: snapshot.targetWeight
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        TrendChartCard(
                            records: records,
                            logs: logs,
                            range: viewModel.chartRange,
                            targetWeight: snapshot.targetWeight > 0 ? snapshot.targetWeight : nil,
                            footer: { TrendSummaryStrip(stats: stats) },
                            onSelectRange: { viewModel.chartRange = $0 },
                            onSelectLog: { viewModel.openWeightLog($0) }
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

/// Three quiet figures under the chart — no nested mini-cards.
struct TrendSummaryStrip: View {
    let stats: TrendRangeStats

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            summaryItem(
                "trend.stats.change",
                stats.change.map(Self.signedKg) ?? "—",
                color: stats.change.map(EasePalette.deltaColor)
            )
            summaryItem(
                "trend.stats.avg",
                stats.average.map(EaseFormatters.kg) ?? "—"
            )
            summaryItem(
                "trend.stats.toTarget",
                stats.distanceToTarget.map(EaseFormatters.kg) ?? "—"
            )
        }
        .padding(.top, 4)
    }

    private func summaryItem(
        _ title: LocalizedStringKey,
        _ value: String,
        color: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(EasePalette.secondaryText)
            Text(value)
                .font(EaseFont.number(20))
                .monospacedDigit()
                .foregroundStyle(color ?? EasePalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func signedKg(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(EaseFormatters.kg(value))"
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

    @State private var showsFactors = false

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
        VStack(alignment: .leading, spacing: 10) {
            Text("trend.advanced.title")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(EasePalette.secondaryText)

            if let estimate {
                Text(EaseFormatters.advancedPaceETA(days: estimate.daysRemaining, date: estimate.eta))
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(EasePalette.primaryText)

                Text(EaseFormatters.signedKgPerDay(estimate.adjustedSlopeKg))
                    .font(.system(size: 14, weight: .regular).monospacedDigit())
                    .foregroundStyle(EasePalette.secondaryText)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showsFactors.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("trend.advanced.factors")
                            .font(.system(size: 13, weight: .medium))
                        Image(systemName: showsFactors ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(EasePalette.secondaryText)
                }
                .buttonStyle(.plain)

                if showsFactors {
                    VStack(alignment: .leading, spacing: 8) {
                        factorLine(
                            "trend.advanced.sleep",
                            estimate.averageSleepHours.map(EaseFormatters.sleepDuration) ?? "—",
                            estimate.sleepFactor
                        )
                        factorLine(
                            "trend.advanced.energy",
                            estimate.averageEnergyKcal.map { EaseFormatters.kcal($0) } ?? "—",
                            estimate.energyFactor
                        )
                        factorLine(
                            "trend.advanced.period",
                            String(
                                format: String(localized: "trend.advanced.periodDays"),
                                locale: .current,
                                estimate.periodDaysInWindow
                            ),
                            estimate.periodFactor
                        )
                    }
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            } else {
                Text("trend.advanced.unavailable")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func factorLine(_ title: LocalizedStringKey, _ value: String, _ factor: Double) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(EasePalette.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .regular).monospacedDigit())
                .foregroundStyle(EasePalette.primaryText)
            Text(EaseFormatters.paceFactor(factor))
                .font(.system(size: 13, weight: .regular).monospacedDigit())
                .foregroundStyle(EasePalette.secondaryText)
                .frame(minWidth: 44, alignment: .trailing)
        }
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
