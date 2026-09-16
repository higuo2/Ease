import SwiftUI

struct CalendarTabView: View {
    @Bindable var viewModel: DashboardViewModel
    let records: [DailyRecord]
    let logs: [WeightLog]

    @State private var visibleMonth = CalendarDay.startOfMonth(.now)
    @State private var snapshot: CalendarMonthSnapshot?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: EaseLayout.sectionSpacing) {
                        CalendarMonthHeader(visibleMonth: $visibleMonth)
                        if let snapshot {
                            CalendarMonthGrid(
                                viewModel: viewModel,
                                snapshot: snapshot,
                                cellHeight: dayCellHeight,
                                isAccessibilityType: isAccessibilityType
                            )
                            CalendarSelectedDayCard(viewModel: viewModel, snapshot: snapshot)
                            CalendarMonthOverview(viewModel: viewModel, snapshot: snapshot)
                        }
                    }
                    .easeTabScrollContent()
                }
            }
            .navigationTitle("tab.calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(EasePalette.background, for: .navigationBar)
            .sensoryFeedback(.selection, trigger: CalendarDay.dayKey(from: visibleMonth))
            .onChange(of: visibleMonth) { _, month in
                alignSelection(to: month)
            }
            .onChange(of: monthComputeID, initial: true) { _, _ in
                snapshot = CalendarMonthSnapshot.make(
                    records: records,
                    logs: logs,
                    visibleMonth: visibleMonth,
                    healthByDay: viewModel.healthByDay,
                    sleepHistory: viewModel.sleepHistory,
                    cycleHistory: viewModel.cycleHistory
                )
            }
        }
    }

    private var isAccessibilityType: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var dayCellHeight: CGFloat {
        isAccessibilityType ? 92 : 64
    }

    /// Inputs that rebuild month stats / dots. Intentionally omits `selectedDate`.
    private var monthComputeID: String {
        let lastLog = logs.last.map {
            "\($0.id.uuidString)-\($0.weight)-\($0.timestamp.timeIntervalSinceReferenceDate)"
        } ?? "0"
        let lastRecord = records.last.map {
            "\($0.dayKey)-\($0.weight ?? -1)-\($0.note ?? "")-\($0.variableTags)"
        } ?? "0"
        return [
            CalendarDay.dayKey(from: visibleMonth),
            "\(records.count)",
            "\(logs.count)",
            "\(viewModel.healthByDay.count)",
            "\(viewModel.sleepHistory.nights.count)",
            "\(viewModel.cycleHistory.periodDayKeys.count)",
            lastLog,
            lastRecord
        ].joined(separator: "|")
    }

    private func alignSelection(to month: Date) {
        let days = CalendarDay.daysInMonth(containing: month)
        let selectedKey = CalendarDay.dayKey(from: viewModel.selectedDate)
        if days.contains(where: { CalendarDay.dayKey(from: $0) == selectedKey }) {
            return
        }
        let fallback = days.last { !CalendarDay.isFuture($0) } ?? days.last
        if let fallback {
            viewModel.selectedDate = CalendarDay.startOfDay(fallback)
        }
    }
}

private struct CalendarMonthHeader: View {
    @Binding var visibleMonth: Date

