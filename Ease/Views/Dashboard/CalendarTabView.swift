import SwiftUI

struct CalendarTabView: View {
    @Bindable var viewModel: DashboardViewModel
    let records: [DailyRecord]
    let logs: [WeightLog]

    @State private var visibleMonth = CalendarDay.startOfMonth(.now)
    @State private var daySheet: DaySheetItem?

    private var selectedDate: Date { viewModel.selectedDate }
    private var monthDays: [Date] { CalendarDay.daysInMonth(containing: visibleMonth) }
    private var leadingEmpty: Int { CalendarDay.leadingEmptyDays(inMonthContaining: visibleMonth) }
    private var weekdaySymbols: [String] { CalendarDay.weekdayHeaderSymbols() }
    private var monthStats: MonthWeightStats {
        MonthWeightStats.make(records: records, logs: logs, monthContaining: visibleMonth)
    }
    private var weekAverageWeight: Double? {
        WeekWeightStats.averageWeight(
            records: records,
            logs: logs,
            weekContaining: selectedDate
        )
    }
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        monthHeader
                        calendarCard
                        monthOverviewCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("tab.calendar")
            .navigationBarTitleDisplayMode(.inline)
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
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

    private var calendarCard: some View {
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
                        Color.clear.frame(minHeight: 64)
                    }
                    ForEach(monthDays, id: \.self) { day in
                        dayCell(day)
                    }
                }
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isFuture = CalendarDay.isFuture(day)
        let isSelected = CalendarDay.dayKey(from: day) == CalendarDay.dayKey(from: selectedDate)
        let weight = WeightMetrics.weightOnDay(records: records, logs: logs, on: day)
        let previous = CalendarDay.addingDays(-1, to: day)
        let prevWeight = WeightMetrics.weightOnDay(records: records, logs: logs, on: previous)
        let delta: Double? = {
            guard let weight, let prevWeight else { return nil }
            return MeasurementBounds.roundedToTenth(weight - prevWeight)
        }()
        let diet = records.first { $0.dayKey == CalendarDay.dayKey(from: day) }?.dietStatus

        return Button {
            guard !isFuture else { return }
            let start = CalendarDay.startOfDay(day)
            viewModel.selectedDate = start
            daySheet = DaySheetItem(date: start)
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
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? EasePalette.primaryText : .secondary)
                } else {
                    Text(" ")
                        .font(.caption2)
                }
                if let delta {
                    Text(deltaPrefix(delta) + EaseFormatters.oneDecimal(abs(delta)))
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundStyle(EasePalette.semanticDelta(delta))
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
            .frame(maxWidth: .infinity, minHeight: 64)
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

    private var monthOverviewCard: some View {
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
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    alignment: .leading,
                    spacing: 14
                ) {
                    netChangeStat
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

    private var netChangeStat: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("calendar.stat.monthDelta")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let delta = monthStats.monthDelta {
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
        records: [DailyRecord],
        logs: [WeightLog],
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

        let recordsByDay = Dictionary(grouping: records, by: \.dayKey).compactMapValues(\.first)

        for day in days {
            let key = CalendarDay.dayKey(from: day, calendar: calendar)
            if recordsByDay[key]?.dietStatus == .clean {
                cleanDays += 1
                currentCleanStreak += 1
                bestCleanStreak = max(bestCleanStreak, currentCleanStreak)
            } else {
                currentCleanStreak = 0
            }

            guard let weight = WeightMetrics.weightOnDay(records: records, logs: logs, on: day, calendar: calendar) else {
                continue
            }
            checkins += 1
            weights.append(weight)
            if firstWeight == nil { firstWeight = weight }
            lastWeight = weight
            let previous = CalendarDay.addingDays(-1, to: day, calendar: calendar)
            if let prev = WeightMetrics.weightOnDay(records: records, logs: logs, on: previous, calendar: calendar) {
                let delta = MeasurementBounds.roundedToTenth(weight - prev)
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
        records: [DailyRecord],
        logs: [WeightLog],
        weekContaining date: Date,
        calendar: Calendar = .current
    ) -> Double? {
        let days = CalendarDay.weekDates(containing: date, calendar: calendar)
            .filter { !CalendarDay.isFuture($0, calendar: calendar) }
        let weights = days.compactMap {
            WeightMetrics.weightOnDay(records: records, logs: logs, on: $0, calendar: calendar)
        }
        guard !weights.isEmpty else { return nil }
        return MeasurementBounds.roundedToTenth(weights.reduce(0, +) / Double(weights.count))
    }
}
