import SwiftUI
import UIKit

struct DashboardView: View {
    var body: some View {
        ZStack {
            Color(UIColor.secondarySystemBackground)
                .ignoresSafeArea()

            EaseCard {
                Text("dashboard.placeholder")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
        }
    }
}

#Preview {
    DashboardView()
}
