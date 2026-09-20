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
        TrendPremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                WeightForecastCardHeader()

                if let estimate {
                    WeightForecastActionRow(eta: estimate.eta) {
                        isDetailPresented = true
                    }
                    .sheet(isPresented: $isDetailPresented) {
                        WeightForecastDetailSheet(estimate: estimate)
                    }
                } else {
                    Text("trend.advanced.unavailable")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct WeightForecastCardHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("trend.advanced.title")
                .font(.headline)
                .foregroundStyle(EasePalette.primaryText)
            Text(windowCaption)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var windowCaption: String {
        String(
            format: String(localized: "trend.insights.window"),
            locale: .current,
            AdvancedPaceEstimator.lookbackDays
        )
    }
}

private struct WeightForecastActionRow: View {
    let eta: Date
    let action: () -> Void

    private var rowTint: Color { EasePalette.sleepTeal }

    var body: some View {
        Button(action: action) {
            TrendActionRow(tint: rowTint) {
                HStack(alignment: .center, spacing: 12) {
                    Text("trend.advanced.horizon")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(EaseFormatters.advancedPaceHorizon(eta))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    TrendEntryChevron()
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("trend.forecast.openDetail.hint"))
    }
}
