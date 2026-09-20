import SwiftUI

struct AdvancedEstimateCard: View, Equatable {
    let snapshot: DashboardSnapshot?
    let estimate: AdvancedPaceEstimator.Result?
    @State private var isDetailPresented = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.estimate == rhs.estimate
            && lhs.snapshot?.targetWeight == rhs.snapshot?.targetWeight
            && lhs.snapshot?.displayWeight == rhs.snapshot?.displayWeight
            && lhs.snapshot?.progress == rhs.snapshot?.progress
    }

    var body: some View {
        EaseCard(padding: 24) {
            VStack(alignment: .leading, spacing: 12) {
                TrendAnalysisHeader(
                    title: "trend.advanced.title",
                    windowDays: AdvancedPaceEstimator.lookbackDays
                )

                if let estimate {
                    Button {
                        isDetailPresented = true
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text("trend.advanced.horizon")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 8)
                                Text(EaseFormatters.advancedPaceHorizon(estimate.eta))
                                    .font(.system(.body, design: .rounded, weight: .medium))
                                    .foregroundStyle(EasePalette.primaryText)
                                    .multilineTextAlignment(.trailing)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.85)
                            }
                            TrendEntryChevron()
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("trend.forecast.openDetail.hint"))
                    .sheet(isPresented: $isDetailPresented) {
                        WeightForecastDetailSheet(estimate: estimate)
                    }
                } else {
                    Text("trend.advanced.unavailable")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
