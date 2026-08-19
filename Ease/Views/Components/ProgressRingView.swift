import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    let lostKg: Double
    let remainingKg: Double
    let targetWeight: Double

    private var clamped: Double { min(max(progress, 0), 1) }
    private var isComplete: Bool { clamped >= 1 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(EasePalette.track, style: StrokeStyle(lineWidth: 12, lineCap: .round))
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(
                        colors: [EasePalette.accentSoft, EasePalette.accent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 6) {
                if isComplete {
                    Text(EaseFormatters.targetKg(targetWeight))
                        .font(EaseFont.number(22))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                        .multilineTextAlignment(.center)
                } else {
                    Text(EaseFormatters.lostKg(lostKg))
                        .font(EaseFont.number(20))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.primaryText)
                    Text(EaseFormatters.remainingKg(remainingKg))
                        .font(.system(size: 14, weight: .regular))
                        .monospacedDigit()
                        .foregroundStyle(EasePalette.secondaryText)
                }
            }
            .padding(.horizontal, 28)
        }
        .frame(width: 196, height: 196)
        .frame(maxWidth: .infinity)
    }
}
