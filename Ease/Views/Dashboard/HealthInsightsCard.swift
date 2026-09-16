import SwiftUI

struct HealthInsightsCard: View {
    let insights: [HealthInsight]
    var calendar: Calendar = .current

    @State private var expandedID: String?

    var body: some View {
        if !insights.isEmpty {
            EaseCard(padding: 20) {
                VStack(alignment: .leading, spacing: 0) {
                    TrendAnalysisHeader(
                        title: "trend.insights.title",
                        windowDays: HealthInsightEngine.lookbackDays
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(insights.enumerated()), id: \.element.id) { index, insight in
                            if index > 0 {
                                Divider()
                                    .overlay(EasePalette.hairline)
                                    .padding(.vertical, 12)
                            }
                            insightRow(insight)
                        }
                    }
                    .padding(.top, 14)

                    TrendAnalysisFootnote()
                        .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(TrendAnalysisMotion.accordion, value: expandedID)
            }
            .sensoryFeedback(.selection, trigger: expandedID)
        }
    }

    private func insightRow(_ insight: HealthInsight) -> some View {
        let isExpanded = expandedID == insight.id
        return Button {
            withAnimation(TrendAnalysisMotion.accordion) {
                expandedID = isExpanded ? nil : insight.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    TrendTintIconTile(systemName: insight.symbolName, tint: iconColor(insight.kind))
                    Text(insight.localizedHeadline(calendar: calendar))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(EasePalette.primaryText)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    Text(insight.deltaText())
                        .font(.headline.weight(.bold).monospacedDigit())
                        .foregroundStyle(heroColor(insight))
                        .contentTransition(.numericText())
                        .lineLimit(1)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }

                if isExpanded {
                    comparisonCapsules(insight)
                    Text(insight.sampleSizeText())
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(TrendAnalysisMotion.accordion, value: isExpanded)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(insight.accessibilitySummary(calendar: calendar))
        .accessibilityHint(Text("trend.insights.row.hint"))
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(
            isExpanded
                ? Text("trend.insights.row.expanded")
                : Text("trend.insights.row.collapsed")
        )
    }

    private func comparisonCapsules(_ insight: HealthInsight) -> some View {
        HStack(spacing: 8) {
            metricCapsule(
                label: insight.inGroupLabel(calendar: calendar),
                value: insight.inValueText(),
                mean: insight.inMean,
                comparesWeight: insight.comparesWeight
            )
            metricCapsule(
                label: insight.outGroupLabel(),
                value: insight.outValueText(),
                mean: insight.outMean,
                comparesWeight: insight.comparesWeight
            )
        }
    }

    private func metricCapsule(
        label: String,
        value: String,
        mean: Double,
        comparesWeight: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(EasePalette.secondaryText)
                .lineLimit(1)
            Text(value)
                .font(.subheadline.weight(.medium).monospacedDigit())
                .foregroundStyle(comparesWeight ? EasePalette.semanticDelta(mean) : EasePalette.primaryText)
                .contentTransition(.numericText())
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
