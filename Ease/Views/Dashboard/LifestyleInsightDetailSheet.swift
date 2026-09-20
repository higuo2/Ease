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

                        VStack(alignment: .leading, spacing: 8) {
                            Text(insight.sampleSizeText())
                                .font(.caption2)
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                            Text("trend.insights.footnote")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                    }
                    .padding(20)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(.title2.weight(.semibold).monospacedDigit())
                .foregroundStyle(
                    insight.comparesWeight
                        ? EasePalette.semanticDelta(mean)
                        : EasePalette.primaryText
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            EasePalette.card,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(EasePalette.hairline, lineWidth: 1)
        }
    }

    private var adviceSection: some View {
        EaseCard(padding: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.body)
                    .foregroundStyle(EasePalette.accent)
                    .accessibilityHidden(true)
                Text(insight.actionAdvice())
                    .font(.subheadline)
                    .foregroundStyle(EasePalette.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
