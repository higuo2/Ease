import SwiftUI

struct CalendarTabView: View {
    @Bindable var viewModel: DashboardViewModel
    let records: [DailyRecord]
    let logs: [WeightLog]

    @State private var visibleMonth = CalendarDay.startOfMonth(.now)

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
                        dayDetailCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("tab.calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(EasePalette.background, for: .navigationBar)
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

        return Button {
            guard !isFuture else { return }
            viewModel.selectedDate = CalendarDay.startOfDay(day)
        } label: {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.system(.body, design: .rounded, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : (isFuture ? Color.secondary : EasePalette.primaryText))
                    .frame(width: 30, height: 30)
                    .background {
                        if isSelected {
                            Circle().fill(Color.black)
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
                        .foregroundStyle(EasePalette.deltaColor(delta))
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
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    compactStat("calendar.stat.checkins", "\(monthStats.checkinDays)")
                    compactStat("calendar.stat.lossDays", "\(monthStats.lossDays)")
                    compactStat("calendar.stat.gainDays", "\(monthStats.gainDays)")
                    compactStat(
                        "calendar.stat.avgDelta",
                        monthStats.averageDelta.map { signedOne($0) } ?? "—"
                    )
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

    private var dayDetailCard: some View {
        let bounds = WeightMetrics.dayBounds(records: records, logs: logs, on: selectedDate)
        let swing = WeightMetrics.daytimeSwing(records: records, logs: logs, on: selectedDate)
        let record = records.first { $0.dayKey == CalendarDay.dayKey(from: selectedDate) }

        return EaseCard(padding: 20) {
            VStack(alignment: .leading, spacing: 16) {
                Text(selectedDate, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.headline)
                    .foregroundStyle(EasePalette.primaryText)

                HStack(alignment: .top, spacing: 0) {
                    detailMetric("calendar.detail.am", bounds.morning.map(EaseFormatters.oneDecimal))
                    detailMetric("calendar.detail.pm", bounds.evening.map(EaseFormatters.oneDecimal))
                    detailMetric(
                        "calendar.detail.day",
                        swing.map { signedOne($0) },
                        showUnit: false
                    )
                }

                Divider().overlay(EasePalette.hairline)

                HStack(spacing: 12) {
                    if let diet = record?.dietStatus {
                        Label {
                            Text(LocalizedStringKey(diet.titleKey))
                        } icon: {
                            Image(systemName: diet.systemImage)
                        }
                        .font(.subheadline)
                        .foregroundStyle(EasePalette.primaryText)
                    } else {
                        Text("calendar.diet.empty")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button {
                        viewModel.openWeightEntry(for: selectedDate)
                    } label: {
                        Text("calendar.log")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func detailMetric(
        _ title: LocalizedStringKey,
        _ value: String?,
        showUnit: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value ?? "—")
                    .font(.title3.monospacedDigit())
                    .foregroundStyle(EasePalette.primaryText)
                if showUnit, value != nil {
                    Text("unit.kg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func signedOne(_ value: Double) -> String {
        if value > 0 { return "+\(EaseFormatters.oneDecimal(value))" }
        if value < 0 { return EaseFormatters.oneDecimal(value) }
        return EaseFormatters.oneDecimal(value)
    }
}

struct MonthWeightStats {
    var checkinDays: Int
    var lossDays: Int
    var gainDays: Int
    var averageDelta: Double?
    var monthDelta: Double?
    var averageWeight: Double?

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

        for day in days {
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
            averageWeight: averageWeight
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
