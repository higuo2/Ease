import SwiftUI
import Charts

struct TrendLogPoint: Equatable, Sendable, Identifiable {
    var id: UUID
    var timestamp: Date
    var weight: Double
}

struct TrendChartPoint: Equatable, Sendable, Identifiable {
    var id: String
    var date: Date
    var weight: Double
}

struct TrendMAPoint: Equatable, Sendable, Identifiable {
    var id: Date { date }
    var date: Date
    var value: Double
}

struct TrendChartModel: Equatable, Sendable {
    var range: ChartRange
    var rangeStart: Date
    var rangeEnd: Date
    var points: [TrendChartPoint]
    var daily: [TrendChartPoint]
    var movingAverage: [TrendMAPoint]
    var yDomain: ClosedRange<Double>
    var logsByDay: [String: [TrendLogPoint]]
    var maByDay: [String: Double]

    var xDomain: ClosedRange<Date> {
        rangeStart...CalendarDay.endOfDay(rangeEnd)
    }

    var isEmpty: Bool { points.isEmpty }

    func dailyPoint(on date: Date, calendar: Calendar = .current) -> TrendChartPoint? {
        let key = CalendarDay.dayKey(from: date, calendar: calendar)
        return daily.first { CalendarDay.dayKey(from: $0.date, calendar: calendar) == key }
    }

    func nearestLog(to date: Date, calendar: Calendar = .current) -> TrendLogPoint? {
        let key = CalendarDay.dayKey(from: date, calendar: calendar)
        guard let onDay = logsByDay[key], !onDay.isEmpty else { return nil }
        return onDay.min { lhs, rhs in
            abs(lhs.timestamp.timeIntervalSince(date)) < abs(rhs.timestamp.timeIntervalSince(date))
        }
    }

    static func make(
        records: [DailyRecord],
        logs: [WeightLog],
        range: ChartRange,
        targetWeight: Double?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TrendChartModel {
        let rangeEnd = CalendarDay.startOfDay(now, calendar: calendar)
        let samples = WeightMetrics.samples(from: records, logs: logs, calendar: calendar)
        let rangeStart: Date
        if let count = range.dayCount {
            rangeStart = CalendarDay.addingDays(-(count - 1), to: rangeEnd, calendar: calendar)
        } else {
            rangeStart = samples.map(\.date).min().map { CalendarDay.startOfDay($0, calendar: calendar) } ?? rangeEnd
        }
        let endExclusive = CalendarDay.endOfDay(rangeEnd, calendar: calendar)

        var logPoints: [TrendLogPoint] = []
        logPoints.reserveCapacity(logs.count)
        var logsByDay: [String: [TrendLogPoint]] = [:]
        for log in logs {
            let point = TrendLogPoint(id: log.id, timestamp: log.timestamp, weight: log.weight)
            logPoints.append(point)
            let key = CalendarDay.dayKey(from: log.timestamp, calendar: calendar)
            logsByDay[key, default: []].append(point)
        }
        for key in logsByDay.keys {
            logsByDay[key]?.sort { $0.timestamp < $1.timestamp }
        }

        let daysWithLogs = Set(logsByDay.keys)
        var points: [TrendChartPoint] = []
        points.reserveCapacity(logs.count + records.count)
        for log in logs where log.timestamp >= rangeStart && log.timestamp < endExclusive {
            points.append(TrendChartPoint(id: log.id.uuidString, date: log.timestamp, weight: log.weight))
        }
        for record in records {
            guard let weight = record.weight, !daysWithLogs.contains(record.dayKey) else { continue }
            let day = CalendarDay.startOfDay(record.date, calendar: calendar)
            guard day >= rangeStart && day <= rangeEnd else { continue }
            points.append(TrendChartPoint(id: "legacy-\(record.dayKey)", date: record.date, weight: weight))
        }
        points.sort { $0.date < $1.date }

        let daily = Dictionary(
            points.map { (CalendarDay.dayKey(from: $0.date, calendar: calendar), $0) },
            uniquingKeysWith: { lhs, rhs in lhs.date < rhs.date ? rhs : lhs }
        )
        .values
        .sorted { $0.date < $1.date }

        let movingAverages = WeightMetrics.sevenDayMovingAverages(samples: samples, calendar: calendar)
        var maByDay: [String: Double] = [:]
        maByDay.reserveCapacity(movingAverages.count)
        var movingAverage: [TrendMAPoint] = []
        movingAverage.reserveCapacity(daily.count)
        for sample in movingAverages {
            let key = CalendarDay.dayKey(from: sample.date, calendar: calendar)
            maByDay[key] = sample.weight
        }
        for point in daily {
            let key = CalendarDay.dayKey(from: point.date, calendar: calendar)
            if let ma = maByDay[key] {
                movingAverage.append(TrendMAPoint(date: point.date, value: ma))
            }
        }

        var values = points.map(\.weight) + movingAverage.map(\.value)
        if let targetWeight { values.append(targetWeight) }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 0
        let padding = max((maxV - minV) * 0.12, 0.8)

        return TrendChartModel(
            range: range,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            points: points,
            daily: daily,
            movingAverage: movingAverage,
            yDomain: (minV - padding)...(maxV + padding),
            logsByDay: logsByDay,
            maByDay: maByDay
        )
    }
}

private struct ChartDayPreview: Equatable {
    var date: Date
    var weight: Double
    var movingAverage: Double?
}

struct TrendChartCard: View, Equatable {
    let model: TrendChartModel
    var targetWeight: Double? = nil
    var logSheetPresented: Bool = false
    var focusDate: Date? = nil
    var focusNonce: Int = 0
    let onSelectRange: (ChartRange) -> Void
    let onSelectLog: (UUID, Date) -> Void

