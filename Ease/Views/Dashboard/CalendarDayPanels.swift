import SwiftUI
import UIKit

// MARK: - Premium panel shell

struct CalendarPremiumPanel<Content: View>: View {
    var contentInset: CGFloat = 22
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        content()
            .padding(contentInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(EasePalette.card, in: shape)
            .overlay(shape.strokeBorder(Color.black.opacity(0.04), lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Daily snapshot

struct DailySnapshotView: View {
    @Bindable var viewModel: DashboardViewModel
    let snapshot: CalendarMonthSnapshot

    var body: some View {
        let selected = snapshot.day(for: viewModel.selectedDate)
        let hasLogs = selected.map(\.hasLogs) ?? false

        if let selected, hasLogs {
            Button {
                viewModel.openWeightEntry(for: selected.date)
            } label: {
                CalendarPremiumPanel {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .center, spacing: 8) {
                            Text(selected.date, format: EaseDateFormat.weekdayMonthDay)
                                .font(.headline)
                                .foregroundStyle(EasePalette.primaryText)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: EaseLayout.gridGap),
                                GridItem(.flexible(), spacing: EaseLayout.gridGap)
                            ],
                            alignment: .leading,
                            spacing: 12
                        ) {
                            DailyMetricTile(
                                symbol: "scalemass.fill",
                                fill: HomeModule.weight.fill,
                                title: "calendar.detail.weight",
                                value: selected.weight.map { EaseFormatters.kg($0) }
                            )
                            DailyMetricTile(
                                symbol: "moon.fill",
                                fill: HomeModule.sleep.fill,
                                title: "calendar.detail.sleep",
                                value: selected.sleepHours.map(EaseFormatters.sleepDuration)
                            )
                            DailyMetricTile(
                                symbol: "flame.fill",
                                fill: HomeModule.energy.fill,
                                title: "health.energy",
                                value: selected.activeEnergyKcal.map { EaseFormatters.kcal($0) }
                            )
                            DailyMetricTile(
                                symbol: "drop.fill",
                                fill: HomeModule.period.fill,
                                title: "calendar.detail.period",
                                value: periodValue(
                                    dayNumber: selected.periodDayNumber,
                                    logged: selected.marks.contains(.period)
                                )
                            )
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(Text("calendar.detail.openLog.hint"))
        } else {
            Button {
                viewModel.openWeightEntry(for: viewModel.selectedDate)
            } label: {
                Text(emptyCTATitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(EasePalette.primaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 16)
                    .background(EasePalette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(
                                EasePalette.secondaryText.opacity(0.28),
                                style: StrokeStyle(lineWidth: 1.2, dash: [6, 4])
                            )
                    }
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyCTATitle: String {
        String(
            format: String(localized: "calendar.cta.logData"),
            locale: .current,
            viewModel.selectedDate.formatted(EaseDateFormat.monthDay)
        )
    }

    private func periodValue(dayNumber: Int?, logged: Bool) -> String? {
        if let dayNumber {
            return String(format: String(localized: "calendar.detail.periodDay"), locale: .current, dayNumber)
        }
        return logged ? String(localized: "calendar.detail.periodYes") : nil
    }
}

private struct DailyMetricTile: View {
    let symbol: String
    let fill: Color
    let title: LocalizedStringKey
    let value: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(EasePalette.primaryText)
                .accessibilityHidden(true)

            Text(title)
                .font(.caption)
                .foregroundStyle(EasePalette.secondaryText)
                .lineLimit(1)
            Text(value ?? "—")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(EasePalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Monthly overview

struct MonthlyOverviewCard: View {
    @Bindable var viewModel: DashboardViewModel
    let snapshot: CalendarMonthSnapshot

    private enum Layout {
        static let panelInset: CGFloat = 16
        static let sectionSpacing: CGFloat = 14
        static let middleColumnSpacing: CGFloat = 12
        static let metricLabelSpacing: CGFloat = 6
        static let footerColumnSpacing: CGFloat = 16
        static let footerInsetH: CGFloat = 12
        static let footerInsetV: CGFloat = 10
    }

    var body: some View {
        let weekAverageWeight = WeekWeightStats.averageWeight(
            weightIndex: WeightMetrics.DayIndex(lastWeightByDay: snapshot.lastWeightByDay),
            weekContaining: viewModel.selectedDate
        )
        let stats = snapshot.stats
        let logProgress = stats.elapsedDays > 0
            ? Double(stats.checkinDays) / Double(stats.elapsedDays)
            : 0

        CalendarPremiumPanel(contentInset: Layout.panelInset) {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                Text(overviewTitle)
                    .font(.headline)
                    .foregroundStyle(EasePalette.primaryText)

                HStack(alignment: .center, spacing: Layout.middleColumnSpacing) {
                    netChangeColumn(delta: stats.monthDelta)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    logProgressColumn(
                        progress: logProgress,
                        checkins: stats.checkinDays,
                        elapsed: stats.elapsedDays
                    )
                    .frame(maxWidth: .infinity)
                }

                averagesFooter(
                    monthAverage: stats.averageWeight.map { EaseFormatters.kg($0) },
                    weekAverage: weekAverageWeight.map { EaseFormatters.kg($0) }
                )

                if snapshot.workoutStats.days > 0 {
                    workoutOverview(snapshot.workoutStats)
                }
            }
        }
    }

    private var overviewTitle: String {
        String(
            format: String(localized: "calendar.overview.title"),
            locale: .current,
            snapshot.month.formatted(EaseDateFormat.monthWide)
        )
    }

    private func netChangeColumn(delta: Double?) -> some View {
        let valueColor = delta.map(EasePalette.semanticDelta) ?? Color.primary
        return VStack(alignment: .leading, spacing: Layout.metricLabelSpacing) {
            overviewMetricLabel("calendar.stat.monthDelta")
            Text(netChangeText(delta) ?? "—")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
    }

    private func logProgressColumn(progress: Double, checkins: Int, elapsed: Int) -> some View {
        VStack(spacing: Layout.metricLabelSpacing) {
            ZStack {
                EaseArcRing(
                    progress: progress,
                    colors: [EasePalette.morandiGreen, EasePalette.mint],
                    lineWidth: 8,
                    diameter: 76
                )
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(checkins)")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text("/ \(elapsed)")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.primary.opacity(0.72))
                }
            }
            overviewMetricLabel("calendar.stat.loggedDays")
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: String(localized: "calendar.stat.loggedDays.value"),
                locale: .current,
                checkins,
                elapsed
            )
        )
    }

    private func workoutOverview(_ stats: MonthWorkoutStats) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                TrendModuleGlyph(systemName: "figure.run", tint: EasePalette.iconEnergy)
                VStack(alignment: .leading, spacing: 2) {
                    overviewMetricLabel("calendar.overview.workoutDays")
                    Text(
                        String(
                            format: String(localized: "calendar.overview.workoutDays.value"),
                            locale: .current,
                            stats.days
                        )
                    )
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }

            HStack(alignment: .top, spacing: Layout.footerColumnSpacing) {
                averageFooterCell(
                    title: "calendar.overview.totalDuration",
                    value: stats.totalMinutes > 0 ? EaseFormatters.workoutDuration(stats.totalMinutes) : nil
                )
                averageFooterCell(
                    title: "calendar.overview.totalKcal",
                    value: stats.days > 0 ? EaseFormatters.kcal(stats.totalKcal) : nil
                )
            }
            HStack(alignment: .top, spacing: Layout.footerColumnSpacing) {
                averageFooterCell(
                    title: "calendar.overview.avgDuration",
                    value: stats.averageMinutes.map(EaseFormatters.workoutDuration)
                )
                averageFooterCell(
                    title: "calendar.overview.avgKcal",
                    value: stats.averageKcal.map { EaseFormatters.kcal($0) }
                )
            }
        }
        .padding(.horizontal, Layout.footerInsetH)
        .padding(.vertical, Layout.footerInsetV)
        .background(
            Color(uiColor: .secondarySystemFill),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private func averagesFooter(monthAverage: String?, weekAverage: String?) -> some View {
        HStack(alignment: .top, spacing: Layout.footerColumnSpacing) {
            averageFooterCell(title: "calendar.stat.monthAvg", value: monthAverage)
            averageFooterCell(title: "calendar.stat.weekAvg", value: weekAverage)
        }
        .padding(.horizontal, Layout.footerInsetH)
        .padding(.vertical, Layout.footerInsetV)
        .background(
            Color(uiColor: .secondarySystemFill),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func averageFooterCell(title: LocalizedStringKey, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            overviewMetricLabel(title)
            Text(value ?? "—")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func overviewMetricLabel(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption)
            .foregroundStyle(Color.primary.opacity(0.8))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }

    private func netChangeText(_ delta: Double?) -> String? {
        guard let delta else { return nil }
        if delta == 0 {
            return EaseFormatters.kg(0)
        }
        let arrow = delta < 0 ? "▼ " : "▲ "
        return arrow + EaseFormatters.oneDecimal(abs(delta)) + "\u{00A0}" + String(localized: "unit.kg")
    }
}
