import SwiftUI
import Charts

struct TrendChartCard: View {
    let records: [DailyRecord]
    let range: ChartRange
    let onSelectRange: (ChartRange) -> Void
    let onSelectDate: (Date) -> Void

    private var visibleRecords: [DailyRecord] {
        let start = Calendar.current.date(byAdding: .day, value: -(range.rawValue - 1), to: CalendarDay.startOfDay(.now)) ?? .now
        return records.filter { $0.date >= start && $0.weight != nil }
    }

    private var weightPoints: [(date: Date, weight: Double)] {
        visibleRecords.compactMap { record in
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

                if weightPoints.isEmpty {
                    Text("dashboard.chart.empty")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 160, alignment: .center)
                } else {
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
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: 180)
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { location in
                                    let x: CGFloat
                                    if let plotFrame = proxy.plotFrame {
                                        x = location.x - geometry[plotFrame].origin.x
                                    } else {
                                        x = location.x
                                    }
                                    guard let date: Date = proxy.value(atX: x) else { return }
                                    if let nearest = nearestRecord(to: date) {
                                        onSelectDate(nearest.date)
                                    }
                                }
                        }
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

    private var dietRow: some View {
        HStack {
            ForEach(recentDietDays, id: \.self) { day in
                let key = CalendarDay.dayKey(from: day)
                let record = records.first { $0.dayKey == key }
                VStack(spacing: 4) {
                    Image(systemName: record?.dietStatus?.systemImage ?? "circle")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(record?.dietStatus == nil ? EasePalette.secondaryText.opacity(0.4) : EasePalette.primaryText)
                    if let tags = record?.variableTags, !tags.isEmpty {
                        Image(systemName: tags[0].systemImage)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(EasePalette.accent)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityLabel(Text("dashboard.dietRow"))
    }

    private func nearestRecord(to date: Date) -> DailyRecord? {
        let target = CalendarDay.startOfDay(date)
        let maxDelta: TimeInterval = 2 * 24 * 60 * 60
        return visibleRecords
            .filter { abs($0.date.timeIntervalSince(target)) <= maxDelta }
            .min { lhs, rhs in
                abs(lhs.date.timeIntervalSince(target)) < abs(rhs.date.timeIntervalSince(target))
            }
    }
}
