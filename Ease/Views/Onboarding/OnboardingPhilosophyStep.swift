import SwiftUI

struct OnboardingPhilosophyStep: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("onboarding.philosophy.title")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(EasePalette.primaryText)
            Text("onboarding.philosophy.subtitle")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(EasePalette.secondaryText)

            EaseCard {
                VStack(alignment: .leading, spacing: 16) {
                    principle(icon: "chart.line.uptrend.xyaxis", key: "onboarding.philosophy.point1")
                    principle(icon: "xmark.circle", key: "onboarding.philosophy.point2")
                    principle(icon: "person.2.slash", key: "onboarding.philosophy.point3")
                }
            }

            Spacer()
            EasePrimaryButton(title: "onboarding.continue", action: onContinue)
        }
    }

    private func principle(icon: String, key: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(EasePalette.accent)
                .frame(width: 24)
            Text(key)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(EasePalette.primaryText)
        }
    }
}
