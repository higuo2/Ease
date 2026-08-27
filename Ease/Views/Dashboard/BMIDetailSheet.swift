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
                    VStack(spacing: 20) {
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
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Text("common.close")
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel(Text("bmi.sheet.info"))
                    .popover(isPresented: $showInfo) {
                        infoPopover
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
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

                VStack(alignment: .leading, spacing: 8) {
                    if let bmi {
                        Text(EaseFormatters.oneDecimal(bmi))
                            .font(EaseFont.number(44))
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
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(EasePalette.secondaryText)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(EasePalette.recessed, in: Capsule())
                    }
                }
                .accessibilityElement(children: .combine)

                BMIRangeBar(bmi: bmi, standard: standard, showsNeedle: verdict.showsNeedle)
            }
        }
    }

    private var inputsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            inputCell(
                symbol: "ruler",
                labelKey: "settings.height",
                value: heightCm > 0
                    ? "\(EaseFormatters.oneDecimal(heightCm)) \(String(localized: "unit.cm"))"
                    : String(localized: "bmi.input.heightMissing")
            )
            inputCell(
                symbol: "scalemass",
                labelKey: "module.weight",
                value: weightKg.map(EaseFormatters.kg) ?? String(localized: "module.noData")
            )
            inputCell(
                symbol: "birthday.cake",
                labelKey: "settings.birthDate",
                value: ageYears.map(EaseFormatters.ageYearsCompact) ?? String(localized: "bmi.input.ageUnknown")
            )
            inputCell(
                symbol: "person",
                labelKey: "settings.sex",
                value: String(localized: String.LocalizationValue(sex.titleKey))
            )
        }
    }

    private func inputCell(symbol: String, labelKey: LocalizedStringKey, value: String) -> some View {
        EaseCard(fill: EasePalette.recessed, radius: 16, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
                    .accessibilityHidden(true)
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(EasePalette.primaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(labelKey) + Text(", ") + Text(value))
    }

    private func rangeCard(_ range: (low: Double, high: Double)) -> some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("bmi.sheet.healthyRange")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
                Text(EaseFormatters.healthyWeightRange(low: range.low, high: range.high))
                    .font(EaseFont.number(22))
                    .monospacedDigit()
                    .foregroundStyle(EasePalette.primaryText)
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
