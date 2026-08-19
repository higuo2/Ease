import SwiftUI

struct OnboardingMeasurementsStep: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                EaseTextButton(title: "onboarding.back", action: viewModel.goBack)
                Spacer()
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("onboarding.measurements.title")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(EasePalette.primaryText)
                    Text("onboarding.measurements.subtitle")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(EasePalette.secondaryText)

                    EaseCard {
                        VStack(spacing: 20) {
                            EaseField(
                                title: "onboarding.height",
                                placeholder: "onboarding.height.placeholder",
                                text: $viewModel.heightText,
                                suffix: "unit.cm"
                            )
                            EaseField(
                                title: "onboarding.currentWeight",
                                placeholder: "onboarding.weight.placeholder",
                                text: $viewModel.currentWeightText,
                                suffix: "unit.kg"
                            )
                            EaseField(
                                title: "onboarding.targetWeight",
                                placeholder: "onboarding.weight.placeholder",
                                text: $viewModel.targetWeightText,
                                suffix: "unit.kg"
                            )
                        }
                    }

                    if let errorKey = viewModel.errorKey {
                        Text(LocalizedStringKey(errorKey))
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(EasePalette.secondaryText)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            EasePrimaryButton(
                title: "onboarding.continue",
                isEnabled: viewModel.canContinueMeasurements,
                action: viewModel.goNextFromMeasurements
            )
        }
    }
}
