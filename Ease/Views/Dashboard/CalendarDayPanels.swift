import SwiftUI
import UIKit

// MARK: - Premium panel shell

struct CalendarPremiumPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        content()
            .padding(22)
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

    var body: some View {
        let weekAverageWeight = WeekWeightStats.averageWeight(
            weightIndex: WeightMetrics.DayIndex(lastWeightByDay: snapshot.lastWeightByDay),
            weekContaining: viewModel.selectedDate
        )
        let stats = snapshot.stats
        let logProgress = stats.elapsedDays > 0
            ? Double(stats.checkinDays) / Double(stats.elapsedDays)
            : 0

        CalendarPremiumPanel {
            VStack(alignment: .leading, spacing: 20) {
                Text(overviewTitle)
                    .font(.headline)
                    .foregroundStyle(EasePalette.primaryText)

                HStack(alignment: .center, spacing: 0) {
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
        return VStack(alignment: .leading, spacing: 10) {
            Text("calendar.stat.monthDelta")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(netChangeText(delta) ?? "—")
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .accessibilityElement(children: .combine)
    }

    private func logProgressColumn(progress: Double, checkins: Int, elapsed: Int) -> some View {
        VStack(spacing: 10) {
            ZStack {
                EaseArcRing(
                    progress: progress,
                    colors: [EasePalette.morandiGreen, EasePalette.mint],
                    lineWidth: 8,
                    diameter: 84
                )
                VStack(spacing: 0) {
                    Text("\(checkins)")
                        .font(.headline.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("/ \(elapsed)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text("calendar.stat.loggedDays")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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

    private func averagesFooter(monthAverage: String?, weekAverage: String?) -> some View {
        HStack(spacing: 0) {
            averageFooterCell(title: "calendar.stat.monthAvg", value: monthAverage)
            Divider()
            averageFooterCell(title: "calendar.stat.weekAvg", value: weekAverage)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Color(uiColor: .secondarySystemFill),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func averageFooterCell(title: LocalizedStringKey, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value ?? "—")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
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
