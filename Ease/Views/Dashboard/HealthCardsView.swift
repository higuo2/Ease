import SwiftUI

struct HealthCardsView: View {
    let record: DailyRecord?
    let health: HealthDaySnapshot?
    var onOpenSleep: () -> Void
    var onOpenCycle: () -> Void
    var onEditJournal: (() -> Void)? = nil
    var onDeleteJournal: (() -> Void)? = nil

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
            dietStrip
        }
    }

    private var dietStrip: some View {
        let card = EaseCard(
            accessibilityLabel: dietAccessibilityLabel,
            accessibilityHint: onEditJournal == nil ? nil : "a11y.record.hint",
            combinesChildren: true
        ) {
            HStack(alignment: .top, spacing: 16) {
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

        return Group {
            if let onEditJournal {
                card.easeRecordContextMenu(
                    onEdit: onEditJournal,
                    onDelete: record == nil ? nil : onDeleteJournal
                )
            } else {
                card
            }
        }
    }

    private var dietAccessibilityLabel: LocalizedStringKey {
        if let diet = record?.dietStatus {
            LocalizedStringKey(diet.titleKey)
        } else {
            "today.dietPending"
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

    private func labeledIcon(systemName: String, labelKey: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .foregroundStyle(EasePalette.primaryText)
                .accessibilityHidden(true)
            Text(LocalizedStringKey(labelKey))
                .font(.caption)
                .foregroundStyle(EasePalette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minWidth: 44)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(LocalizedStringKey(labelKey)))
    }
}
