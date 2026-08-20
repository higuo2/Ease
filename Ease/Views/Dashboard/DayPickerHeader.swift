import SwiftUI

enum DayPickerMode: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .week: "dayPicker.week"
        case .month: "dayPicker.month"
        }
    }
}

struct DayPickerHeader: View {
    @Binding var selectedDate: Date
    @Binding var mode: DayPickerMode

    @State private var cursor: Date = CalendarDay.startOfDay(.now)

    var body: some View {
        EaseCard {
            VStack(spacing: 14) {
            HStack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(EasePalette.primaryText)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("dayPicker.previous"))

                Spacer(minLength: 8)

                Text(headerTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(EasePalette.primaryText)
                    .monospacedDigit()

                Spacer(minLength: 8)

                Button(action: goForward) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(canGoForward ? EasePalette.primaryText : EasePalette.secondaryText.opacity(0.35))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .disabled(!canGoForward)
                .accessibilityLabel(Text("dayPicker.next"))
            }

            HStack(spacing: 6) {
                ForEach(DayPickerMode.allCases) { item in
                    Button {
                        mode = item
                        cursor = selectedDate
                    } label: {
                        Text(item.titleKey)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(item == mode ? Color.white : EasePalette.secondaryText)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(item == mode ? EasePalette.accent : EasePalette.track)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if mode == .week {
                weekRow
            } else {
                monthGrid
            }
            }
        }
        .onAppear {
            cursor = selectedDate
        }
        .onChange(of: selectedDate) { _, newValue in
            if !isVisible(newValue) {
                cursor = newValue
            }
        }
        .onChange(of: mode) { _, _ in
            cursor = selectedDate
        }
    }

    private var headerTitle: String {
        if mode == .week {
            let days = CalendarDay.weekDates(containing: cursor)
            guard let first = days.first, let last = days.last else { return "" }
            let style = Date.FormatStyle().month(.abbreviated).day()
            return "\(first.formatted(style)) – \(last.formatted(style))"
        }
        return cursor.formatted(Date.FormatStyle().month(.wide).year())
    }

    private var canGoForward: Bool {
        !CalendarDay.isFuture(nextCursor)
    }

    private var nextCursor: Date {
        switch mode {
        case .week:
            CalendarDay.addingDays(7, to: CalendarDay.startOfWeek(cursor))
        case .month:
            Calendar.current.date(
                byAdding: .month,
                value: 1,
                to: CalendarDay.startOfMonth(cursor)
            ) ?? cursor
        }
    }

    private var previousCursor: Date {
        switch mode {
        case .week:
            CalendarDay.addingDays(-7, to: CalendarDay.startOfWeek(cursor))
        case .month:
            Calendar.current.date(
                byAdding: .month,
                value: -1,
                to: CalendarDay.startOfMonth(cursor)
            ) ?? cursor
        }
    }

    private var weekRow: some View {
        let days = CalendarDay.weekDates(containing: cursor)
        return HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                dayCell(day, showsWeekday: true)
            }
        }
    }

    private var monthGrid: some View {
        let days = CalendarDay.daysInMonth(containing: cursor)
        let leading = CalendarDay.leadingEmptyDays(inMonthContaining: cursor)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(CalendarDay.weekdayHeaderSymbols(), id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0..<leading, id: \.self) { _ in
                    Color.clear.frame(height: 36)
                }
                ForEach(days, id: \.self) { day in
                    dayCell(day, showsWeekday: false)
                }
            }
        }
    }

    private func dayCell(_ day: Date, showsWeekday: Bool) -> some View {
        let selected = Calendar.current.isDate(day, inSameDayAs: selectedDate)
        let future = CalendarDay.isFuture(day)
        let today = Calendar.current.isDateInToday(day)
        return Button {
            guard !future else { return }
            selectedDate = CalendarDay.startOfDay(day)
        } label: {
            VStack(spacing: 4) {
                if showsWeekday {
                    Text(day, format: .dateTime.weekday(.narrow))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(future ? EasePalette.secondaryText.opacity(0.35) : EasePalette.secondaryText)
                }
                Text(day, format: .dateTime.day())
                    .font(.system(size: 15, weight: selected ? .bold : .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(future ? EasePalette.secondaryText.opacity(0.35) : EasePalette.primaryText)
                    .frame(width: 36, height: 36)
                    .background {
                        if selected {
                            Circle().fill(EasePalette.accent.opacity(0.18))
                        } else if today {
                            Circle().stroke(EasePalette.accent.opacity(0.45), lineWidth: 1)
                        }
                    }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(future)
    }

    private func isVisible(_ date: Date) -> Bool {
        switch mode {
        case .week:
            CalendarDay.weekDates(containing: cursor).contains { Calendar.current.isDate($0, inSameDayAs: date) }
        case .month:
            Calendar.current.isDate(date, equalTo: cursor, toGranularity: .month)
        }
    }

    private func goBack() {
        cursor = previousCursor
    }

    private func goForward() {
        guard canGoForward else { return }
        cursor = nextCursor
    }
}
