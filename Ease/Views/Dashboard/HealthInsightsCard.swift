import SwiftUI

struct HealthInsightsCard: View {
    let insights: [HealthInsight]
    var calendar: Calendar = .current

    @State private var expandedID: String?

    var body: some View {
        if !insights.isEmpty {
            EaseCard(padding: 20) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("trend.insights.title")
                        .font(.headline)
                        .foregroundStyle(EasePalette.primaryText)

                    Text(windowCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

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

                    Text("trend.insights.footnote")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 16)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .sensoryFeedback(.selection, trigger: expandedID)
        }
    }

    private var windowCaption: String {
        String(
            format: String(localized: "trend.insights.window"),
            locale: .current,
            HealthInsightEngine.lookbackDays
        )
    }

    private var windowDetail: String {
        String(
            format: String(localized: "trend.insights.window.detail"),
            locale: .current,
            HealthInsightEngine.lookbackDays
        )
    }

    private func insightRow(_ insight: HealthInsight) -> some View {
        let expanded = expandedID == insight.id
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                expandedID = expanded ? nil : insight.id
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    insightIcon(insight)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey(insight.titleKey))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(EasePalette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        comparisonBlock(insight)
                        Text(insight.sampleSizeText())
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                        .accessibilityHidden(true)
                }

                if expanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(windowDetail)
                        Text(insight.localizedDefinition(calendar: calendar))
                        Text("trend.insights.footnote")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(EasePalette.recessed, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(insight.comparesWeight ? EasePalette.semanticDelta(mean) : EasePalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func insightIcon(_ insight: HealthInsight) -> some View {
        let color = iconColor(insight.kind)
        return Image(systemName: insight.symbolName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 30, height: 30)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityHidden(true)
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
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: insight.symbolName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(noteIconColor)
                        .frame(width: 28, height: 28)
                        .background(
                            noteIconColor.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(insight.titleKey))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(EasePalette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(insight.localizedBody(calendar: calendar))
                            .font(.subheadline)
                            .foregroundStyle(EasePalette.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text("trend.insights.footnote")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var noteIconColor: Color {
        switch insight.kind {
        case .shortSleepWeight, .weekdaySleep: EasePalette.iconSleep
        case .periodWeight: EasePalette.iconPeriod
        case .lowEnergyWeight: EasePalette.iconEnergy
        }
    }
}
