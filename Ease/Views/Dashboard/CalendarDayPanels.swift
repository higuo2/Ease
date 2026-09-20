import SwiftUI
import UIKit

// MARK: - Premium panel shell

struct CalendarPremiumPanel<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(panelBackground)
            .overlay(panelBorder)
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.regularMaterial)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }

    private var panelBorder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
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
                                tint: .blue,
                                title: "calendar.detail.weight",
                                value: selected.weight.map { EaseFormatters.kg($0) }
                            )
                            DailyMetricTile(
                                symbol: "moon.fill",
                                tint: .indigo,
                                title: "calendar.detail.sleep",
                                value: selected.sleepHours.map(EaseFormatters.sleepDuration)
                            )
                            DailyMetricTile(
                                symbol: "flame.fill",
                                tint: .orange,
                                title: "health.energy",
                                value: selected.activeEnergyKcal.map { EaseFormatters.kcal($0) }
                            )
                            DailyMetricTile(
                                symbol: "drop.fill",
                                tint: EasePalette.iconPeriod,
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
    let tint: Color
    let title: LocalizedStringKey
    let value: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .symbolRenderingMode(.hierarchical)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value ?? "—")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(EasePalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            tint.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
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
            VStack(alignment: .leading, spacing: 18) {
                Text(overviewTitle)
                    .font(.headline)
                    .foregroundStyle(EasePalette.primaryText)

                HStack(alignment: .center, spacing: 16) {
                    netChangeHero(delta: stats.monthDelta)
                    logProgressRing(
                        progress: logProgress,
                        checkins: stats.checkinDays,
                        elapsed: stats.elapsedDays
                    )
                }

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    auxiliaryLine(
                        title: "calendar.stat.monthAvg",
                        value: stats.averageWeight.map { EaseFormatters.kg($0) }
                    )
                    Spacer(minLength: 8)
                    auxiliaryLine(
                        title: "calendar.stat.weekAvg",
                        value: weekAverageWeight.map { EaseFormatters.kg($0) }
                    )
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

    private func netChangeHero(delta: Double?) -> some View {
        let tint = delta.map(EasePalette.semanticDelta) ?? EasePalette.primaryText
        return VStack(alignment: .leading, spacing: 8) {
            Text("calendar.stat.monthDelta")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(netChangeText(delta) ?? "—")
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(tint)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            (delta.map { EasePalette.semanticDelta($0).opacity(0.12) } ?? Color.primary.opacity(0.04)),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private func logProgressRing(progress: Double, checkins: Int, elapsed: Int) -> some View {
        VStack(spacing: 6) {
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
                        .foregroundStyle(EasePalette.primaryText)
                    Text("/ \(elapsed)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text("calendar.stat.loggedDays")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 96)
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

    private func auxiliaryLine(title: LocalizedStringKey, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
            Text(value ?? "—")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
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
