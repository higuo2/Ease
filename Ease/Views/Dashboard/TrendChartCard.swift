import SwiftUI
import Charts

private struct ChartDayPreview: Equatable {
    var date: Date
    var weight: Double?
    var movingAverage: Double?
    var diet: DietStatus?
    var tags: [VariableTag]
    var sleepHours: Double?
    var activeEnergyKcal: Double?
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
    let onSelectRange: (ChartRange) -> Void
    let onSelectLog: (WeightLog) -> Void

    @State private var preview: ChartDayPreview?

    private var rangeStart: Date {
        Calendar.current.date(
            byAdding: .day,
            value: -(range.rawValue - 1),
            to: CalendarDay.startOfDay(.now)
        ) ?? CalendarDay.startOfDay(.now)
    }

    private var rangeEnd: Date {
        CalendarDay.startOfDay(.now)
    }

    private var xDomain: ClosedRange<Date> {
        rangeStart...CalendarDay.endOfDay(rangeEnd)
    }

    private var visibleDays: [Date] {
        CalendarDay.datesBack(range.rawValue, from: .now)
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

    private var energyPoints: [(date: Date, value: Double)] {
        visibleDays.compactMap { day in
            guard let value = healthByDay[CalendarDay.dayKey(from: day)]?.activeEnergyKcal else {
                return nil
            }
            return (day, value)
        }
    }

    private var sleepPoints: [(date: Date, value: Double)] {
        visibleDays.compactMap { day in
            guard let value = healthByDay[CalendarDay.dayKey(from: day)]?.previousNightSleepHours else {
                return nil
            }
            return (day, value)
        }
    }

    private var hasHealthLayer: Bool {
        !energyPoints.isEmpty || !sleepPoints.isEmpty
    }

    private var recentDietDays: [Date] {
        CalendarDay.datesBack(7, from: .now)
    }

    /// Keep a usable Y span so a single weight point does not collapse into a blank plot.
    private var weightYDomain: ClosedRange<Double> {
        let values = weightPoints.map(\.weight) + movingAveragePoints.map(\.value)
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
                HStack {
                    Text("dashboard.trend")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(EasePalette.primaryText)
                    Spacer()
                    rangePicker
                }

                if let preview {
                    previewRow(preview)
                }

                if weightPoints.isEmpty && !hasHealthLayer {
                    Text("dashboard.chart.empty")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
                } else {
                    if !weightPoints.isEmpty {
                        weightChart
                    }
                    if hasHealthLayer {
                        healthLayer
                    }
                }

                dietRow
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
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(item == range ? Color.white : EasePalette.secondaryText)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(item == range ? EasePalette.accent : EasePalette.track)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weightChart: some View {
        Chart {
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
                .symbolSize(48)
            }

            ForEach(movingAveragePoints, id: \.date) { point in
                LineMark(
                    x: .value("chart.axis.date", point.date),
                    y: .value("chart.axis.ma", point.value)
                )
                .foregroundStyle(EasePalette.accent)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3))
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
                    .foregroundStyle(EasePalette.accent)
                }
            }

            if let preview {
                RuleMark(x: .value("chart.axis.date", preview.date))
                    .foregroundStyle(EasePalette.accent.opacity(0.35))
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
        .frame(height: 180)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                dragLayer(proxy: proxy, geometry: geometry)
            }
        }
    }

    private var healthLayer: some View {
        VStack(spacing: 8) {
            if !energyPoints.isEmpty {
                healthBars(points: energyPoints, yKey: "chart.axis.energy")
            }
            if !sleepPoints.isEmpty {
                healthBars(points: sleepPoints, yKey: "chart.axis.sleep")
            }
        }
    }

    private func healthBars(points: [(date: Date, value: Double)], yKey: String) -> some View {
        Chart {
            ForEach(points, id: \.date) { point in
                BarMark(
                    x: .value("chart.axis.date", point.date, unit: .day),
                    y: .value(yKey, point.value)
                )
                .foregroundStyle(EasePalette.healthBar)
                .cornerRadius(2)
            }
            if let preview {
                RuleMark(x: .value("chart.axis.date", preview.date))
                    .foregroundStyle(EasePalette.accent.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartXScale(domain: xDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .frame(height: 36)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                dragLayer(proxy: proxy, geometry: geometry)
            }
        }
    }

    private var dietRow: some View {
        HStack {
            ForEach(recentDietDays, id: \.self) { day in
                let record = record(on: day)
                let merged = tags(on: day)
                VStack(spacing: 4) {
                    Image(systemName: record?.dietStatus?.systemImage ?? "circle")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(record?.dietStatus == nil ? EasePalette.secondaryText.opacity(0.4) : EasePalette.primaryText)
                    if let tag = merged.first {
                        Image(systemName: tag.systemImage)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(EasePalette.accent)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityLabel(Text("dashboard.dietRow"))
    }

    private func previewRow(_ preview: ChartDayPreview) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(preview.date, format: .dateTime.month(.abbreviated).day())
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
                if let weight = preview.weight {
                    Text(EaseFormatters.kg(weight))
                        .font(EaseFont.number(18))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                }
                if let ma = preview.movingAverage {
                    Text(String(format: String(localized: "chart.preview.ma"), locale: .current, ma))
                        .font(.system(size: 12, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.accent)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    if let diet = preview.diet {
                        Image(systemName: diet.systemImage)
                    }
                    ForEach(preview.tags, id: \.self) { tag in
                        Image(systemName: tag.systemImage)
                    }
                }
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(EasePalette.primaryText)
                if let hours = preview.sleepHours {
                    Text(EaseFormatters.hours(hours))
                        .font(.system(size: 12, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.secondaryText)
                }
                if let kcal = preview.activeEnergyKcal {
                    Text(EaseFormatters.kcal(kcal))
                        .font(.system(size: 12, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.secondaryText)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("chart.preview.a11y"))
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
            tags: HealthDisplay.tags(record: record, isMenstrual: health?.isMenstrual == true),
            sleepHours: health?.previousNightSleepHours,
            activeEnergyKcal: health?.activeEnergyKcal
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
