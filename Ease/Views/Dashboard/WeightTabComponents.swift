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

/// Four equal Morandi squares: BMI · Measurements · Weight · Diet
struct HomeModuleGrid: View {
    let bmi: Double?
    let bodyFat: Double?
    let dietStatus: DietStatus?
    let onOpenMetrics: () -> Void
    let onOpenWeight: () -> Void
    let onOpenDiet: () -> Void

    private let spacing: CGFloat = 14

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing)
            ],
            spacing: spacing
        ) {
            moduleSquare(
                title: "grid.bmi",
                fill: EasePalette.morandiMist,
                action: nil
            ) {
                if let bmi {
                    Text(EaseFormatters.oneDecimal(bmi))
                        .font(EaseFont.number(28))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                    if let bodyFat {
                        Text(EaseFormatters.bodyFat(bodyFat))
                            .font(.system(size: 13, weight: .regular))
                            .monospacedDigit()
                            .foregroundStyle(EasePalette.secondaryText)
                    }
                } else {
                    Text("—")
                        .font(EaseFont.number(28))
                        .foregroundStyle(EasePalette.secondaryText)
                }
            }

            moduleSquare(
                title: "dashboard.metrics",
                fill: EasePalette.morandiBlush,
                action: onOpenMetrics
            ) {
                Image(systemName: "ruler")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(EasePalette.primaryText)
                Text("module.tapToLog")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
            }

            moduleSquare(
                title: "module.weight",
                fill: EasePalette.morandiSage,
                action: onOpenWeight
            ) {
                Image(systemName: "scalemass")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(EasePalette.primaryText)
                Text("module.tapToLog")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
            }

            moduleSquare(
                title: "module.diet",
                fill: EasePalette.morandiSand,
                action: onOpenDiet
            ) {
                Image(systemName: dietStatus?.systemImage ?? "fork.knife")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(EasePalette.primaryText)
                if let dietStatus {
                    Text(LocalizedStringKey(dietStatus.titleKey))
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                } else {
                    Text("module.tapToLog")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                }
            }
        }
    }

    private func moduleSquare<Content: View>(
        title: LocalizedStringKey,
        fill: Color,
        action: (() -> Void)?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(EasePalette.primaryText)
                Spacer(minLength: 0)
                content()
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .aspectRatio(1, contentMode: .fit)
            .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
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
