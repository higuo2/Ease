import SwiftUI

struct HealthCardsView: View {
    let record: DailyRecord?
    let health: HealthDaySnapshot?
    let onOpenSleep: () -> Void
    let onOpenCycle: () -> Void

    private var sleepHours: Double? { health?.previousNightSleepHours }
    private var energyKcal: Double? { health?.activeEnergyKcal }
    private var isPeriodDay: Bool {
        health?.isMenstrual == true || record?.variableTags.contains(.period) == true
    }
    private var journalTags: [VariableTag] {
        (record?.variableTags ?? []).filter { $0 != .period }
    }

    var body: some View {
        VStack(spacing: 12) {
            if sleepHours != nil || isPeriodDay || energyKcal != nil {
                HStack(spacing: 12) {
                    if let sleepHours {
                        semanticCard(
                            fill: EasePalette.sleepMint,
                            symbol: "moon.fill",
                            titleKey: "health.sleep",
                            value: EaseFormatters.sleepDuration(sleepHours),
                            action: onOpenSleep
                        )
                    }
                    if isPeriodDay {
                        semanticCard(
                            fill: EasePalette.periodPink,
                            symbol: "drop.fill",
                            titleKey: "health.period",
                            value: nil,
                            action: onOpenCycle
                        )
                    }
                    if let energyKcal {
                        semanticCard(
                            fill: EasePalette.energyOrange,
                            symbol: "bolt.fill",
                            titleKey: "health.energy",
                            value: EaseFormatters.kcal(energyKcal),
                            action: nil
                        )
                    }
                }
            }
            dietStrip
        }
    }

    private var dietStrip: some View {
        EaseCard {
            HStack(spacing: 16) {
                if let diet = record?.dietStatus {
                    labeledIcon(systemName: diet.systemImage, labelKey: diet.titleKey)
                } else {
                    labeledIcon(systemName: "circle.dashed", labelKey: "today.dietPending")
                }
                ForEach(journalTags, id: \.self) { tag in
                    labeledIcon(systemName: tag.systemImage, labelKey: tag.titleKey)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func semanticCard(
        fill: Color,
        symbol: String,
        titleKey: LocalizedStringKey,
        value: String?,
        action: (() -> Void)?
    ) -> some View {
        let card = EaseCard(fill: fill) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(EasePalette.primaryText)
                Text(titleKey)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
                    .lineLimit(2)
                if let value {
                    Text(value)
                        .font(EaseFont.number(16))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        if let action {
            card
                .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .onTapGesture(perform: action)
                .accessibilityAddTraits(.isButton)
        } else {
            card
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
}
