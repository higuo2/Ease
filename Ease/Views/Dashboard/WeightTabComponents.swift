import SwiftUI
import UIKit

struct StageGoalCard: View {
    let progress: Double
    let startWeight: Double
    let targetWeight: Double
    let remainingKg: Double
    let paceLine: String?
    var onTap: (() -> Void)? = nil

    @State private var animatedProgress: Double = 0
    @State private var selectionTick = 0

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    private var percentComplete: Int {
        Int((clampedProgress * 100).rounded())
    }

    private var currentWeight: Double {
        startWeight + (targetWeight - startWeight) * clampedProgress
    }

    var body: some View {
        Button {
            selectionTick += 1
            onTap?()
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                headerRow
                progressTrack
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(stageProgressLabel)
                milestoneFooter
                if let paceLine {
                    Text(paceLine)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: selectionTick)
        .onAppear {
            animatedProgress = 0
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = clampedProgress
            }
        }
        .onChange(of: progress) { _, _ in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animatedProgress = clampedProgress
            }
        }
    }

    private var headerRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("weight.stageGoal")
                .font(.headline)
                .foregroundStyle(EasePalette.primaryText)
            Spacer(minLength: 8)
            Text(verbatim: "\(percentComplete)%")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(EasePalette.primaryText)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(EasePalette.recessed, in: Capsule())
                .accessibilityHidden(true)
        }
    }

    private var progressTrack: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let fraction = min(max(animatedProgress, 0), 1)
            let fillWidth = width * fraction
            let thumbX = min(max(fillWidth, 7), max(width - 7, 7))

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.black.opacity(0.05))
                    .frame(height: 10)
                    .frame(maxHeight: .infinity, alignment: .center)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [EasePalette.accentSoft, EasePalette.accentWarm, EasePalette.coral],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(fillWidth, fraction > 0 ? 10 : 0), height: 10)
                    .frame(maxHeight: .infinity, alignment: .center)

                Text(EaseFormatters.kg(currentWeight))
                    .font(.caption2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(EasePalette.secondaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial, in: Capsule())
                    .position(
                        x: min(max(thumbX, 28), max(width - 28, 28)),
                        y: 8
                    )

                Circle()
                    .fill(Color.white)
                    .frame(width: 14, height: 14)
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
                    .position(x: thumbX, y: geo.size.height / 2)
            }
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animatedProgress)
        }
        .frame(height: 36)
    }

    private var milestoneFooter: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("weight.start")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(EaseFormatters.kg(startWeight))
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(EasePalette.primaryText)
                    .easeNumericText(startWeight)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(EaseFormatters.remainingKg(remainingKg))
                .font(.caption.weight(.semibold))
                .foregroundStyle(EasePalette.coral)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(EasePalette.coral.opacity(0.08), in: Capsule())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .easeNumericText(remainingKg)

            VStack(alignment: .trailing, spacing: 4) {
                Text("weight.target")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(EaseFormatters.kg(targetWeight))
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(EasePalette.primaryText)
                    .easeNumericText(targetWeight)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var stageProgressLabel: String {
        String(
            format: String(localized: "a11y.stageGoal"),
            locale: .current,
            percentComplete,
            EaseFormatters.kg(remainingKg)
        )
    }
}

struct HomeModuleGrid: View {
    let modules: [HomeModule]
    let bmi: Double?
    let bmiCategoryKey: String?
    let sleepHours: Double?
    let isPeriodDay: Bool
    let energyKcal: Double?
    let canAddMore: Bool
    let onOpenMetrics: () -> Void
    let onOpenWeight: () -> Void
    let onOpenSleep: () -> Void
    let onOpenPeriod: () -> Void
    let onOpenEnergy: () -> Void
    let onOpenBMI: () -> Void
    let onAddModule: () -> Void

    private let spacing: CGFloat = EaseLayout.gridGap

    var body: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: spacing),
                GridItem(.flexible(), spacing: spacing)
            ],
            spacing: spacing
        ) {
            ForEach(modules) { module in
                moduleTile(module)
            }
            if canAddMore {
                addTile
            }
        }
    }

    @ViewBuilder
    private func moduleTile(_ module: HomeModule) -> some View {
        switch module {
        case .bmi:
            square(module, action: onOpenBMI) {
                if let bmi {
                    Text(EaseFormatters.oneDecimal(bmi))
                        .font(EaseFont.number(28))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                        .easeNumericText(bmi)
                    if let bmiCategoryKey {
                        tileCaption(LocalizedStringKey(bmiCategoryKey))
                    }
                } else {
                    Text("—")
                        .font(EaseFont.number(28))
                        .foregroundStyle(EasePalette.secondaryText)
                }
            }
        case .measurements:
            square(module, action: onOpenMetrics) {
                Image(systemName: module.symbolName)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(EasePalette.primaryText)
                tileCaption("module.tapToLog")
            }
        case .weight:
            square(module, action: onOpenWeight) {
                Image(systemName: module.symbolName)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(EasePalette.primaryText)
                tileCaption("module.tapToLog")
            }
        case .diet:
            EmptyView()
        case .sleep:
            square(module, action: onOpenSleep) {
                if let sleepHours {
                    Text(EaseFormatters.sleepDuration(sleepHours))
                        .font(EaseFont.number(22))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                } else {
                    Image(systemName: module.symbolName)
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(EasePalette.primaryText)
                    tileCaption("module.noData")
                }
            }
        case .period:
            square(module, action: onOpenPeriod) {
                Image(systemName: module.symbolName)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(EasePalette.primaryText)
                tileCaption(isPeriodDay ? "module.period.today" : "module.noData")
            }
        case .energy:
            square(module, action: onOpenEnergy) {
                if let energyKcal {
                    Text(EaseFormatters.kcal(energyKcal))
                        .font(EaseFont.number(18))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                        .minimumScaleFactor(0.7)
                        .lineLimit(2)
                } else {
                    Image(systemName: module.symbolName)
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(EasePalette.primaryText)
                    tileCaption("module.noData")
                }
            }
        }
    }

    private var addTile: some View {
        Button(action: onAddModule) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(EasePalette.secondaryText)
                Text("module.add")
                    .font(.caption)
                    .foregroundStyle(EasePalette.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(EasePalette.hairline, style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
            )
        }
        .buttonStyle(.plain)
    }

    private func square<Content: View>(
        _ module: HomeModule,
        action: (() -> Void)?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button {
            action?()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(LocalizedStringKey(module.titleKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(EasePalette.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                content()
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .aspectRatio(1, contentMode: .fit)
            .background(module.fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private func tileCaption(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption)
            .foregroundStyle(EasePalette.secondaryText)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: true)
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
                    .easeNumericText(weight)
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
    }
}

struct HomeModuleEditor: View {
    @Binding var modules: [HomeModule]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("settings.homeModules")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(EasePalette.secondaryText)
            ForEach(HomeModule.selectable) { module in
                Toggle(isOn: binding(for: module)) {
                    Label {
                        Text(LocalizedStringKey(module.titleKey))
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(EasePalette.primaryText)
                    } icon: {
                        Image(systemName: module.symbolName)
                            .foregroundStyle(EasePalette.secondaryText)
                    }
                }
                .tint(EasePalette.coral)
            }
        }
    }

    private func binding(for module: HomeModule) -> Binding<Bool> {
        Binding(
            get: { modules.contains(module) },
            set: { isOn in
                if isOn {
                    if !modules.contains(module) { modules.append(module) }
                } else {
                    modules.removeAll { $0 == module }
                    if modules.isEmpty { modules = HomeModule.defaults }
                }
            }
        )
    }
}
