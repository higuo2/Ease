import SwiftUI

struct CalendarTabView: View {
    @Bindable var viewModel: DashboardViewModel
    let records: [DailyRecord]
    let logs: [WeightLog]

    @State private var visibleMonth = CalendarDay.startOfMonth(.now)

    private var selectedDate: Date { viewModel.selectedDate }
    private var monthDays: [Date] { CalendarDay.daysInMonth(containing: visibleMonth) }
    private var leadingEmpty: Int { CalendarDay.leadingEmptyDays(inMonthContaining: visibleMonth) }
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

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        monthHeader
                        weekdayHeader
                        monthGrid
                        averageWeightBar
                        monthStatsBar
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
                    .foregroundStyle(EasePalette.primaryText)
            }
            .buttonStyle(.plain)

            Spacer()
            Text(visibleMonth, format: .dateTime.year().month(.wide))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(EasePalette.primaryText)
            Spacer()

            Button {
                guard let next = Calendar.current.date(byAdding: .month, value: 1, to: visibleMonth) else { return }
                let nextMonth = CalendarDay.startOfMonth(next)
                guard nextMonth <= CalendarDay.startOfMonth(.now) else { return }
                visibleMonth = nextMonth
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundStyle(EasePalette.primaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
            ForEach(CalendarDay.weekdayHeaderSymbols(), id: \.self) { symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(0..<leadingEmpty, id: \.self) { _ in
                Color.clear.frame(height: 56)
            }
            ForEach(monthDays, id: \.self) { day in
                dayCell(day)
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
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isFuture ? EasePalette.secondaryText.opacity(0.35) : EasePalette.primaryText)
                if let weight {
                    Text(EaseFormatters.oneDecimal(weight))
                        .font(.system(size: 11, weight: .regular).monospacedDigit())
                        .foregroundStyle(EasePalette.primaryText)
                } else {
                    Text(" ")
                        .font(.system(size: 11))
                }
                if let delta {
                    Text(deltaPrefix(delta) + EaseFormatters.oneDecimal(abs(delta)))
                        .font(.system(size: 10, weight: .regular).monospacedDigit())
                        .foregroundStyle(EasePalette.deltaColor(delta))
                } else {
                    Text(" ")
                        .font(.system(size: 10))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? EasePalette.recessed : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private var averageWeightBar: some View {
        EaseCard {
            HStack(spacing: 0) {
                averageCell(
                    "calendar.stat.weekAvg",
                    weekAverageWeight.map(EaseFormatters.kg) ?? "—"
                )
                Rectangle()
                    .fill(EasePalette.hairline)
                    .frame(width: 1, height: 36)
                averageCell(
                    "calendar.stat.monthAvg",
                    monthStats.averageWeight.map(EaseFormatters.kg) ?? "—"
                )
            }
        }
    }

    private func averageCell(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(EasePalette.secondaryText)
            Text(value)
                .font(EaseFont.number(22))
                .monospacedDigit()
                .foregroundStyle(EasePalette.primaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var monthStatsBar: some View {
        EaseRecessedCard {
            HStack(spacing: 0) {
                monthStat("calendar.stat.checkins", "\(monthStats.checkinDays)")
                monthStat("calendar.stat.lossDays", "\(monthStats.lossDays)")
                monthStat("calendar.stat.gainDays", "\(monthStats.gainDays)")
                monthStat("calendar.stat.avgDelta", monthStats.averageDelta.map { signedOne($0) } ?? "—")
                monthStat("calendar.stat.monthDelta", monthStats.monthDelta.map { signedOne($0) } ?? "—")
            }
        }
    }

    private func monthStat(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(EaseFont.number(14))
                .monospacedDigit()
                .foregroundStyle(EasePalette.primaryText)
            Text(title)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(EasePalette.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var dayDetailCard: some View {
        let bounds = WeightMetrics.dayBounds(records: records, logs: logs, on: selectedDate)
        let swing = WeightMetrics.daytimeSwing(records: records, logs: logs, on: selectedDate)
        let record = records.first { $0.dayKey == CalendarDay.dayKey(from: selectedDate) }

        return EaseCard {
            VStack(alignment: .leading, spacing: 14) {
                Text(selectedDate, format: .dateTime.month(.abbreviated).day().weekday(.wide))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(EasePalette.primaryText)

                HStack {
                    detailMetric("history.morning", bounds.morning.map(EaseFormatters.kg))
                    detailMetric("history.evening", bounds.evening.map(EaseFormatters.kg))
                    detailMetric("history.daytimeSwing", swing.map { signedKg($0) })
                }

                HStack(spacing: 10) {
                    if let diet = record?.dietStatus {
                        Label {
                            Text(LocalizedStringKey(diet.titleKey))
                        } icon: {
                            Image(systemName: diet.systemImage)
                        }
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(EasePalette.primaryText)
                    } else {
                        Text("calendar.diet.empty")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(EasePalette.secondaryText)
                    }
                    Spacer()
                    Button {
                        viewModel.openWeightEntry(for: selectedDate)
                    } label: {
                        Text("calendar.log")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.black, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func detailMetric(_ title: LocalizedStringKey, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(EasePalette.secondaryText)
            Text(value ?? "—")
                .font(EaseFont.number(15))
                .monospacedDigit()
                .foregroundStyle(EasePalette.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func deltaPrefix(_ delta: Double) -> String {
        if delta < 0 { return "▼" }
        if delta > 0 { return "▲" }
        return ""
    }

    private func signedOne(_ value: Double) -> String {
        let sign = value > 0 ? "+" : (value < 0 ? "" : "")
        return "\(sign)\(EaseFormatters.oneDecimal(value))"
    }

    private func signedKg(_ value: Double) -> String {
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(EaseFormatters.kg(value))"
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
