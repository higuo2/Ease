import SwiftUI

struct EaseArcRing: View {
    let progress: Double
    let colors: [Color]
    var lineWidth: CGFloat = 12
    var diameter: CGFloat = 196

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(EasePalette.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            if clamped > 0 {
                ProgressRingArc(progress: clamped)
                    .stroke(
                        AngularGradient(
                            colors: colors,
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + 360 * clamped)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

struct ProgressRingView: View {
    let progress: Double
    let lostKg: Double
    let remainingKg: Double
    let targetWeight: Double

    private var clamped: Double { min(max(progress, 0), 1) }
    private var isComplete: Bool { clamped >= 1 }

    var body: some View {
        ZStack {
            EaseArcRing(
                progress: clamped,
                colors: [EasePalette.accentSoft, EasePalette.accent]
            )
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
        .frame(maxWidth: .infinity)
    }
}

/// Draws the progress arc as an explicit path so a small fraction (e.g. 2%)
/// cannot render as a full ring the way `Circle().trim()` + `AngularGradient` can.
private struct ProgressRingArc: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let lineWidth: CGFloat = 12
        let radius = max(0, min(rect.width, rect.height) / 2 - lineWidth / 2)
        var path = Path()
        guard progress > 0, radius > 0 else { return path }
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * min(max(progress, 0), 1)),
            clockwise: false
        )
        return path
    }
}
