import SwiftUI

struct BMIDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let bmi: Double?
    let weightKg: Double?
    let heightCm: Double
    let bodyFat: Double?
    let birthDate: Date?
    let sex: BiologicalSex
    let now: Date

    private var verdict: BMIClassifier.Verdict {
        BMIClassifier.classify(bmi: bmi, birthDate: birthDate, now: now)
    }
    private var ageYears: Int? {
        guard let birthDate else { return nil }
        return BMIClassifier.ageYears(birthDate: birthDate, on: now)
    }
    private var healthyRange: (low: Double, high: Double)? {
        BMIClassifier.chinaHealthyWeightKg(heightCm: heightCm)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                EasePalette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 20) {
                        heroCard
                        inputsCard
                        formulaCard
                        chinaTableCard
                        whoTableCard
                        if let healthyRange {
                            rangeCard(healthyRange)
                        }
                        disclaimerCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle("bmi.sheet.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EaseTextButton(title: "common.close", action: { dismiss() })
                }
            }
            .toolbarBackground(EasePalette.background, for: .navigationBar)
        }
        .preferredColorScheme(.light)
    }

    private var heroCard: some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("grid.bmi")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
                if let bmi {
                    Text(EaseFormatters.oneDecimal(bmi))
                        .font(EaseFont.number(36))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                } else {
                    Text("module.noData")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(EasePalette.secondaryText)
                }
                if let key = verdict.titleKey {
                    Text(LocalizedStringKey(key))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(EasePalette.secondaryText)
                }
                Text("bmi.standard.china.inUse")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inputsCard: some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("bmi.sheet.inputs")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(EasePalette.primaryText)
                inputRow("settings.height") {
                    if heightCm > 0 {
                        HStack(spacing: 4) {
                            Text(EaseFormatters.oneDecimal(heightCm))
                                .monospacedDigit()
                            Text("unit.cm")
                        }
                    } else {
                        Text("bmi.input.heightMissing")
                    }
                }
                inputRow("module.weight") {
                    if let weightKg {
                        Text(EaseFormatters.kg(weightKg))
                    } else {
                        Text("module.noData")
                    }
                }
                inputRow("settings.birthDate") {
                    if let ageYears {
                        Text(EaseFormatters.ageYears(ageYears))
                    } else {
                        Text("bmi.input.ageUnknown")
                    }
                }
                inputRow("settings.sex") {
                    Text(LocalizedStringKey(sex.titleKey))
                }
                if let bodyFat {
                    inputRow("grid.bodyFat") {
                        Text(EaseFormatters.bodyFat(bodyFat))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var formulaCard: some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("bmi.sheet.formula")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(EasePalette.primaryText)
                Text("bmi.formula.body")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var chinaTableCard: some View {
        bandTable(
            titleKey: "bmi.standard.china",
            rangeKey: \.chinaRangeKey,
            current: {
                if case .band(let band, _) = verdict { return band }
                return nil
            }()
        )
    }

    private var whoTableCard: some View {
        bandTable(
            titleKey: "bmi.standard.who",
            rangeKey: \.whoRangeKey,
            current: bmi.map(BMIClassifier.whoBand)
        )
    }

    private func bandTable(
        titleKey: LocalizedStringKey,
        rangeKey: KeyPath<BMIBand, String>,
        current: BMIBand?
    ) -> some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(titleKey)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(EasePalette.primaryText)
                ForEach(BMIBand.allCases, id: \.self) { band in
                    HStack {
                        Text(LocalizedStringKey(band.titleKey))
                            .foregroundStyle(EasePalette.primaryText)
                        Spacer()
                        Text(LocalizedStringKey(band[keyPath: rangeKey]))
                            .monospacedDigit()
                            .foregroundStyle(EasePalette.secondaryText)
                    }
                    .font(.system(size: 14, weight: current == band ? .medium : .regular))
                }
            }
        }
    }

    private func rangeCard(_ range: (low: Double, high: Double)) -> some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("bmi.sheet.healthyRange")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(EasePalette.primaryText)
                Text(EaseFormatters.healthyWeightRange(low: range.low, high: range.high))
                    .font(.system(size: 16, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(EasePalette.primaryText)
                Text("bmi.sheet.healthyRange.footnote")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var disclaimerCard: some View {
        EaseCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("bmi.disclaimer")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
                if case .notApplicable = verdict {
                    Text("bmi.sheet.footnote.minor")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                } else if verdict.assumedAdult {
                    Text("bmi.sheet.footnote.ageUnknown")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inputRow(_ title: LocalizedStringKey, @ViewBuilder value: () -> some View) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(EasePalette.secondaryText)
            Spacer(minLength: 12)
            value()
                .foregroundStyle(EasePalette.primaryText)
                .multilineTextAlignment(.trailing)
        }
        .font(.system(size: 14, weight: .regular))
    }
}
