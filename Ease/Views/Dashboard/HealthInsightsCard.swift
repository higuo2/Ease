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
        let expanded = expandedID == insight.id
        return Button {
            withAnimation(TrendAnalysisMotion.accordion) {
                expandedID = expanded ? nil : insight.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    TrendTintIconTile(systemName: insight.symbolName, tint: iconColor(insight.kind))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(insight.titleKey))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(EasePalette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        if !expanded {
                            Text(insight.inValueText())
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(
                                    insight.comparesWeight
                                        ? EasePalette.semanticDelta(insight.inMean)
                                        : EasePalette.primaryText
                                )
                                .contentTransition(.numericText())
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }

                if expanded {
                    comparisonBlock(insight)
                    Text(insight.sampleSizeText())
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                    Text(insight.localizedDefinition(calendar: calendar))
                        .font(.caption)
                        .foregroundStyle(EasePalette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(insight.accessibilitySummary(calendar: calendar))
        .accessibilityHint(Text("trend.insights.row.hint"))
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(
            expanded
                ? Text("trend.insights.row.expanded")
                : Text("trend.insights.row.collapsed")
        )
    }

    private func comparisonBlock(_ insight: HealthInsight) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                groupValue(insight, isInGroup: true)
                groupValue(insight, isInGroup: false)
            }
            VStack(alignment: .leading, spacing: 8) {
                groupValue(insight, isInGroup: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                groupValue(insight, isInGroup: false)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func groupValue(_ insight: HealthInsight, isInGroup: Bool) -> some View {
        let label = isInGroup
            ? insight.inGroupLabel(calendar: calendar)
            : insight.outGroupLabel()
        let value = isInGroup ? insight.inValueText() : insight.outValueText()
        let mean = isInGroup ? insight.inMean : insight.outMean
        return VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(EasePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(insight.comparesWeight ? EasePalette.semanticDelta(mean) : EasePalette.primaryText)
                .contentTransition(.numericText())
                .fixedSize(horizontal: false, vertical: true)
        }
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(insight.titleKey))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(EasePalette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                HStack(alignment: .top, spacing: 12) {
                    noteMetric(label: insight.inGroupLabel(calendar: calendar), value: insight.inValueText(), mean: insight.inMean, comparesWeight: insight.comparesWeight)
                    noteMetric(label: insight.outGroupLabel(), value: insight.outValueText(), mean: insight.outMean, comparesWeight: insight.comparesWeight)
                }
                TrendAnalysisFootnote()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(insight.accessibilitySummary(calendar: calendar))
    }

    private func noteMetric(label: String, value: String, mean: Double, comparesWeight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(EasePalette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(comparesWeight ? EasePalette.semanticDelta(mean) : EasePalette.primaryText)
        }
    }

    private var noteIconColor: Color {
        switch insight.kind {
        case .shortSleepWeight, .weekdaySleep: EasePalette.iconSleep
        case .periodWeight: EasePalette.iconPeriod
        case .lowEnergyWeight: EasePalette.iconEnergy
        }
    }
}