    @State private var preview: ChartDayPreview?
    @State private var scrubDayKey = ""
    @State private var isScrubbing = false
    @State private var lastScrubX: CGFloat = -.infinity

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model == rhs.model
            && lhs.targetWeight == rhs.targetWeight
            && lhs.logSheetPresented == rhs.logSheetPresented
            && lhs.focusDate == rhs.focusDate
            && lhs.focusNonce == rhs.focusNonce
    }

    var body: some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 16) {
                TrendRangePicker(range: model.range, onSelectRange: onSelectRange)
                if model.isEmpty {
                    Text("dashboard.chart.empty")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
                } else {
                    weightChart
                }
            }
        }
        .onChange(of: logSheetPresented) { _, presented in
            if presented {
                clearPreview()
            }
        }
        .onChange(of: model.range) { _, _ in
            clearPreview()
        }
        .onChange(of: focusNonce) { _, _ in
            pinFocusIfPossible()
        }
        .sensoryFeedback(.selection, trigger: model.range)
    }

    private var weightChart: some View {
        Chart {
            if let targetWeight {
                RuleMark(y: .value(Self.yWeight, targetWeight))
                    .foregroundStyle(EasePalette.secondaryText.opacity(0.55))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .annotation(position: .top, alignment: .trailing) {
                        Text(EaseFormatters.targetKg(targetWeight))
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(EasePalette.secondaryText)
                    }
            }

            if model.daily.count >= 2 {
                ForEach(model.daily) { point in
                    LineMark(
                        x: .value(Self.xDate, point.date),
                        y: .value(Self.yWeight, point.weight)
                    )
                    .foregroundStyle(EasePalette.chartLineGradient)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }
            }

            ForEach(model.daily) { point in
                PointMark(
                    x: .value(Self.xDate, point.date),
                    y: .value(Self.yWeight, point.weight)
                )
                .foregroundStyle(EasePalette.coral)
                .symbolSize(48)
            }

            ForEach(model.movingAverage) { point in
                LineMark(
                    x: .value(Self.xDate, point.date),
                    y: .value(Self.yWeight, point.value)
                )
                .foregroundStyle(EasePalette.chartMuted)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            }
        }
        .chartXScale(domain: model.xDomain)
        .chartYScale(domain: model.yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisGridLine()
                    .foregroundStyle(EasePalette.track)
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: EaseDateFormat.monthDayNumeric)
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
        .chartOverlay { proxy in
            GeometryReader { geometry in
                interactionLayer(proxy: proxy, geometry: geometry)
            }
        }
        .frame(height: 260)
        .sensoryFeedback(.selection, trigger: scrubDayKey)
    }

    private func tooltip(date: Date, weight: Double, movingAverage: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(date, format: EaseDateFormat.monthDayNumeric)
                Text(EaseFormatters.kg(weight))
                    .monospacedDigit()
            }
            .font(.system(size: 13, weight: .semibold))
            if let movingAverage {
                Text(EaseFormatters.sevenDayMA(movingAverage))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.75))
                    .monospacedDigit()
            }
        }
        .foregroundStyle(Color.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(EasePalette.tooltip, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func interactionLayer(proxy: ChartProxy, geometry: GeometryProxy) -> some View {
        let previewPoint: CGPoint? = {
            guard let preview else { return nil }
            return plotPoint(for: preview.date, weight: preview.weight, proxy: proxy, geometry: geometry)
        }()

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .highPriorityGesture(scrubAndTapGesture(proxy: proxy, geometry: geometry))

            if let preview, let point = previewPoint {
                Capsule()
                    .fill(EasePalette.primaryText.opacity(0.18))
                    .frame(width: 1.5, height: geometry.size.height)
                    .position(x: point.x, y: geometry.size.height / 2)
                    .allowsHitTesting(false)
                Circle()
                    .fill(EasePalette.coralDeep)
                    .frame(width: 10, height: 10)
                    .position(point)
                    .allowsHitTesting(false)
                tooltip(
                    date: preview.date,
                    weight: preview.weight,
                    movingAverage: preview.movingAverage
                )
                .fixedSize()
                .position(
                    x: tooltipX(point.x, width: geometry.size.width),
                    y: max(22, point.y - 36)
                )
                .allowsHitTesting(false)
            }
        }
    }

    private func scrubAndTapGesture(proxy: ChartProxy, geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let distance = hypot(value.translation.width, value.translation.height)
                guard distance >= 8 else { return }
                isScrubbing = true
                guard abs(value.location.x - lastScrubX) >= Self.scrubMinDeltaX else { return }
                lastScrubX = value.location.x
                applyPreview(makePreview(at: value.location, proxy: proxy, geometry: geometry))
            }
            .onEnded { value in
                let distance = hypot(value.translation.width, value.translation.height)
                let wasScrubbing = isScrubbing
                isScrubbing = false
                if wasScrubbing || distance >= 8 {
                    return
                }
                handleTap(at: value.location, proxy: proxy, geometry: geometry)
            }
    }

    private func handleTap(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) {
        guard let next = makePreview(at: location, proxy: proxy, geometry: geometry) else {
            clearPreview()
            return
        }
        if let log = model.nearestLog(to: next.date) {
            clearPreview()
            onSelectLog(log.id, log.timestamp)
        } else {
            applyPreview(next)
        }
    }

    private func applyPreview(_ next: ChartDayPreview?) {
        preview = next
        guard let next else {
            scrubDayKey = ""
            return
        }
        let key = CalendarDay.dayKey(from: next.date)
        if key != scrubDayKey {
            scrubDayKey = key
        }
    }

    private func clearPreview() {
        preview = nil
        scrubDayKey = ""
        isScrubbing = false
        lastScrubX = -.infinity
    }

    private func pinFocusIfPossible() {
        guard let focusDate, let point = model.dailyPoint(on: focusDate) else { return }
        applyPreview(
            ChartDayPreview(
                date: point.date,
                weight: point.weight,
                movingAverage: model.maByDay[CalendarDay.dayKey(from: point.date)]
            )
        )
    }

    private func plotPoint(
        for date: Date,
        weight: Double,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) -> CGPoint? {
        guard let plotFrame = proxy.plotFrame else { return nil }
        let frame = geometry[plotFrame]
        guard let x = proxy.position(forX: date), let y = proxy.position(forY: weight) else {
            return nil
        }
        return CGPoint(x: frame.origin.x + x, y: frame.origin.y + y)
    }

    private func tooltipX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        min(max(x, 64), max(64, width - 64))
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
        guard day >= model.rangeStart && day <= model.rangeEnd else { return nil }
        return date
    }

    private func makePreview(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) -> ChartDayPreview? {
        guard let date = dateAt(location, proxy: proxy, geometry: geometry) else { return nil }
        guard let point = model.dailyPoint(on: date) else { return nil }
        return ChartDayPreview(
            date: point.date,
            weight: point.weight,
            movingAverage: model.maByDay[CalendarDay.dayKey(from: point.date)]
        )
    }

    private static let yWeight = "chart.axis.weight"
    private static let xDate = "chart.axis.date"
    private static let scrubMinDeltaX: CGFloat = 2
}

private struct TrendRangePicker: View, Equatable {
    let range: ChartRange
    let onSelectRange: (ChartRange) -> Void

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.range == rhs.range
    }

    var body: some View {
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
                        .background(item == range ? Color.black : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(EasePalette.recessed, in: Capsule())
    }
}
