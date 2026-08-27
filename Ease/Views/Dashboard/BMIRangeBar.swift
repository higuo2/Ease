import SwiftUI

struct BMIRangeBar: View {
    var bmi: Double?
    var standard: BMIStandard
    var showsNeedle: Bool

    private var fractions: [BMIBand: Double] {
        BMIClassifier.bandFractions(standard: standard)
    }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                HStack(spacing: 0) {
                    ForEach(BMIBand.allCases, id: \.self) { band in
                        Rectangle()
                            .fill(fill(for: band))
                            .frame(width: max(0, width * (fractions[band] ?? 0)))
                    }
                }
                .clipShape(Capsule())
                .opacity(showsNeedle ? 1 : 0.45)

                if showsNeedle, let bmi {
                    Capsule()
                        .fill(EasePalette.primaryText)
                        .frame(width: 3, height: 20)
                        .position(
                            x: needleX(bmi: bmi, width: width),
                            y: geo.size.height / 2
                        )
                }
            }
            .frame(height: 14)

            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(BMIBand.allCases, id: \.self) { band in
                        Text(LocalizedStringKey(band.titleKey))
                            .font(.caption2)
                            .foregroundStyle(EasePalette.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .multilineTextAlignment(.center)
                            .frame(width: max(0, geo.size.width * (fractions[band] ?? 0)))
                    }
                }
            }
            .frame(height: 16)
        }
        .animation(.snappy(duration: 0.25), value: standard)
        .accessibilityHidden(true)
    }

    private func fill(for band: BMIBand) -> Color {
        switch band {
        case .underweight: EasePalette.morandiMist
        case .normal: EasePalette.morandiSage
        case .overweight: EasePalette.morandiSand
        case .obese: EasePalette.morandiBlush
        }
    }

    private func needleX(bmi: Double, width: CGFloat) -> CGFloat {
        let t = BMIClassifier.barFraction(bmi: bmi)
        return 1.5 + (width - 3) * t
    }
}
