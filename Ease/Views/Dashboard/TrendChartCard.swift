import SwiftUI
import Charts

private struct ChartDayPreview: Equatable {
    var date: Date
    var weight: Double?
    var movingAverage: Double?
    var diet: DietStatus?
    var tags: [VariableTag]
}

private struct ChartTagMark: Identifiable {
    var id: Date { date }
    var date: Date
    var y: Double
    var tags: [VariableTag]
}

private struct ChartWeightPoint: Identifiable {
    var id: String
    var date: Date
    var weight: Double
}

struct TrendChartCard: View {
    let records: [DailyRecord]
    let logs: [WeightLog]
    let healthByDay: [String: HealthDaySnapshot]
    let range: ChartRange
    var targetWeight: Double? = nil
    let onSelectRange: (ChartRange) -> Void
    let onSelectLog: (WeightLog) -> Void

    @State private var preview: ChartDayPreview?

    private var rangeEnd: Date {
        CalendarDay.startOfDay(.now)
    }

    private var rangeStart: Date {
        if let count = range.dayCount {
            return Calendar.current.date(
                byAdding: .day,
                value: -(count - 1),
                to: rangeEnd
            ) ?? rangeEnd
        }
        let samples = WeightMetrics.samples(from: records, logs: logs)
        return samples.map(\.date).min().map { CalendarDay.startOfDay($0) } ?? rangeEnd
    }

    private var xDomain: ClosedRange<Date> {
        rangeStart...CalendarDay.endOfDay(rangeEnd)
    }

    private var daySpan: Int {
        max(
            1,
            Calendar.current.dateComponents([.day], from: rangeStart, to: rangeEnd).day.map { $0 + 1 } ?? 1
        )
    }

    private var visibleDays: [Date] {
        CalendarDay.datesBack(daySpan, from: .now).filter { $0 >= rangeStart }
    }

    private var recordsInRange: [DailyRecord] {
        records.filter { $0.date >= rangeStart && $0.date <= rangeEnd }
    }

    private var chartWeightPoints: [ChartWeightPoint] {
        let fromLogs = logsInRange.map {
            ChartWeightPoint(id: $0.id.uuidString, date: $0.timestamp, weight: $0.weight)
        }
        let daysWithLogs = Set(logsInRange.map { CalendarDay.dayKey(from: $0.timestamp) })
        let fromLegacy = recordsInRange.compactMap { record -> ChartWeightPoint? in
            guard let weight = record.weight, !daysWithLogs.contains(record.dayKey) else { return nil }
            return ChartWeightPoint(id: "legacy-\(record.dayKey)", date: record.date, weight: weight)
        }
        return (fromLogs + fromLegacy).sorted { $0.date < $1.date }
    }

    private var weightPoints: [(date: Date, weight: Double)] {
        chartWeightPoints.map { ($0.date, $0.weight) }
    }

    private var logsInRange: [WeightLog] {
        let end = CalendarDay.endOfDay(rangeEnd)
        return logs.filter { $0.timestamp >= rangeStart && $0.timestamp < end }
    }

    private var movingAveragePoints: [(date: Date, value: Double)] {
        let lastPerDay = Dictionary(
            chartWeightPoints.map { (CalendarDay.dayKey(from: $0.date), $0) },
            uniquingKeysWith: { lhs, rhs in lhs.date < rhs.date ? rhs : lhs }
        )
        return lastPerDay.values
            .sorted { $0.date < $1.date }
            .compactMap { point in
                guard let ma = WeightMetrics.sevenDayMA(records: records, logs: logs, endingOn: point.date) else {
                    return nil
                }
                return (point.date, ma)
            }
    }

    private var weightYDomain: ClosedRange<Double> {
        var values = weightPoints.map(\.weight) + movingAveragePoints.map(\.value)
        if let targetWeight { values.append(targetWeight) }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 0
        let mid = (minV + maxV) / 2
        let halfSpan = max((maxV - minV) / 2 + 0.3, 0.6)
        return (mid - halfSpan)...(mid + halfSpan)
    }

    private var tagMarks: [ChartTagMark] {
        visibleDays.compactMap { day in
            let dayTags = tags(on: day)
            guard !dayTags.isEmpty else { return nil }
            return ChartTagMark(
                date: day,
                y: WeightMetrics.weightOnDay(records: records, logs: logs, on: day) ?? weightYDomain.upperBound,
                tags: dayTags
            )
        }
    }

