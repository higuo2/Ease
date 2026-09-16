import SwiftUI

struct CalendarTabView: View {
    @Bindable var viewModel: DashboardViewModel
    let records: [DailyRecord]
    let logs: [WeightLog]

    @State private var visibleMonth = CalendarDay.startOfMonth(.now)
    @State private var daySheet: DaySheetItem?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var selectedDate: Date { viewModel.selectedDate }
    private var selectedDayKey: String { CalendarDay.dayKey(from: selectedDate) }
    private var monthDays: [Date] { CalendarDay.daysInMonth(containing: visibleMonth) }
    private var leadingEmpty: Int { CalendarDay.leadingEmptyDays(inMonthContaining: visibleMonth) }
    private var weekdaySymbols: [String] { CalendarDay.weekdayHeaderSymbols() }
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    var body: some View {
        let weightIndex = WeightMetrics.DayIndex.make(records: records, logs: logs)
        let monthStats = MonthWeightStats.make(
            weightIndex: weightIndex,
            monthContaining: visibleMonth
        )
        let weekAverageWeight = WeekWeightStats.averageWeight(
            weightIndex: weightIndex,
            weekContaining: selectedDate
        )
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: EaseLayout.sectionSpacing) {
                        monthHeader
                        calendarCard(weightIndex: weightIndex)
                        monthOverviewCard(monthStats: monthStats, weekAverageWeight: weekAverageWeight)
                    }
                    .easeTabScrollContent()
                }
            }
            .navigationTitle("tab.calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(EasePalette.background, for: .navigationBar)
            .sheet(item: $daySheet) { item in
                CalendarDayDetailSheet(
                    date: item.date,
                    logs: logs,
                    onLogWeight: {
                        daySheet = nil
                        viewModel.openWeightEntry(for: item.date)
                    }
                )
                .easeSheetPresentation()
            }
            .sensoryFeedback(.selection, trigger: CalendarDay.dayKey(from: visibleMonth))
        }
    }

    private var monthHeader: some View {
        HStack {
            Button {
                if let previous = Calendar.current.date(byAdding: .month, value: -1, to: visibleMonth) {
                    visibleMonth = CalendarDay.startOfMonth(previous)
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EasePalette.primaryText)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("calendar.previousMonth"))

            Spacer()
            Text(visibleMonth, format: .dateTime.year().month(.wide))
                .font(.headline)
                .foregroundStyle(EasePalette.primaryText)
            Spacer()

            Button {
                guard let next = Calendar.current.date(byAdding: .month, value: 1, to: visibleMonth) else { return }
                let nextMonth = CalendarDay.startOfMonth(next)
                guard nextMonth <= CalendarDay.startOfMonth(.now) else { return }
                visibleMonth = nextMonth
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EasePalette.primaryText)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("calendar.nextMonth"))
            .disabled(CalendarDay.startOfMonth(visibleMonth) >= CalendarDay.startOfMonth(.now))
            .opacity(CalendarDay.startOfMonth(visibleMonth) >= CalendarDay.startOfMonth(.now) ? 0.35 : 1)
        }
    }

    private func calendarCard(
        weightIndex: WeightMetrics.DayIndex
    ) -> some View {
        EaseCard(padding: 16) {
            VStack(spacing: 12) {
                LazyVGrid(columns: gridColumns, spacing: 4) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(0..<leadingEmpty, id: \.self) { _ in
                        Color.clear.frame(height: dayCellHeight)
                    }
                    ForEach(monthDays, id: \.self) { day in
                        dayCell(day, weightIndex: weightIndex)
                    }
                }
            }
        }
    }

    private var isAccessibilityType: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var dayCellHeight: CGFloat {
        isAccessibilityType ? 96 : 72
    }

    private var metricLineHeight: CGFloat {
        isAccessibilityType ? 18 : 14
    }

    private func dayCell(
        _ day: Date,
        weightIndex: WeightMetrics.DayIndex
    ) -> some View {
        let isFuture = CalendarDay.isFuture(day)
        let isSelected = CalendarDay.dayKey(from: day) == selectedDayKey
        let isToday = Calendar.current.isDateInToday(day)
        let weight = weightIndex.weight(on: day)
        let delta = weightIndex.delta(on: day)

        return Button {
            guard !isFuture else { return }
            let start = CalendarDay.startOfDay(day)
            if isSelected {
                daySheet = DaySheetItem(date: start)
            } else {
                viewModel.selectedDate = start
            }
        } label: {
            VStack(spacing: 4) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.system(.body, design: .rounded, weight: isSelected ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(dayNumberStyle(isFuture: isFuture, isSelected: isSelected))
                    .frame(width: 30, height: 30)
                    .background {
                        if isSelected {
                            Circle().fill(EasePalette.accent.opacity(0.15))
                        }
                    }
                    .overlay {
                        if isToday {
                            Circle().stroke(EasePalette.accent, lineWidth: 1.5)
                        }
                    }

                Group {
                    if let weight {
                        Text(EaseFormatters.oneDecimal(weight))
                            .font(metricFont)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: metricLineHeight)

                Group {
                    if let delta {
                        HStack(spacing: 0) {
                            Text(deltaPrefix(delta))
                                .foregroundStyle(.secondary)
                            Text(EaseFormatters.oneDecimal(abs(delta)))
                                .foregroundStyle(EasePalette.semanticDelta(delta))
                        }
                        .font(isAccessibilityType ? .caption.weight(.medium) : .caption2.weight(.medium))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: metricLineHeight)
            }
            .frame(maxWidth: .infinity)
            .frame(height: dayCellHeight)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private var metricFont: Font {
        isAccessibilityType ? .caption : .caption2
    }

    private func dayNumberStyle(isFuture: Bool, isSelected: Bool) -> AnyShapeStyle {
        if isFuture { return AnyShapeStyle(.tertiary) }
        if isSelected { return AnyShapeStyle(EasePalette.accent) }
        return AnyShapeStyle(EasePalette.primaryText)
    }

    private func deltaPrefix(_ delta: Double) -> String {
        if delta < 0 { return "▼" }
        if delta > 0 { return "▲" }
        return ""
    }

    private func monthOverviewCard(
        monthStats: MonthWeightStats,
        weekAverageWeight: Double?
    ) -> some View {
        EaseCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text(overviewTitle)
                    .font(.headline)
                    .foregroundStyle(EasePalette.primaryText)

                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    overviewHero(
                        "calendar.stat.monthAvg",
                        monthStats.averageWeight.map(EaseFormatters.oneDecimal)
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    netChangeHero(monthDelta: monthStats.monthDelta)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Divider().overlay(EasePalette.hairline)

                HStack(alignment: .top, spacing: 8) {
                    compactStat("calendar.stat.weekAvg", kgValue(weekAverageWeight))
                    compactStat("calendar.stat.checkins", loggedDaysValue(monthStats.checkinDays))
                    compactStat("calendar.stat.lossDays", "\(monthStats.lossDays)")
                    compactStat("calendar.stat.gainDays", "\(monthStats.gainDays)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var overviewTitle: String {
        String(
            format: String(localized: "calendar.overview.title"),
            locale: .current,
            visibleMonth.formatted(.dateTime.month(.wide))
        )
    }

    private func overviewHero(
        _ title: LocalizedStringKey,
        _ value: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value ?? "—")
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(EasePalette.primaryText)
                if value != nil {
                    Text("unit.kg")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func netChangeHero(monthDelta: Double?) -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("calendar.stat.monthDelta")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let delta = monthDelta {
                Text(deltaPrefix(delta) + EaseFormatters.oneDecimal(abs(delta)) + "\u{00A0}" + String(localized: "unit.kg"))
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(EasePalette.semanticDelta(delta))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("—")
                    .font(.title2.bold())
                    .foregroundStyle(EasePalette.primaryText)
            }
        }
    }

    private func compactStat(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(EasePalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func kgValue(_ value: Double?) -> String {
        guard let value else { return "—" }
        return EaseFormatters.oneDecimal(value) + "\u{00A0}" + String(localized: "unit.kg")
    }

    private func loggedDaysValue(_ days: Int) -> String {
        String(format: String(localized: "calendar.stat.daysCount"), locale: .current, days)
    }
}

private struct DaySheetItem: Identifiable {
    let date: Date
    var id: String { CalendarDay.dayKey(from: date) }
}

struct MonthWeightStats {
    var checkinDays: Int
    var lossDays: Int
    var gainDays: Int
    var averageDelta: Double?
    var monthDelta: Double?
    var averageWeight: Double?

    static func make(
        weightIndex: WeightMetrics.DayIndex,
        monthContaining date: Date,
        calendar: Calendar = .current
    ) -> MonthWeightStats {
        let days = CalendarDay.daysInMonth(containing: date, calendar: calendar)
            .filter { !CalendarDay.isFuture($0, calendar: calendar) }
        var checkins = 0
        var loss = 0
        var gain = 0
        var deltas: [Double] = []
        var weights: [Double] = []
        var firstWeight: Double?
        var lastWeight: Double?

        for day in days {
            guard let weight = weightIndex.weight(on: day, calendar: calendar) else {
                continue
            }
            checkins += 1
            weights.append(weight)
            if firstWeight == nil { firstWeight = weight }
            lastWeight = weight
            if let delta = weightIndex.delta(on: day, calendar: calendar) {
                deltas.append(delta)
                if delta < 0 { loss += 1 }
                if delta > 0 { gain += 1 }
            }
        }

        let average = deltas.isEmpty
            ? nil
            : MeasurementBounds.roundedToTenth(deltas.reduce(0, +) / Double(deltas.count))
        let monthDelta: Double?
        if let firstWeight, let lastWeight {
            monthDelta = MeasurementBounds.roundedToTenth(lastWeight - firstWeight)
        } else {
            monthDelta = nil
        }
        let averageWeight = weights.isEmpty
            ? nil
            : MeasurementBounds.roundedToTenth(weights.reduce(0, +) / Double(weights.count))

        return MonthWeightStats(
            checkinDays: checkins,
            lossDays: loss,
            gainDays: gain,
            averageDelta: average,
            monthDelta: monthDelta,
            averageWeight: averageWeight
        )
    }
}

enum WeekWeightStats {
    static func averageWeight(
        weightIndex: WeightMetrics.DayIndex,
        weekContaining date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        let days = CalendarDay.weekDates(containing: date, calendar: calendar)
            .filter { !CalendarDay.isFuture($0, calendar: calendar) }
        let weights = days.compactMap { weightIndex.weight(on: $0, calendar: calendar) }
        guard !weights.isEmpty else { return nil }
        return MeasurementBounds.roundedToTenth(weights.reduce(0, +) / Double(weights.count))
    }
}
