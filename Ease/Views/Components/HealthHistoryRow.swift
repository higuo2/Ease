import SwiftUI
import Charts

/// Two-column history row for Sleep / Energy / Cycle detail lists.
struct HealthHistoryRow: View {
    var leadingWidth: CGFloat = 118
    let leading: String
    let trailing: String

    init(date: Date, value: String, leadingWidth: CGFloat = 118) {
        self.leadingWidth = leadingWidth
        self.leading = date.formatted(
            Date.FormatStyle().weekday(.abbreviated).day().month(.abbreviated)
        )
        self.trailing = value
    }

    init(leading: String, value: String, leadingWidth: CGFloat = 148) {
        self.leadingWidth = leadingWidth
        self.leading = leading
        self.trailing = value
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(leading)
                .font(.subheadline)
                .foregroundStyle(EasePalette.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: leadingWidth, alignment: .leading)
            Text(trailing)
                .font(.body.monospacedDigit())
                .foregroundStyle(EasePalette.primaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(EasePalette.recessed, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

enum HealthDetailChart {
    static let dayBarVisibleDays = 7
    static let cycleVisibleDays = 14
    static let barRatio: CGFloat = 0.55
    static let barCornerRadius: CGFloat = 6
    static let visibleDayLength: TimeInterval = 24 * 3600

    /// Leading edge of the visible window so `latest` sits at the trailing side.
    static func leadingX(latest: Date, visibleDays: Int, calendar: Calendar = .current) -> Date {
        CalendarDay.addingDays(-(visibleDays - 1), to: latest, calendar: calendar)
    }
}

extension View {
    func easeScrollableHealthChart(latestDate: Date, visibleDays: Int) -> some View {
        chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: TimeInterval(visibleDays) * HealthDetailChart.visibleDayLength)
            .chartScrollPosition(initialX: HealthDetailChart.leadingX(latest: latestDate, visibleDays: visibleDays))
    }
}
