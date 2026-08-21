import SwiftUI

struct StageGoalCard: View {
    let progress: Double
    let startWeight: Double
    let targetWeight: Double
    let remainingKg: Double
    let paceLine: String?

    var body: some View {
        EaseRecessedCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("weight.stageGoal")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(EasePalette.primaryText)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(EasePalette.track)
                            .frame(height: 8)
                        Capsule()
                            .fill(EasePalette.coral)
                            .frame(width: max(8, geo.size.width * progress), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("weight.start")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(EasePalette.secondaryText)
                        Text(EaseFormatters.kg(startWeight))
                            .font(EaseFont.number(15))
                            .monospacedDigit()
                            .foregroundStyle(EasePalette.primaryText)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("weight.remaining")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(EasePalette.secondaryText)
                        Text(EaseFormatters.kg(remainingKg))
                            .font(EaseFont.number(15))
                            .monospacedDigit()
                            .foregroundStyle(EasePalette.coral)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("weight.target")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(EasePalette.secondaryText)
                        Text(EaseFormatters.kg(targetWeight))
                            .font(EaseFont.number(15))
                            .monospacedDigit()
                            .foregroundStyle(EasePalette.primaryText)
                    }
                }

                if let paceLine {
                    Text(paceLine)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                }
            }
        }
    }
}

struct HealthMetricGrid: View {
    let bmi: Double?
    let bodyFat: Double?
    let waterLine: String?
    let metricsEntry: String?
    let onOpenMetrics: () -> Void
    let onOpenWater: () -> Void

    private var cells: [(title: LocalizedStringKey, value: String, action: (() -> Void)?)] {
        var result: [(LocalizedStringKey, String, (() -> Void)?)] = []
        if let bmi {
            result.append(("grid.bmi", EaseFormatters.oneDecimal(bmi), nil))
        }
        if let bodyFat {
            result.append(("grid.bodyFat", String(format: "%.1f%%", locale: .current, bodyFat), nil))
        }
        if let waterLine {
            result.append(("grid.water", waterLine, onOpenWater))
        }
        if let metricsEntry {
            result.append(("dashboard.metrics", metricsEntry, onOpenMetrics))
        }
        return result
    }

    var body: some View {
        let items = cells
        if items.isEmpty {
            EmptyView()
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    Button {
                        item.action?()
                    } label: {
                        EaseRecessedCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.title)
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundStyle(EasePalette.secondaryText)
                                Text(item.value)
                                    .font(EaseFont.number(22))
                                    .monospacedDigit()
                                    .foregroundStyle(EasePalette.primaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(item.action == nil)
                }
            }
        }
    }
}

struct ShortcutCardsRow: View {
    let dietStatus: DietStatus?
    let waterSummary: String?
    let onWater: () -> Void
    let onDiet: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            shortcutCard(
                title: "shortcut.water",
                subtitle: waterSummary,
                systemImage: "drop",
                action: onWater
            )
            shortcutCard(
                title: "shortcut.diet",
                subtitle: nil,
                systemImage: dietStatus?.systemImage ?? "fork.knife",
                action: onDiet
            )
        }
    }

    private func shortcutCard(
        title: LocalizedStringKey,
        subtitle: String?,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            EaseCard {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(EasePalette.primaryText)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(EasePalette.secondaryText)
                        } else {
                            Image(systemName: systemImage)
                                .font(.system(size: 18, weight: .regular))
                                .foregroundStyle(EasePalette.secondaryText)
                        }
                    }
                    Spacer()
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(width: 28, height: 28)
                        .background(Color.black, in: Circle())
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct WeightHeroView: View {
    let weight: Double?
    let weekDelta: Double?

    var body: some View {
        VStack(spacing: 10) {
            if let weight {
                Text(EaseFormatters.kg(weight))
                    .font(EaseFont.hero(52))
                    .monospacedDigit()
                    .foregroundStyle(EasePalette.primaryText)
            } else {
                Text("dashboard.weightUnavailable")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(EasePalette.secondaryText)
            }
            if let weekDelta {
                HStack(spacing: 4) {
                    Image(systemName: weekDelta < 0 ? "arrow.down" : (weekDelta > 0 ? "arrow.up" : "minus"))
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(format: String(localized: "weight.weekDelta"), locale: .current, abs(weekDelta)))
                        .font(.system(size: 14, weight: .regular))
                        .monospacedDigit()
                }
                .foregroundStyle(EasePalette.deltaColor(weekDelta))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
