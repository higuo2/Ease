import SwiftUI

struct HealthInsightsCard: View, Equatable {
    let insights: [HealthInsight]
    var calendar: Calendar = .current

    @State private var selectedInsight: HealthInsight?

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.insights == rhs.insights
    }

    var body: some View {
        if !insights.isEmpty {
            EaseCard(padding: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("trend.insights.title")
                            .font(.headline)
                            .foregroundStyle(EasePalette.primaryText)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                            if index > 0 {
                                Divider()
                                    .overlay(EasePalette.hairline)
                                    .padding(.vertical, 14)
                            }
                            insightRow(insight)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .sheet(item: $selectedInsight) { insight in
                LifestyleInsightDetailSheet(insight: insight, calendar: calendar)
            }
        }
    }

    private var subtitle: String {
        let count = insights.count
        let window = HealthInsightEngine.lookbackDays
        if count == 1 {
            return String(
                format: String(localized: "trend.insights.cardSubtitle.one"),
                locale: .current,
                window
            )
        }
        return String(
            format: String(localized: "trend.insights.cardSubtitle.many"),
            locale: .current,
            count,
            window
        )
    }

    private func insightRow(_ insight: HealthInsight) -> some View {
        Button {
            selectedInsight = insight
        } label: {
            HStack(alignment: .center, spacing: 12) {
                TrendTintIconTile(systemName: insight.symbolName, tint: iconColor(insight.kind))
                Text(insight.cardDisplayTitle(calendar: calendar))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(EasePalette.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(insight.deltaText())
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(heroColor(insight))
                    .contentTransition(.numericText())
                    .lineLimit(1)
                TrendEntryChevron()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(insight.accessibilitySummary(calendar: calendar))
        .accessibilityHint(Text("trend.insights.openDetail.hint"))
        .accessibilityAddTraits(.isButton)
    }

    private func heroColor(_ insight: HealthInsight) -> Color {
        insight.comparesWeight ? EasePalette.semanticDelta(insight.delta) : EasePalette.primaryText
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    TrendTintIconTile(systemName: insight.symbolName, tint: noteIconColor)
                    Text(insight.localizedHeadline(calendar: calendar))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(EasePalette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(insight.deltaText())
                        .font(.headline.weight(.bold).monospacedDigit())
                        .foregroundStyle(
                            insight.comparesWeight
                                ? EasePalette.semanticDelta(insight.delta)
                                : EasePalette.primaryText
                        )
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    noteCapsule(
                        label: insight.inGroupLabel(calendar: calendar),
                        value: insight.inValueText(),
                        mean: insight.inMean
                    )
                    noteCapsule(
                        label: insight.outGroupLabel(),
                        value: insight.outValueText(),
                        mean: insight.outMean
                    )
                }
                Text(insight.sampleSizeText())
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                TrendAnalysisFootnote()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(insight.accessibilitySummary(calendar: calendar))
    }

    private func noteCapsule(label: String, value: String, mean: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(EasePalette.secondaryText)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(insight.comparesWeight ? EasePalette.semanticDelta(mean) : EasePalette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            EasePalette.recessed,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private var noteIconColor: Color {
        switch insight.kind {
        case .shortSleepWeight, .weekdaySleep: EasePalette.iconSleep
        case .periodWeight: EasePalette.iconPeriod
        case .lowEnergyWeight: EasePalette.iconEnergy
        }
    }
}
