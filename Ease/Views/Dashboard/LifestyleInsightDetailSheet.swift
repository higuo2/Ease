import SwiftUI

struct LifestyleInsightDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let insight: HealthInsight
    var calendar: Calendar = .current

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: EaseLayout.sectionSpacing) {
                        comparisonSection
                        adviceSection

                        TrendLegalFootnote("trend.insights.detailDisclaimer")
                            .padding(.top, 12)
                    }
                    .padding(20)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle(insight.cardDisplayTitle(calendar: calendar))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EaseCloseToolbarButton(action: { dismiss() })
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
        .preferredColorScheme(.light)
        .easeSheetPresentation()
    }

    private var comparisonSection: some View {
        HStack(alignment: .top, spacing: EaseLayout.gridGap) {
            comparisonCard(
                label: insight.inGroupLabel(calendar: calendar),
                value: insight.inValueText(),
                mean: insight.inMean
            )
            comparisonCard(
                label: insight.outGroupLabel(),
                value: insight.outValueText(),
                mean: insight.outMean
            )
        }
    }

    private func comparisonCard(label: String, value: String, mean: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(
                    insight.comparesWeight
                        ? EasePalette.semanticDelta(mean)
                        : EasePalette.primaryText
                )
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 20)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var adviceSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .font(.body)
                .foregroundStyle(tipAccent)
                .accessibilityHidden(true)
            Text(insight.actionAdvice())
                .font(.subheadline)
                .foregroundStyle(EasePalette.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            tipAccent.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var tipAccent: Color {
        switch insight.kind {
        case .shortSleepWeight, .weekdaySleep:
            return EasePalette.iconSleep
        case .periodWeight:
            return EasePalette.iconPeriod
        case .lowEnergyWeight:
            return EasePalette.iconEnergy
        }
    }
}
