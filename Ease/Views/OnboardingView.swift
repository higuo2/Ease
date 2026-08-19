import SwiftUI
import UIKit

struct OnboardingView: View {
    var body: some View {
        ZStack {
            Color(UIColor.secondarySystemBackground)
                .ignoresSafeArea()

            EaseCard {
                Text("onboarding.placeholder")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    OnboardingView()
}
