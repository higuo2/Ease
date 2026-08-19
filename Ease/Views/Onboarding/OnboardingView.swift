import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            EasePalette.background.ignoresSafeArea()
            VStack(spacing: 20) {
                stepDots
                    .padding(.top, 12)
                Group {
                    switch viewModel.step {
                    case .philosophy:
                        OnboardingPhilosophyStep(onContinue: viewModel.goNextFromPhilosophy)
                    case .measurements:
                        OnboardingMeasurementsStep(viewModel: viewModel)
                    case .permissions:
                        OnboardingPermissionsStep(
                            isBusy: viewModel.isBusy,
                            onBack: viewModel.goBack,
                            onContinue: {
                                Task { await viewModel.continueWithPermissions(context: modelContext) }
                            },
                            onSkip: {
                                viewModel.finish(context: modelContext, notificationsEnabled: false)
                            }
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: viewModel.step.rawValue)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .preferredColorScheme(.light)
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(1...3, id: \.self) { index in
                Capsule()
                    .fill(index <= viewModel.step.rawValue ? EasePalette.accent : EasePalette.track)
                    .frame(width: index == viewModel.step.rawValue ? 22 : 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text("onboarding.progress"))
    }
}

#Preview {
    OnboardingView()
        .modelContainer(EaseModelContainer.preview())
}
