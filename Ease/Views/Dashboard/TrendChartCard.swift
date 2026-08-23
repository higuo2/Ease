import SwiftUI
import Charts

private struct ChartDayPreview: Equatable {
    var date: Date
    var weight: Double?
}

private struct ChartWeightPoint: Identifiable {
    var id: String
    var date: Date
    var weight: Double
}

struct TrendChartCard: View {
    let records: [DailyRecord]
    let logs: [WeightLog]
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

    private var logsInRange: [WeightLog] {
        let end = CalendarDay.endOfDay(rangeEnd)
        return logs.filter { $0.timestamp >= rangeStart && $0.timestamp < end }
    }

    private var recordsInRange: [DailyRecord] {
        records.filter { $0.date >= rangeStart && $0.date <= rangeEnd }
    }

    /// Every weigh-in in range (muted dots).
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

    /// Last weigh-in per calendar day — the readable trend line.
    private var dailyPoints: [ChartWeightPoint] {
        Dictionary(
            chartWeightPoints.map { (CalendarDay.dayKey(from: $0.date), $0) },
            uniquingKeysWith: { lhs, rhs in lhs.date < rhs.date ? rhs : lhs }
        )
        .values
        .sorted { $0.date < $1.date }
    }

    private var movingAveragePoints: [(date: Date, value: Double)] {
        dailyPoints.compactMap { point in
            guard let ma = WeightMetrics.sevenDayMA(records: records, logs: logs, endingOn: point.date) else {
                return nil
            }
            return (point.date, ma)
        }
    }

    private var weightYDomain: ClosedRange<Double> {
        var values = chartWeightPoints.map(\.weight) + movingAveragePoints.map(\.value)
        if let targetWeight { values.append(targetWeight) }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 0
        let padding = max((maxV - minV) * 0.12, 0.8)
        return (minV - padding)...(maxV + padding)
    }

    var body: some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 16) {
                rangePicker
                if chartWeightPoints.isEmpty {
                    Text("dashboard.chart.empty")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
                } else {
                    weightChart
                }
            }
        }
    }

    private var rangePicker: some View {
        HStack(spacing: 4) {
            ForEach(ChartRange.allCases) { item in
                Button {
                    onSelectRange(item)
                } label: {
                    Text(LocalizedStringKey(item.titleKey))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(item == range ? Color.white : EasePalette.secondaryText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(item == range ? Color.black : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(EasePalette.recessed, in: Capsule())
    }

    private var weightChart: some View {
        Chart {
            if let targetWeight {
                RuleMark(y: .value("chart.axis.target", targetWeight))
                    .foregroundStyle(EasePalette.secondaryText.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text(EaseFormatters.targetKg(targetWeight))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(EasePalette.secondaryText)
                    }
            }

            if dailyPoints.count >= 2 {
                ForEach(dailyPoints) { point in
                    LineMark(
                        x: .value("chart.axis.date", point.date),
                        y: .value("chart.axis.weight", point.weight)
                    )
                    .foregroundStyle(EasePalette.chartLineGradient)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
            }

            ForEach(dailyPoints) { point in
                PointMark(
                    x: .value("chart.axis.date", point.date),
                    y: .value("chart.axis.weight", point.weight)
                )
                .foregroundStyle(EasePalette.coral)
                .symbolSize(48)
            }

            ForEach(movingAveragePoints, id: \.date) { point in
                LineMark(
                    x: .value("chart.axis.date", point.date),
                    y: .value("chart.axis.ma", point.value)
                )
                .foregroundStyle(EasePalette.chartMuted)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }

            if let preview, let weight = preview.weight {
                RuleMark(x: .value("chart.axis.date", preview.date))
                    .foregroundStyle(EasePalette.primaryText.opacity(0.18))
                PointMark(
                    x: .value("chart.axis.date", preview.date),
                    y: .value("chart.axis.weight", weight)
                )
                .foregroundStyle(EasePalette.coralDeep)
                .symbolSize(70)
                .annotation(position: .top, spacing: 8) {
                    tooltip(date: preview.date, weight: weight)
                }
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: weightYDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine()
                    .foregroundStyle(EasePalette.track)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.defaultDigits).day())
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(EasePalette.secondaryText)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                    .foregroundStyle(EasePalette.track)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(EaseFormatters.oneDecimal(number))
                            .font(.system(size: 11, weight: .regular).monospacedDigit())
                            .foregroundStyle(EasePalette.secondaryText)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.padding(.top, 28)
        }
        .frame(height: 260)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                dragLayer(proxy: proxy, geometry: geometry)
            }
        }
    }

    private func tooltip(date: Date, weight: Double) -> some View {
        HStack(spacing: 8) {
            Text(date, format: .dateTime.month(.defaultDigits).day())
            Text(EaseFormatters.kg(weight))
                .monospacedDigit()
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(EasePalette.tooltip, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func dragLayer(proxy: ChartProxy, geometry: GeometryProxy) -> some View {
        Rectangle()
            .fill(Color.clear)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        preview = makePreview(at: value.location, proxy: proxy, geometry: geometry)
                    }
                    .onEnded { _ in
                        preview = nil
                    }
            )
            .onTapGesture { location in
                if let preview = makePreview(at: location, proxy: proxy, geometry: geometry),
                   let log = nearestLog(to: preview.date) {
                    onSelectLog(log)
                }
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
        guard let weight = WeightMetrics.weightOnDay(records: records, logs: logs, on: day) else { return nil }
        return ChartDayPreview(date: day, weight: weight)
    }

    private func nearestLog(to date: Date) -> WeightLog? {
        let key = CalendarDay.dayKey(from: date)
        let onDay = logsInRange.filter { CalendarDay.dayKey(from: $0.timestamp) == key }
        guard !onDay.isEmpty else { return nil }
        return onDay.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(date)) < abs(rhs.timestamp.timeIntervalSince(date))
        }
    }
}
