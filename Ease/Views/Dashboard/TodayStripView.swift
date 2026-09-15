import SwiftUI

struct TodayStripView: View {
    let record: DailyRecord?
    let health: HealthDaySnapshot?

    var body: some View {
        EaseCard {
            HStack(spacing: 16) {
                if let hours = health?.previousNightSleepHours {
                    metricIcon(systemName: "moon.fill", text: EaseFormatters.hours(hours))
                }
                if let kcal = health?.activeEnergyKcal {
                    metricIcon(systemName: "bolt.fill", text: EaseFormatters.kcal(kcal))
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func metricIcon(systemName: String, text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(EasePalette.primaryText)
            Text(text)
                .font(.system(size: 11, weight: .regular))
                .monospacedDigit()
                .foregroundStyle(EasePalette.secondaryText)
        }
        .frame(minWidth: 44)
    }
}
