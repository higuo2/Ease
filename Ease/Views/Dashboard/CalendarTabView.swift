import SwiftUI

struct CalendarTabView: View {
    @Bindable var viewModel: DashboardViewModel
    let records: [DailyRecord]
    let logs: [WeightLog]

    @State private var visibleMonth = CalendarDay.startOfMonth(.now)
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var selectedDate: Date { viewModel.selectedDate }
    private var selectedDayKey: String { CalendarDay.dayKey(from: selectedDate) }
    private var monthDays: [Date] { CalendarDay.daysInMonth(containing: visibleMonth) }
    private var leadingEmpty: Int { CalendarDay.leadingEmptyDays(inMonthContaining: visibleMonth) }
    private var weekdaySymbols: [String] { CalendarDay.weekdayHeaderSymbols() }
    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    private var recordsByDay: [String: DailyRecord] {
        Dictionary(records.map { ($0.dayKey, $0) }, uniquingKeysWith: { _, last in last })
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
                        selectedDayCard(weightIndex: weightIndex)
                        monthOverviewCard(monthStats: monthStats, weekAverageWeight: weekAverageWeight)
                    }
                    .easeTabScrollContent()
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: selectedDayKey)
                }
            }
            .navigationTitle("tab.calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(EasePalette.background, for: .navigationBar)
            .sensoryFeedback(.selection, trigger: selectedDayKey)
            .sensoryFeedback(.selection, trigger: CalendarDay.dayKey(from: visibleMonth))
            .onChange(of: visibleMonth) { _, month in
                alignSelection(to: month)
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

    private func calendarCard(weightIndex: WeightMetrics.DayIndex) -> some View {
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
        isAccessibilityType ? 92 : 64
    }

    private func dayCell(
        _ day: Date,
        weightIndex: WeightMetrics.DayIndex
    ) -> some View {
        let isFuture = CalendarDay.isFuture(day)
        let isSelected = CalendarDay.dayKey(from: day) == selectedDayKey
        let isToday = Calendar.current.isDateInToday(day)
        let weight = weightIndex.weight(on: day)
        let dots = statusDots(on: day, hasWeight: weight != nil)
        let faded = isFuture || (weight == nil && dots.isEmpty)

        return Button {
            guard !isFuture else { return }
            viewModel.selectedDate = CalendarDay.startOfDay(day)
        } label: {
            VStack(spacing: 3) {
                Text("\(Calendar.current.component(.day, from: day))")
                    .font(.system(.body, design: .rounded, weight: isSelected ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(dayNumberStyle(isFuture: isFuture, faded: faded, isSelected: isSelected))
                    .frame(width: 30, height: 30)
                    .background {
                        if isToday && !isSelected {
                            Circle().fill(EasePalette.accent.opacity(0.12))
                        }
                    }
                    .overlay {
                        if isSelected {
                            Circle()
                                .strokeBorder(EasePalette.accent, lineWidth: 1.5)
                        }
                    }

                HStack(spacing: 3) {
                    ForEach(Array(dots.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
                .opacity(dots.isEmpty ? 0 : 1)

                Group {
                    if let weight, !isFuture {
                        Text(EaseFormatters.oneDecimal(weight))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(EasePalette.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: isAccessibilityType ? 16 : 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: dayCellHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(dayAccessibilityLabel(day, weight: weight, dots: dots, isFuture: isFuture))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private func dayNumberStyle(isFuture: Bool, faded: Bool, isSelected: Bool) -> AnyShapeStyle {
        if isFuture || faded { return AnyShapeStyle(.tertiary) }
        if isSelected { return AnyShapeStyle(EasePalette.primaryText) }
        return AnyShapeStyle(EasePalette.primaryText)
    }

    private func statusDots(on day: Date, hasWeight: Bool) -> [Color] {
        var dots: [Color] = []
        if hasWeight { dots.append(EasePalette.mint) }
        if isPeriod(on: day) { dots.append(EasePalette.periodRose) }
        if sleepHours(on: day) != nil { dots.append(EasePalette.iconSleep) }
        return Array(dots.prefix(3))
    }

    private func dayAccessibilityLabel(
        _ day: Date,
        weight: Double?,
        dots: [Color],
        isFuture: Bool
    ) -> String {
        let dateText = day.formatted(.dateTime.month(.abbreviated).day())
        if isFuture { return dateText }
        var parts = [dateText]
        if let weight {
            parts.append(EaseFormatters.kg(weight))
        }
        if isPeriod(on: day) {
            parts.append(String(localized: "calendar.detail.period"))
        }
        if sleepHours(on: day) != nil {
            parts.append(String(localized: "calendar.detail.sleep"))
        }
        if dots.isEmpty && weight == nil {
            parts.append(String(localized: "calendar.cell.empty"))
        }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func selectedDayCard(weightIndex: WeightMetrics.DayIndex) -> some View {
        let weight = weightIndex.weight(on: selectedDate)
        let sleep = sleepHours(on: selectedDate)
        let periodDay = viewModel.cycleHistory.periodDayNumber(on: selectedDate)
        let periodLogged = isPeriod(on: selectedDate)
        let note = note(on: selectedDate)
        let hasLogs = weight != nil || sleep != nil || periodLogged || note != nil

        if hasLogs {
            EaseCard(padding: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(selectedDate, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                            .font(.headline)
                            .foregroundStyle(EasePalette.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer(minLength: 8)
                        Button("common.edit") {
                            viewModel.openWeightEntry(for: selectedDate)
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(EasePalette.secondaryText)
                        .buttonStyle(.borderless)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: EaseLayout.gridGap),
                            GridItem(.flexible(), spacing: EaseLayout.gridGap)
                        ],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        detailMetric(
                            "calendar.detail.weight",
                            weight.map { EaseFormatters.kg($0) }
                        )
                        detailMetric(
                            "calendar.detail.sleep",
                            sleep.map(EaseFormatters.sleepDuration)
                        )
                        detailMetric(
                            "calendar.detail.period",
                            periodValue(dayNumber: periodDay, logged: periodLogged)
                        )
                        detailMetric(
                            "calendar.detail.notes",
                            note,
                            lineLimit: 2
                        )
                    }
                }
            }
        } else {
            Button {
                viewModel.openWeightEntry(for: selectedDate)
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
            selectedDate.formatted(.dateTime.month(.abbreviated).day())
        )
    }

    private func detailMetric(
        _ title: LocalizedStringKey,
        _ value: String?,
        lineLimit: Int = 1
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value ?? "—")
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(EasePalette.primaryText)
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            EasePalette.recessed,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func periodValue(dayNumber: Int?, logged: Bool) -> String? {
        if let dayNumber {
            return String(format: String(localized: "calendar.detail.periodDay"), locale: .current, dayNumber)
        }
        return logged ? String(localized: "calendar.detail.periodYes") : nil
    }

    private func monthOverviewCard(
        monthStats: MonthWeightStats,
        weekAverageWeight: Double?
    ) -> some View {
        EaseCard(padding: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Text(overviewTitle)
                    .font(.headline)
                    .foregroundStyle(EasePalette.primaryText)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: EaseLayout.gridGap),
                        GridItem(.flexible(), spacing: EaseLayout.gridGap)
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    overviewStat(
                        "calendar.stat.monthAvg",
                        monthStats.averageWeight.map { EaseFormatters.kg($0) }
                    )
                    overviewStat(
                        "calendar.stat.monthDelta",
                        netChangeText(monthStats.monthDelta),
                        valueColor: monthStats.monthDelta.map(EasePalette.semanticDelta)
                    )
                    overviewStat(
                        "calendar.stat.weekAvg",
                        weekAverageWeight.map { EaseFormatters.kg($0) }
                    )
                    overviewStat(
                        "calendar.stat.loggedDays",
                        String(
                            format: String(localized: "calendar.stat.loggedDays.value"),
                            locale: .current,
                            monthStats.checkinDays,
                            monthStats.elapsedDays
                        )
                    )
                }
            }
        }
    }

    private var overviewTitle: String {
        String(
            format: String(localized: "calendar.overview.title"),
            locale: .current,
            visibleMonth.formatted(.dateTime.month(.wide))
        )
    }

    private func overviewStat(
        _ title: LocalizedStringKey,
        _ value: String?,
        valueColor: Color? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value ?? "—")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(valueColor ?? EasePalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            EasePalette.recessed,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func netChangeText(_ delta: Double?) -> String? {
        guard let delta else { return nil }
        if delta == 0 {
            return EaseFormatters.kg(0)
        }
        let arrow = delta < 0 ? "▼ " : "▲ "
        return arrow + EaseFormatters.oneDecimal(abs(delta)) + "\u{00A0}" + String(localized: "unit.kg")
    }

    private func sleepHours(on date: Date) -> Double? {
        let key = CalendarDay.dayKey(from: date)
        return viewModel.healthByDay[key]?.previousNightSleepHours
            ?? viewModel.sleepHistory.hours(on: date)
    }

    private func isPeriod(on date: Date) -> Bool {
        let key = CalendarDay.dayKey(from: date)
        if viewModel.healthByDay[key]?.isMenstrual == true { return true }
        if viewModel.cycleHistory.isMenstrual(date) { return true }
        return recordsByDay[key]?.variableTags.contains(.period) == true
    }

    private func note(on date: Date) -> String? {
        let trimmed = recordsByDay[CalendarDay.dayKey(from: date)]?.note?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func alignSelection(to month: Date) {
        let days = CalendarDay.daysInMonth(containing: month)
        let selectedKey = CalendarDay.dayKey(from: selectedDate)
        if days.contains(where: { CalendarDay.dayKey(from: $0) == selectedKey }) {
            return
        }
        let fallback = days.last { !CalendarDay.isFuture($0) } ?? days.last
        if let fallback {
            viewModel.selectedDate = CalendarDay.startOfDay(fallback)
        }
    }
}

struct MonthWeightStats {
    var checkinDays: Int
    var elapsedDays: Int
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
            elapsedDays: days.count,
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
