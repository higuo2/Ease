import SwiftUI

struct HealthInsightsCard: View {
    let insights: [HealthInsight]
    var calendar: Calendar = .current

    var body: some View {
        if !insights.isEmpty {
            EaseCard(padding: 20) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("trend.insights.title")
                        .font(.headline)
                        .foregroundStyle(EasePalette.primaryText)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(insights) { insight in
                            insightRow(insight)
                        }
                    }
                    .padding(.top, 14)

                    Text("trend.insights.footnote")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func insightRow(_ insight: HealthInsight) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insight.symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(iconColor(insight.kind))
                .frame(width: 18, alignment: .center)
                .padding(.top, 2)
            Text(insight.localizedBody(calendar: calendar))
                .font(.subheadline)
                .foregroundStyle(EasePalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func iconColor(_ kind: HealthInsight.Kind) -> Color {
        switch kind {
        case .shortSleepWeight, .weekdaySleep: EasePalette.iconSleep
        case .periodWeight: EasePalette.iconPeriod
        case .lowEnergyWeight: EasePalette.iconEnergy
        }
    }
}

struct HealthInsightNoteCard: View {
    let insight: HealthInsight
    var calendar: Calendar = .current

    var body: some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(insight.localizedBody(calendar: calendar))
                    .font(.subheadline)
                    .foregroundStyle(EasePalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("trend.insights.footnote")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}
