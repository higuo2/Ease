import SwiftUI

struct BMIDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bmi: Double?
    let weightKg: Double?
    let heightCm: Double
    let birthDate: Date?
    let sex: BiologicalSex
    let now: Date

    @State private var standard: BMIStandard = .china
    @State private var showInfo = false
    @State private var infoPulse = 0

    private var verdict: BMIClassifier.Verdict {
        BMIClassifier.classify(bmi: bmi, birthDate: birthDate, now: now, standard: standard)
    }
    private var ageYears: Int? {
        guard let birthDate else { return nil }
        return BMIClassifier.ageYears(birthDate: birthDate, on: now)
    }
    private var healthyRange: (low: Double, high: Double)? {
        if case .notApplicable = verdict { return nil }
        return BMIClassifier.healthyWeightKg(heightCm: heightCm, standard: standard)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        heroCard
                        inputsGrid
                        if let healthyRange {
                            rangeCard(healthyRange)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("bmi.sheet.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EaseCloseToolbarButton(action: { dismiss() })
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        infoPulse += 1
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel(Text("bmi.sheet.info"))
                    .popover(isPresented: $showInfo) {
                        infoPopover
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
            .sensoryFeedback(.impact(flexibility: .soft, intensity: 0.6), trigger: infoPulse)
        }
        .preferredColorScheme(.light)
    }

    private var heroCard: some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 16) {
                Picker("bmi.sheet.standard", selection: $standard) {
                    ForEach(BMIStandard.allCases) { option in
                        Text(LocalizedStringKey(option.pickerKey)).tag(option)
                    }
                }
                .pickerStyle(.segmented)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    if let bmi {
                        Text(EaseFormatters.oneDecimal(bmi))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(EasePalette.primaryText)
                            .easeNumericText(bmi)
                    } else {
                        Text("module.noData")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(EasePalette.secondaryText)
                    }

                    if let key = verdict.titleKey {
                        Text(LocalizedStringKey(key))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(statusForeground)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(statusBackground, in: Capsule())
                    }
                }
                .accessibilityElement(children: .combine)

                BMIRangeBar(bmi: bmi, standard: standard, showsNeedle: verdict.showsNeedle)
            }
        }
    }

    private var statusForeground: Color {
        switch verdict {
        case .band(.underweight, _): Color(red: 0.22, green: 0.45, blue: 0.78)
        case .band(.normal, _): Color(red: 0.18, green: 0.55, blue: 0.32)
        case .band(.overweight, _): Color(red: 0.72, green: 0.45, blue: 0.08)
        case .band(.obese, _): Color(red: 0.72, green: 0.28, blue: 0.35)
        default: EasePalette.secondaryText
        }
    }

    private var statusBackground: Color {
        switch verdict {
        case .band(.underweight, _): Color.blue.opacity(0.15)
        case .band(.normal, _): Color.green.opacity(0.15)
        case .band(.overweight, _): Color.orange.opacity(0.15)
        case .band(.obese, _): Color.pink.opacity(0.15)
        default: EasePalette.recessed
        }
    }

    private var inputsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            metricTile(
                symbol: "ruler",
                labelKey: "settings.height",
                value: heightCm > 0
                    ? "\(EaseFormatters.oneDecimal(heightCm)) \(String(localized: "unit.cm"))"
                    : String(localized: "bmi.input.heightMissing")
            )
            metricTile(
                symbol: "scalemass",
                labelKey: "module.weight",
                value: weightKg.map(EaseFormatters.kg) ?? String(localized: "module.noData")
            )
            metricTile(
                symbol: "birthday.cake",
                labelKey: "bmi.metric.age",
                value: ageYears.map(EaseFormatters.ageYearsYrs) ?? String(localized: "bmi.input.ageUnknown")
            )
            metricTile(
                symbol: "person",
                labelKey: "settings.sex",
                value: String(localized: String.LocalizationValue(sex.titleKey))
            )
        }
    }

    private func metricTile(symbol: String, labelKey: LocalizedStringKey, value: String) -> some View {
        EaseCard(fill: EasePalette.card, radius: 16, padding: 14) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(EasePalette.secondaryText)
                    .frame(width: 28, height: 28)
                    .background(
                        Color(red: 242 / 255, green: 243 / 255, blue: 245 / 255),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(labelKey)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(value)
                        .font(.callout.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(labelKey) + Text(", ") + Text(value))
    }

    private func rangeCard(_ range: (low: Double, high: Double)) -> some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("bmi.sheet.healthyRange")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(EasePalette.secondaryText)
                Text(EaseFormatters.healthyWeightRange(low: range.low, high: range.high))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(EasePalette.primaryText)

                IdealWeightRangeBar(
                    low: range.low,
                    high: range.high,
                    current: weightKg
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var infoPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("bmi.formula.body")
            Text("bmi.disclaimer")
            if case .notApplicable = verdict {
                Text("bmi.sheet.footnote.minor")
            } else if verdict.assumedAdult {
                Text("bmi.sheet.footnote.ageUnknown")
            }
        }
        .font(.system(size: 14, weight: .regular))
        .foregroundStyle(EasePalette.secondaryText)
        .padding(20)
        .frame(maxWidth: 320, alignment: .leading)
    }
}

private struct IdealWeightRangeBar: View {
    let low: Double
    let high: Double
    let current: Double?

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let pad = max((high - low) * 0.35, 2)
            let start = low - pad
            let end = high + pad
            let span = max(end - start, 0.001)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(EasePalette.recessed)
                    .frame(height: 8)

                Capsule()
                    .fill(Color.green.opacity(0.35))
                    .frame(width: max(4, width * CGFloat((high - low) / span)), height: 8)
                    .offset(x: width * CGFloat((low - start) / span))

                if let current {
                    let clamped = min(max(current, start), end)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay {
                            Circle().strokeBorder(Color.white, lineWidth: 2)
                        }
                        .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)
                        .offset(x: width * CGFloat((clamped - start) / span) - 6)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 16)
        .accessibilityHidden(true)
    }
}
