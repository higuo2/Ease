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

struct TrendChartCard: View {
    let records: [DailyRecord]
    let healthByDay: [String: HealthDaySnapshot]
    let range: ChartRange
    let onSelectRange: (ChartRange) -> Void
    let onSelectDate: (Date) -> Void

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

    private var weightPoints: [(date: Date, weight: Double)] {
        recordsInRange.compactMap { record in
            guard let weight = record.weight else { return nil }
            return (record.date, weight)
        }
    }

    private var movingAveragePoints: [(date: Date, value: Double)] {
        weightPoints.compactMap { point in
            guard let ma = WeightMetrics.sevenDayMA(records: records, endingOn: point.date) else {
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
            ForEach(weightPoints, id: \.date) { point in
                LineMark(
                    x: .value("chart.axis.date", point.date),
                    y: .value("chart.axis.weight", point.weight)
                )
                .foregroundStyle(EasePalette.chartMuted)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.5))

                PointMark(
                    x: .value("chart.axis.date", point.date),
                    y: .value("chart.axis.weight", point.weight)
                )
                .foregroundStyle(EasePalette.chartMuted)
                .symbolSize(24)
                .annotation(position: .top, spacing: 4) {
                    if let tag = tags(on: point.date).first {
                        Image(systemName: tag.systemImage)
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(EasePalette.accent)
                    }
                }
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

            if let preview {
                RuleMark(x: .value("chart.axis.date", preview.date))
                    .foregroundStyle(EasePalette.accent.opacity(0.35))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
        }
        .chartXScale(domain: xDomain)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
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
                guard let day = makePreview(at: location, proxy: proxy, geometry: geometry)?.date,
                      let nearest = nearestRecord(to: day) else { return }
                onSelectDate(nearest.date)
            }
    }

    private func makePreview(at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy) -> ChartDayPreview? {
        let x: CGFloat
        if let plotFrame = proxy.plotFrame {
            x = location.x - geometry[plotFrame].origin.x
        } else {
            x = location.x
        }
        guard let date: Date = proxy.value(atX: x) else { return nil }
        let day = CalendarDay.startOfDay(date)
        guard day >= rangeStart && day <= rangeEnd else { return nil }
        let key = CalendarDay.dayKey(from: day)
        let record = records.first { $0.dayKey == key }
        let health = healthByDay[key]
        return ChartDayPreview(
            date: day,
            weight: record?.weight,
            movingAverage: WeightMetrics.sevenDayMA(records: records, endingOn: day),
            diet: record?.dietStatus,
            tags: HealthDisplay.tags(record: record, isMenstrual: health?.isMenstrual == true),
            sleepHours: health?.previousNightSleepHours,
            activeEnergyKcal: health?.activeEnergyKcal
        )
    }

    private func nearestRecord(to date: Date) -> DailyRecord? {
        let target = CalendarDay.startOfDay(date)
        let maxDelta: TimeInterval = 2 * 24 * 60 * 60
        return recordsInRange
            .filter { abs($0.date.timeIntervalSince(target)) <= maxDelta }
            .min { lhs, rhs in
                abs(lhs.date.timeIntervalSince(target)) < abs(rhs.date.timeIntervalSince(target))
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