    var body: some View {
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
            Text(visibleMonth, format: EaseDateFormat.yearMonthWide)
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
}

private struct CalendarMonthGrid: View {
    @Bindable var viewModel: DashboardViewModel
    let snapshot: CalendarMonthSnapshot
    let cellHeight: CGFloat
    let isAccessibilityType: Bool

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    var body: some View {
        let selectedKey = CalendarDay.dayKey(from: viewModel.selectedDate)
        EaseCard(padding: 16) {
            VStack(spacing: 12) {
                LazyVGrid(columns: gridColumns, spacing: 4) {
                    ForEach(Array(snapshot.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: gridColumns, spacing: 8) {
                    ForEach(0..<snapshot.leadingEmpty, id: \.self) { _ in
                        Color.clear.frame(height: cellHeight)
                    }
                    ForEach(snapshot.days) { day in
                        CalendarDayCell(
                            day: day,
                            isSelected: day.dayKey == selectedKey,
                            height: cellHeight,
                            isAccessibilityType: isAccessibilityType,
                            onSelect: {
                                viewModel.selectedDate = day.date
                            }
                        )
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selectedKey)
    }
}

private struct CalendarDayCell: View, Equatable {
    let day: CalendarDaySnapshot
    let isSelected: Bool
    let height: CGFloat
    let isAccessibilityType: Bool
    let onSelect: () -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.day == rhs.day
            && lhs.isSelected == rhs.isSelected
            && lhs.height == rhs.height
            && lhs.isAccessibilityType == rhs.isAccessibilityType
    }

    var body: some View {
        let faded = day.isFuture || (day.weight == nil && day.marks.isEmpty)
        Button {
            guard !day.isFuture else { return }
            onSelect()
        } label: {
            VStack(spacing: 3) {
                Text("\(day.dayNumber)")
                    .font(.system(.body, design: .rounded, weight: isSelected ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(dayNumberStyle(faded: faded))
                    .frame(width: 30, height: 30)
                    .background {
                        if day.isToday && !isSelected {
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
                    if day.marks.contains(.weight) {
                        Circle().fill(EasePalette.mint).frame(width: 4, height: 4)
                    }
                    if day.marks.contains(.period) {
                        Circle().fill(EasePalette.periodRose).frame(width: 4, height: 4)
                    }
                    if day.marks.contains(.sleep) {
                        Circle().fill(EasePalette.iconSleep).frame(width: 4, height: 4)
                    }
                }
                .frame(height: 4)
                .opacity(day.marks.isEmpty ? 0 : 1)

                Group {
                    if let weight = day.weight, !day.isFuture {
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
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(day.isFuture)
        .accessibilityLabel(day.accessibilityLabel)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }

    private func dayNumberStyle(faded: Bool) -> AnyShapeStyle {
        if day.isFuture || faded { return AnyShapeStyle(.tertiary) }
        return AnyShapeStyle(EasePalette.primaryText)
    }
}

private struct CalendarSelectedDayCard: View {
    @Bindable var viewModel: DashboardViewModel
    let snapshot: CalendarMonthSnapshot

    var body: some View {
        let selected = snapshot.day(for: viewModel.selectedDate)
        let hasLogs = selected.map(\.hasLogs) ?? false

        if let selected, hasLogs {
            EaseCard(padding: 20) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(selected.date, format: EaseDateFormat.weekdayMonthDay)
                            .font(.headline)
                            .foregroundStyle(EasePalette.primaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Spacer(minLength: 8)
                        Button("common.edit") {
                            viewModel.openWeightEntry(for: selected.date)
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
                            selected.weight.map { EaseFormatters.kg($0) }
                        )
                        detailMetric(
                            "calendar.detail.sleep",
                            selected.sleepHours.map(EaseFormatters.sleepDuration)
                        )
                        detailMetric(
                            "calendar.detail.period",
                            periodValue(dayNumber: selected.periodDayNumber, logged: selected.marks.contains(.period))
                        )
                        detailMetric(
                            "calendar.detail.notes",
                            selected.note,
                            lineLimit: 2
                        )
                    }
                }
            }
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
}

private struct CalendarMonthOverview: View {
    @Bindable var viewModel: DashboardViewModel
    let snapshot: CalendarMonthSnapshot

    var body: some View {
        let weekAverageWeight = WeekWeightStats.averageWeight(
            weightIndex: WeightMetrics.DayIndex(lastWeightByDay: snapshot.lastWeightByDay),
            weekContaining: viewModel.selectedDate
        )
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
                        snapshot.stats.averageWeight.map { EaseFormatters.kg($0) }
                    )
                    overviewStat(
                        "calendar.stat.monthDelta",
                        netChangeText(snapshot.stats.monthDelta),
                        valueColor: snapshot.stats.monthDelta.map(EasePalette.semanticDelta)
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
                            snapshot.stats.checkinDays,
                            snapshot.stats.elapsedDays
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
            snapshot.month.formatted(EaseDateFormat.monthWide)
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
}

struct CalendarDayMarks: OptionSet, Equatable, Sendable {
    let rawValue: UInt8

    static let weight = CalendarDayMarks(rawValue: 1 << 0)
    static let period = CalendarDayMarks(rawValue: 1 << 1)
    static let sleep = CalendarDayMarks(rawValue: 1 << 2)
}

struct CalendarDaySnapshot: Equatable, Identifiable, Sendable {
    var id: String { dayKey }
    var dayKey: String
    var date: Date
    var dayNumber: Int
    var weight: Double?
    var sleepHours: Double?
    var marks: CalendarDayMarks
    var note: String?
    var periodDayNumber: Int?
    var isFuture: Bool
    var isToday: Bool
    var accessibilityLabel: String

    var hasLogs: Bool {
        weight != nil || sleepHours != nil || marks.contains(.period) || note != nil
    }
}

struct CalendarMonthSnapshot: Equatable, Sendable {
    var month: Date
    var weekdaySymbols: [String]
    var leadingEmpty: Int
    var days: [CalendarDaySnapshot]
    var stats: MonthWeightStats
    var lastWeightByDay: [String: Double]

    func day(for date: Date, calendar: Calendar = .current) -> CalendarDaySnapshot? {
        let key = CalendarDay.dayKey(from: date, calendar: calendar)
        return days.first { $0.dayKey == key }
    }

    static func make(
        records: [DailyRecord],
        logs: [WeightLog],
        visibleMonth: Date,
        healthByDay: [String: HealthDaySnapshot],
        sleepHistory: SleepHistory,
        cycleHistory: CycleHistory,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> CalendarMonthSnapshot {
        let weightIndex = WeightMetrics.DayIndex.make(records: records, logs: logs, calendar: calendar)
        let recordsByDay = WeightMetrics.recordsByDayKey(records)
        let monthDays = CalendarDay.daysInMonth(containing: visibleMonth, calendar: calendar)
        let days: [CalendarDaySnapshot] = monthDays.map { day in
            makeDay(
                day,
                weightIndex: weightIndex,
                recordsByDay: recordsByDay,
                healthByDay: healthByDay,
                sleepHistory: sleepHistory,
                cycleHistory: cycleHistory,
                calendar: calendar,
                now: now
            )
        }
        return CalendarMonthSnapshot(
            month: CalendarDay.startOfMonth(visibleMonth, calendar: calendar),
            weekdaySymbols: CalendarDay.weekdayHeaderSymbols(calendar: calendar),
            leadingEmpty: CalendarDay.leadingEmptyDays(inMonthContaining: visibleMonth, calendar: calendar),
            days: days,
            stats: MonthWeightStats.make(weightIndex: weightIndex, monthContaining: visibleMonth, calendar: calendar),
            lastWeightByDay: weightIndex.lastWeightByDay
        )
    }

    private static func makeDay(
        _ day: Date,
        weightIndex: WeightMetrics.DayIndex,
        recordsByDay: [String: DailyRecord],
        healthByDay: [String: HealthDaySnapshot],
        sleepHistory: SleepHistory,
        cycleHistory: CycleHistory,
        calendar: Calendar,
        now: Date
    ) -> CalendarDaySnapshot {
        let key = CalendarDay.dayKey(from: day, calendar: calendar)
        let isFuture = CalendarDay.isFuture(day, calendar: calendar)
        let weight = weightIndex.weight(on: day, calendar: calendar)
        let sleep = healthByDay[key]?.previousNightSleepHours ?? sleepHistory.hours(on: day, calendar: calendar)
        var marks: CalendarDayMarks = []
        if weight != nil { marks.insert(.weight) }
        let periodLogged = healthByDay[key]?.isMenstrual == true
            || cycleHistory.isMenstrual(day, calendar: calendar)
            || recordsByDay[key]?.variableTags.contains(.period) == true
        if periodLogged { marks.insert(.period) }
        if sleep != nil { marks.insert(.sleep) }
        let note = recordsByDay[key]?.note?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = (note?.isEmpty == false) ? note : nil
        return CalendarDaySnapshot(
            dayKey: key,
            date: CalendarDay.startOfDay(day, calendar: calendar),
            dayNumber: calendar.component(.day, from: day),
            weight: weight,
            sleepHours: sleep,
            marks: marks,
            note: trimmedNote,
            periodDayNumber: cycleHistory.periodDayNumber(on: day, calendar: calendar),
            isFuture: isFuture,
            isToday: calendar.isDate(day, inSameDayAs: now),
            accessibilityLabel: accessibilityLabel(
                day: day,
                weight: weight,
                period: periodLogged,
                sleep: sleep != nil,
                isFuture: isFuture,
                empty: marks.isEmpty && weight == nil
            )
        )
    }

    private static func accessibilityLabel(
        day: Date,
        weight: Double?,
        period: Bool,
        sleep: Bool,
        isFuture: Bool,
        empty: Bool
    ) -> String {
        let dateText = day.formatted(EaseDateFormat.monthDay)
        if isFuture { return dateText }
        var parts = [dateText]
        if let weight {
            parts.append(EaseFormatters.kg(weight))
        }
        if period {
            parts.append(String(localized: "calendar.detail.period"))
        }
        if sleep {
            parts.append(String(localized: "calendar.detail.sleep"))
        }
        if empty {
            parts.append(String(localized: "calendar.cell.empty"))
        }
        return parts.joined(separator: ", ")
    }
}

struct MonthWeightStats: Equatable, Sendable {
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
