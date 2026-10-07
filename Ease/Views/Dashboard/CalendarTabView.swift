import SwiftUI

struct CalendarTabView: View {
    @Bindable var viewModel: DashboardViewModel
    let records: [DailyRecord]
    let logs: [WeightLog]
    let workoutLogs: [WorkoutLog]

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
                            DailySnapshotView(viewModel: viewModel, snapshot: snapshot)
                            MonthlyOverviewCard(viewModel: viewModel, snapshot: snapshot)
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
            .onChange(of: monthComputeToken, initial: true) { _, _ in
                snapshot = CalendarMonthSnapshot.make(
                    records: records,
                    logs: logs,
                    visibleMonth: visibleMonth,
                    healthByDay: viewModel.healthByDay,
                    sleepHistory: viewModel.sleepHistory,
                    cycleHistory: viewModel.cycleHistory,
                    workoutLogs: workoutLogs
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
    private var monthComputeToken: Int {
        var hasher = Hasher()
        hasher.combine(CalendarDay.dayKey(from: visibleMonth))
        hasher.combine(records.count)
        hasher.combine(logs.count)
        hasher.combine(viewModel.healthByDay.count)
        hasher.combine(viewModel.sleepHistory.nights.count)
        hasher.combine(viewModel.cycleHistory.periodDayKeys.count)
        hasher.combine(workoutLogs.count)
        hasher.combine(workoutLogs.map(\.updatedAt.timeIntervalSinceReferenceDate).max() ?? 0)
        hasher.combine(workoutLogs.reduce(0) { $0 + $1.kcal })
        hasher.combine(workoutLogs.reduce(0) { $0 + ($1.durationMinutes ?? 0) })
        DashboardComputeToken.mixWeightLogTail(logs.last, into: &hasher)
        DashboardComputeToken.mixDailyRecordCalendarTail(records.last, into: &hasher)
        return hasher.finalize()
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
                    if day.marks.contains(.workout) {
                        Circle().fill(EasePalette.iconEnergy).frame(width: 4, height: 4)
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

struct CalendarDayMarks: OptionSet, Equatable, Sendable {
    let rawValue: UInt8

    static let weight = CalendarDayMarks(rawValue: 1 << 0)
    static let period = CalendarDayMarks(rawValue: 1 << 1)
    static let sleep = CalendarDayMarks(rawValue: 1 << 2)
    static let workout = CalendarDayMarks(rawValue: 1 << 3)
}

struct CalendarDaySnapshot: Equatable, Identifiable, Sendable {
    var id: String { dayKey }
    var dayKey: String
    var date: Date
    var dayNumber: Int
    var weight: Double?
    var sleepHours: Double?
    var activeEnergyKcal: Double?
    var marks: CalendarDayMarks
    var note: String?
    var periodDayNumber: Int?
    var isFuture: Bool
    var isToday: Bool
    var accessibilityLabel: String

    var hasLogs: Bool {
        weight != nil
            || sleepHours != nil
            || activeEnergyKcal != nil
            || marks.contains(.period)
            || marks.contains(.workout)
            || note != nil
    }
}

struct CalendarMonthSnapshot: Equatable, Sendable {
    var month: Date
    var weekdaySymbols: [String]
    var leadingEmpty: Int
    var days: [CalendarDaySnapshot]
    var stats: MonthWeightStats
    var workoutStats: MonthWorkoutStats
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
        workoutLogs: [WorkoutLog] = [],
        calendar: Calendar = .current,
        now: Date = .now
    ) -> CalendarMonthSnapshot {
        let weightIndex = WeightMetrics.DayIndex.make(records: records, logs: logs, calendar: calendar)
        let recordsByDay = WeightMetrics.recordsByDayKey(records)
        let workoutDayKeys = Set(
            workoutLogs.map { CalendarDay.dayKey(from: $0.timestamp, calendar: calendar) }
        )
        let monthDays = CalendarDay.daysInMonth(containing: visibleMonth, calendar: calendar)
        let days: [CalendarDaySnapshot] = monthDays.map { day in
            makeDay(
                day,
                weightIndex: weightIndex,
                recordsByDay: recordsByDay,
                healthByDay: healthByDay,
                sleepHistory: sleepHistory,
                cycleHistory: cycleHistory,
                workoutDayKeys: workoutDayKeys,
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
            workoutStats: MonthWorkoutStats.make(
                logs: workoutLogs,
                monthContaining: visibleMonth,
                calendar: calendar,
                now: now
            ),
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
        workoutDayKeys: Set<String>,
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
        let hasWorkout = workoutDayKeys.contains(key)
        if hasWorkout { marks.insert(.workout) }
        let note = recordsByDay[key]?.note?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = (note?.isEmpty == false) ? note : nil
        return CalendarDaySnapshot(
            dayKey: key,
            date: CalendarDay.startOfDay(day, calendar: calendar),
            dayNumber: calendar.component(.day, from: day),
            weight: weight,
            sleepHours: sleep,
            activeEnergyKcal: healthByDay[key]?.activeEnergyKcal,
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
                workout: hasWorkout,
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
        workout: Bool,
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
        if workout {
            parts.append(String(localized: "calendar.detail.workout"))
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

struct MonthWorkoutStats: Equatable, Sendable {
    var days: Int
    var sessions: Int
    var totalKcal: Double
    var totalMinutes: Int
    var daysWithDuration: Int
    var averageKcal: Double?
    var averageMinutes: Int?

    static let empty = MonthWorkoutStats(
        days: 0,
        sessions: 0,
        totalKcal: 0,
        totalMinutes: 0,
        daysWithDuration: 0,
        averageKcal: nil,
        averageMinutes: nil
    )

    static func make(
        logs: [WorkoutLog],
        monthContaining date: Date,
        calendar: Calendar = .current,
        now: Date = .now
    ) -> MonthWorkoutStats {
        let monthDays = CalendarDay.daysInMonth(containing: date, calendar: calendar)
        guard let monthStart = monthDays.first else { return .empty }
        let monthEnd = CalendarDay.addingDays(1, to: CalendarDay.startOfDay(monthDays.last ?? monthStart, calendar: calendar), calendar: calendar)
        let inMonth = logs.filter { log in
            let stamp = log.timestamp
            guard stamp >= monthStart, stamp < monthEnd else { return false }
            return !CalendarDay.isFuture(stamp, now: now, calendar: calendar)
        }
        guard !inMonth.isEmpty else { return .empty }

        var minutesByDay: [String: Int] = [:]
        var kcalByDay: [String: Double] = [:]
        for log in inMonth {
            let key = CalendarDay.dayKey(from: log.timestamp, calendar: calendar)
            kcalByDay[key, default: 0] += log.kcal
            if let minutes = log.durationMinutes {
                minutesByDay[key, default: 0] += minutes
            }
        }

        let days = kcalByDay.count
        let totalKcal = kcalByDay.values.reduce(0, +)
        let totalMinutes = minutesByDay.values.reduce(0, +)
        let daysWithDuration = minutesByDay.count
        let averageKcal = days > 0 ? (totalKcal / Double(days)).rounded() : nil
        let averageMinutes = daysWithDuration > 0
            ? Int((Double(totalMinutes) / Double(daysWithDuration)).rounded())
            : nil

        return MonthWorkoutStats(
            days: days,
            sessions: inMonth.count,
            totalKcal: totalKcal.rounded(),
            totalMinutes: totalMinutes,
            daysWithDuration: daysWithDuration,
            averageKcal: averageKcal,
            averageMinutes: averageMinutes
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
