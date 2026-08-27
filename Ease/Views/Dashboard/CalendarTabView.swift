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
        let recordsByDay = WeightMetrics.recordsByDayKey(records)
        let weightIndex = WeightMetrics.DayIndex.make(records: records, logs: logs)
        let monthStats = MonthWeightStats.make(
            recordsByDay: recordsByDay,
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
                    VStack(spacing: EaseLayout.sectionSpacing) {
                        monthHeader
                        calendarCard(recordsByDay: recordsByDay, weightIndex: weightIndex)
                        monthOverviewCard(monthStats: monthStats, weekAverageWeight: weekAverageWeight)
                        DailyMomentsCard(
                            date: selectedDate,
                            record: recordsByDay[selectedDayKey],
                            journalRecords: records,
                            onAddMeal: {
                                viewModel.openDietEntry(for: selectedDate)
                            }
                        )
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
                    .font(.body.weight(.semibold))
                    .foregroundStyle(EasePalette.primaryText)
            }
            .buttonStyle(.plain)

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
                    .font(.body.weight(.semibold))
                    .foregroundStyle(EasePalette.primaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    private func calendarCard(
        recordsByDay: [String: DailyRecord],
        weightIndex: WeightMetrics.DayIndex
    ) -> some View {
        EaseCard(padding: 16) {
            VStack(spacing: 12) {
                LazyVGrid(columns: gridColumns, spacing: 4) {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(0..<leadingEmpty, id: \.self) { _ in
                        Color.clear.frame(minHeight: isAccessibilityType ? 88 : 64)
                    }
                    ForEach(monthDays, id: \.self) { day in
                        dayCell(day, recordsByDay: recordsByDay, weightIndex: weightIndex)
                    }
                }
            }
        }
    }

    private var isAccessibilityType: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private func dayCell(
        _ day: Date,
        recordsByDay: [String: DailyRecord],
        weightIndex: WeightMetrics.DayIndex
    ) -> some View {
        let isFuture = CalendarDay.isFuture(day)
        let dayKey = CalendarDay.dayKey(from: day)
        let isSelected = dayKey == selectedDayKey
        let weight = weightIndex.weight(on: day)
        let delta = weightIndex.delta(on: day)
        let diet = recordsByDay[dayKey]?.dietStatus

        return Button {
            guard !isFuture else { return }
            let start = CalendarDay.startOfDay(day)
            if isSelected {
                daySheet = DaySheetItem(date: start)
            } else {
                viewModel.selectedDate = start
            }
        } label: {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.system(.body, design: .rounded, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (isFuture ? Color.secondary : EasePalette.primaryText))
                    .frame(width: 30, height: 30)
                    .background {
                        if isSelected {
                            Circle().fill(EasePalette.accent)
                        }
                    }
                if let weight {
                    Text(EaseFormatters.oneDecimal(weight))
                        .font(isAccessibilityType ? .caption : .caption2)
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? EasePalette.primaryText : .secondary)
                        .lineLimit(isAccessibilityType ? 2 : 1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                } else {
                    Text(" ")
                        .font(.caption2)
                }
                if let delta {
                    Text(deltaPrefix(delta) + EaseFormatters.oneDecimal(abs(delta)))
                        .font(isAccessibilityType ? .caption.weight(.medium) : .system(size: 9, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.semanticDelta(delta))
                        .lineLimit(isAccessibilityType ? 2 : 1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                } else if let diet {
                    Circle()
                        .fill(EasePalette.dietTint(diet))
                        .frame(width: 5, height: 5)
                        .padding(.top, 2)
                } else {
                    Text(" ")
                        .font(.system(size: 9))
                }
            }
            .frame(maxWidth: .infinity, minHeight: isAccessibilityType ? 88 : 64)
            .opacity(isFuture ? 0.3 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
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

                HStack(alignment: .firstTextBaseline, spacing: 24) {
                    overviewHero(
                        "calendar.stat.monthAvg",
                        monthStats.averageWeight.map(EaseFormatters.oneDecimal),
                        emphasize: true
                    )
                    overviewHero(
                        "calendar.stat.weekAvg",
                        weekAverageWeight.map(EaseFormatters.oneDecimal),
                        emphasize: false
                    )
                    Spacer(minLength: 0)
                }

                Divider().overlay(EasePalette.hairline)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: EaseLayout.gridGap),
                        GridItem(.flexible(), spacing: EaseLayout.gridGap),
                        GridItem(.flexible(), spacing: EaseLayout.gridGap)
                    ],
                    alignment: .leading,
                    spacing: EaseLayout.gridGap
                ) {
                    netChangeStat(monthDelta: monthStats.monthDelta)
                    iconStat(
                        title: "calendar.stat.cleanDays",
                        value: daysCount(monthStats.cleanDays),
                        systemImage: "leaf.fill",
                        tint: EasePalette.dietClean
                    )
                    iconStat(
                        title: "calendar.stat.bestStreak",
                        value: daysCount(monthStats.bestCleanStreak),
                        systemImage: "flame.fill",
                        tint: EasePalette.accentWarm
                    )
                    compactStat("calendar.stat.checkins", "\(monthStats.checkinDays)")
                    compactStat("calendar.stat.lossDays", "\(monthStats.lossDays)")
                    compactStat("calendar.stat.gainDays", "\(monthStats.gainDays)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func netChangeStat(monthDelta: Double?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("calendar.stat.monthDelta")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let delta = monthDelta {
                Text(deltaPrefix(delta) + EaseFormatters.oneDecimal(abs(delta)) + " kg")
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(EasePalette.semanticDelta(delta))
            } else {
                Text("—")
                    .font(.subheadline.bold())
                    .foregroundStyle(EasePalette.primaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func iconStat(
        title: LocalizedStringKey,
        value: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(EasePalette.primaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        _ value: String?,
        emphasize: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value ?? "—")
                    .font(emphasize ? .title2.bold() : .title3.weight(.semibold))
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

    private func compactStat(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(EasePalette.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func daysCount(_ value: Int) -> String {
        String(
            format: String(localized: "calendar.stat.daysCount"),
            locale: .current,
            value
        )
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
    var cleanDays: Int
    var bestCleanStreak: Int

    static func make(
        recordsByDay: [String: DailyRecord],
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
        var cleanDays = 0
        var bestCleanStreak = 0
        var currentCleanStreak = 0

        for day in days {
            let key = CalendarDay.dayKey(from: day, calendar: calendar)
            if recordsByDay[key]?.dietStatus == .clean {
                cleanDays += 1
                currentCleanStreak += 1
                bestCleanStreak = max(bestCleanStreak, currentCleanStreak)
            } else {
                currentCleanStreak = 0
            }

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
            averageWeight: averageWeight,
            cleanDays: cleanDays,
            bestCleanStreak: bestCleanStreak
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
