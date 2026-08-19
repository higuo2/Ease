import SwiftUI

struct WeightSummaryCard: View {
    let weight: Double?
    let bodyFat: Double?
    let bmi: Double?

    var body: some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("dashboard.currentWeight")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
                if let weight {
                    Text(EaseFormatters.kg(weight))
                        .font(EaseFont.number(36))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                } else {
                    Text("dashboard.weightUnavailable")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(EasePalette.secondaryText)
                }
                if let bodyFat {
                    Text(EaseFormatters.bodyFat(bodyFat))
                        .font(.system(size: 16, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.secondaryText)
                }
                if let bmi {
                    Text(EaseFormatters.bmi(bmi))
                        .font(EaseFont.number(18, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