    var body: some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 16) {
                rangePicker

                if let preview {
                    tooltip(preview)
                }

                if weightPoints.isEmpty {
                    Text("dashboard.chart.empty")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 200, alignment: .center)
                } else {
                    weightChart
                }
            }
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 6) {
            ForEach(ChartRange.allCases) { item in
                Button {
                    onSelectRange(item)
                } label: {
                    Text(LocalizedStringKey(item.titleKey))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(item == range ? EasePalette.primaryText : EasePalette.secondaryText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(item == range ? EasePalette.card : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(EasePalette.recessed, in: Capsule())
    }

    private func tooltip(_ preview: ChartDayPreview) -> some View {
        HStack(spacing: 8) {
            Text(preview.date, format: .dateTime.month(.defaultDigits).day())
            if let weight = preview.weight {
                Text(EaseFormatters.kg(weight))
                    .monospacedDigit()
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(EasePalette.tooltip, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var weightChart: some View {
        Chart {
            if let targetWeight {
                RuleMark(y: .value("chart.axis.target", targetWeight))
                    .foregroundStyle(EasePalette.secondaryText.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
            }

            if chartWeightPoints.count >= 2 {
                ForEach(chartWeightPoints) { point in
                    LineMark(
                        x: .value("chart.axis.date", point.date),
                        y: .value("chart.axis.weight", point.weight)
                    )
                    .foregroundStyle(EasePalette.chartMuted)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
            }

            ForEach(chartWeightPoints) { point in
                PointMark(
                    x: .value("chart.axis.date", point.date),
                    y: .value("chart.axis.weight", point.weight)
                )
                .foregroundStyle(EasePalette.chartMuted)
                .symbolSize(36)
            }

            ForEach(movingAveragePoints, id: \.date) { point in
                LineMark(
                    x: .value("chart.axis.date", point.date),
                    y: .value("chart.axis.ma", point.value)
                )
                .foregroundStyle(EasePalette.coral)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }

            ForEach(tagMarks) { mark in
                PointMark(
                    x: .value("chart.axis.date", mark.date),
                    y: .value("chart.axis.weight", mark.y)
                )
                .symbolSize(0)
                .annotation(position: .top, spacing: 6) {
                    HStack(spacing: 2) {
                        ForEach(mark.tags, id: \.self) { tag in
                            Image(systemName: tag.systemImage)
                        }
                    }
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
                }
            }

            if let preview {
                RuleMark(x: .value("chart.axis.date", preview.date))
                    .foregroundStyle(EasePalette.primaryText.opacity(0.2))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: weightYDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartPlotStyle { plot in
            plot.padding(.top, 18)
        }
        .frame(height: 220)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                dragLayer(proxy: proxy, geometry: geometry)
            }
        }
    }

    private func dragLayer(proxy: ChartProxy, geometry: GeometryProxy) -> some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onChanged { value in
                        preview = makePreview(at: value.location, proxy: proxy, geometry: geometry)
                    }
                    .onEnded { _ in
                        preview = nil
                    }
            )
            .onTapGesture { location in
                guard let tapped = dateAt(location, proxy: proxy, geometry: geometry),
                      let log = nearestLog(to: tapped) else { return }
                onSelectLog(log)
            }
    }

    private func dateAt(_ location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) -> Date? {
        let x: CGFloat
        if let plotFrame = proxy.plotFrame {
            x = location.x - geometry[plotFrame].origin.x
        } else {
            x = location.x
        }
        guard let date: Date = proxy.value(atX: x) else { return nil }
        let day = CalendarDay.startOfDay(date)
        guard day >= rangeStart && day <= rangeEnd else { return nil }
        return date
    }

    private func makePreview(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) -> ChartDayPreview? {
        guard let date = dateAt(location, proxy: proxy, geometry: geometry) else { return nil }
        let day = CalendarDay.startOfDay(date)
        let key = CalendarDay.dayKey(from: day)
        let record = records.first { $0.dayKey == key }
        let health = healthByDay[key]
        return ChartDayPreview(
            date: day,
            weight: WeightMetrics.weightOnDay(records: records, logs: logs, on: day),
            movingAverage: WeightMetrics.sevenDayMA(records: records, logs: logs, endingOn: day),
            diet: record?.dietStatus,
            tags: HealthDisplay.tags(record: record, isMenstrual: health?.isMenstrual == true)
        )
    }

    private func nearestLog(to date: Date) -> WeightLog? {
        let key = CalendarDay.dayKey(from: date)
        let onDay = logsInRange.filter { CalendarDay.dayKey(from: $0.timestamp) == key }
        guard !onDay.isEmpty else { return nil }
        return onDay.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(date)) < abs(rhs.timestamp.timeIntervalSince(date))
        }
    }

    private func record(on day: Date) -> DailyRecord? {
        let key = CalendarDay.dayKey(from: day)
        return records.first { $0.dayKey == key }
    }

    private func tags(on day: Date) -> [VariableTag] {
        let key = CalendarDay.dayKey(from: day)
        return HealthDisplay.tags(
            record: record(on: day),
            isMenstrual: healthByDay[key]?.isMenstrual == true
        )
    }
}
