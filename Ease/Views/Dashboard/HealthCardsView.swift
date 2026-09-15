import SwiftUI

struct HealthCardsView: View {
    let record: DailyRecord?
    let health: HealthDaySnapshot?
    var onOpenSleep: () -> Void
    var onOpenCycle: () -> Void

    private var sleepHours: Double? { health?.previousNightSleepHours }
    private var energyKcal: Double? { health?.activeEnergyKcal }
    private var isPeriodDay: Bool {
        health?.isMenstrual == true || record?.variableTags.contains(.period) == true
    }

    var body: some View {
        VStack(spacing: 12) {
            if sleepHours != nil || isPeriodDay || energyKcal != nil {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 108), spacing: 12)],
                    spacing: 12
                ) {
                    if let sleepHours {
                        semanticCard(
                            fill: EasePalette.sleepMint,
                            symbol: "moon.fill",
                            titleKey: "health.sleep",
                            value: EaseFormatters.sleepDuration(sleepHours),
                            hintKey: "a11y.health.sleep.hint",
                            action: onOpenSleep
                        )
                    }
                    if isPeriodDay {
                        semanticCard(
                            fill: EasePalette.periodPink,
                            symbol: "drop.fill",
                            titleKey: "health.period",
                            value: nil,
                            hintKey: "a11y.health.period.hint",
                            action: onOpenCycle
                        )
                    }
                    if let energyKcal {
                        semanticCard(
                            fill: EasePalette.energyOrange,
                            symbol: "bolt.fill",
                            titleKey: "health.energy",
                            value: EaseFormatters.kcal(energyKcal),
                            hintKey: nil,
                            action: nil
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func semanticCard(
        fill: Color,
        symbol: String,
        titleKey: LocalizedStringKey,
        value: String?,
        hintKey: LocalizedStringKey?,
        action: (() -> Void)?
    ) -> some View {
        let card = EaseCard(
            fill: fill,
            accessibilityLabel: titleKey,
            accessibilityHint: hintKey,
            combinesChildren: true
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(EasePalette.primaryText)
                    .accessibilityHidden(true)
                Text(titleKey)
                    .font(.caption)
                    .foregroundStyle(EasePalette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if let value {
                    Text(value)
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(EasePalette.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if let action {
            card
                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .onTapGesture(perform: action)
                .accessibilityAddTraits(.isButton)
        } else {
            card
        }
    }
}
