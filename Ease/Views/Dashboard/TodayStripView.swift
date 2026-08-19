import SwiftUI

struct TodayStripView: View {
    let record: DailyRecord?
    let health: HealthDaySnapshot?

    var body: some View {
        EaseCard {
            HStack(spacing: 16) {
                if let diet = record?.dietStatus {
                    labeledIcon(systemName: diet.systemImage, labelKey: diet.titleKey)
                } else {
                    labeledIcon(systemName: "circle.dashed", labelKey: "today.dietPending")
                }
                if let hours = health?.previousNightSleepHours {
                    metricIcon(systemName: "moon.fill", text: EaseFormatters.hours(hours))
                }
                if let kcal = health?.activeEnergyKcal {
                    metricIcon(systemName: "bolt.fill", text: EaseFormatters.kcal(kcal))
                }
                ForEach(HealthDisplay.tags(record: record, isMenstrual: health?.isMenstrual == true), id: \.self) { tag in
                    labeledIcon(systemName: tag.systemImage, labelKey: tag.titleKey)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func labeledIcon(systemName: String, labelKey: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(EasePalette.primaryText)
            Text(LocalizedStringKey(labelKey))
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(EasePalette.secondaryText)
        }
        .frame(minWidth: 44)
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
