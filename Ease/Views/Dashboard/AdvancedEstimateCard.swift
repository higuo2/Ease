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
        TrendHealthMetricCard(
            action: estimate == nil ? nil : { isDetailPresented = true },
            accessibilityHintKey: estimate == nil ? nil : "trend.forecast.openDetail.hint"
        ) {
            HStack(alignment: .center, spacing: 12) {
                TrendHealthIconBadge(systemName: "scalemass.fill", tint: .green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("trend.advanced.horizon")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(windowCaption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let estimate {
                    Text(EaseFormatters.advancedPaceHorizon(estimate.eta))
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                } else {
                    Text("trend.advanced.unavailable")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .sheet(isPresented: $isDetailPresented) {
            if let estimate {
                WeightForecastDetailSheet(estimate: estimate)
            }
        }
    }

    private var windowCaption: String {
        String(
            format: String(localized: "trend.forecast.basedOnWindow"),
            locale: .current,
            AdvancedPaceEstimator.lookbackDays
        )
    }
}
