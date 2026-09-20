import SwiftUI

struct BMIRangeBar: View {
    var bmi: Double?
    var standard: BMIStandard
    var showsNeedle: Bool

    private var fractions: [BMIBand: Double] {
        BMIClassifier.bandFractions(standard: standard)
    }

    var body: some View {
        VStack(spacing: 10) {
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
                        .fill(Color.white)
                        .frame(width: 4, height: 16)
                        .shadow(color: .black.opacity(0.22), radius: 1.5, y: 0.5)
                        .overlay {
                            Capsule()
                                .strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5)
                        }
                        .position(
                            x: needleX(bmi: bmi, width: width),
                            y: geo.size.height / 2
                        )
                        .animation(.snappy(duration: 0.28), value: bmi)
                        .animation(.snappy(duration: 0.28), value: standard)
                }
            }
            .frame(height: 14)

            HStack(spacing: 0) {
                ForEach(BMIBand.allCases, id: \.self) { band in
                    Text(LocalizedStringKey(band.titleKey))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(EasePalette.primaryText.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .animation(.snappy(duration: 0.25), value: standard)
        .accessibilityHidden(true)
    }

    private func fill(for band: BMIBand) -> Color {
        switch band {
        case .underweight:
            Color(red: 0.55, green: 0.72, blue: 0.92)
        case .normal:
            Color(red: 0.42, green: 0.78, blue: 0.55)
        case .overweight:
            Color(red: 0.96, green: 0.72, blue: 0.32)
        case .obese:
            Color(red: 0.93, green: 0.55, blue: 0.58)
        }
    }

    private func needleX(bmi: Double, width: CGFloat) -> CGFloat {
        let t = BMIClassifier.barFraction(bmi: bmi)
        return 2 + (width - 4) * t
    }
}
