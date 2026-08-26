import SwiftUI
import Charts

struct CycleDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let history: CycleHistory
    var isPlaceholder = false

    private var lastSpan: CycleSpan? { history.spans.last }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        summaryCard
                        if !history.spans.isEmpty {
                            EaseCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("cycle.calendar")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(EasePalette.primaryText)
                                    timelineChart
                                    ForEach(recentMonths, id: \.self) { month in
                                        monthRow(month)
                                    }
                                }
                            }
                            EaseCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("cycle.recent")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(EasePalette.primaryText)
                                    ForEach(Array(history.spans.reversed().prefix(8))) { span in
                                        spanRow(span)
                                    }
                                }
                            }
                        } else {
                            EaseCard {
                                Text("cycle.empty")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(EasePalette.secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(20)
                }
                .easeHealthPlaceholder(isPlaceholder)
            }
            .navigationTitle("cycle.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EaseTextButton(title: "common.close", action: { dismiss() })
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
        .preferredColorScheme(.light)
        .tint(EasePalette.periodRose)
    }

    private var summaryCard: some View {
        EaseCard(fill: EasePalette.periodPink) {
            HStack(spacing: 20) {
                if let progress = history.progress {
                    EaseArcRing(
                        progress: progress,
                        colors: [EasePalette.periodPink, EasePalette.periodRose],
                        diameter: 108
                    )
                }
                VStack(alignment: .leading, spacing: 8) {
                    if let next = history.predictedNextStart {
                        Text(EaseFormatters.cycleNext(next))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(EasePalette.primaryText)
                    } else {
                        Text("cycle.title")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(EasePalette.primaryText)
                    }
                    if let length = history.cycleLengthDays {
                        Text(String(format: String(localized: "cycle.length"), locale: .current, Int(length.rounded())))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(EasePalette.secondaryText)
                    }
                    if let lastSpan {
                        Text(String(format: String(localized: "cycle.lastDuration"), locale: .current, lastSpan.durationDays))
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(EasePalette.secondaryText)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var timelineChart: some View {
        Chart {
            ForEach(history.spans) { span in
                BarMark(
                    xStart: .value("chart.axis.date", span.start),
                    xEnd: .value("chart.axis.date", CalendarDay.endOfDay(span.end)),
                    y: .value("cycle.title", 1)
                )
                .foregroundStyle(EasePalette.periodRose.opacity(0.7))
                .cornerRadius(4)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisGridLine().foregroundStyle(EasePalette.track)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(.system(size: 10))
                            .foregroundStyle(EasePalette.secondaryText)
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 56)
    }

    private var recentMonths: [Date] {
        let start = CalendarDay.startOfMonth(.now)
        return (0..<4).compactMap { offset in
            Calendar.current.date(byAdding: .month, value: -offset, to: start)
        }
    }

    private func monthRow(_ month: Date) -> some View {
        let days = CalendarDay.daysInMonth(containing: month)
        let leading = CalendarDay.leadingEmptyDays(inMonthContaining: month)
        return VStack(alignment: .leading, spacing: 8) {
            Text(month, format: .dateTime.year().month(.wide))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(EasePalette.primaryText)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 6) {
                ForEach(0..<leading, id: \.self) { _ in
                    Color.clear.frame(height: 18)
                }
                ForEach(days, id: \.self) { day in
                    let key = CalendarDay.dayKey(from: day)
                    let on = history.periodDayKeys.contains(key)
                    Text("\(Calendar.current.component(.day, from: day))")
                        .font(.system(size: 10, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? Color.white : EasePalette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 18)
                        .background(on ? EasePalette.periodRose : Color.clear, in: Circle())
                }
            }
        }
    }

    private func spanRow(_ span: CycleSpan) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(spanLabel(span))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(EasePalette.primaryText)
                Text(String(format: String(localized: "cycle.spanDays"), locale: .current, span.durationDays))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func spanLabel(_ span: CycleSpan) -> String {
        let style = Date.FormatStyle().month(.abbreviated).day()
        if Calendar.current.isDate(span.start, inSameDayAs: span.end) {
            return span.start.formatted(style)
        }
        return "\(span.start.formatted(style)) – \(span.end.formatted(style))"
    }
}

private extension CycleSpan {
    var durationDays: Int {
        (Calendar.current.dateComponents(
            [.day],
            from: CalendarDay.startOfDay(start),
            to: CalendarDay.startOfDay(end)
        ).day ?? 0) + 1
    }
}
