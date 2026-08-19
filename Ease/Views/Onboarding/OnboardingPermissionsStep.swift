import SwiftUI

struct OnboardingPermissionsStep: View {
    let isBusy: Bool
    let onBack: () -> Void
    let onContinue: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                EaseTextButton(title: "onboarding.back", action: onBack)
                    .disabled(isBusy)
                Spacer()
            }
            Text("onboarding.permissions.title")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(EasePalette.primaryText)
            Text("onboarding.permissions.subtitle")
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(EasePalette.secondaryText)

            EaseCard {
                VStack(alignment: .leading, spacing: 16) {
                    permissionRow(icon: "heart", title: "onboarding.permissions.health.title", detail: "onboarding.permissions.health.detail")
                    permissionRow(icon: "bell", title: "onboarding.permissions.notifications.title", detail: "onboarding.permissions.notifications.detail")
                }
            }

            Spacer()
            EasePrimaryButton(
                title: "onboarding.permissions.continue",
                isBusy: isBusy,
                action: onContinue
            )
            EaseTextButton(title: "onboarding.skip", action: onSkip)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
        }
    }

    private func permissionRow(icon: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(EasePalette.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(EasePalette.primaryText)
                Text(detail)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(EasePalette.secondaryText)
            }
        }
    }
}
